Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$workDir = Join-Path $logs "phase008r2-content-pack-preflight-$stamp"
$report = Join-Path $workDir "report.txt"
$snapshotsDir = Join-Path $workDir "snapshots"
$zip = Join-Path $logs "phase008r2-content-pack-preflight-$stamp.zip"

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
    Add-Line "PHASE 008R2 PREFLIGHT: FAILED"
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
    Write-Host "PHASE 008R2 PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R2 PREFLIGHT" -ForegroundColor Cyan
Write-Host "First Governed Content-Pack Specification" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008R2 PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Add-Line "Purpose: determine the exact first content pack required to close measured curriculum coverage gaps."

# ------------------------------------------------------------------
# 1. Verify 008R1 foundation exists.
# ------------------------------------------------------------------

$requiredPaths = @(
    "tools\content-compiler\new-activity.mjs",
    "tools\content-compiler\validate-coverage.mjs",
    "content\curriculum\coverage-policy.json",
    "content\curriculum\skill-graph.json",
    "package.json"
)

foreach ($relative in $requiredPaths) {
    $full = Join-Path $root $relative

    if (-not (Test-Path $full)) {
        throw "Required post-008R1 contract missing: $relative"
    }
}

$newActivityText = Get-Content (Join-Path $root "tools\content-compiler\new-activity.mjs") -Raw
$coverageValidatorText = Get-Content (Join-Path $root "tools\content-compiler\validate-coverage.mjs") -Raw

foreach ($token in @(
    "--age-band",
    "--difficulty",
    "--primary-skill",
    "--sequence",
    "originalityReviewed",
    "false"
)) {
    if ($newActivityText -notmatch [Regex]::Escape($token)) {
        throw "008R1 authoring contract drifted. Missing token: $token"
    }
}

foreach ($token in @(
    "minimumEnabledPrimaryActivities",
    "targetEnabledPrimaryActivities",
    "enabledPrimary",
    "draftPrimary"
)) {
    if ($coverageValidatorText -notmatch [Regex]::Escape($token)) {
        throw "008R1 coverage validator drifted. Missing token: $token"
    }
}

Write-Host "PASS: post-008R1 governed authoring foundation verified" -ForegroundColor Green

# ------------------------------------------------------------------
# 2. Collect bounded scopes.
# ------------------------------------------------------------------

$manifestRoot = Join-Path $root "content\activity-manifests"
$manifestFiles = if (Test-Path $manifestRoot) {
    @(Get-ChildItem $manifestRoot -File -Filter *.json -ErrorAction SilentlyContinue)
} else {
    @()
}

$blueprintFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-architecture\src") `
        @("*.ts","*.tsx","*.json")
)

$schemaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$runtimeFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\game-runtime\src") `
        @("*.ts","*.tsx","*.json")
)

$mechanicFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\game-mechanics\src") `
        @("*.ts","*.tsx","*.json")
)

$assetFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\assets\src") `
        @("*.ts","*.tsx","*.json")
)

$contentLibraryFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-library\src") `
        @("*.ts","*.tsx","*.json")
)

$compilerFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\content-compiler") `
        @("*.mjs","*.cjs","*.ts","*.json")
)

$allFiles = @(
    @($manifestFiles) +
    @($blueprintFiles) +
    @($schemaFiles) +
    @($runtimeFiles) +
    @($mechanicFiles) +
    @($assetFiles) +
    @($contentLibraryFiles) +
    @($compilerFiles)
)

Write-Host "PASS: bounded content/runtime scopes collected ($($allFiles.Count) files)" -ForegroundColor Green

# ------------------------------------------------------------------
# 3. Snapshot exact contracts.
# ------------------------------------------------------------------

foreach ($relative in @(
    "content\curriculum\skill-graph.json",
    "content\curriculum\coverage-policy.json",
    "tools\content-compiler\new-activity.mjs",
    "tools\content-compiler\validate-coverage.mjs",
    "tools\content-compiler\compile.mjs",
    "packages\content-schema\src\activity.schema.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\learning-insights\src\activityMetadata.ts"
)) {
    Snapshot $relative
}

foreach ($manifest in ($manifestFiles | Sort-Object Name)) {
    $relative = $manifest.FullName.Substring($root.Length).TrimStart("\")
    Snapshot $relative
}

# ------------------------------------------------------------------
# 4. Structured current-gap analysis.
# ------------------------------------------------------------------

Add-Line ""
Add-Line "===================================================="
Add-Line "STRUCTURED COVERAGE GAP ANALYSIS"
Add-Line "===================================================="

$graph = Try-Json (Join-Path $root "content\curriculum\skill-graph.json")
$policy = Try-Json (Join-Path $root "content\curriculum\coverage-policy.json")

if ($null -eq $graph) {
    throw "skill-graph.json could not be parsed."
}

if ($null -eq $policy) {
    throw "coverage-policy.json could not be parsed."
}

$activeSkills = @(
    @($graph.skills) |
    Where-Object { $_.active -eq $true }
)

$coverageRows = @()

foreach ($skill in $activeSkills) {
    $enabledPrimary = @()
    $draftPrimary = @()
    $difficulties = @()
    $ageBands = @()

    foreach ($manifestFile in $manifestFiles) {
        $manifest = Try-Json $manifestFile.FullName
        if ($null -eq $manifest) { continue }

        $mappings = @($manifest.skillMappings)

        $isPrimary = $false

        foreach ($mapping in $mappings) {
            if (
                $mapping.skillId -eq $skill.id -and
                $mapping.role -eq "primary"
            ) {
                $isPrimary = $true
                break
            }
        }

        if (-not $isPrimary) { continue }

        $activityId =
            if ($manifest.activity -and $manifest.activity.id) {
                [string]$manifest.activity.id
            } else {
                $manifestFile.BaseName
            }

        if ($manifest.catalogue -and $manifest.catalogue.enabled -eq $true) {
            $enabledPrimary += $activityId
        } else {
            $draftPrimary += $activityId
        }

        if ($manifest.activity -and $null -ne $manifest.activity.difficulty) {
            $difficulties += [int]$manifest.activity.difficulty
        }

        if ($manifest.catalogue -and $manifest.catalogue.ageBands) {
            $ageBands += @($manifest.catalogue.ageBands)
        }
    }

    $enabledCount = $enabledPrimary.Count
    $minimum = [int]$policy.activeSkillPolicy.minimumEnabledPrimaryActivities
    $target = [int]$policy.activeSkillPolicy.targetEnabledPrimaryActivities

    $status =
        if ($enabledCount -lt $minimum) {
            "FAIL"
        }
        elseif ($enabledCount -lt $target) {
            "DEPTH-GAP"
        }
        else {
            "TARGET"
        }

    $coverageRows += [PSCustomObject]@{
        SkillId = [string]$skill.id
        Domain = [string]$skill.domain
        EnabledPrimaryCount = $enabledCount
        DraftPrimaryCount = $draftPrimary.Count
        Status = $status
        Difficulties = ((@($difficulties | Sort-Object -Unique)) -join ",")
        AgeBands = ((@($ageBands | Sort-Object -Unique)) -join ",")
    }
}

foreach ($row in ($coverageRows | Sort-Object Status,SkillId)) {
    Add-Line (
        "Skill={0} | Domain={1} | EnabledPrimary={2} | DraftPrimary={3} | Status={4} | Difficulties={5} | AgeBands={6}" -f
        $row.SkillId,
        $row.Domain,
        $row.EnabledPrimaryCount,
        $row.DraftPrimaryCount,
        $row.Status,
        $row.Difficulties,
        $row.AgeBands
    )
}

# ------------------------------------------------------------------
# 5. Inspect supported mechanics / blueprints / assets so the first
#    content pack reuses existing runtime instead of inventing new engines.
# ------------------------------------------------------------------

Search-Files `
    @($blueprintFiles + $runtimeFiles + $mechanicFiles + $contentLibraryFiles) `
    @(
        "blueprintId",
        "implementationKey",
        "mechanic",
        "choice",
        "match",
        "sort",
        "drag",
        "tap",
        "select",
        "prompt",
        "feedback"
    ) `
    "SUPPORTED BLUEPRINT / MECHANIC CONTRACT"

Search-Files `
    @($manifestFiles + $assetFiles + $schemaFiles) `
    @(
        "asset",
        "hibiscus",
        "flower",
        "colour",
        "shape",
        "object",
        "malaysiaElements",
        "provenance",
        "originalityReviewed",
        "culturalReviewed",
        "accessibility"
    ) `
    "REUSABLE ASSET / CULTURAL / REVIEW CONTRACT"

# ------------------------------------------------------------------
# 6. Define exactly what the next implementation must decide.
# ------------------------------------------------------------------

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008R2 IMPLEMENTATION DECISIONS"
Add-Line "===================================================="
Add-Line "1. First close every FAIL coverage gap before adding new skills."
Add-Line "2. Prefer existing blueprint/mechanic/runtime contracts for the first pack."
Add-Line "3. Do not auto-enable generated activities."
Add-Line "4. Do not mark originalityReviewed/culturalReviewed true automatically."
Add-Line "5. Do not fabricate curriculum source/reviewer evidence."
Add-Line "6. Keep age-band expansion separate unless current evidence shows it is required to close the gap."
Add-Line "7. Do not create difficulty >1 merely to manufacture adaptive-difficulty variance."
Add-Line "8. Generate content specifications/manifests from measurable skill coverage needs."
Add-Line "9. Every new activity must be original, culturally safe, accessibility-aware, and compiler-valid."
Add-Line "10. Coverage validator must continue to detect enabled-primary coverage independently of specific skill IDs."

# ------------------------------------------------------------------
# 7. Create machine-readable summary for the next implementation.
# ------------------------------------------------------------------

$summaryPath = Join-Path $workDir "coverage-summary.json"

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    policy = @{
        minimumEnabledPrimaryActivities = [int]$policy.activeSkillPolicy.minimumEnabledPrimaryActivities
        targetEnabledPrimaryActivities = [int]$policy.activeSkillPolicy.targetEnabledPrimaryActivities
    }
    activeSkills = @(
        $coverageRows |
        Sort-Object SkillId |
        ForEach-Object {
            @{
                skillId = $_.SkillId
                domain = $_.Domain
                enabledPrimaryCount = $_.EnabledPrimaryCount
                draftPrimaryCount = $_.DraftPrimaryCount
                status = $_.Status
                difficulties = $_.Difficulties
                ageBands = $_.AgeBands
            }
        }
    )
}

$summary |
    ConvertTo-Json -Depth 8 |
    Set-Content -Path $summaryPath -Encoding UTF8

# ------------------------------------------------------------------
# 8. Zip only the preflight artefacts.
# ------------------------------------------------------------------

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
Write-Host "PASS: Phase 008R2 preflight ZIP created" -ForegroundColor Green
Write-Host "ZIP:" -ForegroundColor Cyan
Write-Host "  $zip" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, manifest, generated catalogue, dependency, or lockfile was modified." -ForegroundColor Cyan
