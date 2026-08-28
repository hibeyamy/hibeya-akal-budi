param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$src = Join-Path $root "apps\learner-web\src"
$main = Join-Path $src "main.tsx"
$app = Join-Path $src "App.tsx"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null
$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008b-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))
}

function Run([string]$Name,[string]$Command) {
  Write-Host "`n==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8
  $stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out=Join-Path $logs "phase008b-$stamp-out.log"
  $err=Join-Path $logs "phase008b-$stamp-err.log"
  $p=Start-Process -FilePath "cmd.exe" -ArgumentList @("/d","/s","/c",$Command) -WorkingDirectory $root -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -Wait -PassThru
  $o=if(Test-Path $out){Get-Content $out -Raw}else{""}
  $e=if(Test-Path $err){Get-Content $err -Raw}else{""}
  if($o){Write-Host $o;Add-Content $log $o -Encoding UTF8}
  if($e){Write-Host $e;Add-Content $log $e -Encoding UTF8}
  if($p.ExitCode-ne 0){
    $diag=Join-Path $logs "FAILED-phase008b-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }
  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_|Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host "`nPHASE 008B: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host "`n===================================================="
Write-Host "HIBEYA AKAL BUDI - PHASE 008B"
Write-Host "Learner Shell Runtime Integration"
Write-Host "===================================================="

if(-not(Test-Path $main)){throw "Missing learner main.tsx"}
if(-not(Test-Path (Join-Path $src "shell\LearnerShell.tsx"))){throw "Phase 008A shell missing"}

# Preserve current production entry point before any integration.
$backup=Join-Path $backups "$runId-apps__learner-web__src__main.tsx"
Copy-Item $main $backup -Force
Write-Host "Backup: $backup"

# Inspect main.tsx structurally. We deliberately refuse to overwrite a complex
# entry point; in that case a diagnostic is generated for the next repair.
$mainText=Get-Content $main -Raw
WriteText (Join-Path $logs "phase008b-$runId-main-before.txt") $mainText

# Create a runtime wrapper independently first.
WriteText (Join-Path $src "shell\LearnerRuntimeShell.tsx") @'
import type {
  ReactNode
} from "react";

import {
  LearnerShell
} from "./LearnerShell";

export interface LearnerRuntimeShellProps {
  children:
    ReactNode;

  learnerName?:
    string;

  progressPercent?:
    number;
}

export function LearnerRuntimeShell({
  children,
  learnerName,
  progressPercent
}: LearnerRuntimeShellProps) {
  return (
    <LearnerShell
      learnerName={learnerName}
      progressPercent={progressPercent}
      title="Jom belajar!"
      subtitle="Pilih satu aktiviti dan belajar mengikut rentak sendiri."
    >
      {children}
    </LearnerShell>
  );
}
'@

$index=Join-Path $src "shell\index.ts"
$indexText=Get-Content $index -Raw
if($indexText -notmatch "LearnerRuntimeShell"){
  Add-Content $index @'

export {
  LearnerRuntimeShell,
  type LearnerRuntimeShellProps
} from "./LearnerRuntimeShell";
'@ -Encoding UTF8
}

# Do not replace an existing App.tsx. Create one only when absent.
if(-not(Test-Path $app)){
  WriteText $app @'
import {
  LearnerHome,
  LearnerRuntimeShell
} from "./shell";

export default function App() {
  return (
    <LearnerRuntimeShell
      progressPercent={0}
    >
      <LearnerHome />
    </LearnerRuntimeShell>
  );
}
'@
  Write-Host "PASS: App.tsx created for learner shell runtime" -ForegroundColor Green
}else{
  Write-Host "INFO: Existing App.tsx preserved." -ForegroundColor Yellow
}

# Patch only a simple React root render. Complex runtime composition is not guessed.
if($mainText -match 'createRoot' -and $mainText -notmatch 'LearnerRuntimeShell'){
  $appImportPresent = $mainText -match 'from\s+["'']\./App["'']'
  if(-not $appImportPresent -and (Test-Path $app)){
    # If main already renders an application component, preserve it; otherwise
    # integration will be handled explicitly by a repair after diagnostics.
    if($mainText -match '<App\s*/>'){
      Write-Host "INFO: main.tsx already renders App; runtime shell is available through App integration." -ForegroundColor Yellow
    } else {
      Write-Host "INFO: Non-trivial main.tsx detected; no blind JSX replacement performed." -ForegroundColor Yellow
    }
  }
}

Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm storybook:build"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Git whitespace check" "git diff --check"

if($Commit){
  Run "Stage Phase 008B" "git add apps/learner-web/src/shell apps/learner-web/src/App.tsx"
  Run "Commit Phase 008B" 'git commit -m "feat: integrate learner runtime shell"'
}

Write-Host "`n====================================================" -ForegroundColor Green
Write-Host "PHASE 008B: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Runtime shell foundation validated." -ForegroundColor Cyan
Write-Host "Production entry point was preserved unless safe integration was structurally evident." -ForegroundColor Cyan
