param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$masters = Join-Path $root "assets\masters"
$exports = Join-Path $root "assets\exports"
$runtime = Join-Path $root "packages\assets\src\generated"
$tools = Join-Path $root "tools\assets"

New-Item -ItemType Directory -Force -Path $logs,$backups,$masters,$exports,$runtime,$tools | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007g-v2-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))
}

function Backup([string]$Path) {
  if (-not (Test-Path $Path)) { return }
  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")
  Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase007g-v2-$stamp-out.log"
  $err = Join-Path $logs "phase007g-v2-$stamp-err.log"

  $p = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $o = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $e = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($o) {
    Write-Host $o
    Add-Content $log $o -Encoding UTF8
  }

  if ($e) {
    Write-Host $e
    Add-Content $log $e -Encoding UTF8
  }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase007g-v2-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"

    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 007G V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007G V2" -ForegroundColor Cyan
Write-Host "Production Visual Target Alignment" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Target contract: the attached concept boards are treated as the visual direction,
# not as literal production artwork. This phase raises the asset bar and requires
# manual acceptance before commercialReady can become true.

$contract = @'
# HIBEYA Akal Budi â€” Production Visual Target Contract

## North-star experience

The finished product must visually converge on the approved concept direction:

- premium but warm preschool learning product;
- clean off-white application surfaces;
- strong hierarchy and generous whitespace;
- rounded cards and controls;
- restrained shadows;
- bright but controlled accent colours;
- Malaysian cultural cues without visual clutter;
- polished original learner illustrations;
- responsive learner experience across desktop, tablet and phone;
- separate parent-oriented information density;
- consistent design system across learner, parent and Storybook surfaces.

## Learner UI

- Large touch targets.
- One dominant task per screen.
- Illustration-led choices.
- Minimal reading burden for young learners.
- Clear progress and reward feedback.
- Friendly, safe visual language.
- No advertising or dark-pattern presentation.

## Parent UI

- Calm dashboard density.
- Learning time, completion, accuracy and skill progress.
- Clear recent activity.
- Avoid child-like decoration where it reduces analytical readability.

## Illustration quality bar

Every production learner asset must:

1. be immediately recognisable at 96â€“180 px;
2. use a consistent soft dimensional/vector-rendered style;
3. have clean silhouette and controlled internal detail;
4. remain readable on light backgrounds;
5. use consistent lighting and outline treatment;
6. avoid clip-art/emoji appearance;
7. avoid uncanny or anatomically confusing forms;
8. be original or carry documented commercial rights;
9. be suitable for children;
10. pass human visual review before commercial release.

## Current six-asset audit

The following six assets are the baseline family to audit together:

- apple-red
- apple-green
- banana-yellow
- hibiscus-red
- hibiscus-yellow
- hibiscus-purple

The previously approved apple/banana assets are NOT automatically rejected. They are retained unless the owner decides they materially fall below this visual contract.

## Hibiscus-specific bar

The bunga raya must have:

- unmistakable five-petal hibiscus silhouette;
- visible central throat;
- prominent projecting staminal column/anthers;
- natural petal overlap;
- supporting green leaves;
- clear red/yellow/purple colour differentiation;
- consistent family geometry and lighting;
- recognisable Malaysian bunga raya context.

## Release rule

Technical PASS is necessary but not sufficient.
Human visual approval remains mandatory for learner-facing production artwork.
'@

WriteText (Join-Path $root "PRODUCTION_VISUAL_TARGET.md") $contract

# More polished deterministic vector candidates. These remain review candidates.
function HibiscusSvg([string]$id,[string]$label,[string]$c1,[string]$c2,[string]$c3,[string]$throat,[string]$accent) {
@"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 360" role="img" aria-labelledby="title desc">
<title id="title">$label</title>
<desc id="desc">Original HIBEYA production review illustration: $label.</desc>
<defs>
  <radialGradient id="petal" cx="48%" cy="38%" r="70%">
    <stop offset="0" stop-color="$c1"/>
    <stop offset=".58" stop-color="$c2"/>
    <stop offset="1" stop-color="$c3"/>
  </radialGradient>
  <radialGradient id="throat" cx="50%" cy="45%" r="58%">
    <stop offset="0" stop-color="$throat"/>
    <stop offset=".72" stop-color="$c3"/>
    <stop offset="1" stop-color="$c2"/>
  </radialGradient>
  <linearGradient id="leaf" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#7BCB48"/>
    <stop offset=".55" stop-color="#3F9E3E"/>
    <stop offset="1" stop-color="#1F6D36"/>
  </linearGradient>
  <linearGradient id="stamen" x1="0" y1="1" x2="1" y2="0">
    <stop offset="0" stop-color="$throat"/>
    <stop offset=".7" stop-color="$accent"/>
    <stop offset="1" stop-color="#FFD85A"/>
  </linearGradient>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="5" stdDeviation="5" flood-color="#23333F" flood-opacity=".18"/>
  </filter>
</defs>

<g filter="url(#shadow)" stroke="#263844" stroke-width="5.5" stroke-linejoin="round">
  <path d="M124 247 C72 251 46 280 37 319 C78 316 112 300 139 265 C135 256 130 250 124 247Z" fill="url(#leaf)"/>
  <path d="M234 246 C286 250 313 278 323 317 C281 315 247 299 220 264 C224 256 229 250 234 246Z" fill="url(#leaf)"/>
  <path d="M112 274 C88 289 68 301 48 310" fill="none" stroke="#B7E37E" stroke-width="3"/>
  <path d="M246 273 C270 288 291 300 312 308" fill="none" stroke="#B7E37E" stroke-width="3"/>

  <path d="M179 170 C139 142 111 91 136 54 C156 25 191 44 196 91 C205 43 242 27 260 59 C282 99 246 144 205 171 C197 176 188 178 179 170Z" fill="url(#petal)"/>
  <path d="M178 171 C134 161 80 165 63 126 C50 96 77 72 112 91 C87 60 101 29 132 34 C173 40 185 104 190 154 C189 164 185 169 178 171Z" fill="url(#petal)"/>
  <path d="M177 172 C139 191 99 231 68 216 C39 202 45 166 80 151 C42 149 27 118 48 95 C78 64 130 101 169 143 C177 153 181 164 177 172Z" fill="url(#petal)"/>
  <path d="M181 173 C217 194 256 234 288 220 C318 207 313 170 279 153 C317 152 333 121 312 98 C284 66 230 102 192 143 C183 153 178 165 181 173Z" fill="url(#petal)"/>
  <path d="M180 171 C220 161 274 166 292 128 C306 98 279 73 244 91 C270 61 256 30 225 34 C184 39 171 103 168 153 C169 163 173 169 180 171Z" fill="url(#petal)"/>

  <ellipse cx="180" cy="172" rx="43" ry="35" fill="url(#throat)" stroke="none"/>
  <path d="M180 173 C203 150 229 126 254 91 C266 75 276 59 283 44" fill="none" stroke="url(#stamen)" stroke-width="8" stroke-linecap="round"/>
</g>

<g fill="$accent" stroke="#263844" stroke-width="2">
  <circle cx="285" cy="42" r="6"/>
  <circle cx="276" cy="55" r="5"/>
  <circle cx="291" cy="57" r="5"/>
  <circle cx="268" cy="68" r="5"/>
  <circle cx="282" cy="71" r="5"/>
  <circle cx="258" cy="81" r="5"/>
</g>
<g fill="#FFD85A">
  <circle cx="288" cy="40" r="2"/>
  <circle cx="279" cy="53" r="2"/>
  <circle cx="294" cy="55" r="2"/>
</g>
</svg>
"@
}

$batch = @{
  "hibiscus-red"    = HibiscusSvg "hibiscus-red" "Bunga raya merah" "#FF7A78" "#ED4149" "#A91832" "#7D1731" "#FFC43D"
  "hibiscus-yellow" = HibiscusSvg "hibiscus-yellow" "Bunga raya kuning" "#FFF28A" "#F7C83D" "#E98B24" "#C94B31" "#E95343"
  "hibiscus-purple" = HibiscusSvg "hibiscus-purple" "Bunga raya ungu" "#D6A5F2" "#A96BD4" "#683C9C" "#4E286F" "#FFC43D"
}

foreach ($id in $batch.Keys) {
  foreach ($base in @($masters,$exports,$runtime)) {
    $file = Join-Path $base "$id.svg"
    Backup $file
    WriteText $file $batch[$id]
  }
}

Write-Host "PASS: upgraded hibiscus review candidates created" -ForegroundColor Green

# Audit script: verifies the six-asset visual baseline exists and does not silently
# downgrade approved apple/banana assets.
$audit = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow",
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

const failures = [];
const report = [];

for (const id of ids) {
  const files = [
    path.join(root,"assets","masters",`${id}.svg`),
    path.join(root,"assets","exports",`${id}.svg`),
    path.join(root,"packages","assets","src","generated",`${id}.svg`)
  ];

  for (const file of files) {
    if (!fs.existsSync(file)) failures.push(`${id}: missing ${path.relative(root,file)}`);
  }

  if (files.every(fs.existsSync)) {
    const hashes = files.map(file =>
      crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex")
    );
    if (new Set(hashes).size !== 1) failures.push(`${id}: master/export/runtime mismatch`);

    const svg = fs.readFileSync(files[0],"utf8");
    if (/<script\b|<foreignObject\b|\bon[a-z]+\s*=/i.test(svg)) failures.push(`${id}: unsafe SVG`);
    if (!/viewBox=/i.test(svg)) failures.push(`${id}: missing viewBox`);
  }

  report.push({
    id,
    humanVisualReviewRequired: true,
    target: "PRODUCTION_VISUAL_TARGET.md"
  });
}

fs.writeFileSync(
  path.join(root,"assets","visual-audit.json"),
  JSON.stringify({schemaVersion:1,assets:report},null,2)+"\n",
  "utf8"
);

if (failures.length) {
  failures.forEach(x => console.error(`VISUAL BASELINE ERROR: ${x}`));
  process.exit(1);
}

console.log("VISUAL BASELINE: PASS (6 assets structurally ready for human audit)");
'@

WriteText (Join-Path $tools "audit-production-visual-baseline.mjs") $audit

# Storybook side-by-side gallery for all six assets.
$gallery = @'
const ids = [
  ["apple-red","Epal merah"],
  ["apple-green","Epal hijau"],
  ["banana-yellow","Pisang kuning"],
  ["hibiscus-red","Bunga raya merah"],
  ["hibiscus-yellow","Bunga raya kuning"],
  ["hibiscus-purple","Bunga raya ungu"]
];

const assets = ids.map(([id,label]) => ({
  id,
  label,
  src: new URL(`../../../packages/assets/src/generated/${id}.svg`, import.meta.url).href
}));

export default { title: "Assets/Production Visual Baseline" };

export function SixAssetAudit() {
  return (
    <main style={{padding:"2rem",fontFamily:"system-ui,sans-serif",background:"#faf8f2",minHeight:"100vh"}}>
      <h1>HIBEYA Akal Budi â€” Production Visual Baseline</h1>
      <p>Compare all six assets as one commercial family. Review recognisability, polish, consistency, lighting, silhouette and child suitability.</p>
      <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(220px,1fr))",gap:"1.25rem",marginTop:"2rem"}}>
        {assets.map(asset => (
          <figure key={asset.id} style={{margin:0,padding:"1.5rem",border:"1px solid #e5dfd2",borderRadius:"20px",background:"#fff",boxShadow:"0 8px 24px rgba(35,51,63,.08)"}}>
            <img src={asset.src} alt={asset.label} style={{display:"block",width:"180px",height:"180px",objectFit:"contain",margin:"0 auto"}} />
            <figcaption style={{textAlign:"center",marginTop:"1rem",fontWeight:700}}>
              {asset.label}<br/><small style={{fontWeight:500}}>{asset.id}</small>
            </figcaption>
          </figure>
        ))}
      </div>
    </main>
  );
}
'@

WriteText (Join-Path $root "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx") $gallery

# Root scripts, safely merged.
$packagePath = Join-Path $root "package.json"
Backup $packagePath
$temp = Join-Path $env:TEMP "hibeya-phase007g-v2-package.cjs"
WriteText $temp @'
const fs=require("fs");
const p=process.argv[2];
const pkg=JSON.parse(fs.readFileSync(p,"utf8"));
pkg.scripts ??= {};
pkg.scripts["assets:visual-baseline:audit"]="node tools/assets/audit-production-visual-baseline.mjs";
pkg.scripts["assets:visual-baseline:review"]="pnpm assets:visual-baseline:audit && pnpm storybook:build";
fs.writeFileSync(p,JSON.stringify(pkg,null,2)+"\n","utf8");
'@
& node $temp $packagePath
if ($LASTEXITCODE -ne 0) { throw "package.json update failed" }
Remove-Item $temp -Force -ErrorAction SilentlyContinue

Run "Six-asset production visual audit" "pnpm assets:visual-baseline:audit"
Run "Asset provenance validation" "pnpm assets:validate"
Run "Asset production pipeline validation" "pnpm assets:pipeline:validate"
Run "Illustration system validation" "pnpm illustration:validate"
Run "Storybook production build" "pnpm storybook:build"
Run "Asset package typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Curriculum source validation" "pnpm curriculum:sources:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 007G V2" "git add PRODUCTION_VISUAL_TARGET.md assets packages/assets/src/generated apps/ui-storybook/stories/ProductionVisualBaseline.stories.tsx tools/assets package.json"
  Run "Commit Phase 007G V2" 'git commit -m "feat: align learner assets to production visual target"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007G V2: PASS - MANUAL VISUAL REVIEW REQUIRED" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Run: pnpm storybook" -ForegroundColor Cyan
Write-Host "Open: Assets -> Production Visual Baseline -> Six Asset Audit" -ForegroundColor Cyan
Write-Host ""
Write-Host "Do NOT finalise the hibiscus batch until all six assets have been compared" -ForegroundColor Yellow
Write-Host "against PRODUCTION_VISUAL_TARGET.md." -ForegroundColor Yellow
