# Make sure we are running in the folder where this script lives
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Script directory: $scriptDir"

# Find all beamer slide tex files
$beamerFiles = Get-ChildItem -Path . -Filter 'slides_*.tex' -File

Write-Host "Found $($beamerFiles.Count) beamer .tex files:"
$beamerFiles | ForEach-Object { Write-Host " - $($_.Name)" }

if ($beamerFiles.Count -eq 0) {
    Write-Host "No slides_*.tex files found. Exiting."
    return
}

foreach ($file in $beamerFiles) {
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
