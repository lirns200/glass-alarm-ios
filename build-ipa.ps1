param(
    [switch]$Signed,
    [string]$Output = "dist"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Section([string]$text) {
    ""
    "==== $text ===="
}

function Get-RunContext([string[]]$BuilderOutput) {
    $line = ($BuilderOutput | Select-String -Pattern "https://github\.com/[^\s]+/actions/runs/\d+" -AllMatches).Matches.Value | Select-Object -Last 1
    if (-not $line) {
        return $null
    }

    $runMatch = [regex]::Match($line, "/actions/runs/(?<id>\d+)")
    $repoMatch = [regex]::Match($line, "github\.com/(?<repo>[^/]+/[^/]+)/actions/runs/")

    if (-not $runMatch.Success -or -not $repoMatch.Success) {
        return $null
    }

    [PSCustomObject]@{
        RunUrl = $line
        RunId  = $runMatch.Groups["id"].Value
        Repo   = $repoMatch.Groups["repo"].Value
    }
}

function Show-GitHubFailureDetails([string]$Repo, [string]$RunId) {
    $headers = @{ "User-Agent" = "GlassAlarmBuilder" }

    Write-Section "Fetching failure details from GitHub"

    $jobsUrl = "https://api.github.com/repos/$Repo/actions/runs/$RunId/jobs"
    $jobs = Invoke-RestMethod -Headers $headers -Uri $jobsUrl

    foreach ($job in $jobs.jobs) {
        "Job: $($job.name) | Conclusion: $($job.conclusion)"

        $failedSteps = @($job.steps | Where-Object { $_.conclusion -eq "failure" })
        foreach ($step in $failedSteps) {
            "  Failed step: $($step.number) - $($step.name)"
        }

        if ($job.check_run_url) {
            $checkRun = Invoke-RestMethod -Headers $headers -Uri $job.check_run_url
            $annotationsUrl = $checkRun.output.annotations_url

            if ($annotationsUrl) {
                $annotations = Invoke-RestMethod -Headers $headers -Uri $annotationsUrl
                foreach ($note in $annotations) {
                    if ($note.annotation_level -eq "failure" -or $note.annotation_level -eq "warning") {
                        "  [$($note.annotation_level.ToUpper())] $($note.message)"
                    }
                }
            }
        }
    }
}

$builderPath = Join-Path $PSScriptRoot "builder.exe"
if (-not (Test-Path -LiteralPath $builderPath)) {
    throw "builder.exe not found at: $builderPath"
}

$buildArgs = @("ios", "build", "-o", $Output)
if (-not $Signed) {
    $buildArgs += "--unsigned"
}

Write-Section "Starting iOS build"
"Command: .\\builder.exe $($buildArgs -join ' ')"

$builderOutput = & $builderPath @buildArgs 2>&1
$exitCode = $LASTEXITCODE

$builderOutput | ForEach-Object { $_ }

$runContext = Get-RunContext -BuilderOutput $builderOutput
if ($runContext) {
    ""
    "GitHub run: $($runContext.RunUrl)"
}

if ($exitCode -ne 0) {
    Write-Section "Build failed"

    if ($runContext) {
        try {
            Show-GitHubFailureDetails -Repo $runContext.Repo -RunId $runContext.RunId
        } catch {
            "Could not fetch detailed failure diagnostics: $($_.Exception.Message)"
        }
    } else {
        "Could not detect GitHub run URL from builder output."
    }

    exit $exitCode
}

Write-Section "Build succeeded"
$distPath = Join-Path $PSScriptRoot $Output
if (Test-Path -LiteralPath $distPath) {
    $latestIpa = Get-ChildItem -LiteralPath $distPath -Filter "*.ipa" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestIpa) {
        "Latest IPA: $($latestIpa.FullName)"
        "Size: $([Math]::Round($latestIpa.Length / 1MB, 2)) MB"
    } else {
        "No IPA found in output folder: $distPath"
    }
}
