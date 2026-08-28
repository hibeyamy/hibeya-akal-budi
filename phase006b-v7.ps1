param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006b-v7-session-$runId.log"

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $directory = Split-Path -Parent $Path

  if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Write-SessionLog {
  param(
    [Parameter(Mandatory)][string]$Message
  )

  Add-Content `
    -Path $sessionLog `
    -Value $Message `
    -Encoding UTF8
}

function Write-Step {
  param([string]$Message)

  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
  Write-SessionLog "==> $Message"
}

trap {
  $details = @"
PHASE 006B V7 UNHANDLED ERROR

TIME:
$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")

MESSAGE:
$($_.Exception.Message)

ERROR RECORD:
$($_ | Out-String)

POSITION:
$($_.InvocationInfo.PositionMessage)

SCRIPT STACK:
$($_.ScriptStackTrace)
"@

  Write-Utf8NoBom `
    -Path $sessionLog `
    -Content $details

  Write-Host ""
  Write-Host "Phase 006B V7 failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Write-Step $Name

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase006b-v7-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase006b-v7-$timestamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d", "/s", "/c", $Command) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText = if (Test-Path $stdout) { Get-Content $stdout -Raw } else { "" }
  $errText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { "" }

  if ($outText) {
    Write-Host $outText
    Write-SessionLog $outText
  }

  if ($errText) {
    Write-Host $errText
    Write-SessionLog $errText
  }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase006b-v7-$timestamp-$($Name.Replace(' ','-')).log"

    Write-Utf8NoBom `
      -Path $diagnostic `
      -Content @"
COMMAND:
$Command

EXIT CODE:
$($process.ExitCode)

STDOUT:
$outText

STDERR:
$errText
"@

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diagnostic"
  }

  Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

function Get-NestedPropertyValue {
  param(
    [Parameter(Mandatory)]$Object,
    [Parameter(Mandatory)][string[]]$Path
  )

  $current = $Object

  foreach ($segment in $Path) {
    if ($null -eq $current) {
      return $null
    }

    $property = $current.PSObject.Properties[$segment]

    if ($null -eq $property) {
      return $null
    }

    $current = $property.Value
  }

  return $current
}

function Get-RequiredWorkspaceDependency {
  param(
    [Parameter(Mandatory)][string]$PackageJsonPath,
    [Parameter(Mandatory)][string]$Section,
    [Parameter(Mandatory)][string]$DependencyName
  )

  if (-not (Test-Path $PackageJsonPath)) {
    throw "Package file not found: $PackageJsonPath"
  }

  $pkg = Get-Content $PackageJsonPath -Raw | ConvertFrom-Json

  $value = Get-NestedPropertyValue `
    -Object $pkg `
    -Path @($Section, $DependencyName)

  if (
    $null -eq $value -or
    [string]::IsNullOrWhiteSpace([string]$value)
  ) {
    throw "Could not resolve $Section.$DependencyName from $PackageJsonPath"
  }

  return ([string]$value).Trim()
}

function Find-WorkspaceDependency {
  param(
    [Parameter(Mandatory)][string]$DependencyName
  )

  $candidateFiles = @()

  $rootPackage = Join-Path $repoRoot "package.json"
  if (Test-Path $rootPackage) {
    $candidateFiles += Get-Item $rootPackage
  }

  foreach ($base in @("apps", "packages")) {
    $basePath = Join-Path $repoRoot $base

    if (Test-Path $basePath) {
      $candidateFiles += Get-ChildItem `
        -Path $basePath `
        -Recurse `
        -File `
        -Filter "package.json" `
        -ErrorAction SilentlyContinue |
      Where-Object {
        $_.FullName -notmatch '[\\/]node_modules[\\/]'
      }
    }
  }

  foreach ($file in $candidateFiles) {
    try {
      $pkg = Get-Content $file.FullName -Raw | ConvertFrom-Json

      foreach ($section in @("devDependencies", "dependencies", "peerDependencies")) {
        $value = Get-NestedPropertyValue `
          -Object $pkg `
          -Path @($section, $DependencyName)

        if (
          $null -ne $value -and
          -not [string]::IsNullOrWhiteSpace([string]$value)
        ) {
          $resolved = ([string]$value).Trim()

          Write-SessionLog "Resolved $DependencyName=$resolved from $($file.FullName) [$section]"

          return $resolved
        }
      }
    }
    catch {
      continue
    }
  }

  throw "Could not find dependency '$DependencyName' in any workspace package.json."
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006B V7" -ForegroundColor Cyan
Write-Host "Shared React Primitives + Storybook" -ForegroundColor Cyan
Write-Host "Workspace dependency discovery + full diagnostics" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Write-SessionLog "PHASE 006B V7 START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"


# ============================================================
# 1. Resolve dependencies robustly.
# ============================================================

Write-Step "Resolving workspace dependency versions"

$learnerPackagePath =
  Join-Path $repoRoot "apps\learner-web\package.json"

$reactRange =
  Get-RequiredWorkspaceDependency `
    -PackageJsonPath $learnerPackagePath `
    -Section "dependencies" `
    -DependencyName "react"

$reactDomRange =
  Get-RequiredWorkspaceDependency `
    -PackageJsonPath $learnerPackagePath `
    -Section "dependencies" `
    -DependencyName "react-dom"

$typesReactRange =
  Find-WorkspaceDependency `
    -DependencyName "@types/react"

$typesReactDomRange =
  Find-WorkspaceDependency `
    -DependencyName "@types/react-dom"

$typescriptRange =
  Find-WorkspaceDependency `
    -DependencyName "typescript"

Write-Host "React: $reactRange" -ForegroundColor Green
Write-Host "react-dom: $reactDomRange" -ForegroundColor Green
Write-Host "@types/react: $typesReactRange" -ForegroundColor Green
Write-Host "@types/react-dom: $typesReactDomRange" -ForegroundColor Green
Write-Host "TypeScript: $typescriptRange" -ForegroundColor Green


# ============================================================
# 2. Build package manifests fully before serialisation.
# ============================================================

Write-Step "Preparing package metadata"

$uiPackage = @{
  "name" = "@akal-budi/ui"
  "version" = "0.0.0"
  "private" = $true
  "type" = "module"
  "exports" = @{
    "." = "./src/index.ts"
    "./styles.css" = "./src/styles.css"
  }
  "scripts" = @{
    "typecheck" = "tsc --noEmit"
    "test" = "echo `"tests pending`""
    "build" = "echo `"build source package`""
  }
  "peerDependencies" = @{
    "react" = $reactRange
    "react-dom" = $reactDomRange
  }
  "devDependencies" = @{
    "typescript" = $typescriptRange
    "@types/react" = $typesReactRange
    "@types/react-dom" = $typesReactDomRange
  }
}

$storybookPackage = @{
  "name" = "ui-storybook"
  "version" = "0.0.0"
  "private" = $true
  "type" = "module"
  "scripts" = @{
    "storybook" = "storybook dev -p 6006"
    "build-storybook" = "storybook build"
    "typecheck" = "tsc --noEmit"
    "test" = "echo `"storybook stories validated by build`""
    "build" = "storybook build"
  }
  "dependencies" = @{
    "@akal-budi/ui" = "workspace:*"
    "@akal-budi/design-system" = "workspace:*"
    "react" = $reactRange
    "react-dom" = $reactDomRange
  }
  "devDependencies" = @{
    "typescript" = $typescriptRange
    "@types/react" = $typesReactRange
    "@types/react-dom" = $typesReactDomRange
  }
}


# ============================================================
# 3. Shared UI package.
# ============================================================

Write-Step "Writing @akal-budi/ui"

$uiRoot = Join-Path $repoRoot "packages\ui"

New-Item `
  -ItemType Directory `
  -Force `
  -Path (Join-Path $uiRoot "src") `
  | Out-Null

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "package.json") `
  -Content ($uiPackage | ConvertTo-Json -Depth 100)

$uiTsconfig = @'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  },
  "include": ["src"]
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "tsconfig.json") `
  -Content $uiTsconfig

$uiStyles = @'
.ab-ui-button {
  min-height: var(--ab-touch-target-min, 44px);
  border: 0;
  border-radius: var(--ab-radius-lg);
  padding: 0.75rem 1.25rem;
  font: inherit;
  font-weight: 600;
  cursor: pointer;
  transition:
    transform var(--ab-motion-quick) var(--ab-motion-ease-standard),
    background-color var(--ab-motion-gentle) var(--ab-motion-ease-standard);
}

.ab-ui-button:focus-visible {
  outline: 4px solid var(--ab-focus-ring);
  outline-offset: 3px;
}

.ab-ui-button:disabled {
  cursor: default;
  opacity: 0.6;
}

.ab-ui-button[data-variant="primary"] {
  background: var(--ab-brand-ink);
  color: var(--ab-text-inverse);
}

.ab-ui-button[data-variant="secondary"] {
  border: 1px solid #cbd5e1;
  background: var(--ab-surface-card);
  color: var(--ab-text-primary);
}

.ab-ui-button[data-variant="gentle"] {
  background: var(--ab-feedback-gentle-surface);
  color: var(--ab-feedback-gentle-text);
}

.ab-ui-surface {
  border-radius: var(--ab-radius-xl);
  background: var(--ab-surface-card);
  color: var(--ab-text-primary);
}

.ab-ui-surface[data-elevation="flat"] {
  box-shadow: none;
}

.ab-ui-surface[data-elevation="raised"] {
  box-shadow:
    0 1px 2px rgb(15 23 42 / 0.06),
    0 8px 24px rgb(15 23 42 / 0.06);
}

.ab-ui-feedback {
  border-radius: var(--ab-radius-lg);
  padding: var(--ab-space-md);
}

.ab-ui-feedback[data-tone="success"] {
  background: var(--ab-feedback-success-surface);
  color: var(--ab-feedback-success-text);
}

.ab-ui-feedback[data-tone="gentle"] {
  background: var(--ab-feedback-gentle-surface);
  color: var(--ab-feedback-gentle-text);
}

.ab-ui-feedback[data-tone="error"] {
  background: var(--ab-feedback-error-surface);
  color: var(--ab-feedback-error-text);
}

.ab-ui-audience-shell {
  min-height: 100%;
  background: var(--ab-surface-page);
  color: var(--ab-text-primary);
  font-family:
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    "Segoe UI",
    sans-serif;
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "src\styles.css") `
  -Content $uiStyles

$button = @'
import type {
  ButtonHTMLAttributes
} from "react";

export type ButtonVariant =
  | "primary"
  | "secondary"
  | "gentle";

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
}

export function Button({
  variant = "primary",
  type = "button",
  className = "",
  ...props
}: ButtonProps) {
  return (
    <button
      {...props}
      type={type}
      data-variant={variant}
      className={[
        "ab-ui-button",
        className
      ].filter(Boolean).join(" ")}
    />
  );
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "src\Button.tsx") `
  -Content $button

$surface = @'
import type {
  HTMLAttributes,
  PropsWithChildren
} from "react";

export type SurfaceElevation =
  | "flat"
  | "raised";

export interface SurfaceProps
  extends PropsWithChildren<HTMLAttributes<HTMLDivElement>> {
  elevation?: SurfaceElevation;
}

export function Surface({
  elevation = "raised",
  className = "",
  children,
  ...props
}: SurfaceProps) {
  return (
    <div
      {...props}
      data-elevation={elevation}
      className={[
        "ab-ui-surface",
        className
      ].filter(Boolean).join(" ")}
    >
      {children}
    </div>
  );
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "src\Surface.tsx") `
  -Content $surface

$feedback = @'
import type {
  HTMLAttributes,
  PropsWithChildren
} from "react";

export type FeedbackTone =
  | "success"
  | "gentle"
  | "error";

export interface FeedbackPanelProps
  extends PropsWithChildren<HTMLAttributes<HTMLDivElement>> {
  tone?: FeedbackTone;
}

export function FeedbackPanel({
  tone = "gentle",
  className = "",
  children,
  ...props
}: FeedbackPanelProps) {
  return (
    <div
      {...props}
      data-tone={tone}
      className={[
        "ab-ui-feedback",
        className
      ].filter(Boolean).join(" ")}
      aria-live={props["aria-live"] ?? "polite"}
    >
      {children}
    </div>
  );
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "src\FeedbackPanel.tsx") `
  -Content $feedback

$shell = @'
import type {
  HTMLAttributes,
  PropsWithChildren
} from "react";

export type Audience =
  | "learner"
  | "parent";

export interface AudienceShellProps
  extends PropsWithChildren<HTMLAttributes<HTMLDivElement>> {
  audience: Audience;
}

export function AudienceShell({
  audience,
  className = "",
  children,
  ...props
}: AudienceShellProps) {
  return (
    <div
      {...props}
      data-ab-audience={audience}
      className={[
        "ab-ui-audience-shell",
        className
      ].filter(Boolean).join(" ")}
    >
      {children}
    </div>
  );
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "src\AudienceShell.tsx") `
  -Content $shell

$uiIndex = @'
export { AudienceShell } from "./AudienceShell";
export { Button } from "./Button";
export { FeedbackPanel } from "./FeedbackPanel";
export { Surface } from "./Surface";

export type {
  Audience,
  AudienceShellProps
} from "./AudienceShell";

export type {
  ButtonProps,
  ButtonVariant
} from "./Button";

export type {
  FeedbackPanelProps,
  FeedbackTone
} from "./FeedbackPanel";

export type {
  SurfaceElevation,
  SurfaceProps
} from "./Surface";
'@

Write-Utf8NoBom `
  -Path (Join-Path $uiRoot "src\index.ts") `
  -Content $uiIndex


# ============================================================
# 4. Storybook workspace.
# ============================================================

Write-Step "Writing Storybook workspace"

$storybookRoot =
  Join-Path $repoRoot "apps\ui-storybook"

New-Item `
  -ItemType Directory `
  -Force `
  -Path (Join-Path $storybookRoot ".storybook") `
  | Out-Null

New-Item `
  -ItemType Directory `
  -Force `
  -Path (Join-Path $storybookRoot "stories") `
  | Out-Null

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot "package.json") `
  -Content ($storybookPackage | ConvertTo-Json -Depth 100)

$storybookTsconfig = @'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  },
  "include": [".storybook", "stories"]
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot "tsconfig.json") `
  -Content $storybookTsconfig

$main = @'
import type {
  StorybookConfig
} from "@storybook/react-vite";

const config: StorybookConfig = {
  stories: [
    "../stories/**/*.stories.@(ts|tsx)"
  ],
  addons: [
    "@storybook/addon-a11y"
  ],
  framework: {
    name: "@storybook/react-vite",
    options: {}
  }
};

export default config;
'@

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot ".storybook\main.ts") `
  -Content $main

$preview = @'
import type {
  Preview
} from "@storybook/react-vite";

import "../../../packages/design-system/src/tokens.css";
import "@akal-budi/ui/styles.css";

const preview: Preview = {
  parameters: {
    controls: {
      expanded: true
    },
    a11y: {
      test: "error"
    }
  }
};

export default preview;
'@

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot ".storybook\preview.ts") `
  -Content $preview

$buttonStory = @'
import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  Button
} from "@akal-budi/ui";

const meta = {
  title: "Primitives/Button",
  component: Button,
  decorators: [
    Story => (
      <AudienceShell
        audience="learner"
        style={{ padding: "2rem" }}
      >
        <Story />
      </AudienceShell>
    )
  ],
  args: {
    children: "Aktiviti seterusnya"
  }
} satisfies Meta<typeof Button>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Primary: Story = {};

export const Secondary: Story = {
  args: {
    variant: "secondary",
    children: "Mula semula"
  }
};

export const Gentle: Story = {
  args: {
    variant: "gentle",
    children: "Sambung"
  }
};

export const Disabled: Story = {
  args: {
    disabled: true,
    children: "Belum tersedia"
  }
};
'@

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot "stories\Button.stories.tsx") `
  -Content $buttonStory

$surfaceStory = @'
import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  Surface
} from "@akal-budi/ui";

const meta = {
  title: "Primitives/Surface",
  component: Surface,
  decorators: [
    Story => (
      <AudienceShell
        audience="learner"
        style={{ padding: "2rem" }}
      >
        <Story />
      </AudienceShell>
    )
  ],
  args: {
    style: {
      maxWidth: "28rem",
      padding: "2rem"
    },
    children: "Permukaan kandungan Akal Budi"
  }
} satisfies Meta<typeof Surface>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Raised: Story = {};

export const Flat: Story = {
  args: {
    elevation: "flat"
  }
};
'@

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot "stories\Surface.stories.tsx") `
  -Content $surfaceStory

$feedbackStory = @'
import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  FeedbackPanel
} from "@akal-budi/ui";

const meta = {
  title: "Primitives/FeedbackPanel",
  component: FeedbackPanel,
  decorators: [
    Story => (
      <AudienceShell
        audience="learner"
        style={{ padding: "2rem" }}
      >
        <Story />
      </AudienceShell>
    )
  ],
  args: {
    children: "Cuba lagi. Tengok dengan teliti."
  }
} satisfies Meta<typeof FeedbackPanel>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Gentle: Story = {};

export const Success: Story = {
  args: {
    tone: "success",
    children: "Betul. Bagus."
  }
};

export const Error: Story = {
  args: {
    tone: "error",
    children: "Aktiviti belum dapat dimuatkan."
  }
};
'@

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot "stories\FeedbackPanel.stories.tsx") `
  -Content $feedbackStory

$audienceStory = @'
import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  Button,
  Surface
} from "@akal-budi/ui";

const meta = {
  title: "Foundations/Audience",
  component: AudienceShell
} satisfies Meta<typeof AudienceShell>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Learner: Story = {
  args: {
    audience: "learner",
    style: {
      padding: "2rem"
    },
    children: (
      <Surface style={{ padding: "2rem" }}>
        <h2>Learner</h2>
        <p>
          Large targets, low reading density, minimal motion.
        </p>
        <Button>
          Teruskan
        </Button>
      </Surface>
    )
  }
};

export const Parent: Story = {
  args: {
    audience: "parent",
    style: {
      padding: "2rem"
    },
    children: (
      <Surface style={{ padding: "2rem" }}>
        <h2>Parent</h2>
        <p>
          Higher information density with the same semantic design language.
        </p>
        <Button>
          Lihat kemajuan
        </Button>
      </Surface>
    )
  }
};
'@

Write-Utf8NoBom `
  -Path (Join-Path $storybookRoot "stories\Audience.stories.tsx") `
  -Content $audienceStory


# ============================================================
# 5. Root Storybook commands using a real temp JS file.
# ============================================================

Write-Step "Adding root Storybook commands"

$tempEditor =
  Join-Path `
    $env:TEMP `
    "akal-budi-package-editor.cjs"

$editorSource = @'
const fs = require("fs");

const packagePath =
  process.argv[2];

const pkg =
  JSON.parse(
    fs.readFileSync(
      packagePath,
      "utf8"
    )
  );

pkg.scripts ??= {};

pkg.scripts.storybook =
  "pnpm --filter ui-storybook storybook";

pkg.scripts["storybook:build"] =
  "pnpm --filter ui-storybook build-storybook";

fs.writeFileSync(
  packagePath,
  JSON.stringify(
    pkg,
    null,
    2
  ) +
  "\n"
);
'@

Write-Utf8NoBom `
  -Path $tempEditor `
  -Content $editorSource

& node `
  $tempEditor `
  (Join-Path $repoRoot "package.json")

if (
  $LASTEXITCODE -ne 0
) {
  throw "Could not update root package.json."
}

Remove-Item `
  $tempEditor `
  -Force `
  -ErrorAction SilentlyContinue


# ============================================================
# 6. Install and validate.
# ============================================================

Invoke-Native `
  -Name "Workspace install" `
  -Command "pnpm install"

Invoke-Native `
  -Name "Install Storybook dependencies" `
  -Command "pnpm --filter ui-storybook add -D storybook @storybook/react-vite @storybook/addon-a11y"

Invoke-Native `
  -Name "UI package typecheck" `
  -Command "pnpm --filter @akal-budi/ui typecheck"

Invoke-Native `
  -Name "Storybook typecheck" `
  -Command "pnpm --filter ui-storybook typecheck"

Invoke-Native `
  -Name "Storybook production build" `
  -Command "pnpm storybook:build"

Invoke-Native `
  -Name "Design validation" `
  -Command "pnpm design:validate"

Invoke-Native `
  -Name "Curriculum validation" `
  -Command "pnpm curriculum:validate"

Invoke-Native `
  -Name "Curriculum source validation" `
  -Command "pnpm curriculum:sources:validate"

Invoke-Native `
  -Name "Content compiler check" `
  -Command "pnpm content:check"

Invoke-Native `
  -Name "Repository typecheck" `
  -Command "pnpm typecheck"

Invoke-Native `
  -Name "All tests" `
  -Command "pnpm test"

Invoke-Native `
  -Name "Production build" `
  -Command "pnpm build"

if (
  Test-Path (
    Join-Path `
      $repoRoot `
      ".env.security.local"
  )
) {
  Invoke-Native `
    -Name "RLS security regression" `
    -Command "node --env-file=.env.security.local node_modules/vitest/vitest.mjs run tools/security-tests/rls.integration.test.ts --no-file-parallelism"
}

Write-Step "Supabase dry-run"

$supabaseOut =
  & cmd.exe /d /s /c "pnpm supabase db push --dry-run" 2>&1

$supabaseExit =
  $LASTEXITCODE

$supabaseText =
  ($supabaseOut | Out-String)

Write-Host $supabaseText

if ($supabaseExit -ne 0) {
  if (
    $supabaseText -match
      "(Connection timed out|connect timeout|ENOTFOUND|ECONNREFUSED|network is unreachable|temporary failure|connection reset)"
  ) {
    Write-Host "DEFERRED: Supabase remote dry-run unavailable due to external connectivity." -ForegroundColor Yellow
  }
  else {
    throw "Supabase dry-run failed for a non-transient reason."
  }
}
else {
  Write-Host "PASS: Supabase dry-run" -ForegroundColor Green
}

Invoke-Native `
  -Name "Git whitespace check" `
  -Command "git diff --check"


if ($Commit) {
  Invoke-Native `
    -Name "Git stage" `
    -Command "git add packages/ui apps/ui-storybook package.json pnpm-lock.yaml"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "feat: add shared UI primitives and Storybook"'
}


Write-SessionLog "PHASE 006B V7 PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006B V7: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Session log: $sessionLog" -ForegroundColor DarkGray
Write-Host "View Storybook with:" -ForegroundColor White
Write-Host "  pnpm storybook" -ForegroundColor Cyan
