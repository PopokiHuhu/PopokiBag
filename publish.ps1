# Publishes a new Popoki Bag version on GitHub (WowUp picks up updates from there).
# Usage: bump "## Version:" in PopokiBag.toc and PopokiBag_Forever.toc, then:
#   powershell -ExecutionPolicy Bypass -File publish.ps1 -NotesFile notes.md
# The notes (Markdown) become the GitHub release body - WowUp shows it in the Changelog tab -
# and are added on top of CHANGELOG.md in the repository.
param([string]$Notes = "", [string]$NotesFile = "")

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

# 3. release notes -> top of CHANGELOG.md
if ($NotesFile) { $Notes = [IO.File]::ReadAllText((Resolve-Path $NotesFile)) }
if (-not $Notes) { $Notes = "Popoki Bag $version" }
$changelog = Join-Path $repo "CHANGELOG.md"
$old = if (Test-Path $changelog) { [IO.File]::ReadAllText($changelog) -replace '^# Changelog\s*', '' } else { "" }
$entry = "## $version`n`n" + $Notes.Trim() + "`n`n"
[IO.File]::WriteAllText($changelog, "# Changelog`n`n" + $entry + $old, (New-Object Text.UTF8Encoding $false))

# 4. commit + tag
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -q -m "Popoki Bag $version" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
}
git tag $tag

# 5. zip with a PopokiBag/ folder inside (git archive = forward slashes, which WowUp expects)
$zip = Join-Path $repo "PopokiBag-$version-forever.zip"  # -forever suffix: WowUp Hub matches the zip to the WoW Forever game version
git archive --format=zip --prefix=PopokiBag/ -o $zip $tag
Copy-Item $zip "$env:USERPROFILE\Desktop\" -Force

# 6. push and release
git push -q origin HEAD
git push -q origin $tag
$notesTmp = Join-Path $env:TEMP "popokibag-notes.md"
[IO.File]::WriteAllText($notesTmp, $Notes, (New-Object Text.UTF8Encoding $false))
& "C:\Program Files\GitHub CLI\gh.exe" release create $tag $zip --title "Popoki Bag $version" --notes-file $notesTmp
Write-Host "Published $tag"
