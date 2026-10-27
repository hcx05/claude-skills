<#
.SYNOPSIS
  Delegate a task to the Antigravity CLI (agy) as a sub-agent and print a compact result.

.EXAMPLE
  .\agy-delegate.ps1 -Task "Summarize the repo structure" -Tier easy -Dir C:\proj
  .\agy-delegate.ps1 -TaskFile task.md -Tier hard -Mode accept-edits
#>
param(
  [string]$Task,
  [string]$TaskFile,
  # Gemini only (Claude models are handled by Claude's own Agent tool):
  # easy -> flash, medium -> argon-medium, hard/research -> argon-high
  [ValidateSet('easy','medium','hard','research')][string]$Tier = 'medium',
  [string]$Model,                       # explicit model id overrides -Tier (see `agy models`)
  [ValidateSet('plan','accept-edits','auto')][string]$Mode = 'plan',   # plan = read-only
  [string]$Dir = (Get-Location).Path,   # working directory for the sub-agent
  [string[]]$AddDir = @(),
  [string]$Conversation,                # resume a previous agy conversation ID
  [int]$TimeoutSec = 600,
  [switch]$Raw                          # print full JSON instead of the summary
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

if ($TaskFile) { $Task = Get-Content -Raw -Encoding UTF8 $TaskFile }
if (-not $Task) { throw 'Provide -Task or -TaskFile.' }

if (-not $Model) {
  $Model = switch ($Tier) {
    'easy'     { 'gemini-3.8-flash-medium' }
    'medium'   { 'gemini-4-argon-medium' }
    'hard'     { 'gemini-4-argon-high' }
    'research' { 'gemini-4-argon-high' }
  }
}

$argv = @('--print', $Task, '--output-format', 'json', '--model', $Model,
          '--mode', $Mode, '--print-timeout', "${TimeoutSec}s")
foreach ($d in $AddDir) { $argv += @('--add-dir', $d) }
if ($Conversation) { $argv += @('--conversation', $Conversation) }

Push-Location $Dir
$ErrorActionPreference = 'Continue'   # agy writes diagnostics to stderr; don't treat as terminating
try { $out = & agy @argv 2>&1 | ForEach-Object { "$_" } | Out-String } finally { Pop-Location }

if ($Raw) { $out; exit 0 }

# agy may print progress lines before the JSON; take the last JSON object.
$json = ($out -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1)
if (-not $json) {
  Write-Output "[agy] no JSON result (model=$Model mode=$Mode). Raw output:`n$out"
  if ($out -match 'permission') { Write-Output "[hint] The task needed a tool denied in headless '$Mode' mode. Retry with -Mode accept-edits if appropriate." }
  exit 1
}

$r = $json | ConvertFrom-Json
Write-Output "[agy] status=$($r.status) model=$Model mode=$Mode conversation=$($r.conversation_id) duration=$([math]::Round($r.duration_seconds,1))s tokens=$($r.usage.total_tokens)"
Write-Output '---'
Write-Output $r.response
if ($r.status -ne 'SUCCESS') { exit 1 }
