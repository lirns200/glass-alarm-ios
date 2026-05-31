#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

RUN_URL_RE = re.compile(r"https://github\.com/[^\s]+/actions/runs/\d+")
RUN_ID_RE = re.compile(r"/actions/runs/(?P<id>\d+)")
REPO_RE = re.compile(r"github\.com/(?P<repo>[^/]+/[^/]+)/actions/runs/")
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


@dataclass
class BuildSettings:
    project_dir: Path
    builder_path: Path
    workspace_dir: Path
    signed: bool
    timeout: str | None
    diagnostics: bool
    final_output_dir: Path | None


@dataclass
class WizardActions:
    init_if_missing: bool
    auth_github: bool
    init_project_name: str | None
    init_scheme: str | None


@dataclass
class RunPaths:
    run_dir: Path
    logs_dir: Path
    artifacts_dir: Path
    builder_log: Path
    diagnostics_log: Path
    errors_file: Path
    summary_file: Path


@dataclass
class RunResult:
    code: int
    lines: list[str]
    seconds: float


# --------------------------------
# IO helpers
# --------------------------------


def clean_line(value: str) -> str:
    return ANSI_RE.sub("", value).rstrip("\n\r")


def append_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", errors="replace") as f:
        f.write(text)


def print_section(title: str) -> None:
    print(f"\n{'=' * 12} {title} {'=' * 12}")


def safe_console_write(text: str, end: str = "") -> None:
    value = text + end
    try:
        print(text, end=end)
    except UnicodeEncodeError:
        encoding = getattr(sys.stdout, "encoding", None) or "utf-8"
        safe = value.encode(encoding, errors="replace").decode(encoding, errors="replace")
        sys.stdout.write(safe)


# --------------------------------
# CLI / Wizard
# --------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Автоматическая remote-сборка iOS IPA через builder.exe"
    )
    parser.add_argument("--interactive", action="store_true", help="Пошаговый CMD-мастер")
    parser.add_argument("--project-dir", default=".", help="Папка проекта")
    parser.add_argument("--builder", default="builder.exe", help="Путь к builder.exe")
    parser.add_argument("--workspace-dir", default="ipa_build_workspace", help="Отдельная папка для run-логов и IPA")
    parser.add_argument("--signed", action="store_true", help="Собрать signed IPA")
    parser.add_argument("--timeout", default=None, help="Таймаут builder, например 45m")
    parser.add_argument("--no-diagnostics", action="store_true", help="Не запрашивать GitHub-диагностику")
    parser.add_argument(
        "-o",
        "--output",
        dest="final_output",
        default=None,
        help="Куда дополнительно скопировать финальный IPA",
    )

    parser.add_argument("--init-if-missing", action="store_true", help="Выполнить builder init при отсутствии builder.json")
    parser.add_argument("--auth-github", action="store_true", help="Выполнить builder auth github перед сборкой")
    parser.add_argument("--init-project", default=None, help="project name для builder init")
    parser.add_argument("--init-scheme", default=None, help="scheme для builder init")
    return parser.parse_args()


def normalize_input_path(value: str) -> str:
    return value.strip().strip('"').strip("'")


def ask_text(prompt: str, default: str | None = None, required: bool = True) -> str:
    while True:
        suffix = f" [{default}]" if default else ""
        raw = input(f"{prompt}{suffix}: ").strip()
        if raw:
            return raw
        if default is not None:
            return default
        if not required:
            return ""
        print("  -> Поле обязательно")


def ask_yes_no(prompt: str, default: bool = True) -> bool:
    hint = "Y/n" if default else "y/N"
    while True:
        raw = input(f"{prompt} ({hint}): ").strip().lower()
        if not raw:
            return default
        if raw in {"y", "yes", "д", "да"}:
            return True
        if raw in {"n", "no", "н", "нет"}:
            return False
        print("  -> Введите y или n")


def ask_existing_dir(prompt: str, default: Path) -> Path:
    while True:
        entered = ask_text(prompt, str(default))
        path = Path(normalize_input_path(entered)).expanduser().resolve()
        if path.exists() and path.is_dir():
            return path
        print(f"  -> Папка не найдена: {path}")


def ask_existing_file(prompt: str, default: Path) -> Path:
    while True:
        entered = ask_text(prompt, str(default))
        path = Path(normalize_input_path(entered)).expanduser().resolve()
        if path.exists() and path.is_file():
            return path
        print(f"  -> Файл не найден: {path}")


def interactive_wizard() -> tuple[BuildSettings, WizardActions]:
    print("\n" + "=" * 74)
    print("        IPA Builder Wizard (CMD) — всё в отдельной папке")
    print("=" * 74)

    project_dir = ask_existing_dir("Введите путь к папке проекта", Path.cwd())
    builder_path = ask_existing_file("Введите путь к builder.exe", project_dir / "builder.exe")
    workspace_dir = Path(normalize_input_path(ask_text(
        "Папка для run-логов и артефактов",
        str(project_dir / "ipa_build_workspace"),
    ))).expanduser().resolve()

    signed = ask_yes_no("Собрать SIGNED IPA? (иначе будет unsigned)", default=False)
    timeout_text = ask_text("Таймаут builder (например 45m, пусто = default)", default="", required=False).strip()
    diagnostics = ask_yes_no("Показывать GitHub-диагностику при ошибке", default=True)

    final_output_dir: Path | None = None
    if ask_yes_no("Копировать финальный IPA в отдельную папку?", default=False):
        final_output_dir = Path(normalize_input_path(ask_text("Куда копировать финальный IPA"))).expanduser().resolve()

    builder_json = project_dir / "builder.json"
    init_if_missing = False
    init_project_name: str | None = None
    init_scheme: str | None = None

    if not builder_json.exists():
        print("\n[!] builder.json не найден")
        init_if_missing = ask_yes_no("Сделать builder init автоматически?", default=True)
        if init_if_missing:
            init_project_name = ask_text("Project name для builder init", project_dir.name)
            init_scheme = ask_text("Scheme для builder init", project_dir.name)

    auth_github = ask_yes_no("Сделать builder auth github перед сборкой", default=False)

    print("\nПроверьте настройки:")
    print(f"  Проект:            {project_dir}")
    print(f"  builder.exe:       {builder_path}")
    print(f"  Рабочая папка run: {workspace_dir}")
    print(f"  Тип сборки:        {'SIGNED' if signed else 'UNSIGNED'}")
    print(f"  Таймаут:           {timeout_text or 'по умолчанию'}")
    print(f"  Диагностика:       {'да' if diagnostics else 'нет'}")
    print(f"  Final output:      {final_output_dir or '-'}")
    print(f"  init if missing:   {'да' if init_if_missing else 'нет'}")
    print(f"  auth github:       {'да' if auth_github else 'нет'}")

    if not ask_yes_no("Запустить сборку сейчас?", default=True):
        print("Отменено пользователем")
        sys.exit(0)

    settings = BuildSettings(
        project_dir=project_dir,
        builder_path=builder_path,
        workspace_dir=workspace_dir,
        signed=signed,
        timeout=timeout_text or None,
        diagnostics=diagnostics,
        final_output_dir=final_output_dir,
    )
    actions = WizardActions(
        init_if_missing=init_if_missing,
        auth_github=auth_github,
        init_project_name=init_project_name,
        init_scheme=init_scheme,
    )
    return settings, actions


def settings_from_args(args: argparse.Namespace) -> tuple[BuildSettings, WizardActions]:
    project_dir = Path(normalize_input_path(args.project_dir)).expanduser().resolve()
    if not project_dir.exists() or not project_dir.is_dir():
        raise ValueError(f"Папка проекта не найдена: {project_dir}")

    builder_path = Path(normalize_input_path(args.builder)).expanduser()
    if not builder_path.is_absolute():
        builder_path = project_dir / builder_path
    builder_path = builder_path.resolve()
    if not builder_path.exists() or not builder_path.is_file():
        raise ValueError(f"builder.exe не найден: {builder_path}")

    workspace_dir = Path(normalize_input_path(args.workspace_dir)).expanduser()
    if not workspace_dir.is_absolute():
        workspace_dir = project_dir / workspace_dir
    workspace_dir = workspace_dir.resolve()

    final_output_dir: Path | None = None
    if args.final_output:
        final_output_dir = Path(normalize_input_path(args.final_output)).expanduser()
        if not final_output_dir.is_absolute():
            final_output_dir = project_dir / final_output_dir
        final_output_dir = final_output_dir.resolve()

    settings = BuildSettings(
        project_dir=project_dir,
        builder_path=builder_path,
        workspace_dir=workspace_dir,
        signed=bool(args.signed),
        timeout=args.timeout,
        diagnostics=not bool(args.no_diagnostics),
        final_output_dir=final_output_dir,
    )
    actions = WizardActions(
        init_if_missing=bool(args.init_if_missing),
        auth_github=bool(args.auth_github),
        init_project_name=args.init_project,
        init_scheme=args.init_scheme,
    )
    return settings, actions


# --------------------------------
# Run folder / command execution
# --------------------------------


def create_run_paths(workspace_dir: Path) -> RunPaths:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir = workspace_dir / f"run-{timestamp}"
    logs_dir = run_dir / "logs"
    artifacts_dir = run_dir / "artifacts"

    logs_dir.mkdir(parents=True, exist_ok=True)
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    return RunPaths(
        run_dir=run_dir,
        logs_dir=logs_dir,
        artifacts_dir=artifacts_dir,
        builder_log=logs_dir / "builder.log.txt",
        diagnostics_log=logs_dir / "github_diagnostics.log.txt",
        errors_file=logs_dir / "errors_summary.txt",
        summary_file=run_dir / "summary.json",
    )


def run_command(cmd: list[str], cwd: Path, log_file: Path, label: str) -> RunResult:
    start = time.time()
    append_text(log_file, f"[{datetime.now().isoformat()}] STEP: {label}\n")
    append_text(log_file, f"CMD: {' '.join(cmd)}\n\n")

    process = subprocess.Popen(
        cmd,
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    lines: list[str] = []
    assert process.stdout is not None

    for raw in process.stdout:
        safe_console_write(raw)
        line = clean_line(raw)
        lines.append(line)
        append_text(log_file, line + "\n")

    process.wait()
    seconds = time.time() - start
    append_text(log_file, f"\nExit code: {process.returncode}\nDuration: {seconds:.1f}s\n")
    return RunResult(code=process.returncode, lines=lines, seconds=seconds)


def run_step(title: str, cmd: list[str], cwd: Path, log_file: Path) -> RunResult:
    print_section(title)
    print("Command:", " ".join(cmd))
    return run_command(cmd, cwd, log_file, title)


# --------------------------------
# Parsing / diagnostics
# --------------------------------


def extract_run_context(lines: Iterable[str]) -> dict[str, str] | None:
    text = "\n".join(lines)
    matches = RUN_URL_RE.findall(text)
    if not matches:
        return None

    run_url = matches[-1]
    run_match = RUN_ID_RE.search(run_url)
    repo_match = REPO_RE.search(run_url)
    if not run_match or not repo_match:
        return None

    return {
        "run_url": run_url,
        "run_id": run_match.group("id"),
        "repo": repo_match.group("repo"),
    }


def github_get_json(url: str, token: str | None) -> object:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "IPA-Build-Wizard",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = Request(url, headers=headers)
    with urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def show_github_failure_details(repo: str, run_id: str, diagnostics_log: Path) -> list[str]:
    token = os.environ.get("GITHUB_TOKEN")
    collected: list[str] = []

    jobs_url = f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/jobs"
    append_text(diagnostics_log, f"Jobs URL: {jobs_url}\n")

    try:
        jobs_payload = github_get_json(jobs_url, token)
    except (HTTPError, URLError, TimeoutError, OSError) as err:
        msg = f"[warn] Не удалось получить jobs: {err}"
        print(msg)
        append_text(diagnostics_log, msg + "\n")
        collected.append(msg)
        return collected

    jobs = jobs_payload.get("jobs", []) if isinstance(jobs_payload, dict) else []
    if not jobs:
        msg = "[warn] В jobs нет данных"
        print(msg)
        append_text(diagnostics_log, msg + "\n")
        collected.append(msg)
        return collected

    print_section("GitHub failure details")
    append_text(diagnostics_log, "\n=== GitHub failure details ===\n")

    for job in jobs:
        line = f"Job: {job.get('name', '<unknown>')} | Conclusion: {job.get('conclusion', '<unknown>')}"
        print(line)
        append_text(diagnostics_log, line + "\n")

        failed_steps = [s for s in job.get("steps", []) if s.get("conclusion") == "failure"]
        for step in failed_steps:
            s_line = f"  Failed step: {step.get('number')} - {step.get('name')}"
            print(s_line)
            append_text(diagnostics_log, s_line + "\n")
            collected.append(s_line)

        check_url = job.get("check_run_url")
        if not check_url:
            continue

        try:
            check_run = github_get_json(check_url, token)
            annotations_url = (
                check_run.get("output", {}).get("annotations_url")
                if isinstance(check_run, dict)
                else None
            )
            if not annotations_url:
                continue

            annotations = github_get_json(annotations_url, token)
            if not isinstance(annotations, list):
                continue

            for note in annotations:
                level = str(note.get("annotation_level", "")).lower()
                if level in {"failure", "warning"}:
                    msg = f"  [{level.upper()}] {note.get('message', '')}"
                    print(msg)
                    append_text(diagnostics_log, msg + "\n")
                    collected.append(msg)
        except (HTTPError, URLError, TimeoutError, OSError) as err:
            msg = f"  [warn] Не удалось загрузить annotations: {err}"
            print(msg)
            append_text(diagnostics_log, msg + "\n")
            collected.append(msg)

    return collected


def collect_error_summary(builder_lines: list[str], diagnostic_lines: list[str]) -> list[str]:
    patterns = [
        re.compile(r"\berror:\b", re.IGNORECASE),
        re.compile(r"\bfailed\b", re.IGNORECASE),
        re.compile(r"exit code", re.IGNORECASE),
        re.compile(r"\bFAILURE\b", re.IGNORECASE),
        re.compile(r"timed out", re.IGNORECASE),
        re.compile(r"could not", re.IGNORECASE),
        re.compile(r"not found", re.IGNORECASE),
    ]

    merged = [clean_line(x) for x in (builder_lines + diagnostic_lines)]
    result: list[str] = []
    seen: set[str] = set()

    for line in merged:
        if not line.strip():
            continue
        if any(p.search(line) for p in patterns):
            if line not in seen:
                result.append(line)
                seen.add(line)

    return result[:50]


# --------------------------------
# Build flow
# --------------------------------


def format_mb(size_bytes: int) -> str:
    return f"{size_bytes / (1024 * 1024):.2f} MB"


def find_latest_ipa(directory: Path) -> Path | None:
    if not directory.exists():
        return None
    files = list(directory.glob("*.ipa"))
    if not files:
        return None
    return max(files, key=lambda p: p.stat().st_mtime)


def maybe_init_builder(settings: BuildSettings, actions: WizardActions, paths: RunPaths) -> int:
    builder_json = settings.project_dir / "builder.json"
    if builder_json.exists() or not actions.init_if_missing:
        return 0

    project_name = actions.init_project_name or settings.project_dir.name
    scheme = actions.init_scheme or settings.project_dir.name

    cmd = [
        str(settings.builder_path),
        "init",
        "-p",
        project_name,
        "--scheme",
        scheme,
    ]
    result = run_step("Builder init", cmd, settings.project_dir, paths.builder_log)
    return result.code


def maybe_auth_github(settings: BuildSettings, actions: WizardActions, paths: RunPaths) -> int:
    if not actions.auth_github:
        return 0

    cmd = [str(settings.builder_path), "auth", "github"]
    result = run_step("Builder GitHub auth", cmd, settings.project_dir, paths.builder_log)
    return result.code


def run_build(settings: BuildSettings, paths: RunPaths) -> tuple[int, dict[str, str] | None, list[str], list[str], Path | None, Path | None]:
    cmd = [
        str(settings.builder_path),
        "ios",
        "build",
        "-o",
        str(paths.artifacts_dir),
    ]
    if not settings.signed:
        cmd.append("--unsigned")
    if settings.timeout:
        cmd.extend(["--timeout", settings.timeout])

    result = run_step("Starting iOS build", cmd, settings.project_dir, paths.builder_log)
    context = extract_run_context(result.lines)

    if context:
        run_line = f"GitHub run: {context['run_url']}"
        print("\n" + run_line)
        append_text(paths.builder_log, "\n" + run_line + "\n")

    diagnostic_lines: list[str] = []
    if result.code != 0 and context and settings.diagnostics:
        diagnostic_lines = show_github_failure_details(context["repo"], context["run_id"], paths.diagnostics_log)

    latest_ipa = find_latest_ipa(paths.artifacts_dir)
    copied_ipa: Path | None = None

    if result.code == 0 and latest_ipa and settings.final_output_dir:
        settings.final_output_dir.mkdir(parents=True, exist_ok=True)
        copied_ipa = settings.final_output_dir / latest_ipa.name
        shutil.copy2(latest_ipa, copied_ipa)

    return result.code, context, result.lines, diagnostic_lines, latest_ipa, copied_ipa


def save_summary(
    paths: RunPaths,
    settings: BuildSettings,
    actions: WizardActions,
    code: int,
    context: dict[str, str] | None,
    latest_ipa: Path | None,
    copied_ipa: Path | None,
    error_lines: list[str],
) -> None:
    payload = {
        "timestamp": datetime.now().isoformat(),
        "status": "success" if code == 0 else "failed",
        "exit_code": code,
        "project_dir": str(settings.project_dir),
        "builder_path": str(settings.builder_path),
        "workspace_dir": str(settings.workspace_dir),
        "run_dir": str(paths.run_dir),
        "artifacts_dir": str(paths.artifacts_dir),
        "builder_log": str(paths.builder_log),
        "diagnostics_log": str(paths.diagnostics_log),
        "errors_file": str(paths.errors_file),
        "summary_file": str(paths.summary_file),
        "signed": settings.signed,
        "timeout": settings.timeout,
        "diagnostics_enabled": settings.diagnostics,
        "final_output_dir": str(settings.final_output_dir) if settings.final_output_dir else None,
        "copied_ipa": str(copied_ipa) if copied_ipa else None,
        "latest_ipa": str(latest_ipa) if latest_ipa else None,
        "run_context": context,
        "actions": {
            "init_if_missing": actions.init_if_missing,
            "auth_github": actions.auth_github,
            "init_project_name": actions.init_project_name,
            "init_scheme": actions.init_scheme,
        },
        "error_summary": error_lines,
    }
    paths.summary_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


# --------------------------------
# Main
# --------------------------------


def main() -> int:
    args = parse_args()

    try:
        if args.interactive or len(sys.argv) == 1:
            settings, actions = interactive_wizard()
        else:
            settings, actions = settings_from_args(args)
    except ValueError as err:
        print(f"[error] {err}")
        return 1

    settings.workspace_dir.mkdir(parents=True, exist_ok=True)
    paths = create_run_paths(settings.workspace_dir)

    print_section("Run folder")
    print(f"Все артефакты этого запуска: {paths.run_dir}")
    print(f"Лог builder: {paths.builder_log}")

    init_code = maybe_init_builder(settings, actions, paths)
    if init_code != 0:
        errors = [f"Builder init завершился с кодом {init_code}"]
        paths.errors_file.write_text("\n".join(errors) + "\n", encoding="utf-8")
        save_summary(paths, settings, actions, init_code, None, None, None, errors)
        print_section("Ошибки (в конце)")
        for i, e in enumerate(errors, start=1):
            print(f"{i}. {e}")
        print(f"\nLogs: {paths.logs_dir}")
        return init_code

    auth_code = maybe_auth_github(settings, actions, paths)
    if auth_code != 0:
        errors = [f"builder auth github завершился с кодом {auth_code}"]
        paths.errors_file.write_text("\n".join(errors) + "\n", encoding="utf-8")
        save_summary(paths, settings, actions, auth_code, None, None, None, errors)
        print_section("Ошибки (в конце)")
        for i, e in enumerate(errors, start=1):
            print(f"{i}. {e}")
        print(f"\nLogs: {paths.logs_dir}")
        return auth_code

    code, context, builder_lines, diag_lines, latest_ipa, copied_ipa = run_build(settings, paths)
    error_lines = collect_error_summary(builder_lines, diag_lines) if code != 0 else []

    if error_lines:
        paths.errors_file.write_text("\n".join(error_lines) + "\n", encoding="utf-8")
    else:
        paths.errors_file.write_text("Ошибок не обнаружено.\n", encoding="utf-8")

    save_summary(paths, settings, actions, code, context, latest_ipa, copied_ipa, error_lines)

    print_section("Итог")
    print(f"Статус: {'SUCCESS' if code == 0 else 'FAILED'}")
    print(f"Run dir: {paths.run_dir}")
    print(f"Builder log: {paths.builder_log}")
    print(f"Diagnostics log: {paths.diagnostics_log}")
    print(f"Errors summary: {paths.errors_file}")
    print(f"Summary json: {paths.summary_file}")

    if latest_ipa:
        print(f"IPA: {latest_ipa} ({format_mb(latest_ipa.stat().st_size)})")
    else:
        print("IPA: не найден")

    if copied_ipa:
        print(f"Скопировано в: {copied_ipa}")

    if code != 0:
        print_section("Ошибки (в конце)")
        if error_lines:
            for i, line in enumerate(error_lines, start=1):
                print(f"{i}. {line}")
        else:
            print("Подробности смотри в логах.")

    return code


if __name__ == "__main__":
    sys.exit(main())
