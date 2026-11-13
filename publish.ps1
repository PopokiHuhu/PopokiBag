# Publikacja nowej wersji Popoki Bag na GitHubie (WowUp pobiera stamtąd aktualizacje).
# Użycie: najpierw podbij "## Version:" w PopokiBag.toc, potem:
#   powershell -ExecutionPolicy Bypass -File publish.ps1 "Krótki opis zmian"
param([string]$Notes = "")

$ErrorActionPreference = "Stop"
$repo   = $PSScriptRoot
$addon  = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\PopokiBag"
Set-Location $repo

# 1. pliki z folderu gry -> repozytorium
Get-ChildItem $repo -File | Where-Object { $_.Extension -in ".lua", ".toc" -or $_.Name -eq "README.txt" } | Remove-Item
Get-ChildItem $addon -File | Where-Object { $_.Extension -in ".lua", ".toc" -or $_.Name -eq "README.txt" } | Copy-Item -Destination $repo

# 2. wersja z .toc
$version = (Select-String -Path "$repo\PopokiBag.toc" -Pattern '^## Version:\s*(\S+)').Matches[0].Groups[1].Value
$tag = "v$version"
if (git tag --list $tag) { throw "Wersja $version już opublikowana - podbij '## Version:' w PopokiBag.toc." }

# 3. commit + tag
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -q -m "Popoki Bag $version" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
}
git tag $tag

# 4. zip z folderem PopokiBag/ w środku (git archive = ukośniki zgodne z WowUp)
$zip = Join-Path $repo "PopokiBag-$version.zip"
git archive --format=zip --prefix=PopokiBag/ -o $zip $tag
Copy-Item $zip "$env:USERPROFILE\Desktop\" -Force

# 5. wysyłka i wydanie
git push -q origin HEAD
git push -q origin $tag
if (-not $Notes) { $Notes = "Popoki Bag $version" }
gh release create $tag $zip --title "Popoki Bag $version" --notes $Notes
Write-Host "Opublikowano $tag"
