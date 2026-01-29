# Make sure we are running in the folder where this script lives
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location -LiteralPath $scriptDir

Write-Host "Script directory: $scriptDir"

# Get the full path to latexmk
$latexmkPath = (Get-Command latexmk -ErrorAction SilentlyContinue).Source
if (-not $latexmkPath) {
    Write-Host "ERROR: latexmk not found in PATH"
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Using latexmk: $latexmkPath"

# 1) Beamer slide tex files (as before)
$beamerFiles = Get-ChildItem -LiteralPath $scriptDir -Filter 'slides_*.tex' -File

# 2) All other .tex files that do NOT include "answer" in the name,
#    excluding the beamer files so they don't compile twice.
$otherTexFiles = Get-ChildItem -LiteralPath $scriptDir -Filter '*.tex' -File | Where-Object {
    $_.Name -notmatch '(?i)answer' -and $_.Name -notlike 'slides_*.tex'
}

Write-Host ""
Write-Host "Found $($beamerFiles.Count) beamer .tex files:"
$beamerFiles | ForEach-Object { Write-Host " - $($_.Name)" }

Write-Host ""
Write-Host "Found $($otherTexFiles.Count) other .tex files (excluding *answer*):"
$otherTexFiles | ForEach-Object { Write-Host " - $($_.Name)" }

# Combine into a single list to compile
$filesToCompile = @($beamerFiles) + @($otherTexFiles)

if ($filesToCompile.Count -eq 0) {
    Write-Host "No matching .tex files found. Exiting."
    Read-Host "Press Enter to exit"
    exit 1
}

# Auxiliary file extensions to clean up (including beamer-specific ones)
$auxExtensions = @('.aux', '.log', '.nav', '.snm', '.toc', '.out', '.fls',
                   '.fdb_latexmk', '.synctex.gz', '.bbl', '.blg', '.vrb',
                   '.bcf', '.run.xml', '.xdv')

Write-Host ""
Write-Host "Compiling $($filesToCompile.Count) files sequentially..."
Write-Host "==============================================="

$successCount = 0
$failCount = 0
$failedFiles = @()

foreach ($file in $filesToCompile) {
    $name = $file.BaseName
    $pdfPath = Join-Path $scriptDir "$name.pdf"

    Write-Host ""
    Write-Host "Compiling: $($file.Name)"

    # Run latexmk with -gg to force full recompilation
    # Use just the filename since we're in the correct directory
    & $latexmkPath -xelatex -interaction=nonstopmode -halt-on-error -gg $file.Name 2>&1 | Out-Null

    # Check if PDF was created/updated
    if (Test-Path -LiteralPath $pdfPath) {
        Write-Host "[OK] $name.pdf"
        $successCount++
    } else {
        Write-Host "[FAILED] $name"
        $failCount++
        $failedFiles += $name
    }

    # Clean up auxiliary files for this file immediately
    foreach ($ext in $auxExtensions) {
        $auxFile = Join-Path $scriptDir "$name$ext"
        if (Test-Path -LiteralPath $auxFile) {
            Remove-Item -LiteralPath $auxFile -Force
        }
    }
}

Write-Host ""
Write-Host "==============================================="
Write-Host "Summary: $successCount succeeded, $failCount failed"
Write-Host "==============================================="

if ($failCount -gt 0) {
    Write-Host ""
    Write-Host "Failed files:"
    $failedFiles | ForEach-Object { Write-Host " - $_" }
}

Write-Host ""
Write-Host "Done!"
