Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b7-preflight-" + $stamp)
$report = Join-Path $work "phase008r3b7-preflight.txt"
$zip = Join-Path $logs ("phase008r3b7-persistence-resume-preflight-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Write-Log([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Save-Zip {
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

function Capture-File([string]$File) {
    if (-not (Test-Path $File)) { return }
    $relative = $File.Substring($root.Length).TrimStart("\")
    $safe = $relative.Replace("\","__").Replace("/","__")
    Copy-Item $File (Join-Path $work $safe) -Force
}

trap {
    Write-Log ""
    Write-Log "PHASE 008R3B.7 PREFLIGHT: FAILED"
    Write-Log ($_ | Out-String)
    Write-Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.7 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Persistence, Resume + Progress Integrity QA" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Write-Log ("Generated: " + (Get-Date).ToString("o"))
Write-Log ("Repository: " + $root)

$roots = @(
    (Join-Path $root "apps\learner-web\src"),
    (Join-Path $root "packages"),
    (Join-Path $root "tools")
)

$files = @()
foreach ($scanRoot in $roots) {
    if (-not (Test-Path $scanRoot)) { continue }
    $files += @(
        Get-ChildItem $scanRoot -Recurse -File -Include *.ts,*.tsx,*.js,*.mjs,*.json -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\dist\\" -and
            $_.FullName -notmatch "\\storybook-static\\" -and
            $_.FullName -notmatch "\\tools\\dev\\logs\\"
        }
    )
}

Write-Log ""
Write-Log "===== STORAGE / PERSISTENCE OWNERSHIP ====="
foreach ($needle in @(
    "localStorage",
    "sessionStorage",
    "indexedDB",
    "IDB",
    "persist",
    "hydrate",
    "rehydrate",
    "storage",
    "repository",
    "saveProgress",
    "loadProgress",
    "progress",
    "mastery",
    "completion",
    "completed",
    "attempt",
    "resume"
)) {
    $hits = @($files | Select-String -SimpleMatch $needle -Context 2,7 -ErrorAction SilentlyContinue)
    Write-Log ""
    Write-Log ("-- " + $needle + " | hits=" + $hits.Count + " --")
    foreach ($hit in $hits) {
        Write-Log $hit.ToString()
        Capture-File $hit.Path
    }
}

Write-Log ""
Write-Log "===== LEARNER LIFECYCLE / ACTIVITY BOUNDARY ====="
foreach ($needle in @(
    "ActivityPlayer",
    "LearnerJourney",
    "submitAnswer",
    "activityId",
    "implementationKey",
    "unlock",
    "locked",
    "onComplete",
    "onProgress",
    "reset",
    "reload",
    "offline",
    "online"
)) {
    $hits = @($files | Select-String -SimpleMatch $needle -Context 2,8 -ErrorAction SilentlyContinue)
    Write-Log ""
    Write-Log ("-- " + $needle + " | hits=" + $hits.Count + " --")
    foreach ($hit in $hits) {
        Write-Log $hit.ToString()
        Capture-File $hit.Path
    }
}

Write-Log ""
Write-Log "===== VERSIONING / MIGRATION / CORRUPTION HANDLING ====="
foreach ($needle in @(
    "version",
    "schemaVersion",
    "migration",
    "migrate",
    "parse",
    "safeParse",
    "JSON.parse",
    "try {",
    "catch",
    "fallback",
    "invalid",
    "corrupt"
)) {
    $hits = @($files | Select-String -SimpleMatch $needle -Context 2,7 -ErrorAction SilentlyContinue)
    Write-Log ""
    Write-Log ("-- " + $needle + " | hits=" + $hits.Count + " --")
    foreach ($hit in $hits) {
        Write-Log $hit.ToString()
        Capture-File $hit.Path
    }
}

Write-Log ""
Write-Log "===== EXISTING TEST COVERAGE ====="
$testFiles = @(
    $files | Where-Object {
        $_.Name -match "\.(spec|test)\." -or
        $_.FullName -match "\\tests\\"
    }
)
foreach ($testFile in $testFiles) {
    $source = Get-Content $testFile.FullName -Raw -ErrorAction SilentlyContinue
    if ($source -match "progress|persist|storage|resume|completion|mastery|reload|offline") {
        $relative = $testFile.FullName.Substring($root.Length).TrimStart("\")
        Write-Log ("TEST: " + $relative)
        Capture-File $testFile.FullName
    }
}

Write-Log ""
Write-Log "===== PACKAGE SCRIPT DISCOVERY ====="
foreach ($relative in @("package.json","apps\learner-web\package.json")) {
    $full = Join-Path $root $relative
    if (-not (Test-Path $full)) { continue }
    Capture-File $full
    $json = Get-Content $full -Raw | ConvertFrom-Json
    Write-Log ("-- " + $relative + " --")
    $scripts = $json.PSObject.Properties["scripts"]
    if ($null -ne $scripts -and $null -ne $scripts.Value) {
        foreach ($property in $scripts.Value.PSObject.Properties) {
            Write-Log ($property.Name + " = " + $property.Value)
        }
    }
}

Write-Log ""
Write-Log "===== R3B.7 DECISION RULES ====="
Write-Log "1. Preflight is read-only: do not modify learner state or storage."
Write-Log "2. Identify the existing persistence owner before adding any new persistence layer."
Write-Log "3. Do not introduce localStorage/IndexedDB merely to satisfy tests if the architecture uses another repository abstraction."
Write-Log "4. Completion must be idempotent: replay/reload must not double-count progress."
Write-Log "5. Incorrect attempts must never become completed progress."
Write-Log "6. Activity state must be isolated by semantic activity ID."
Write-Log "7. Corrupt or obsolete persisted data must fail safely."
Write-Log "8. Content/schema version changes must not silently reinterpret incompatible learner state."
Write-Log "9. Offline/online transitions must preserve already committed progress."
Write-Log "10. Storybook fixtures must not become production persistence dependencies."
Write-Log "11. beza-bunga-raya-001 must participate through the same production persistence contract as other enabled activities."
Write-Log "12. No curriculum, artwork, answer key, mastery threshold or progression rule may change in R3B.7."

Write-Log ""
Write-Log "PHASE 008R3B.7 PREFLIGHT: PASS"
Write-Log "Read-only architecture inspection complete. No repository source, learner state, dependency or lockfile was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3B.7 PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
