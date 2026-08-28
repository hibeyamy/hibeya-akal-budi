[CmdletBinding()]
param(
  [ValidateSet("preflight","validate","closeout","status")]
  [string]$Action="preflight",

  [ValidateSet("auto","content","learner","repository")]
  [string]$Scope="auto",

  [string]$RepositoryRoot="",

  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

if([string]::IsNullOrWhiteSpace($RepositoryRoot)){
  $RepositoryRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
}else{
  $RepositoryRoot=(Resolve-Path -LiteralPath $RepositoryRoot).Path
}

$Repo=$RepositoryRoot
$LogsRoot=Join-Path $Repo "tools\dev\logs"
$StateRoot=Join-Path $Repo "tools\dev\state"
$Ledger=Join-Path $StateRoot "validation-ledger.jsonl"
$RunId=Get-Date -Format "yyyyMMdd-HHmmssfff"
$Slug="hibeya-$Action-$Scope"
$RunDir=Join-Path $LogsRoot "$Slug-$RunId"
$CommandDir=Join-Path $RunDir "commands"
$MainLog=Join-Path $RunDir "session.log"
$FailureFile=Join-Path $RunDir "failure.txt"
$FailureClass=Join-Path $RunDir "failure-classification.txt"
$EvidenceZip=Join-Path $LogsRoot "$Slug-$RunId-EVIDENCE.zip"
$ErrorZip=Join-Path $LogsRoot "$Slug-$RunId-ERROR.zip"

New-Item -ItemType Directory -Force -Path $RunDir,$CommandDir,$StateRoot | Out-Null

function Stamp(){ return (Get-Date -Format "HH:mm:ss") }
function Log([string]$Message=""){
  $Line="[$(Stamp)] $Message"
  Write-Host $Line
  Add-Content -LiteralPath $MainLog -Value $Line -Encoding UTF8
}
function Sha256([string]$Text){
  $Sha=[System.Security.Cryptography.SHA256]::Create()
  try{
    $Bytes=[System.Text.Encoding]::UTF8.GetBytes($Text)
    $Hash=$Sha.ComputeHash($Bytes)
    return ([System.BitConverter]::ToString($Hash)).Replace("-","").ToLowerInvariant()
  }finally{
    $Sha.Dispose()
  }
}
function Invoke-GitRead([string]$Arguments){
  $Psi=New-Object System.Diagnostics.ProcessStartInfo
  $Psi.FileName="git.exe"
  $Psi.Arguments=$Arguments
  $Psi.WorkingDirectory=$Repo
  $Psi.UseShellExecute=$false
  $Psi.RedirectStandardOutput=$true
  $Psi.RedirectStandardError=$true
  $Psi.CreateNoWindow=$true

  $Proc=New-Object System.Diagnostics.Process
  $Proc.StartInfo=$Psi
  try{
    [void]$Proc.Start()
    $Stdout=$Proc.StandardOutput.ReadToEnd()
    $Stderr=$Proc.StandardError.ReadToEnd()
    $Proc.WaitForExit()
    if($Proc.ExitCode -ne 0){
      throw "Read-only Git command failed: git $Arguments (exit $($Proc.ExitCode)). $Stderr"
    }
    return $Stdout
  }finally{
    $Proc.Dispose()
  }
}
function Get-RepoFingerprint(){
  $Head=(Invoke-GitRead "rev-parse HEAD").Trim()
  $Status=Invoke-GitRead "status --porcelain=v1 -uall"
  $Diff=Invoke-GitRead "diff --binary -- ."
  $Staged=Invoke-GitRead "diff --cached --binary -- ."
  return (Sha256 ($Head+"`n"+$Status+"`n"+$Diff+"`n"+$Staged))
}
function Write-Ledger([string]$Gate,[string]$Fingerprint,[string]$Result,[double]$Seconds,[int]$ExitCode){
  $Record=[ordered]@{
    timestamp=(Get-Date).ToUniversalTime().ToString("o")
    action=$Action
    scope=$Scope
    gate=$Gate
    fingerprint=$Fingerprint
    result=$Result
    seconds=$Seconds
    exitCode=$ExitCode
  }
  ($Record | ConvertTo-Json -Compress) | Add-Content -LiteralPath $Ledger -Encoding UTF8
}
function Has-Pass([string]$Gate,[string]$Fingerprint){
  if($Force -or -not(Test-Path -LiteralPath $Ledger)){ return $false }
  $Found=$false
  foreach($Line in Get-Content -LiteralPath $Ledger){
    if([string]::IsNullOrWhiteSpace($Line)){ continue }
    try{
      $Row=$Line | ConvertFrom-Json
      if($Row.gate -eq $Gate -and $Row.fingerprint -eq $Fingerprint -and $Row.result -eq "PASS"){
        $Found=$true
      }
    }catch{}
  }
  return $Found
}
function Run-Gate([string]$Name,[string]$Command,[string]$Fingerprint,[switch]$Cacheable){
  $Safe=($Name -replace '[^A-Za-z0-9]+','-').Trim('-').ToLowerInvariant()
  $StdoutLog=Join-Path $CommandDir "$Safe.stdout.log"
  $StderrLog=Join-Path $CommandDir "$Safe.stderr.log"
  $CombinedLog=Join-Path $CommandDir "$Safe.log"

  if($Cacheable -and (Has-Pass $Name $Fingerprint)){
    Log "SKIP   $Name (same repository fingerprint already PASS)"
    Write-Ledger $Name $Fingerprint "SKIP-CACHED-PASS" 0 0
    return
  }

  Log "START  $Name"
  Log "CMD    $Command"
  $Started=Get-Date

  # Do not pipe native stderr through Windows PowerShell 5.1. It can promote
  # ordinary stderr text into NativeCommandError even when the child exits 0.
  # Start-Process captures both streams as files; the real exit code is authoritative.
  $Args=@("/d","/s","/c",$Command)
  $Child=Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList $Args `
    -WorkingDirectory $Repo `
    -Wait `
    -PassThru `
    -NoNewWindow `
    -RedirectStandardOutput $StdoutLog `
    -RedirectStandardError $StderrLog
  $ExitCode=$Child.ExitCode

  $OutText=""
  $ErrText=""
  if(Test-Path -LiteralPath $StdoutLog){
    $OutText=(Get-Content -LiteralPath $StdoutLog -Raw -ErrorAction SilentlyContinue)
    if($null -eq $OutText){ $OutText="" }
  }
  if(Test-Path -LiteralPath $StderrLog){
    $ErrText=(Get-Content -LiteralPath $StderrLog -Raw -ErrorAction SilentlyContinue)
    if($null -eq $ErrText){ $ErrText="" }
  }

  if(-not [string]::IsNullOrWhiteSpace($OutText)){ Write-Host $OutText.TrimEnd() }
  if(-not [string]::IsNullOrWhiteSpace($ErrText)){ Write-Host $ErrText.TrimEnd() }

  @"
COMMAND: $Command
EXIT: $ExitCode

--- STDOUT ---
$OutText

--- STDERR ---
$ErrText
"@ | Set-Content -LiteralPath $CombinedLog -Encoding UTF8

  $Seconds=[Math]::Round(((Get-Date)-$Started).TotalSeconds,1)
  if($ExitCode -ne 0){
    Write-Ledger $Name $Fingerprint "FAIL" $Seconds $ExitCode
    "CODE OR TEST FAILURE`r`nGate: $Name`r`nExitCode: $ExitCode" |
      Set-Content -LiteralPath $FailureClass -Encoding UTF8
    Log "FAIL   $Name (${Seconds}s)"
    throw "$Name failed with exit code $ExitCode."
  }

  Write-Ledger $Name $Fingerprint "PASS" $Seconds 0
  Log "PASS   $Name (${Seconds}s)"
}
function Make-Zip([string]$Destination){
  if(Test-Path -LiteralPath $Destination){ Remove-Item -LiteralPath $Destination -Force }
  Compress-Archive -Path (Join-Path $RunDir "*") -DestinationPath $Destination -CompressionLevel Optimal -Force
}
function Detect-Scope(){
  $Changed=@()
  $Changed += @((Invoke-GitRead "diff --name-only") -split "[`r`n]+" | Where-Object { $_ })
  $Changed += @((Invoke-GitRead "diff --cached --name-only") -split "[`r`n]+" | Where-Object { $_ })
  $Changed += @((Invoke-GitRead "ls-files --others --exclude-standard") -split "[`r`n]+" | Where-Object { $_ })
  $Changed=@($Changed | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

  $Changed | Set-Content -LiteralPath (Join-Path $RunDir "changed-files.txt") -Encoding UTF8

  if($Changed.Count -eq 0){ return "repository" }

  $ContentHit=$false
  $LearnerHit=$false
  $RepoHit=$false

  foreach($File in $Changed){
    $Norm=$File.Replace("\","/")
    if($Norm -match '^(content/|packages/content-library/|tools/content-compiler/)'){ $ContentHit=$true; continue }
    if($Norm -match '^(apps/learner-web/|packages/(domain|learning-engine|progress-store|content-library)/)'){ $LearnerHit=$true; continue }
    if($Norm -match '^(package\.json|pnpm-lock\.yaml|pnpm-workspace\.yaml|turbo\.json|tsconfig|tools/dev/)'){ $RepoHit=$true; continue }
  }

  if($RepoHit){ return "repository" }
  if($ContentHit -and $LearnerHit){ return "learner" }
  if($LearnerHit){ return "learner" }
  if($ContentHit){ return "content" }
  return "repository"
}

try{
  Set-Location $Repo
  "HIBEYA AKAL BUDI - PERMANENT DEV ORCHESTRATOR" | Set-Content -LiteralPath $MainLog -Encoding UTF8
  Log "Action: $Action"
  Log "Requested scope: $Scope"
  Log "Repository: $Repo"
  Log "PowerShell: $($PSVersionTable.PSVersion)"

  $Node=(& node --version | Out-String).Trim()
  $Pnpm=(& pnpm --version | Out-String).Trim()
  Log "Node: $Node"
  Log "pnpm: $Pnpm"
  if($Node -notmatch '^v24\.'){ throw "Node 24.x is required." }

  $EffectiveScope=$Scope
  if($Scope -eq "auto"){ $EffectiveScope=Detect-Scope }
  Log "Effective scope: $EffectiveScope"
  $EffectiveScope | Set-Content -LiteralPath (Join-Path $RunDir "effective-scope.txt") -Encoding UTF8

  (Invoke-GitRead "status --short") | Set-Content -LiteralPath (Join-Path $RunDir "git-status.txt") -Encoding UTF8
  $Fingerprint=Get-RepoFingerprint
  $Fingerprint | Set-Content -LiteralPath (Join-Path $RunDir "repository-fingerprint.txt") -Encoding UTF8
  Log "Fingerprint: $Fingerprint"

  "Action=$Action`r`nRequestedScope=$Scope`r`nEffectiveScope=$EffectiveScope`r`nNode=$Node`r`npnpm=$Pnpm`r`nFingerprint=$Fingerprint" |
    Set-Content -LiteralPath (Join-Path $RunDir "preflight-context.txt") -Encoding UTF8

  if($Action -eq "status"){
    if(Test-Path -LiteralPath $Ledger){
      Get-Content -LiteralPath $Ledger -Tail 50 | Set-Content -LiteralPath (Join-Path $RunDir "ledger-tail.jsonl") -Encoding UTF8
    }
    Log "PASS   status"
  }
  elseif($Action -eq "preflight"){
    Run-Gate "Git whitespace check" "git diff --check" $Fingerprint -Cacheable
    Run-Gate "Content reproducibility" "pnpm content:check" $Fingerprint -Cacheable
  }
  elseif($Action -eq "validate"){
    if($EffectiveScope -eq "content"){
      Run-Gate "Content reproducibility" "pnpm content:check" $Fingerprint -Cacheable
      Run-Gate "Content coverage" "pnpm content:coverage:validate" $Fingerprint -Cacheable
      Run-Gate "Content sequencing" "pnpm content:sequence:validate" $Fingerprint -Cacheable
      Run-Gate "Content eligibility" "pnpm content:eligibility:validate" $Fingerprint -Cacheable
      Run-Gate "Content library tests" "pnpm --filter @akal-budi/content-library test" $Fingerprint -Cacheable
      Run-Gate "Content library typecheck" "pnpm --filter @akal-budi/content-library typecheck" $Fingerprint -Cacheable
    }
    elseif($EffectiveScope -eq "learner"){
      Run-Gate "Content reproducibility" "pnpm content:check" $Fingerprint -Cacheable
      Run-Gate "Content library tests" "pnpm --filter @akal-budi/content-library test" $Fingerprint -Cacheable
      Run-Gate "Learner web typecheck" "pnpm --filter learner-web typecheck" $Fingerprint -Cacheable
      Run-Gate "Learner web tests" "pnpm --filter learner-web test" $Fingerprint -Cacheable
    }
    else{
      Run-Gate "Repository typecheck" "pnpm typecheck" $Fingerprint -Cacheable
      Run-Gate "Repository tests" "pnpm test" $Fingerprint -Cacheable
    }
    Run-Gate "Git whitespace check" "git diff --check" $Fingerprint -Cacheable
  }
  elseif($Action -eq "closeout"){
    Run-Gate "Repository typecheck" "pnpm typecheck" $Fingerprint -Cacheable
    Run-Gate "Repository tests" "pnpm test" $Fingerprint -Cacheable
    Run-Gate "Production build" "pnpm build" $Fingerprint -Cacheable
    Run-Gate "Fresh Storybook build" "pnpm storybook:build" $Fingerprint -Cacheable
    Run-Gate "Accessibility regression" "pnpm qa:a11y" $Fingerprint -Cacheable
    Run-Gate "Visual regression" "pnpm qa:visual" $Fingerprint -Cacheable
    Run-Gate "Learner journey regression" "pnpm qa:journey" $Fingerprint -Cacheable
    Run-Gate "Git whitespace check" "git diff --check" $Fingerprint -Cacheable
  }

  Log "PASS   HIBEYA $Action / $EffectiveScope"
  Make-Zip $EvidenceZip
  Write-Host ""
  Write-Host "HIBEYA ORCHESTRATOR: PASS" -ForegroundColor Green
  Write-Host "Evidence: $EvidenceZip" -ForegroundColor Cyan
  exit 0
}catch{
  $Failure=$_
  if(-not(Test-Path -LiteralPath $FailureClass)){
    "UNCLASSIFIED FAILURE" | Set-Content -LiteralPath $FailureClass -Encoding UTF8
  }
  @"
HIBEYA AKAL BUDI - PERMANENT DEV ORCHESTRATOR
STATUS: FAILED
Generated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
Action: $Action
Scope: $Scope
Repository: $Repo

MESSAGE:
$($Failure.Exception.Message)

ERROR:
$($Failure | Out-String)

POSITION:
$($Failure.InvocationInfo.PositionMessage)

STACK:
$($Failure.ScriptStackTrace)
"@ | Set-Content -LiteralPath $FailureFile -Encoding UTF8
  try{ Make-Zip $ErrorZip }catch{}
  Write-Host ""
  Write-Host "HIBEYA ORCHESTRATOR: FAILED" -ForegroundColor Red
  Write-Host "Upload only: $ErrorZip" -ForegroundColor Yellow
  exit 1
}
