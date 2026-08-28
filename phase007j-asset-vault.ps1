param([switch]$Commit)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"; $tools=Join-Path $root "tools\assets"; $vault=Join-Path $root "assets\vault"
New-Item -ItemType Directory -Force -Path $logs,$tools,$vault|Out-Null
$runId=Get-Date -Format "yyyyMMdd-HHmmssfff"; $log=Join-Path $logs "phase007j-$runId.log"
function WriteText([string]$Path,[string]$Content){$d=Split-Path -Parent $Path;if($d){New-Item -ItemType Directory -Force -Path $d|Out-Null};[IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))}
function Run([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

    $commandStamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $stdout = Join-Path $logs "phase007j-$commandStamp-stdout.log"
    $stderr = Join-Path $logs "phase007j-$commandStamp-stderr.log"

    $process = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList @("/d", "/s", "/c", $Command) `
        -WorkingDirectory $root `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -NoNewWindow `
        -Wait `
        -PassThru

    $outText = if (Test-Path $stdout) {
        Get-Content $stdout -Raw -ErrorAction SilentlyContinue
    } else {
        ""
    }

    $errText = if (Test-Path $stderr) {
        Get-Content $stderr -Raw -ErrorAction SilentlyContinue
    } else {
        ""
    }

    if ($outText) {
        Write-Host $outText
        Add-Content $log "`nSTDOUT:`n$outText" -Encoding UTF8
    }

    if ($errText) {
        # stderr is diagnostic output only. Native tools such as pnpm can
        # legitimately write progress/output here even when exit code is 0.
        Write-Host $errText
        Add-Content $log "`nSTDERR:`n$errText" -Encoding UTF8
    }

    $exitCode = $process.ExitCode

    if ($exitCode -ne 0) {
        $diagnostic = Join-Path $logs "phase007j-command-failure-$commandStamp.log"

        $diagnosticText = @"
PHASE 007J COMMAND FAILURE
NAME: $Name
COMMAND: $Command
EXIT CODE: $exitCode

STDOUT:
$outText

STDERR:
$errText
"@

        [IO.File]::WriteAllText(
            $diagnostic,
            $diagnosticText,
            [Text.UTF8Encoding]::new($false)
        )

        throw "$Name failed with exit code $exitCode. Diagnostic: $diagnostic"
    }

    Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
    Write-Host "PASS: $Name" -ForegroundColor Green
}
trap{Add-Content $log "`n$($_|Out-String)`n$($_.ScriptStackTrace)";Write-Host "`nPHASE 007J: FAILED" -ForegroundColor Red;Write-Host "Log: $log" -ForegroundColor Yellow;exit 1}
Write-Host "`n====================================================`nHIBEYA AKAL BUDI - PHASE 007J`nAsset Vault + Versioned Integrity Catalogue`n====================================================" -ForegroundColor Cyan

WriteText (Join-Path $tools "build-asset-vault.mjs") @'
import crypto from "node:crypto"; import fs from "node:fs"; import path from "node:path"; import process from "node:process";
const root=process.cwd(), md=path.join(root,"assets","manifests"), vd=path.join(root,"assets","vault"), cp=path.join(vd,"catalogue.json");
fs.mkdirSync(vd,{recursive:true});
const hash=f=>crypto.createHash("sha256").update(fs.readFileSync(f)).digest("hex");
const old=fs.existsSync(cp)?JSON.parse(fs.readFileSync(cp,"utf8")):{assets:[]};
const assets=[];
for(const n of fs.readdirSync(md).filter(x=>x.endsWith(".json")).sort()){
 const m=JSON.parse(fs.readFileSync(path.join(md,n),"utf8")); if(m.status!=="production"||m.commercialReady!==true)continue;
 const rr=m.runtime?.file;if(!rr)throw new Error(`${m.id}: missing runtime.file`);const ra=path.join(root,rr);if(!fs.existsSync(ra))throw new Error(`${m.id}: runtime missing`);
 const mr=m.sourceFile??m.runtimeOptimisation?.sourceMaster??null, ma=mr?path.join(root,mr):null, rh=hash(ra), mh=ma&&fs.existsSync(ma)?hash(ma):null;
 const prev=old.assets?.find(x=>x.id===m.id);let version=prev?.version??1;if(prev&&(prev.runtimeSha256!==rh||prev.masterSha256!==mh))version++;
 assets.push({id:m.id,version,status:"production",commercialReady:true,masterFile:mr,masterSha256:mh,runtimeFile:rr,runtimeSha256:rh,runtimeBytes:fs.statSync(ra).size,alt:m.runtime?.alt??null});
}
fs.writeFileSync(cp,JSON.stringify({schemaVersion:1,assetCount:assets.length,assets},null,2)+"\n");
console.log(`ASSET VAULT: ${assets.length} production assets catalogued`);
'@

WriteText (Join-Path $tools "validate-asset-vault.mjs") @'
import crypto from "node:crypto";import fs from "node:fs";import path from "node:path";import process from "node:process";
const root=process.cwd(),p=path.join(root,"assets","vault","catalogue.json"),bad=[];if(!fs.existsSync(p)){console.error("ASSET VAULT ERROR: catalogue missing");process.exit(1)}
const c=JSON.parse(fs.readFileSync(p,"utf8")),h=f=>crypto.createHash("sha256").update(fs.readFileSync(f)).digest("hex"),ids=new Set();
for(const a of c.assets??[]){if(ids.has(a.id))bad.push(`${a.id}: duplicate`);ids.add(a.id);if(!Number.isInteger(a.version)||a.version<1)bad.push(`${a.id}: invalid version`);
 const r=path.join(root,a.runtimeFile);if(!fs.existsSync(r))bad.push(`${a.id}: runtime missing`);else if(h(r)!==a.runtimeSha256)bad.push(`${a.id}: runtime hash mismatch`);
 if(a.masterFile){const m=path.join(root,a.masterFile);if(!fs.existsSync(m))bad.push(`${a.id}: master missing`);else if(h(m)!==a.masterSha256)bad.push(`${a.id}: master hash mismatch`)}}
if(c.assetCount!==(c.assets??[]).length)bad.push("assetCount mismatch");if(bad.length){bad.forEach(x=>console.error(`ASSET VAULT ERROR: ${x}`));process.exit(1)}
console.log(`ASSET VAULT VALIDATION: PASS (${c.assetCount} assets)`);
'@

WriteText (Join-Path $tools "report-asset-vault.mjs") @'
import fs from "node:fs";import path from "node:path";import process from "node:process";
const c=JSON.parse(fs.readFileSync(path.join(process.cwd(),"assets","vault","catalogue.json"),"utf8"));
console.log("\nHIBEYA ASSET VAULT\n==================");for(const a of c.assets)console.log(`${a.id} | v${a.version} | ${(a.runtimeBytes/1024).toFixed(1)} KB | ${a.runtimeFile}`);console.log(`\nProduction assets: ${c.assetCount}`);
'@

WriteText (Join-Path $root "ASSET_VAULT.md") @'
# HIBEYA Asset Vault
The vault is the integrity catalogue for production-ready HIBEYA artwork. Manifests remain the approval/provenance source of truth.

It records stable asset ID, active version, master/runtime paths, SHA-256 integrity, runtime size and bilingual alt metadata. Approved masters stay under `assets/masters/`; optimised runtime assets stay under `packages/assets/src/generated/`.
'@

$pkg=Join-Path $root "package.json";$temp=Join-Path $env:TEMP "hibeya-phase007j-package.cjs"
WriteText $temp @'
const fs=require("fs"),p=process.argv[2],x=JSON.parse(fs.readFileSync(p,"utf8"));x.scripts??={};
x.scripts["assets:vault:build"]="node tools/assets/build-asset-vault.mjs";
x.scripts["assets:vault:validate"]="node tools/assets/validate-asset-vault.mjs";
x.scripts["assets:vault:report"]="node tools/assets/report-asset-vault.mjs";
x.scripts["assets:vault:qa"]="pnpm assets:vault:validate && pnpm assets:runtime:check && pnpm assets:runtime:validate";
fs.writeFileSync(p,JSON.stringify(x,null,2)+"\n");
'@
node $temp $pkg;if($LASTEXITCODE-ne 0){throw "package.json update failed"};Remove-Item $temp -Force

Run "Build asset vault catalogue" "pnpm assets:vault:build"
Run "Validate asset vault integrity" "pnpm assets:vault:validate"
Run "Asset vault report" "pnpm assets:vault:report"
Run "Commercial registry reproducibility" "pnpm assets:runtime:check"
Run "Commercial runtime validation" "pnpm assets:runtime:validate"
Run "Commercial release validation" "pnpm assets:commercial:validate"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Git whitespace check" "git diff --check"
if($Commit){Run "Stage Phase 007J" "git add assets/vault tools/assets ASSET_VAULT.md package.json";Run "Commit Phase 007J" 'git commit -m "feat: add versioned production asset vault"'}
Write-Host "`n====================================================`nPHASE 007J: PASS`n====================================================" -ForegroundColor Green
