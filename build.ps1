[CmdletBinding()]
param(
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$output = Join-Path $repoRoot 'ff4kster-console.exe'

$compilerCommand = Get-Command fbc -ErrorAction SilentlyContinue
if ($compilerCommand) {
    $compiler = $compilerCommand.Source
} else {
    $defaultCompiler = 'C:\Program Files (x86)\FreeBASIC\fbc.exe'
    if (Test-Path $defaultCompiler) {
        $compiler = $defaultCompiler
    } else {
        throw 'FreeBASIC compiler not found. Install it with: winget install --id FreeBASIC.FreeBASIC'
    }
}

if ($Clean -and (Test-Path $output)) {
    Remove-Item $output -Force
}

Push-Location $repoRoot
try {
    & $compiler -x $output main.bas
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

Write-Output "Built $output"
