Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008r-curriculum-coverage-contract-$stamp.txt"

function Add-Line([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
}

function Add-FileSnapshot([string]$RelativePath) {
    $full = Join-Path $root $RelativePath

    Add-Line ""
    Add-Line "===================================================="
    Add-Line "FILE: $RelativePath"
    Add-Line "===================================================="

    if (Test-Path $full) {
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
            -ErrorAction SilentlyContinue
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

    if ($safeFiles.Count -eq 0) {
        Add-Line "[NO FILES]"
        return
    }

    foreach ($pattern in $Patterns) {
        Add-Line ""
        Add-Line "---- PATTERN: $pattern ----"

        $matches = @(
            $safeFiles |
                Select-String `
                    -Pattern $pattern `
                    -SimpleMatch `
                    -Context 2,8 `
                    -ErrorAction SilentlyContinue
        )

        if ($matches.Count -eq 0) {
            Add-Line "[NO MATCHES]"
            continue
        }

        foreach ($match in $matches) {
            $match.ToString() |
                Add-Content -Path $report -Encoding UTF8
        }
    }
}

function Assert-NoForbiddenFiles([object[]]$Files) {
    $forbidden = @(
        @($Files) |
            Where-Object {
                $_.FullName -match '\\node_modules\\' -or
                $_.FullName -match '\\storybook-static\\' -or
                $_.FullName -match '\\dist\\' -or
                $_.FullName -match '\\test-results\\' -or
                $_.FullName -match '\\playwright-report\\' -or
                $_.FullName -match '\\\.turbo\\' -or
                $_.FullName -match '\\\.git\\'
            }
    )

    if ($forbidden.Count -gt 0) {
        throw "Safety assertion failed: dependency/generated files entered Phase 008R scope."
    }
}

function Try-ReadJson([string]$Path) {
    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

trap {
    Add-Line ""
    Add-Line "PHASE 008R PREFLIGHT: FAILED"
    Add-Line ($_ | Out-String)
    Add-Line $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008R PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R PREFLIGHT" -ForegroundColor Cyan
Write-Host "Curriculum Coverage + Content Depth Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008R PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Add-Line "PowerShell: $($PSVersionTable.PSVersion)"

try { Add-Line "Node: $((& node --version).Trim())" }
catch { Add-Line "Node: [UNAVAILABLE]" }

try { Add-Line "pnpm: $((& pnpm --version).Trim())" }
catch { Add-Line "pnpm: [UNAVAILABLE]" }

Write-Host "Collecting bounded curriculum/content scopes..." -ForegroundColor Cyan

$curriculumSchemaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\curriculum-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$contentSchemaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$contentLibraryFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-library\src") `
        @("*.ts","*.tsx","*.json")
)

$learningInsightFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\learning-insights\src") `
        @("*.ts","*.tsx","*.json")
)

$contentCompilerFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\content-compiler") `
        @("*.ts","*.mjs","*.cjs","*.json")
)

$curriculumToolFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\curriculum") `
        @("*.ts","*.mjs","*.cjs","*.json")
)

$manifestFiles = @()
$manifestRoot = Join-Path $root "content\activity-manifests"

if (Test-Path $manifestRoot) {
    $manifestFiles = @(
        Get-ChildItem `
            -Path $manifestRoot `
            -File `
            -Filter *.json `
            -ErrorAction SilentlyContinue
    )
}

$curriculumContentFiles = @(
    Get-SourceFiles `
        (Join-Path $root "content\curriculum") `
        @("*.json","*.ts","*.tsx")
)

$allFiles = @(
    @($curriculumSchemaFiles) +
    @($contentSchemaFiles) +
    @($contentLibraryFiles) +
    @($learningInsightFiles) +
    @($contentCompilerFiles) +
    @($curriculumToolFiles) +
    @($manifestFiles) +
    @($curriculumContentFiles)
)

Assert-NoForbiddenFiles $allFiles

$scopeCounts = [PSCustomObject]@{
    CurriculumSchema  = @($curriculumSchemaFiles).Count
    ContentSchema     = @($contentSchemaFiles).Count
    ContentLibrary    = @($contentLibraryFiles).Count
    LearningInsights  = @($learningInsightFiles).Count
    ContentCompiler   = @($contentCompilerFiles).Count
    CurriculumTools   = @($curriculumToolFiles).Count
    ActivityManifests = @($manifestFiles).Count
    CurriculumContent = @($curriculumContentFiles).Count
}

$scopeCounts | Format-Table -AutoSize
$scopeCounts | Out-String | Add-Content -Path $report -Encoding UTF8

Write-Host "PASS: source-only curriculum/content scope prepared ($($allFiles.Count) files)" -ForegroundColor Green
Write-Host "PASS: dependency/generated directories excluded by construction" -ForegroundColor Green

$targets = @(
    "content\curriculum\skill-graph.json",
    "packages\curriculum-schema\src\index.ts",
    "packages\content-schema\src\activity.schema.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\content-library\src\eligibility.ts",
    "packages\learning-insights\src\activityMetadata.ts",
    "tools\content-compiler\compile.mjs",
    "tools\content-compiler\new-activity.mjs",
    "tools\curriculum\validate.mjs",
    "tools\curriculum\review-mapping.mjs",
    "package.json"
)

foreach ($target in $targets) {
    Add-FileSnapshot $target
}

Write-Host "Inspecting curriculum graph depth..." -ForegroundColor Cyan

Search-Files `
    @(
        @($curriculumContentFiles) +
        @($curriculumSchemaFiles)
    ) `
    @(
        '"skills"',
        '"prerequisites"',
        '"domain"',
        '"active"',
        "required",
        "recommended",
        "strand",
        "subject",
        "standard",
        "learning-standard",
        "content-standard"
    ) `
    "CURRICULUM GRAPH / STANDARD SEARCH"

Write-Host "Inspecting activity-to-skill coverage..." -ForegroundColor Cyan

Search-Files `
    @(
        @($manifestFiles) +
        @($contentLibraryFiles) +
        @($learningInsightFiles)
    ) `
    @(
        "skillMappings",
        "primary",
        "supporting",
        "learningInsights",
        "objectives",
        "curriculumMappings",
        "alignment",
        "reviewStatus",
        "malaysiaElements",
        "ageBands",
        "sequence"
    ) `
    "ACTIVITY / SKILL / CURRICULUM MAPPING SEARCH"

Write-Host "Inspecting content-generation scalability..." -ForegroundColor Cyan

Search-Files `
    @(
        @($contentCompilerFiles) +
        @($contentSchemaFiles)
    ) `
    @(
        "new-activity",
        "TODO",
        "difficulty",
        "sequence",
        "blueprintId",
        "implementationKey",
        "skillMappings",
        "learningInsights",
        "ageBands",
        "enabled"
    ) `
    "CONTENT AUTHORING / COMPILER SCALABILITY SEARCH"

Write-Host "Inspecting validator coverage..." -ForegroundColor Cyan

Search-Files `
    @(
        @($curriculumToolFiles) +
        @($contentCompilerFiles)
    ) `
    @(
        "validate",
        "fail(",
        "duplicate",
        "coverage",
        "missing",
        "unknown",
        "prerequisite",
        "mapping",
        "source",
        "review"
    ) `
    "VALIDATOR / GOVERNANCE SEARCH"

# ------------------------------------------------------------------
# Structured summaries.
# ------------------------------------------------------------------

Add-Line ""
Add-Line "===================================================="
Add-Line "STRUCTURED CURRICULUM SUMMARY"
Add-Line "===================================================="

$skillGraphPath = Join-Path $root "content\curriculum\skill-graph.json"
$skillGraph = if (Test-Path $skillGraphPath) {
    Try-ReadJson $skillGraphPath
} else {
    $null
}

if ($null -eq $skillGraph) {
    Add-Line "SKILL_GRAPH_PARSE_ERROR"
}
else {
    $skills = @($skillGraph.skills)
    $prerequisites = @($skillGraph.prerequisites)

    Add-Line ("SkillCount={0}" -f $skills.Count)
    Add-Line ("PrerequisiteEdgeCount={0}" -f $prerequisites.Count)

    $domains = @(
        $skills |
            Where-Object { $_.domain } |
            Group-Object domain |
            Sort-Object Name
    )

    foreach ($domain in $domains) {
        Add-Line (
            "Domain={0} | SkillCount={1}" -f
            $domain.Name,
            $domain.Count
        )
    }

    foreach ($skill in ($skills | Sort-Object id)) {
        $incomingRequired = @(
            $prerequisites |
                Where-Object {
                    $_.skillId -eq $skill.id -and
                    $_.strength -eq "required"
                }
        ).Count

        $incomingRecommended = @(
            $prerequisites |
                Where-Object {
                    $_.skillId -eq $skill.id -and
                    $_.strength -eq "recommended"
                }
        ).Count

        Add-Line (
            "Skill={0} | Domain={1} | Active={2} | RequiredPrerequisites={3} | RecommendedPrerequisites={4}" -f
            $skill.id,
            $skill.domain,
            $skill.active,
            $incomingRequired,
            $incomingRecommended
        )
    }
}

Add-Line ""
Add-Line "===================================================="
Add-Line "STRUCTURED ACTIVITY COVERAGE SUMMARY"
Add-Line "===================================================="

$activityCoverage = @()
$manifestParseFailures = @()

foreach ($manifestFile in (@($manifestFiles) | Sort-Object Name)) {
    $manifest = Try-ReadJson $manifestFile.FullName

    if ($null -eq $manifest) {
        $manifestParseFailures += $manifestFile.Name
        continue
    }

    $activityId =
        if ($manifest.activity -and $manifest.activity.id) {
            [string]$manifest.activity.id
        }
        else {
            $manifestFile.BaseName
        }

    $enabled =
        if ($manifest.catalogue -and $null -ne $manifest.catalogue.enabled) {
            [bool]$manifest.catalogue.enabled
        }
        else {
            $false
        }

    $sequence =
        if ($manifest.catalogue -and $null -ne $manifest.catalogue.sequence) {
            [int]$manifest.catalogue.sequence
        }
        else {
            -1
        }

    $difficulty =
        if ($manifest.activity -and $null -ne $manifest.activity.difficulty) {
            [int]$manifest.activity.difficulty
        }
        else {
            -1
        }

    $ageBands = @()
    if ($manifest.catalogue -and $manifest.catalogue.ageBands) {
        $ageBands = @($manifest.catalogue.ageBands)
    }
    elseif ($manifest.activity -and $manifest.activity.ageBand) {
        $ageBands = @([string]$manifest.activity.ageBand)
    }

    $skillMappings = @($manifest.skillMappings)

    $primarySkills = @(
        $skillMappings |
            Where-Object { $_.role -eq "primary" } |
            ForEach-Object { [string]$_.skillId }
    )

    $supportingSkills = @(
        $skillMappings |
            Where-Object { $_.role -eq "supporting" } |
            ForEach-Object { [string]$_.skillId }
    )

    $activityCoverage += [PSCustomObject]@{
        ActivityId       = $activityId
        Enabled          = $enabled
        Sequence         = $sequence
        Difficulty       = $difficulty
        AgeBands         = ($ageBands -join ",")
        PrimarySkills    = ($primarySkills -join ",")
        SupportingSkills = ($supportingSkills -join ",")
    }
}

if ($manifestParseFailures.Count -gt 0) {
    foreach ($failure in $manifestParseFailures) {
        Add-Line "MANIFEST_PARSE_ERROR: $failure"
    }
}

foreach ($row in $activityCoverage) {
    Add-Line (
        "Activity={0} | Enabled={1} | Sequence={2} | Difficulty={3} | AgeBands={4} | Primary={5} | Supporting={6}" -f
        $row.ActivityId,
        $row.Enabled,
        $row.Sequence,
        $row.Difficulty,
        $row.AgeBands,
        $row.PrimarySkills,
        $row.SupportingSkills
    )
}

Add-Line ""
Add-Line "===================================================="
Add-Line "SKILL COVERAGE MATRIX"
Add-Line "===================================================="

$knownSkillIds = @()
if ($null -ne $skillGraph) {
    $knownSkillIds = @(
        @($skillGraph.skills) |
            ForEach-Object { [string]$_.id } |
            Sort-Object
    )
}

foreach ($skillId in $knownSkillIds) {
    $primaryCount = 0
    $supportingCount = 0
    $enabledPrimaryCount = 0

    foreach ($manifestFile in @($manifestFiles)) {
        $manifest = Try-ReadJson $manifestFile.FullName
        if ($null -eq $manifest) { continue }

        $enabled =
            $manifest.catalogue -and
            $manifest.catalogue.enabled -eq $true

        foreach ($mapping in @($manifest.skillMappings)) {
            if ($mapping.skillId -ne $skillId) { continue }

            if ($mapping.role -eq "primary") {
                $primaryCount++
                if ($enabled) {
                    $enabledPrimaryCount++
                }
            }
            elseif ($mapping.role -eq "supporting") {
                $supportingCount++
            }
        }
    }

    Add-Line (
        "Skill={0} | PrimaryActivities={1} | EnabledPrimaryActivities={2} | SupportingActivities={3}" -f
        $skillId,
        $primaryCount,
        $enabledPrimaryCount,
        $supportingCount
    )
}

Add-Line ""
Add-Line "===================================================="
Add-Line "AGE-BAND COVERAGE"
Add-Line "===================================================="

$ageBandGroups = @(
    $activityCoverage |
        Where-Object { $_.Enabled -eq $true } |
        Group-Object AgeBands |
        Sort-Object Name
)

if ($ageBandGroups.Count -eq 0) {
    Add-Line "[NO ENABLED AGE-BAND COVERAGE]"
}
else {
    foreach ($group in $ageBandGroups) {
        Add-Line (
            "AgeBandSet={0} | EnabledActivities={1}" -f
            $group.Name,
            $group.Count
        )
    }
}

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008R DECISION QUESTIONS"
Add-Line "===================================================="
Add-Line "1. Which curriculum skills have zero enabled primary activities?"
Add-Line "2. Which skills are covered by only one enabled activity and therefore lack depth?"
Add-Line "3. Are there enough activities per skill to support mastery, remediation, diversity, and future difficulty adaptation?"
Add-Line "4. Are prerequisite edges absent because the curriculum is intentionally flat, or because progression has not yet been modelled?"
Add-Line "5. Are age bands beyond the current catalogue represented?"
Add-Line "6. Does the authoring tool create curriculum-valid manifests without manual boilerplate duplication?"
Add-Line "7. Should the next implementation expand the skill graph first, the activity corpus first, or both under a governed content-pack contract?"
Add-Line "8. Do not implement adaptive difficulty until multiple enabled difficulty levels exist for the same relevant skill/age-band context."
Add-Line "9. Preserve originality, provenance, wellbeing guardrails, prerequisite integrity, and deterministic sequencing."

Write-Host ""
Write-Host "PASS: Phase 008R preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, persistence, manifest, dependency, generated catalogue, or lockfile was modified." -ForegroundColor Cyan
