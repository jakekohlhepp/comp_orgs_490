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

# Auxiliary file extensions to clean up (including beamer-specific ones)
$auxExtensions = @('.aux', '.log', '.nav', '.snm', '.toc', '.out', '.fls',
                   '.fdb_latexmk', '.synctex.gz', '.bbl', '.blg', '.vrb',
                   '.bcf', '.run.xml', '.xdv')

# Determine number of parallel jobs (use number of CPU cores, max 8)
$maxJobs = [Math]::Min([Environment]::ProcessorCount, 8)
Write-Host ""
Write-Host "Compiling with up to $maxJobs parallel jobs..."

# Compile files in parallel batches
$jobs = @()
foreach ($file in $filesToCompile) {
    $texPath = $file.FullName
    $name    = [System.IO.Path]::GetFileNameWithoutExtension($texPath)
    $dir     = $file.DirectoryName

    # Start a background job for each file
    $job = Start-Job -ScriptBlock {
        param($texPath, $name, $dir)
        Set-Location $dir

        # Build with XeLaTeX, non-interactive
        $output = latexmk -xelatex -f `
            -xelatex="xelatex -interaction=nonstopmode -halt-on-error %O %S" `
            -jobname="$name" "$texPath" 2>&1

        # Check if PDF was created/updated as success indicator
        $pdfPath = Join-Path $dir "$name.pdf"
        $success = Test-Path $pdfPath

        return @{
            Name = $name
            Success = $success
        }
    } -ArgumentList $texPath, $name, $dir

    $jobs += $job
    Write-Host "Started: $($file.Name)"

    # Limit concurrent jobs
    while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $maxJobs) {
        Start-Sleep -Milliseconds 500
    }
}

# Wait for all jobs to complete and collect results
Write-Host ""
Write-Host "Waiting for all compilations to finish..."
$jobs | Wait-Job | Out-Null

# Report results
Write-Host ""
Write-Host "==============================================="
Write-Host "Compilation Results:"
Write-Host "==============================================="
foreach ($job in $jobs) {
    $result = Receive-Job -Job $job
    if ($result.Success) {
        Write-Host "[OK] $($result.Name).pdf"
    } else {
        Write-Host "[FAILED] $($result.Name)"
    }
    Remove-Job -Job $job
}

# Clean up ALL auxiliary files at the end
Write-Host ""
Write-Host "Cleaning up auxiliary files..."
foreach ($file in $filesToCompile) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    foreach ($ext in $auxExtensions) {
        $auxFile = Join-Path $scriptDir "$name$ext"
        if (Test-Path $auxFile) {
            Remove-Item $auxFile -Force
        }
    }
}

Write-Host "Done!"