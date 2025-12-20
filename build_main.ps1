# Make sure we are running in the folder where this script lives
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Script directory: $scriptDir"

# 1) Beamer slide tex files (as before)
$beamerFiles = Get-ChildItem -Path . -Filter 'slides_*.tex' -File

# 2) All other .tex files that do NOT include "answer" in the name,
#    excluding the beamer files so they don't compile twice.
$otherTexFiles = Get-ChildItem -Path . -Filter '*.tex' -File | Where-Object {
    $_.Name -notmatch '(?i)answer' -and $_.Name -notlike 'slides_*.tex'
}

Write-Host ""
Write-Host "Found $($beamerFiles.Count) beamer .tex files:"
$beamerFiles | ForEach-Object { Write-Host " - $($_.Name)" }

Write-Host ""
Write-Host "Found $($otherTexFiles.Count) other .tex files (excluding *answer*):"
$otherTexFiles | ForEach-Object { Write-Host " - $($_.Name)" }

# Combine into a single list to compile
$filesToCompile = @($beamerFiles + $otherTexFiles)

if ($filesToCompile.Count -eq 0) {
    Write-Host "No matching .tex files found. Exiting."
    return
}

foreach ($file in $filesToCompile) {
    $texPath = $file.FullName
    $name    = [System.IO.Path]::GetFileNameWithoutExtension($texPath)

    Write-Host ""
    Write-Host "==============================================="
    Write-Host "Compiling $texPath -> $name.pdf (xelatex)"
    Write-Host "==============================================="

    # Build with XeLaTeX, non-interactive
    latexmk -xelatex -f `
        -xelatex="xelatex -interaction=nonstopmode -halt-on-error %O %S" `
        -jobname="$name" "$texPath"

    # Clean up aux files, keep PDF
    latexmk -c -jobname="$name" "$texPath"
}