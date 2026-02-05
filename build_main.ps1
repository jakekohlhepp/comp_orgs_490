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

# 2) All other .tex files, excluding the beamer files so they don't compile twice.
$otherTexFiles = Get-ChildItem -LiteralPath $scriptDir -Filter '*.tex' -File | Where-Object {
    $_.Name -notlike 'slides_*.tex'
}

Write-Host ""
Write-Host "Found $($beamerFiles.Count) beamer .tex files:"
$beamerFiles | ForEach-Object { Write-Host " - $($_.Name)" }

Write-Host ""
Write-Host "Found $($otherTexFiles.Count) other .tex files:"
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

$maxRetries = 3

foreach ($file in $filesToCompile) {
    $name = $file.BaseName
    $pdfPath = Join-Path $scriptDir "$name.pdf"

    Write-Host ""
    Write-Host "Compiling: $($file.Name)"

    $pdfOk = $false

    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host "  Retry $attempt of $maxRetries (waiting 3s)..."
            Start-Sleep -Seconds 3
        }

        # Run latexmk with -gg to force full recompilation
        & $latexmkPath -xelatex -interaction=nonstopmode -halt-on-error -gg $file.Name 2>&1 | Out-Null

        # Check if PDF was created/updated
        try { $pdfOk = Test-Path -LiteralPath $pdfPath } catch { $pdfOk = $false }

        if (-not $pdfOk) {
            # Workaround: Google Drive can block xdvipdfmx from writing directly
            # to certain filenames. If the .xdv was produced, convert via a temp file.
            $xdvPath = Join-Path $scriptDir "$name.xdv"
            $xdvExists = $false
            try { $xdvExists = Test-Path -LiteralPath $xdvPath } catch {}

            if ($xdvExists) {
                Write-Host "  PDF not created directly -- trying via temp file..."
                $tmpPdf = Join-Path $scriptDir "$name`_tmp.pdf"
                $xdvipdfmxPath = (Get-Command xdvipdfmx -ErrorAction SilentlyContinue).Source
                if ($xdvipdfmxPath) {
                    & $xdvipdfmxPath -E -o $tmpPdf $xdvPath 2>&1 | Out-Null
                    $tmpExists = $false
                    try { $tmpExists = Test-Path -LiteralPath $tmpPdf } catch {}
                    if ($tmpExists) {
                        Move-Item -LiteralPath $tmpPdf -Destination $pdfPath -Force
                        try { $pdfOk = Test-Path -LiteralPath $pdfPath } catch {}
                    }
                }
            }
        }

        if ($pdfOk) { break }
    }

    if ($pdfOk) {
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
        try {
            if (Test-Path -LiteralPath $auxFile) {
                Remove-Item -LiteralPath $auxFile -Force
            }
        } catch {}
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
