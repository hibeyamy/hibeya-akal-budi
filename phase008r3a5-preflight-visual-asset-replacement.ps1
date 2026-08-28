Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs "phase008r3a5-preflight-$stamp"
$report=Join-Path $work "report.txt"
$zip=Join-Path $logs "phase008r3a5-visual-asset-replacement-preflight-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$t=""){
  Add-Content -Path $report -Value $t -Encoding UTF8
  Write-Host $t
}
function Files([string]$p,[string[]]$inc){
  if(-not(Test-Path $p)){return @()}
  @(
    Get-ChildItem $p -Recurse -File -Include $inc -ErrorAction SilentlyContinue |
    Where-Object {
      $_.FullName -notmatch '\\node_modules\\' -and
      $_.FullName -notmatch '\\dist\\' -and
      $_.FullName -notmatch '\\storybook-static\\' -and
      $_.FullName -notmatch '\\\.git\\'
    }
  )
}
function ZipLog(){
  if(Test-Path $zip){Remove-Item $zip -Force}
  Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}
trap{
  Log "PHASE 008R3A.5 PREFLIGHT: FAILED"
  Log ($_|Out-String)
  ZipLog
  Write-Host "ZIP: $zip" -ForegroundColor Yellow
  exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.5 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Fruit Visual Asset Replacement Readiness" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$generated=Join-Path $root "packages\assets\src\generated"
$source=Join-Path $root "packages\assets\source"
$metadata=Join-Path $root "packages\assets\src\metadata.ts"
$pipeline=Join-Path $root "tools\assets\build-raster-assets.mjs"

foreach($r in @($generated,$source,$metadata,$pipeline)){
  if(-not(Test-Path $r)){throw "Required prior-phase contract missing: $r"}
}

$ids=@("apple-red","apple-green","banana-yellow")
$code=@(
  (Files (Join-Path $root "packages") @("*.ts","*.tsx","*.js","*.mjs","*.json","*.md")) +
  (Files (Join-Path $root "apps") @("*.ts","*.tsx","*.js","*.mjs","*.json")) +
  (Files (Join-Path $root "tools") @("*.ts","*.js","*.mjs","*.json"))
)

Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Log ""
Log "FRUIT PHYSICAL INVENTORY"
foreach($id in $ids){
  Log $id
  foreach($ext in @("svg","png","webp","avif")){
    $hits=@(Get-ChildItem $root -Recurse -File -Filter "$id.$ext" -ErrorAction SilentlyContinue |
      Where-Object {$_.FullName -notmatch '\\node_modules\\' -and $_.FullName -notmatch '\\\.git\\'})
    if($hits.Count -eq 0){Log "  .$ext = NONE"}
    foreach($h in $hits){
      Log ("  {0} | {1} bytes | sha256={2}" -f
        $h.FullName.Substring($root.Length).TrimStart("\"),
        $h.Length,
        (Get-FileHash $h.FullName -Algorithm SHA256).Hash)
    }
  }
}

Log ""
Log "FRUIT REFERENCE MATRIX"
foreach($id in $ids){
  $hits=@($code | Select-String -SimpleMatch -Pattern $id -ErrorAction SilentlyContinue)
  Log "$id | hits=$($hits.Count)"
  foreach($h in $hits){
    Log ("  {0}:{1}: {2}" -f
      $h.Path.Substring($root.Length).TrimStart("\"),
      $h.LineNumber,
      $h.Line.Trim())
  }
}

Log ""
Log "CURRENT RASTER PIPELINE CONTRACT"
Get-Content $pipeline | ForEach-Object { Log ("  "+$_) }

Log ""
Log "REPLACEMENT SAFETY CONTRACT"
Log "1. Do not invent or auto-approve fruit artwork in this phase."
Log "2. Do not convert the existing fruit SVG prototypes into raster masters merely to change file format."
Log "3. New fruit PNG masters must be genuinely richer approved artwork."
Log "4. Semantic IDs remain apple-red, apple-green and banana-yellow."
Log "5. Existing SVGs remain runtime fallback until each replacement passes visual and technical review."
Log "6. Raster pipeline should become category/manifest driven rather than hard-coded to hibiscus."
Log "7. New WebP derivatives must be generated from authoritative PNG masters."
Log "8. Registry migration occurs only after derivatives pass validation."
Log "9. Old fruit SVGs retire only after no runtime/code reference remains."
Log "10. Activity manifests, curriculum ordering, mastery and progression remain unchanged."

Log ""
Log "DECISION GATE"
$hasRaster=$false
foreach($id in $ids){
  $png=@(Get-ChildItem $source -Recurse -File -Filter "$id.png" -ErrorAction SilentlyContinue)
  if($png.Count -gt 0){$hasRaster=$true}
}
if($hasRaster){
  Log "STATUS: Candidate fruit raster master(s) already exist; implementation must inspect them individually."
}else{
  Log "STATUS: No fruit raster masters found under authoritative source boundary."
  Log "ACTION: Build the replacement framework first; artwork creation/import remains a separate approval step."
}

ZipLog
Write-Host ""
Write-Host "PASS: Phase 008R3A.5 visual replacement preflight" -ForegroundColor Green
Write-Host "ZIP: $zip" -ForegroundColor Cyan
Write-Host "No artwork or repository source file was modified." -ForegroundColor Cyan
