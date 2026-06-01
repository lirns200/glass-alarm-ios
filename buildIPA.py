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
class Config:
    project_dir: Path
    builder_path: Path
    workspace_dir: Path
    output_dir: Path
    signed: bool
    timeout: str | None
    diagnostics: bool
    skip_auth: bool
    skip_git: bool
    no_push: bool
    dry_run: bool
    init_project: str | None
    init_scheme: str | None


@dataclass
class Paths:
    run_dir: Path
    logs_dir: Path
    artifacts_dir: Path
    builder_log: Path
    diagnostics_log: Path
    errors_log: Path
    summary_json: Path


@dataclass
class CmdResult:
    code: int
    lines: list[str]


def setup_console_utf8() -> None:
    if os.name == "nt":
        os.system("chcp 65001 > nul")
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except Exception:
                pass


def safe_print(text: str = "") -> None:
    try:
        print(text)
    except UnicodeEncodeError:
        enc = getattr(sys.stdout, "encoding", None) or "utf-8"
        fallback = text.encode(enc, errors="replace").decode(enc, errors="replace")
        print(fallback)


def append_line(path: Path, text: str = "") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", errors="replace") as f:
        f.write(text + "\n")


def strip_ansi(value: str) -> str:
    return ANSI_RE.sub("", value).rstrip("\r\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Полностью автоматическая сборка IPA через GitHub Actions"
    )
    parser.add_argument("--project-dir", default=".", help="Путь к папке проекта")
    parser.add_argument("--builder", default="builder.exe", help="Путь к builder.exe")
    parser.add_argument("--workspace", default="ipa_build_workspace", help="Папка для run-логов и артефактов")
    parser.add_argument("--output", default="dist", help="Куда копировать итоговый IPA")
    parser.add_argument("--signed", action="store_true", help="Собрать signed IPA")
    parser.add_argument("--timeout", default=None, help="Таймаут builder, пример: 45m")
    parser.add_argument("--no-diagnostics", action="store_true", help="Не запрашивать GitHub-диагностику")
    parser.add_argument("--skip-auth", action="store_true", help="Пропустить builder auth github")
    parser.add_argument("--skip-git", action="store_true", help="Пропустить commit/push")
    parser.add_argument("--no-push", action="store_true", help="Сделать commit, но не делать push")
    parser.add_argument("--dry-run", action="store_true", help="Показать действия без выполнения")
    parser.add_argument("--init-project", default=None, help="Project name для builder init")
    parser.add_argument("--init-scheme", default=None, help="Scheme для builder init")
    return parser.parse_args()


def resolve_config(args: argparse.Namespace) -> Config:
    project_dir = Path(args.project_dir).expanduser().resolve()
    if not project_dir.exists() or not project_dir.is_dir():
        raise ValueError(f"Папка проекта не найдена: {project_dir}")

    builder_path = Path(args.builder).expanduser()
    if not builder_path.is_absolute():
        builder_path = project_dir / builder_path
    builder_path = builder_path.resolve()
    if not builder_path.exists():
        raise ValueError(f"builder.exe не найден: {builder_path}")

    workspace_dir = Path(args.workspace).expanduser()
    if not workspace_dir.is_absolute():
        workspace_dir = project_dir / workspace_dir
    workspace_dir = workspace_dir.resolve()

    output_dir = Path(args.output).expanduser()
    if not output_dir.is_absolute():
        output_dir = project_dir / output_dir
    output_dir = output_dir.resolve()

    return Config(
        project_dir=project_dir,
        builder_path=builder_path,
        workspace_dir=workspace_dir,
        output_dir=output_dir,
        signed=bool(args.signed),
        timeout=args.timeout,
        diagnostics=not bool(args.no_diagnostics),
        skip_auth=bool(args.skip_auth),
        skip_git=bool(args.skip_git),
        no_push=bool(args.no_push),
        dry_run=bool(args.dry_run),
        init_project=args.init_project,
        init_scheme=args.init_scheme,
    )


def create_paths(workspace_dir: Path) -> Paths:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir = workspace_dir / f"run-{stamp}"
    logs_dir = run_dir / "logs"
    artifacts_dir = run_dir / "artifacts"
    logs_dir.mkdir(parents=True, exist_ok=True)
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    return Paths(
        run_dir=run_dir,
        logs_dir=logs_dir,
        artifacts_dir=artifacts_dir,
        builder_log=logs_dir / "builder.log.txt",
        diagnostics_log=logs_dir / "github_diagnostics.log.txt",
        errors_log=logs_dir / "errors_summary.txt",
        summary_json=run_dir / "summary.json",
    )


def run_command(cmd: list[str], cwd: Path, log_path: Path, dry_run: bool, label: str) -> CmdResult:
    append_line(log_path, f"[{datetime.now().isoformat()}] STEP: {label}")
    append_line(log_path, "CMD: " + " ".join(cmd))
    append_line(log_path)

    if dry_run:
        safe_print(f"[DRY RUN] {' '.join(cmd)}")
        append_line(log_path, "DRY RUN: команда не выполнялась")
        append_line(log_path)
        return CmdResult(code=0, lines=["DRY RUN"])

    proc = subprocess.Popen(
        cmd,
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    out_lines: list[str] = []
    assert proc.stdout is not None
    for raw in proc.stdout:
        line = strip_ansi(raw)
        safe_print(line)
        out_lines.append(line)
        append_line(log_path, line)

    proc.wait()
    append_line(log_path)
    append_line(log_path, f"Exit code: {proc.returncode}")
    append_line(log_path)
    return CmdResult(code=proc.returncode, lines=out_lines)


def extract_run_context(lines: Iterable[str]) -> dict[str, str] | None:
    text = "\n".join(lines)
    urls = RUN_URL_RE.findall(text)
    if not urls:
        return None

    run_url = urls[-1]
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
        "User-Agent": "buildIPA-auto-script",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = Request(url, headers=headers)
    with urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def ensure_builder_initialized(config: Config, paths: Paths) -> int:
    builder_json = config.project_dir / "builder.json"
    workflow = config.project_dir / ".github" / "workflows" / "ios-build.yml"

    if builder_json.exists() and workflow.exists():
        safe_print("[OK] builder.json и workflow уже существуют")
        return 0

    project_name = config.init_project or config.project_dir.name
    scheme = config.init_scheme or config.project_dir.name

    safe_print("[INFO] Не хватает builder-конфига, запускаю builder init...")
    cmd = [str(config.builder_path), "init", "-p", project_name, "--scheme", scheme]
    result = run_command(cmd, config.project_dir, paths.builder_log, config.dry_run, "builder init")
    return result.code


def ensure_github_auth(config: Config, paths: Paths) -> int:
    if config.skip_auth:
        safe_print("[INFO] Пропускаю builder auth github (--skip-auth)")
        return 0

    safe_print("[INFO] Проверяю/выполняю builder auth github...")
    cmd = [str(config.builder_path), "auth", "github"]
    result = run_command(cmd, config.project_dir, paths.builder_log, config.dry_run, "builder auth github")
    return result.code


def is_git_repo(config: Config, paths: Paths) -> bool:
    result = run_command(["git", "rev-parse", "--is-inside-work-tree"], config.project_dir, paths.builder_log, config.dry_run, "check git repo")
    return result.code == 0


def git_current_branch(config: Config, paths: Paths) -> str | None:
    result = run_command(["git", "rev-parse", "--abbrev-ref", "HEAD"], config.project_dir, paths.builder_log, config.dry_run, "get current branch")
    if result.code != 0 or not result.lines:
        return None
    return result.lines[-1].strip()


def git_has_origin(config: Config, paths: Paths) -> bool:
    result = run_command(["git", "remote", "get-url", "origin"], config.project_dir, paths.builder_log, config.dry_run, "check origin remote")
    return result.code == 0


def sync_git(config: Config, paths: Paths) -> int:
    if config.skip_git:
        safe_print("[INFO] Пропускаю git commit/push (--skip-git)")
        return 0

    if not is_git_repo(config, paths):
        safe_print("[WARN] Это не git-репозиторий, пропускаю git sync")
        return 0

    if not git_has_origin(config, paths):
        safe_print("[WARN] Не найден remote origin, пропускаю push")
        return 0

    # Стадия всех файлов в папке проекта
    add_cmd = ["git", "add", "."]
    add_result = run_command(add_cmd, config.project_dir, paths.builder_log, config.dry_run, "git add all")
    if add_result.code != 0:
        return add_result.code

    check_staged = run_command(["git", "diff", "--cached", "--name-only"], config.project_dir, paths.builder_log, config.dry_run, "git diff --cached")
    if check_staged.code != 0:
        return check_staged.code

    if check_staged.lines and check_staged.lines != ["DRY RUN"]:
        msg = f"chore: auto sync ipa build files ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})"
        commit_result = run_command(["git", "commit", "-m", msg], config.project_dir, paths.builder_log, config.dry_run, "git commit")
        if commit_result.code != 0:
            return commit_result.code
    else:
        safe_print("[INFO] Нет новых staged-изменений для commit")

    if config.no_push:
        safe_print("[INFO] Пропускаю push (--no-push)")
        return 0

    branch = git_current_branch(config, paths)
    if not branch:
        safe_print("[WARN] Не удалось определить branch, пропускаю push")
        return 0

    push_result = run_command(["git", "push", "origin", branch], config.project_dir, paths.builder_log, config.dry_run, "git push")
    return push_result.code


def run_build(config: Config, paths: Paths) -> CmdResult:
    cmd = [str(config.builder_path), "ios", "build", "-o", str(paths.artifacts_dir)]
    if not config.signed:
        cmd.append("--unsigned")
    if config.timeout:
        cmd.extend(["--timeout", config.timeout])

    return run_command(cmd, config.project_dir, paths.builder_log, config.dry_run, "builder ios build")


def find_latest_ipa(path: Path) -> Path | None:
    files = list(path.glob("*.ipa"))
    if not files:
        return None
    return max(files, key=lambda p: p.stat().st_mtime)


def fetch_diagnostics(context: dict[str, str], paths: Paths, enabled: bool, dry_run: bool) -> list[str]:
    if dry_run:
        return ["DRY RUN: диагностика не выполнялась"]
    if not enabled:
        return ["Диагностика отключена"]

    token = os.environ.get("GITHUB_TOKEN")
    lines: list[str] = []
    jobs_url = f"https://api.github.com/repos/{context['repo']}/actions/runs/{context['run_id']}/jobs"

    try:
        payload = github_get_json(jobs_url, token)
        jobs = payload.get("jobs", []) if isinstance(payload, dict) else []
    except (HTTPError, URLError, TimeoutError, OSError) as err:
        msg = f"Не удалось получить jobs: {err}"
        lines.append(msg)
        append_line(paths.diagnostics_log, msg)
        return lines

    for job in jobs:
        job_line = f"Job: {job.get('name')} | Conclusion: {job.get('conclusion')}"
        lines.append(job_line)
        append_line(paths.diagnostics_log, job_line)

        for step in job.get("steps", []):
            if step.get("conclusion") == "failure":
                s = f"Failed step: {step.get('number')} - {step.get('name')}"
                lines.append(s)
                append_line(paths.diagnostics_log, s)

        check_url = job.get("check_run_url")
        if not check_url:
            continue

        try:
            check_payload = github_get_json(check_url, token)
            annotations_url = (
                check_payload.get("output", {}).get("annotations_url")
                if isinstance(check_payload, dict)
                else None
            )
            if not annotations_url:
                continue
            annotations = github_get_json(annotations_url, token)
            if not isinstance(annotations, list):
                continue
            for note in annotations:
                lvl = str(note.get("annotation_level", "")).lower()
                if lvl in {"failure", "warning"}:
                    m = f"[{lvl.upper()}] {note.get('message', '')}"
                    lines.append(m)
                    append_line(paths.diagnostics_log, m)
        except (HTTPError, URLError, TimeoutError, OSError) as err:
            e = f"Не удалось загрузить annotations: {err}"
            lines.append(e)
            append_line(paths.diagnostics_log, e)

    return lines


def summarize_errors(build_lines: list[str], diag_lines: list[str]) -> list[str]:
    patterns = [
        re.compile(r"\berror\b", re.IGNORECASE),
        re.compile(r"\bfailed\b", re.IGNORECASE),
        re.compile(r"exit code", re.IGNORECASE),
        re.compile(r"timed out", re.IGNORECASE),
        re.compile(r"not found", re.IGNORECASE),
        re.compile(r"could not", re.IGNORECASE),
    ]

    items: list[str] = []
    seen: set[str] = set()
    for line in [*build_lines, *diag_lines]:
        clean = line.strip()
        if not clean:
            continue
        if any(p.search(clean) for p in patterns):
            if clean not in seen:
                seen.add(clean)
                items.append(clean)

    return items[:50]


def save_summary(paths: Paths, config: Config, status: str, exit_code: int, run_context: dict[str, str] | None, ipa_path: Path | None, copied_to: Path | None, errors: list[str]) -> None:
    payload = {
        "timestamp": datetime.now().isoformat(),
        "status": status,
        "exit_code": exit_code,
        "project_dir": str(config.project_dir),
        "builder_path": str(config.builder_path),
        "workspace_dir": str(config.workspace_dir),
        "run_dir": str(paths.run_dir),
        "artifacts_dir": str(paths.artifacts_dir),
        "builder_log": str(paths.builder_log),
        "diagnostics_log": str(paths.diagnostics_log),
        "errors_log": str(paths.errors_log),
        "output_dir": str(config.output_dir),
        "latest_ipa": str(ipa_path) if ipa_path else None,
        "copied_to": str(copied_to) if copied_to else None,
        "run_context": run_context,
        "errors": errors,
    }
    paths.summary_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    setup_console_utf8()

    try:
        config = resolve_config(parse_args())
    except Exception as err:
        safe_print(f"[ОШИБКА] {err}")
        return 1

    config.workspace_dir.mkdir(parents=True, exist_ok=True)
    config.output_dir.mkdir(parents=True, exist_ok=True)

    paths = create_paths(config.workspace_dir)

    safe_print("=" * 70)
    safe_print("Автоматическая сборка IPA (GitHub + проверка + логи)")
    safe_print("=" * 70)
    safe_print(f"Проект:   {config.project_dir}")
    safe_print(f"builder:  {config.builder_path}")
    safe_print(f"run dir:  {paths.run_dir}")
    safe_print(f"output:   {config.output_dir}")
    safe_print(f"режим:    {'SIGNED' if config.signed else 'UNSIGNED'}")

    t0 = time.time()

    # 1) init missing files
    code = ensure_builder_initialized(config, paths)
    if code != 0:
        errors = [f"builder init завершился с кодом {code}"]
        paths.errors_log.write_text("\n".join(errors) + "\n", encoding="utf-8")
        save_summary(paths, config, "failed", code, None, None, None, errors)
        safe_print("\nОшибки в конце:")
        for i, e in enumerate(errors, 1):
            safe_print(f"{i}. {e}")
        return code

    # 2) auth
    code = ensure_github_auth(config, paths)
    if code != 0:
        errors = [f"builder auth github завершился с кодом {code}"]
        paths.errors_log.write_text("\n".join(errors) + "\n", encoding="utf-8")
        save_summary(paths, config, "failed", code, None, None, None, errors)
        safe_print("\nОшибки в конце:")
        for i, e in enumerate(errors, 1):
            safe_print(f"{i}. {e}")
        return code

    # 3) commit/push
    code = sync_git(config, paths)
    if code != 0:
        errors = [f"git sync завершился с кодом {code}"]
        paths.errors_log.write_text("\n".join(errors) + "\n", encoding="utf-8")
        save_summary(paths, config, "failed", code, None, None, None, errors)
        safe_print("\nОшибки в конце:")
        for i, e in enumerate(errors, 1):
            safe_print(f"{i}. {e}")
        return code

    # 4) build
    build = run_build(config, paths)
    run_context = extract_run_context(build.lines)

    diag_lines: list[str] = []
    if build.code != 0 and run_context:
        diag_lines = fetch_diagnostics(run_context, paths, config.diagnostics, config.dry_run)

    latest_ipa = find_latest_ipa(paths.artifacts_dir)
    copied_to: Path | None = None
    if build.code == 0 and latest_ipa is not None:
        copied_to = config.output_dir / latest_ipa.name
        if not config.dry_run:
            shutil.copy2(latest_ipa, copied_to)

    # 5) final logs
    if build.code == 0:
        paths.errors_log.write_text("Ошибок не обнаружено.\n", encoding="utf-8")
        save_summary(paths, config, "success", 0, run_context, latest_ipa, copied_to, [])

        safe_print("\nСБОРКА УСПЕШНА")
        if run_context:
            safe_print(f"GitHub run: {run_context['run_url']}")
        if latest_ipa:
            size_mb = latest_ipa.stat().st_size / (1024 * 1024)
            safe_print(f"IPA (run): {latest_ipa}")
            safe_print(f"Размер: {size_mb:.2f} MB")
        if copied_to:
            safe_print(f"IPA (копия): {copied_to}")

        safe_print(f"\nЛоги: {paths.logs_dir}")
        safe_print(f"summary.json: {paths.summary_json}")
        safe_print(f"Время: {time.time() - t0:.1f} сек")
        return 0

    errors = summarize_errors(build.lines, diag_lines)
    if not errors:
        errors = ["Сборка завершилась с ошибкой. Смотри логи."]

    paths.errors_log.write_text("\n".join(errors) + "\n", encoding="utf-8")
    save_summary(paths, config, "failed", build.code, run_context, latest_ipa, copied_to, errors)

    safe_print("\nСБОРКА УПАЛА")
    if run_context:
        safe_print(f"GitHub run: {run_context['run_url']}")

    safe_print("\nОшибки в конце:")
    for i, err in enumerate(errors, 1):
        safe_print(f"{i}. {err}")

    safe_print(f"\nПодробные логи: {paths.logs_dir}")
    safe_print(f"summary.json: {paths.summary_json}")
    safe_print(f"Время: {time.time() - t0:.1f} сек")
    return build.code


if __name__ == "__main__":
    sys.exit(main())
