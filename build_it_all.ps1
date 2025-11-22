Get-ChildItem -Filter *.tex -Recurse | ForEach-Object {
    $texPath = $_.FullName
    $name = [System.IO.Path]::GetFileNameWithoutExtension($texPath)

    Write-Host "Compiling $texPath -> $name.pdf (xelatex)"

    # Build with XeLaTeX, non-interactive
    latexmk -xelatex -f `
        -xelatex="xelatex -interaction=nonstopmode -halt-on-error %O %S" `
        -jobname="$name" "$texPath"

    # Clean up aux files, keep PDF
    latexmk -c -jobname="$name" "$texPath"
}
