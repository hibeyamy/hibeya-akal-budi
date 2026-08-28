Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$workDir = Join-Path $logs "phase008r3a-visual-review-preflight-$stamp"
$report = Join-Path $workDir "report.txt"
$snapshotsDir = Join-Path $workDir "snapshots"
$zip = Join-Path $logs "phase008r3a-visual-review-preflight-$stamp.zip"

New-Item -ItemType Directory -Force -Path $workDir,$snapshotsDir | Out-Null

function Add-Line([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
}

function Safe-Name([string]$RelativePath) {
    return ($RelativePath -replace '[\\/:*?"<>|]', '_')
}

function Snapshot([string]$RelativePath) {
    $full = Join-Path $root $RelativePath
    $target = Join-Path $snapshotsDir (Safe-Name $RelativePath)

    Add-Line ""
    Add-Line "===================================================="
    Add-Line "FILE: $RelativePath"
    Add-Line "===================================================="

    if (Test-Path $full) {
        Copy-Item $full $target -Force
        Get-Content $full -ErrorAction Stop |
            Add-Content -Path $report -Encoding UTF8
    }
    else {
        Add-Line "[MISSING]"
    }
}

function Get-SourceFiles(
    [string]$Path,
    [string[]]$Includes
) {
    if (-not (Test-Path $Path)) {
        return @()
    }

    return @(
        Get-ChildItem `
            -Path $Path `
            -Recurse `
            -File `
            -Include $Includes `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\node_modules\\' -and
            $_.FullName -notmatch '\\dist\\' -and
            $_.FullName -notmatch '\\storybook-static\\' -and
            $_.FullName -notmatch '\\test-results\\' -and
            $_.FullName -notmatch '\\playwright-report\\' -and
            $_.FullName -notmatch '\\\.turbo\\' -and
            $_.FullName -notmatch '\\\.git\\'
        }
    )
}

function Search-Files(
    [object[]]$Files,
    [string[]]$Patterns,
    [string]$Section
) {
    Add-Line ""
    Add-Line "===================================================="
    Add-Line $Section
    Add-Line "===================================================="

    $safeFiles = @($Files)

    foreach ($pattern in $Patterns) {
        Add-Line ""
        Add-Line "---- PATTERN: $pattern ----"

        $hits = @(
            $safeFiles |
            Select-String `
                -SimpleMatch `
                -Pattern $pattern `
                -Context 2,8 `
                -ErrorAction SilentlyContinue
        )

        if ($hits.Count -eq 0) {
            Add-Line "[NO MATCHES]"
            continue
        }

        foreach ($hit in $hits) {
            $hit.ToString() |
                Add-Content -Path $report -Encoding UTF8
        }
    }
}

function Try-Json([string]$Path) {
    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

trap {
    Add-Line ""
    Add-Line "PHASE 008R3A PREFLIGHT: FAILED"
    Add-Line ($_ | Out-String)
    Add-Line $_.ScriptStackTrace

    if (Test-Path $zip) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $workDir) {
        Compress-Archive `
            -Path (Join-Path $workDir "*") `
            -DestinationPath $zip `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "PHASE 008R3A PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A PREFLIGHT" -ForegroundColor Cyan
Write-Host "Draft Visual Review Harness Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008R3A PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Add-Line "Purpose: determine the safest way to render a disabled governed draft for visual QA without leaking it into production progression."

$draftPath = Join-Path $root "content\activity-manifests\beza-bunga-raya-001.json"

foreach ($required in @(
    $draftPath,
    (Join-Path $root "apps\ui-storybook"),
    (Join-Path $root "apps\learner-web\src\features\play"),
    (Join-Path $root "tools\visual-regression")
)) {
    if (-not (Test-Path $required)) {
        throw "Required post-008R2 contract missing: $required"
    }
}

$draft = Try-Json $draftPath
if ($null -eq $draft) {
    throw "Draft manifest could not be parsed: $draftPath"
}

foreach ($assertion in @(
    @{ Name = "draft disabled"; Value = ($draft.catalogue.enabled -eq $false) },
    @{ Name = "draft inactive"; Value = ($draft.activity.metadata.active -eq $false) },
    @{ Name = "originality pending"; Value = ($draft.activity.provenance.originalityReviewed -eq $false) },
    @{ Name = "cultural review pending"; Value = ($draft.activity.provenance.culturalReviewed -eq $false) },
    @{ Name = "visual-discrimination primary"; Value = (@($draft.skillMappings | Where-Object { $_.skillId -eq "visual-discrimination" -and $_.role -eq "primary" }).Count -ge 1) }
)) {
    if (-not $assertion.Value) {
        throw "Draft governance assertion failed: $($assertion.Name)"
    }
}

Write-Host "PASS: governed draft state verified" -ForegroundColor Green

$storybookFiles = @(
    Get-SourceFiles `
        (Join-Path $root "apps\ui-storybook") `
        @("*.ts","*.tsx","*.js","*.mjs","*.cjs","*.json")
)

$learnerFiles = @(
    Get-SourceFiles `
        (Join-Path $root "apps\learner-web\src") `
        @("*.ts","*.tsx","*.json")
)

$contentLibraryFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-library\src") `
        @("*.ts","*.tsx","*.json")
)

$assetsFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\assets\src") `
        @("*.ts","*.tsx","*.json")
)

$qaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\visual-regression") `
        @("*.ts","*.tsx","*.js","*.mjs","*.cjs","*.json")
)

$allFiles = @(
    @($storybookFiles) +
    @($learnerFiles) +
    @($contentLibraryFiles) +
    @($assetsFiles) +
    @($qaFiles)
)

Write-Host "PASS: bounded visual/runtime scopes collected ($($allFiles.Count) files)" -ForegroundColor Green

foreach ($relative in @(
    "content\activity-manifests\beza-bunga-raya-001.json",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\activityRegistry.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "apps\learner-web\src\journey\nextLearnerActivity.service.ts",
    "packages\content-library\src\catalogue.ts",
    "tools\content-compiler\compile.mjs",
    "tools\visual-regression\playwright.config.ts",
    "package.json"
)) {
    Snapshot $relative
}

Search-Files `
    @($storybookFiles + $learnerFiles) `
    @(
        "ActivityPlayer",
        "LearnerJourney",
        "stories",
        "StoryObj",
        "render:",
        "args:",
        "play:",
        "activityId",
        "implementationKey",
        "activityRegistry",
        "selectLearnerActivity"
    ) `
    "STORYBOOK / RUNTIME ENTRYPOINT SEARCH"

Search-Files `
    @($qaFiles + $storybookFiles) `
    @(
        "playwright",
        "screenshot",
        "viewport",
        "mobile",
        "tablet",
        "chromium",
        "storyId",
        "iframe",
        "accessibility",
        "touch target",
        "56",
        "toBeVisible",
        "boundingBox"
    ) `
    "VISUAL QA / RESPONSIVE / ACCESSIBILITY SEARCH"

Search-Files `
    @($learnerFiles + $contentLibraryFiles) `
    @(
        "catalogue.enabled",
        "enabled",
        "getPlayableActivities",
        "getEligibleActivitiesForLearner",
        "activityRegistry",
        "implementationKey",
        "blueprint",
        "options",
        "correct"
    ) `
    "DRAFT LEAKAGE / PLAYABILITY BOUNDARY SEARCH"

Search-Files `
    $assetsFiles `
    @(
        "hibiscus-red",
        "hibiscus-yellow",
        "hibiscus",
        "asset"
    ) `
    "HIBISCUS ASSET CONTRACT SEARCH"

Add-Line ""
Add-Line "===================================================="
Add-Line "STRUCTURED DRAFT VISUAL CONTRACT"
Add-Line "===================================================="

Add-Line ("ActivityId={0}" -f $draft.activity.id)
Add-Line ("Mechanic={0}" -f $draft.activity.mechanic)
Add-Line ("ImplementationKey={0}" -f $draft.catalogue.implementationKey)
Add-Line ("BlueprintId={0}" -f $draft.catalogue.blueprintId)
Add-Line ("AgeBand={0}" -f $draft.activity.ageBand)
Add-Line ("Difficulty={0}" -f $draft.activity.difficulty)
Add-Line ("Enabled={0}" -f $draft.catalogue.enabled)
Add-Line ("Active={0}" -f $draft.activity.metadata.active)
Add-Line ("OriginalityReviewed={0}" -f $draft.activity.provenance.originalityReviewed)
Add-Line ("CulturalReviewed={0}" -f $draft.activity.provenance.culturalReviewed)

$options = @($draft.activity.options)

Add-Line ("OptionCount={0}" -f $options.Count)

foreach ($option in $options) {
    Add-Line (
        "Option={0} | Asset={1} | Correct={2}" -f
        $option.id,
        $option.asset,
        $option.correct
    )
}

$correctCount = @($options | Where-Object { $_.correct -eq $true }).Count
$redCount = @($options | Where-Object { $_.asset -eq "hibiscus-red" }).Count
$yellowCount = @($options | Where-Object { $_.asset -eq "hibiscus-yellow" }).Count

Add-Line ("CorrectOptionCount={0}" -f $correctCount)
Add-Line ("HibiscusRedCount={0}" -f $redCount)
Add-Line ("HibiscusYellowCount={0}" -f $yellowCount)

if ($correctCount -ne 1) {
    Add-Line "VISUAL_CONTRACT_ERROR: expected exactly one correct option."
}

if ($redCount -ne 2 -or $yellowCount -ne 1) {
    Add-Line "VISUAL_CONTRACT_WARNING: expected exactly two red hibiscus assets and one yellow hibiscus asset."
}

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008R3A IMPLEMENTATION QUESTIONS"
Add-Line "===================================================="
Add-Line "1. Can a Storybook-only draft fixture render ActivityPlayer without adding the draft to production catalogue outputs?"
Add-Line "2. Can the fixture inject manifest data directly, or is a typed adapter required?"
Add-Line "3. Can Playwright target that Storybook story independently from learner progression?"
Add-Line "4. Can desktop/tablet/mobile visual checks reuse the current visual-regression infrastructure?"
Add-Line "5. Can touch-target checks verify the same >=56px learner standard already used by journey QA?"
Add-Line "6. Can the review harness assert exactly three choices, exactly one correct answer, and visible Malay/English copy?"
Add-Line "7. Can the harness verify that production selectors still cannot discover the disabled draft?"
Add-Line "8. Do not enable, activate, or mark review flags true in 008R3A."
Add-Line "9. Do not introduce a new mechanic if the existing tap-choice runtime can render the draft."
Add-Line "10. Promotion to production belongs to 008R3B only after human visual approval."

$summaryPath = Join-Path $workDir "visual-review-summary.json"

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    activity = @{
        id = [string]$draft.activity.id
        mechanic = [string]$draft.activity.mechanic
        implementationKey = [string]$draft.catalogue.implementationKey
        blueprintId = [string]$draft.catalogue.blueprintId
        ageBand = [string]$draft.activity.ageBand
        difficulty = [int]$draft.activity.difficulty
        enabled = [bool]$draft.catalogue.enabled
        active = [bool]$draft.activity.metadata.active
        originalityReviewed = [bool]$draft.activity.provenance.originalityReviewed
        culturalReviewed = [bool]$draft.activity.provenance.culturalReviewed
    }
    options = @(
        $options | ForEach-Object {
            @{
                id = [string]$_.id
                asset = [string]$_.asset
                correct = [bool]$_.correct
            }
        }
    )
    counts = @{
        options = $options.Count
        correct = $correctCount
        hibiscusRed = $redCount
        hibiscusYellow = $yellowCount
    }
}

$summary |
    ConvertTo-Json -Depth 8 |
    Set-Content -Path $summaryPath -Encoding UTF8

if (Test-Path $zip) {
    Remove-Item $zip -Force
}

Compress-Archive `
    -Path (Join-Path $workDir "*") `
    -DestinationPath $zip `
    -Force

if (-not (Test-Path $zip)) {
    throw "Preflight ZIP was not created."
}

Write-Host ""
Write-Host "PASS: Phase 008R3A visual-review preflight ZIP created" -ForegroundColor Green
Write-Host "ZIP:" -ForegroundColor Cyan
Write-Host "  $zip" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, manifest, generated catalogue, dependency, review flag, or lockfile was modified." -ForegroundColor Cyan
