[CmdletBinding()]
param(
  [switch]$SkipFrozenInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Phase = "008R3B.7"
$Repair = "v1"
$Slug = "repair-phase008r3b7-v1"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"

function Find-RepositoryRoot {
  $candidates = @((Get-Location).Path, $PSScriptRoot)
  foreach ($candidate in $candidates) {
    $current = [System.IO.DirectoryInfo]$candidate
    while ($null -ne $current) {
      if ((Test-Path (Join-Path $current.FullName "package.json")) -and
          (Test-Path (Join-Path $current.FullName "pnpm-workspace.yaml")) -and
          (Test-Path (Join-Path $current.FullName ".git"))) {
        return $current.FullName
      }
      $current = $current.Parent
    }
  }
  throw "Could not locate the Hibeya Akal Budi repository root."
}

$RepoRoot = Find-RepositoryRoot
Set-Location $RepoRoot

$LogDir = Join-Path $RepoRoot "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$LogPath = Join-Path $LogDir ("{0}-{1}.log" -f $Slug, $Timestamp)
$EvidencePath = Join-Path $LogDir ("{0}-{1}-evidence.txt" -f $Slug, $Timestamp)
$FailureSummaryPath = Join-Path $LogDir ("{0}-{1}-failure-summary.txt" -f $Slug, $Timestamp)
$ErrorZipPath = Join-Path $LogDir ("{0}-{1}-ERROR.zip" -f $Slug, $Timestamp)

function Write-Log([string]$Message = "") {
  $Message | Tee-Object -FilePath $LogPath -Append
}

function Write-Section([string]$Title) {
  Write-Log ""
  Write-Log ("=" * 72)
  Write-Log $Title
  Write-Log ("=" * 72)
}

function Get-Sha256([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $null
  }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Add-TextToLog([string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) {
    return
  }

  foreach ($line in ($Text -split "`r?`n")) {
    if ($line.Length -gt 0) {
      Write-Log $line
    }
  }
}

function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Section $Title
  Write-Log ("COMMAND: {0}" -f $Command)

  # Do NOT use PowerShell native 2>&1 here.
  # Windows PowerShell 5.1 can promote ordinary native stderr to a terminating
  # NativeCommandError while $ErrorActionPreference = "Stop".
  # System.Diagnostics.Process captures stdout/stderr as text and the actual
  # native ExitCode is the only success/failure authority.
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/d /s /c `"$Command`""
  $psi.WorkingDirectory = $RepoRoot
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $psi

  $stdout = New-Object System.Text.StringBuilder
  $stderr = New-Object System.Text.StringBuilder

  $outHandler = [System.Diagnostics.DataReceivedEventHandler]{
    param($sender, $eventArgs)
    if ($null -ne $eventArgs.Data) {
      [void]$stdout.AppendLine($eventArgs.Data)
    }
  }

  $errHandler = [System.Diagnostics.DataReceivedEventHandler]{
    param($sender, $eventArgs)
    if ($null -ne $eventArgs.Data) {
      [void]$stderr.AppendLine($eventArgs.Data)
    }
  }

  $process.add_OutputDataReceived($outHandler)
  $process.add_ErrorDataReceived($errHandler)

  try {
    if (-not $process.Start()) {
      throw "Could not start native command: $Command"
    }

    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    $process.WaitForExit()

    # Ensure async stream handlers have drained before reading buffers.
    $process.WaitForExit()

    $code = $process.ExitCode
  }
  finally {
    $process.remove_OutputDataReceived($outHandler)
    $process.remove_ErrorDataReceived($errHandler)
    $process.Dispose()
  }

  Add-TextToLog $stdout.ToString()

  if ($stderr.Length -gt 0) {
    Write-Log ""
    Write-Log "---- STDERR ----"
    Add-TextToLog $stderr.ToString()
    Write-Log "---- END STDERR ----"
  }

  Write-Log ("EXIT CODE: {0}" -f $code)

  if ($code -ne 0) {
    throw "Command failed (exit $code): $Command"
  }
}

function New-ErrorBundle {
  param(
    [Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$Failure
  )

  try {
    $summary = @(
      "HIBEYA AKAL BUDI - PHASE $Phase REPAIR $Repair",
      "STATUS: FAILED",
      ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")),
      ("Repository: {0}" -f $RepoRoot),
      "",
      ("ERROR: {0}" -f $Failure.Exception.Message),
      ("POSITION: {0}" -f $Failure.InvocationInfo.PositionMessage),
      "",
      "Return this ZIP to ChatGPT for diagnosis:",
      $ErrorZipPath
    )

    $summary | Set-Content -LiteralPath $FailureSummaryPath -Encoding UTF8

    if (Test-Path -LiteralPath $LogPath) {
      Copy-Item -LiteralPath $LogPath -Destination $EvidencePath -Force
    }

    $bundleFiles = @(
      $LogPath,
      $EvidencePath,
      $FailureSummaryPath
    ) | Where-Object { Test-Path -LiteralPath $_ }

    if (Test-Path -LiteralPath $ErrorZipPath) {
      Remove-Item -LiteralPath $ErrorZipPath -Force
    }

    Compress-Archive -LiteralPath $bundleFiles -DestinationPath $ErrorZipPath -CompressionLevel Optimal -Force

    Write-Host ""
    Write-Host ("ERROR ZIP: {0}" -f $ErrorZipPath)
  }
  catch {
    Write-Host ("WARNING: Could not generate ERROR ZIP: {0}" -f $_.Exception.Message)
  }
}

$ExpectedFinal = @(
  [PSCustomObject]@{
    Path = "packages\offline\src\index.ts"
    Sha256 = "41777fff6caa20510a4d341b874e5a1f84e7c04068a810e9afe294798f80c6fa"
  },
  [PSCustomObject]@{
    Path = "packages\offline\src\session.repository.ts"
    Sha256 = "d3383100945867c6fadd31e96db2b4bfa049e8116e45c4df3af532e43d847b72"
  },
  [PSCustomObject]@{
    Path = "packages\offline\src\__tests__\learningJourney.repository.test.ts"
    Sha256 = "e6b61522bd22fef5d34b3e415351a5620725805656eec61134211528543a7d64"
  },
  [PSCustomObject]@{
    Path = "packages\offline\src\__tests__\session.repository.test.ts"
    Sha256 = "e410a198461291b1376497d945c448cfca1b59cb1d8af5e8969c9add8731c996"
  },
  [PSCustomObject]@{
    Path = "packages\offline\src\learningJourney.repository.ts"
    Sha256 = "933a7b67948bc543859b0c3ef338c499229de01be49679b183c199be7a021e72"
  },
  [PSCustomObject]@{
    Path = "apps\learner-web\src\features\play\ActivityPlayer.tsx"
    Sha256 = "0a3cc4314faa311156890a97b5bfbca3975088295073f3d7b522969d69c8afb2"
  }
)

try {
  "HIBEYA AKAL BUDI - PHASE $Phase REPAIR $Repair" |
    Set-Content -LiteralPath $LogPath -Encoding UTF8

  Write-Section "REPAIR PREFLIGHT"
  Write-Log ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"))
  Write-Log ("Repository: {0}" -f $RepoRoot)
  Write-Log ("PowerShell: {0}" -f $PSVersionTable.PSVersion)

  $nodeVersion = (& node --version | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $nodeVersion) {
    throw "Node.js is not available on PATH."
  }
  Write-Log ("Node: {0}" -f $nodeVersion)
  if ($nodeVersion -notmatch '^v24\.') {
    throw "Node 24.x is required. Detected: $nodeVersion"
  }

  $pnpmVersion = (& pnpm --version | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $pnpmVersion) {
    throw "pnpm is not available on PATH."
  }
  Write-Log ("pnpm: {0}" -f $pnpmVersion)

  $gitVersion = (& git --version | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "git is not available on PATH."
  }
  Write-Log $gitVersion

  Write-Section "GIT STATUS - BEFORE REPAIR VALIDATION"
  (& git status --short 2>&1 | Out-String).TrimEnd() |
    ForEach-Object { if ($_ -ne "") { Write-Log $_ } }

  Write-Section "VERIFY R3B.7 APPLIED TARGET STATE"

  foreach ($target in $ExpectedFinal) {
    $fullPath = Join-Path $RepoRoot $target.Path
    $current = Get-Sha256 $fullPath

    Write-Log $target.Path
    Write-Log ("  current : {0}" -f $current)
    Write-Log ("  expected: {0}" -f $target.Sha256)

    if ($current -ne $target.Sha256) {
      throw "R3B.7 target drift detected: $($target.Path). This repair deliberately refuses to overwrite source files."
    }
  }

  Write-Log ""
  Write-Log "Applied target state: PASS"
  Write-Log "No source files were modified by this repair."

  if (-not $SkipFrozenInstall) {
    Invoke-Native -Title "VERIFY FROZEN LOCKFILE / WORKSPACE LINKS" `
      -Command "pnpm install --frozen-lockfile"
  }
  else {
    Write-Section "VERIFY FROZEN LOCKFILE / WORKSPACE LINKS"
    Write-Log "SKIPPED by -SkipFrozenInstall"
  }

  Invoke-Native -Title "OFFLINE PERSISTENCE TESTS" `
    -Command "pnpm --filter @akal-budi/offline test"

  Invoke-Native -Title "OFFLINE TYPECHECK" `
    -Command "pnpm --filter @akal-budi/offline typecheck"

  Invoke-Native -Title "LEARNER WEB TYPECHECK" `
    -Command "pnpm --filter learner-web typecheck"

  Invoke-Native -Title "TARGETED LEARNER TESTS" `
    -Command "pnpm --filter learner-web test -- --run src/features/play/selectLearnerActivity.test.ts src/journey/learnerJourney.test.ts src/journey/learnerProgress.test.ts"

  Invoke-Native -Title "CONTENT REPRODUCIBILITY" `
    -Command "pnpm content:check"

  Write-Section "FINAL TARGET FINGERPRINTS"
  foreach ($target in $ExpectedFinal) {
    $current = Get-Sha256 (Join-Path $RepoRoot $target.Path)
    Write-Log ("{0}  {1}" -f $current, $target.Path)

    if ($current -ne $target.Sha256) {
      throw "Final target fingerprint changed unexpectedly: $($target.Path)"
    }
  }

  Write-Section "GIT STATUS - AFTER REPAIR VALIDATION"
  (& git status --short 2>&1 | Out-String).TrimEnd() |
    ForEach-Object { if ($_ -ne "") { Write-Log $_ } }

  Write-Section "PHASE RESULT"
  Write-Log "PHASE 008R3B.7 REPAIR v1: PASS"
  Write-Log "The original R3B.7 source implementation remains applied."
  Write-Log "All validation commands completed with exit code 0."

  Copy-Item -LiteralPath $LogPath -Destination $EvidencePath -Force

  Write-Host ""
  Write-Host "PHASE 008R3B.7 REPAIR v1: PASS"
  Write-Host ("Evidence: {0}" -f $EvidencePath)
  exit 0
}
catch {
  $failure = $_

  try {
    Write-Section "PHASE FAILURE"
    Write-Log "PHASE 008R3B.7 REPAIR v1: FAILED"
    Write-Log ("ERROR: {0}" -f $failure.Exception.Message)
    Write-Log ("POSITION: {0}" -f $failure.InvocationInfo.PositionMessage)

    Write-Section "GIT STATUS - FAILURE"
    (& git status --short 2>&1 | Out-String).TrimEnd() |
      ForEach-Object { if ($_ -ne "") { Write-Log $_ } }
  }
  catch {
    # Preserve the original failure.
  }

  New-ErrorBundle -Failure $failure

  Write-Host ""
  Write-Host "PHASE 008R3B.7 REPAIR v1: FAILED"
  Write-Host "Upload the generated *-ERROR.zip file to ChatGPT."
  exit 1
}
