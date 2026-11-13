# Publishes a new Popoki Bag version on GitHub (WowUp picks up updates from there).
# Usage: bump "## Version:" in PopokiBag.toc and PopokiBag_Forever.toc, then:
#   powershell -ExecutionPolicy Bypass -File publish.ps1 "Short description of changes"
param([string]$Notes = "")

$ErrorActionPreference = "Stop"
$repo   = $PSScriptRoot
$addon  = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\PopokiBag"
Set-Location $repo

# 1. game folder -> repository
Get-ChildItem $repo -File | Where-Object { $_.Extension -in ".lua", ".toc" -or $_.Name -eq "README.txt" } | Remove-Item
Get-ChildItem $addon -File | Where-Object { $_.Extension -in ".lua", ".toc" -or $_.Name -eq "README.txt" } | Copy-Item -Destination $repo

# 2. version from the .toc
$version = (Select-String -Path "$repo\PopokiBag.toc" -Pattern '^## Version:\s*(\S+)').Matches[0].Groups[1].Value
$tag = "v$version"
if (git tag --list $tag) { throw "Version $version is already published - bump '## Version:' in PopokiBag.toc." }

# 3. commit + tag
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -q -m "Popoki Bag $version" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
}
git tag $tag

# 4. zip with a PopokiBag/ folder inside (git archive = forward slashes, which WowUp expects)
$zip = Join-Path $repo "PopokiBag-$version.zip"
git archive --format=zip --prefix=PopokiBag/ -o $zip $tag
Copy-Item $zip "$env:USERPROFILE\Desktop\" -Force

# 5. push and release
git push -q origin HEAD
git push -q origin $tag
if (-not $Notes) { $Notes = "Popoki Bag $version" }
& "C:\Program Files\GitHub CLI\gh.exe" release create $tag $zip --title "Popoki Bag $version" --notes $Notes
Write-Host "Published $tag"
