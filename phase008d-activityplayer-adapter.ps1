param([switch]$Commit)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$player=Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
$bridge=Join-Path $root "apps\learner-web\src\journey\LearnerActivityBridge.tsx"
if(!(Test-Path $player)){throw "Missing ActivityPlayer"}
if(!(Test-Path $bridge)){throw "Missing LearnerActivityBridge"}
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$backup=Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $backup|Out-Null
Copy-Item $player (Join-Path $backup "$stamp-ActivityPlayer.tsx") -Force
Copy-Item $bridge (Join-Path $backup "$stamp-LearnerActivityBridge.tsx") -Force

$patch=Join-Path $env:TEMP "hibeya-008d.cjs"
@'
const fs=require("fs");
const p=process.argv[2];
let s=fs.readFileSync(p,"utf8").replace(/\r\n/g,"\n");
if(!s.includes("export function ActivityPlayerAdapter(")){
 const m="\n\nfunction LearnerMessage({";
 if(!s.includes(m)) throw Error("LearnerMessage boundary not found");
 const a=`

export interface ActivityPlayerAdapterProps {
  activityId: string;
  onComplete?: () => void;
  onExit: () => void;
}

export function ActivityPlayerAdapter({
  activityId,
  onComplete,
  onExit
}: ActivityPlayerAdapterProps) {
  const network = useNetworkStatus();
  const runtimeActivity = resolveRuntimeActivity(activityId);

  if (!runtimeActivity) {
    return (
      <LearnerMessage
        title="Aktiviti belum tersedia"
        message="Kandungan aktiviti tidak dapat dimuatkan."
      />
    );
  }

  return (
    <ResolvedActivityPlayer
      key={runtimeActivity.catalogue.id}
      runtimeActivity={runtimeActivity}
      network={network}
      offlineProfile={false}
      onContinue={onExit}
      onComplete={onComplete}
      onExit={onExit}
      explicitJourneyMode={true}
    />
  );
}
`;
 s=s.replace(m,a+m);
 s=s.replace(
`  onContinue:
    () => void;
}`,
`  onContinue:
    () => void;

  onComplete?:
    () => void;

  onExit?:
    () => void;

  explicitJourneyMode?:
    boolean;
}`);
 s=s.replace(
`  offlineProfile,
  onContinue
}: ResolvedActivityPlayerProps) {`,
`  offlineProfile,
  onContinue,
  onComplete,
  onExit,
  explicitJourneyMode = false
}: ResolvedActivityPlayerProps) {`);
 const c=`      await recordCompletedJourneyActivity(
        activity.id
      );


      setRecoverySession(`;
 if(!s.includes(c)) throw Error("Completion boundary not found");
 s=s.replace(c,`      await recordCompletedJourneyActivity(
        activity.id
      );


      onComplete?.();


      setRecoverySession(`);
 const h=`      <header className="mb-8">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">`;
 if(!s.includes(h)) throw Error("Header boundary not found");
 s=s.replace(h,`      <header className="mb-8">
        {explicitJourneyMode && onExit && (
          <button
            type="button"
            onClick={onExit}
            className="mb-5 min-h-14 rounded-2xl border-2 border-slate-200 bg-white px-5 py-3 font-extrabold text-slate-700 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-slate-200"
          >
            Keluar aktiviti
          </button>
        )}

        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">`);
 fs.writeFileSync(p,s,"utf8");
}
'@ | Set-Content -Path $patch -Encoding UTF8
node $patch $player
if($LASTEXITCODE-ne 0){throw "ActivityPlayer patch failed"}
Remove-Item $patch -Force

@'
import {
  ActivityPlayerAdapter
} from "../features/play/ActivityPlayer";

export interface LearnerActivityBridgeProps {
  activityId: string;
  onClose: () => void;
  onComplete?: () => void;
}

export function LearnerActivityBridge({
  activityId,
  onClose,
  onComplete
}: LearnerActivityBridgeProps) {
  return (
    <ActivityPlayerAdapter
      activityId={activityId}
      onComplete={onComplete}
      onExit={onClose}
    />
  );
}
'@ | Set-Content -Path $bridge -Encoding UTF8

function Run([string]$n,[string]$c){
 Write-Host "`n==> $n" -ForegroundColor Cyan
 Invoke-Expression $c
 if($LASTEXITCODE-ne 0){throw "$n failed"}
 Write-Host "PASS: $n" -ForegroundColor Green
}
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Storybook build" "pnpm storybook:build"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression" "pnpm qa:visual"
Run "Git whitespace check" "git diff --check"
if($Commit){
 Run "Stage" "git add apps/learner-web/src/features/play/ActivityPlayer.tsx apps/learner-web/src/journey/LearnerActivityBridge.tsx"
 Run "Commit" 'git commit -m "feat: connect learner journey to activity player"'
}
Write-Host "`nPHASE 008D: PASS" -ForegroundColor Green
