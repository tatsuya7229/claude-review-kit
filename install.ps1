# install.ps1 — このキットを %USERPROFILE%\.claude に展開する（Windows / PowerShell）。
# 使い方: clone したディレクトリで `powershell -ExecutionPolicy Bypass -File install.ps1`
$ErrorActionPreference = "Stop"
$src = $PSScriptRoot
$dst = Join-Path $env:USERPROFILE ".claude"

New-Item -ItemType Directory -Force -Path "$dst\skills\review-rubric" | Out-Null
New-Item -ItemType Directory -Force -Path "$dst\agents"   | Out-Null
New-Item -ItemType Directory -Force -Path "$dst\commands" | Out-Null

Copy-Item "$src\skills\review-rubric\SKILL.md" "$dst\skills\review-rubric\" -Force
Copy-Item "$src\agents\*.md"   "$dst\agents\"   -Force
Copy-Item "$src\commands\*.md" "$dst\commands\" -Force

Write-Host "Installed to $dst"
Write-Host "Claude Code を再起動すると agents / skills / commands が有効になります。確認: /self-review, /pr-review"
