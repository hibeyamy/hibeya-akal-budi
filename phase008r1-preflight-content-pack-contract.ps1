Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008r1-content-pack-contract-$stamp.txt"

function Line([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
}

function Files([string]$Path,[string[]]$Includes) {
    if (-not (Test-Path $Path)) { return @() }
    return @(
        Get-ChildItem -Path $Path -Recurse -File -Include $Includes -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\node_modules\\|\\dist\\|\\storybook-static\\|\\test-results\\|\\playwright-report\\|\\\.git\\'
            }
    )
}

function Search([object[]]$InputFiles,[string[]]$Patterns,[string]$Title) {
    Line ""
    Line "===================================================="
    Line $Title
    Line "===================================================="
    foreach ($pattern in $Patterns) {
        Line ""
        Line "---- $pattern ----"
        $hits = @($InputFiles | Select-String -SimpleMatch -Pattern $pattern -Context 2,6 -ErrorAction SilentlyContinue)
        if ($hits.Count -eq 0) {
            Line "[NO MATCHES]"
        } else {
            foreach ($hit in $hits) {
                $hit.ToString() | Add-Content -Path $report -Encoding UTF8
            }
        }
    }
}

function Snapshot([string]$Relative) {
    $full = Join-Path $root $Relative
    Line ""
    Line "===================================================="
    Line "FILE: $Relative"
    Line "===================================================="
    if (Test-Path $full) {
        Get-Content $full | Add-Content -Path $report -Encoding UTF8
    } else {
        Line "[MISSING]"
    }
}

trap {
    Line ""
    Line "PHASE 008R1 PREFLIGHT: FAILED"
    Line ($_ | Out-String)
    Write-Host ""
    Write-Host "PHASE 008R1 PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R1 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Governed Content-Pack Contract" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Line "HIBEYA AKAL BUDI - PHASE 008R1 PREFLIGHT"
Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

$schema = @(Files (Join-Path $root "packages\content-schema\src") @("*.ts","*.tsx","*.json"))
$curriculumSchema = @(Files (Join-Path $root "packages\curriculum-schema\src") @("*.ts","*.tsx","*.json"))
$compiler = @(Files (Join-Path $root "tools\content-compiler") @("*.mjs","*.cjs","*.ts","*.json"))
$curriculumTools = @(Files (Join-Path $root "tools\curriculum") @("*.mjs","*.cjs","*.ts","*.json"))
$manifests = @()
$manifestRoot = Join-Path $root "content\activity-manifests"
if (Test-Path $manifestRoot) {
    $manifests = @(Get-ChildItem $manifestRoot -File -Filter *.json)
}
$curriculum = @(Files (Join-Path $root "content\curriculum") @("*.json","*.ts"))

Write-Host "PASS: bounded source scopes collected" -ForegroundColor Green

foreach ($file in @(
    "tools\content-compiler\new-activity.mjs",
    "tools\content-compiler\compile.mjs",
    "tools\curriculum\validate.mjs",
    "tools\curriculum\review-mapping.mjs",
    "content\curriculum\skill-graph.json",
    "packages\content-schema\src\activity.schema.ts",
    "packages\curriculum-schema\src\index.ts",
    "package.json"
)) {
    Snapshot $file
}

Search @($compiler + $schema) @(
    "process.argv",
    "--id",
    "--title",
    "--age",
    "--difficulty",
    "--sequence",
    "--skill",
    "TODO",
    "PENDING",
    "originalityReviewed",
    "culturalReviewed",
    "enabled"
) "AUTHORING CLI / DEFAULT CONTRACT"

Search @($curriculumTools + $curriculumSchema + $curriculum) @(
    "skill-graph",
    "prerequisite",
    "required",
    "recommended",
    "active",
    "validate",
    "cycle",
    "duplicate",
    "unknown"
) "SKILL GRAPH GOVERNANCE CONTRACT"

Search @($manifests + $schema + $compiler) @(
    "skillMappings",
    "primary",
    "supporting",
    "difficulty",
    "ageBands",
    "sequence",
    "curriculumMappings",
    "reviewStatus",
    "provenance",
    "malaysiaElements",
    "accessibility"
) "ACTIVITY PACK GOVERNANCE CONTRACT"

Line ""
Line "===================================================="
Line "CURRENT COVERAGE BASELINE"
Line "===================================================="
Line "Known from Phase 008R:"
Line "SkillCount=2"
Line "PrerequisiteEdgeCount=0"
Line "EnabledActivities=2"
Line "AgeBandCoverage=3-4 only"
Line "colour-recognition: 2 enabled primary activities"
Line "visual-discrimination: 0 enabled primary activities"
Line "Both enabled activities: difficulty=1"

Line ""
Line "===================================================="
Line "008R1 IMPLEMENTATION DECISIONS TO RESOLVE"
Line "===================================================="
Line "1. Can new-activity.mjs safely accept non-interactive parameters for bulk governed authoring?"
Line "2. Can it generate disabled draft manifests without falsely marking provenance/review complete?"
Line "3. Is there a supported tool for adding skills and prerequisite edges, or must one be introduced?"
Line "4. Can coverage validation enforce at least one primary activity per active skill?"
Line "5. Can future depth policy be expressed without hard-coding the current two skills?"
Line "6. Should coverage thresholds be configuration-driven rather than embedded in learner runtime?"
Line "7. No new curriculum claims should be marked verified without source/reviewer evidence."
Line "8. No bulk activity should be enabled automatically merely to satisfy a coverage count."
Line "9. Content expansion must remain manifest/compiler-driven; generated catalogue files are not authoring sources."
Line "10. Difficulty adaptation remains deferred until real same-context difficulty variance exists."

Write-Host ""
Write-Host "PASS: Phase 008R1 governed content-pack preflight created" -ForegroundColor Green
Write-Host "Report: $report" -ForegroundColor White
Write-Host "No source, manifest, schema, dependency, generated file, or lockfile was modified." -ForegroundColor Cyan
