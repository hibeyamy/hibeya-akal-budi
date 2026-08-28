Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b6-promotion-v3-"+$stamp)
$log=Join-Path $work "promotion-v3.log"
$zip=Join-Path $logs ("phase008r3b6-governed-promotion-v3-"+$stamp+".zip")
$backup=Join-Path $work "before"
New-Item -ItemType Directory -Force -Path $work,$backup|Out-Null

function Write-Log([string]$Text=""){
  Add-Content -Path $log -Value $Text -Encoding UTF8
  Write-Host $Text
}
function Invoke-Step([string]$Label,[string]$Command){
  Write-Log ""
  Write-Log ("==> "+$Label)
  Write-Log $Command
  $stdout=Join-Path $work "stdout.txt"
  $stderr=Join-Path $work "stderr.txt"
  $process=Start-Process "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root -Wait -NoNewWindow -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  foreach($file in @($stdout,$stderr)){
    if(Test-Path $file){
      $content=Get-Content $file -Raw -ErrorAction SilentlyContinue
      if($content){Write-Log $content.TrimEnd()}
      Remove-Item $file -Force -ErrorAction SilentlyContinue
    }
  }
  if($process.ExitCode -ne 0){
    throw ($Label+" failed with exit code "+$process.ExitCode)
  }
  Write-Log ("PASS: "+$Label)
}
function Save-Zip {
  foreach($candidate in @("test-results","playwright-report")){
    $source=Join-Path $root $candidate
    if(Test-Path $source){
      Copy-Item $source (Join-Path $work $candidate) -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  if(Test-Path $zip){Remove-Item $zip -Force}
  Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}
trap{
  Write-Log ""
  Write-Log "R3B.6 GOVERNED PROMOTION V3: FAILED"
  Write-Log ($_|Out-String)
  Write-Log $_.ScriptStackTrace
  Save-Zip
  Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow
  exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - R3B.6 GOVERNED PROMOTION V3" -ForegroundColor Cyan
Write-Host "Schema-Correct Activity + Catalogue Promotion" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$manifest=Join-Path $root "content\activity-manifests\beza-bunga-raya-001.json"
if(-not(Test-Path $manifest)){throw "Manifest missing"}
Copy-Item $manifest (Join-Path $backup "beza-bunga-raya-001.before.json") -Force
Write-Log "PASS: before-state manifest snapshot captured"
Write-Log "Human approval basis: visual, originality, cultural suitability and age suitability."

Invoke-Step "Apply schema-correct governed promotion" "node phase008r3b6-promote-beza-bunga-raya-v3.mjs"
Invoke-Step "Verify promotion metadata and answer integrity" "node phase008r3b6-verify-promotion-v3.mjs"
Invoke-Step "Compile content" "pnpm content:compile"
Invoke-Step "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Invoke-Step "Content sequencing validation" "pnpm content:sequence:validate"
Invoke-Step "Content eligibility validation" "pnpm content:eligibility:validate"
Invoke-Step "Content coverage validation" "pnpm content:coverage:validate"
Invoke-Step "R3B.6 integration audit" "node tools/assets/audit-content-runtime-integration.mjs"
Invoke-Step "Asset registry reproducibility" "pnpm assets:runtime:check"
Invoke-Step "Asset runtime validation" "pnpm assets:runtime:validate"
Invoke-Step "Commercial asset validation" "pnpm assets:commercial:validate"
Invoke-Step "Runtime format validation" "pnpm assets:formats:validate"
Invoke-Step "Learner typecheck" "pnpm --filter learner-web typecheck"
Invoke-Step "Storybook production build" "pnpm storybook:build"
Invoke-Step "Responsive production regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-responsive-production.spec.ts"
Invoke-Step "Accessibility interaction regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-accessibility.spec.ts"
Invoke-Step "Learner journey regression" "pnpm qa:journey"
Invoke-Step "Frozen lockfile" "pnpm install --frozen-lockfile"

Write-Log ""
Write-Log "R3B.6 GOVERNED PROMOTION V3: PASS"
Write-Log "beza-bunga-raya-001 is now human-reviewed, active and catalogue-enabled."
Write-Log "Content coverage and complete production regression boundary passed."
Write-Log "No artwork, answer key, competency mapping, mastery or progression rule was changed."

Save-Zip
Write-Host "R3B.6 GOVERNED PROMOTION V3: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
