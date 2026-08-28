Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path;$logs=Join-Path $root "tools\dev\logs";New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff";$work=Join-Path $logs ("phase008r3b6-coverage-preflight-"+$stamp);$report=Join-Path $work "preflight.txt";$zip=Join-Path $logs ("phase008r3b6-content-coverage-repair-preflight-"+$stamp+".zip");New-Item -ItemType Directory -Force -Path $work|Out-Null
function L([string]$t=""){Add-Content $report $t -Encoding UTF8;Write-Host $t}
function Z(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
function C([string]$f){if(Test-Path $f){$rel=$f.Substring($root.Length).TrimStart("\");Copy-Item $f (Join-Path $work ($rel.Replace("\","__"))) -Force;L ("CAPTURED: "+$rel)}}
trap{L "";L "PHASE 008R3B.6 COVERAGE REPAIR PREFLIGHT: FAILED";L ($_|Out-String);L $_.ScriptStackTrace;Z;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - R3B.6 COVERAGE REPAIR PREFLIGHT" -ForegroundColor Cyan
Write-Host "beza-bunga-raya-001 Production Readiness Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
L ("Generated: "+(Get-Date).ToString("o"));L ("Repository: "+$root)

$all=Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue|Where-Object{$_.FullName -notmatch "\\node_modules\\|\\dist\\|\\storybook-static\\|\\test-results\\|\\playwright-report\\|\\tools\\dev\\logs\\"}
$hits=@($all|Select-String -SimpleMatch "beza-bunga-raya-001" -ErrorAction SilentlyContinue)
if($hits.Count-eq 0){throw "beza-bunga-raya-001 not found in repository"}
L "";L "===== ACTIVITY LOCATION / REFERENCES ====="
foreach($h in $hits){L $h.ToString();C $h.Path}

L "";L "===== ACTIVITY SOURCE ====="
$activityFiles=@($hits|ForEach-Object{$_.Path}|Sort-Object -Unique|Where-Object{$_ -match "\.(json|ts|tsx|js|mjs)$"})
foreach($f in $activityFiles){L ("--- "+$f.Substring($root.Length).TrimStart("\")+" ---");L (Get-Content $f -Raw)}

L "";L "===== RELATED VISUAL-DISCRIMINATION CONTRACTS ====="
$code=@($all|Where-Object{$_.Extension -in @(".ts",".tsx",".js",".mjs",".json")})
foreach($needle in @("visual-discrimination","hibiscus-red","hibiscus-yellow","hibiscus-purple","implementationKey","primary","draft","enabled")){
 L "";L ("-- "+$needle+" --")
 foreach($h in @($code|Select-String -SimpleMatch $needle -Context 2,6 -ErrorAction SilentlyContinue)){L $h.ToString();C $h.Path}
}

L "";L "===== VALIDATOR / COMPILER CONTRACTS ====="
foreach($pattern in @("coverage","eligibility","sequence","compile")){
 foreach($f in @($all|Where-Object{$_.Name -match $pattern -and $_.Extension -in @(".mjs",".js",".ts",".json")})){C $f}
}

L "";L "===== DECISION RULES ====="
L "1. Do not change the coverage threshold to make the gate pass."
L "2. Do not promote draft status merely because the competency is below minimum."
L "3. Promotion is allowed only if schema, mechanic, answer integrity, governed assets and learner runtime are production-ready."
L "4. Hibiscus visuals must resolve by semantic ID through getAsset(), never direct PNG/WebP/SVG paths."
L "5. Correctness must remain mechanic/content-owned."
L "6. visual-discrimination must be the intended competency mapping, not a workaround."
L "7. Existing approved artwork must not be regenerated or altered."
L "8. If the draft is not production-ready, identify exact blockers and leave it draft."
L "9. If production-ready, the subsequent repair must make the smallest auditable status/release change."
L "10. Subsequent repair must rerun compiler, sequence, eligibility, coverage, assets, typechecks and learner QA."

L "";L "PHASE 008R3B.6 COVERAGE REPAIR PREFLIGHT: PASS"
L "Inspection only. No activity status, content, artwork, mechanic, validator, dependency or lockfile was modified."
Z
Write-Host "PHASE 008R3B.6 COVERAGE REPAIR PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
