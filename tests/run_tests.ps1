[CmdletBinding()]
param(
    [string]$BdsPath = 'C:\Program Files (x86)\Embarcadero\Studio\17.0',
    [string]$Boss4DPath
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$rsvarsPath = Join-Path $BdsPath 'bin\rsvars.bat'
$outputPath = Join-Path $projectRoot 'test-bin'

if (-not (Test-Path -LiteralPath $rsvarsPath)) {
    throw "Delphi environment not found: $rsvarsPath"
}

if ($Boss4DPath) {
    if (-not (Test-Path -LiteralPath $Boss4DPath)) {
        throw "Boss4D executable not found: $Boss4DPath"
    }

    Push-Location $projectRoot
    try {
        & $Boss4DPath install --no-register
        if ($LASTEXITCODE -ne 0) {
            throw "Boss4D dependency installation failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

$dependencyPaths = Get-ChildItem (Join-Path $projectRoot 'modules') `
    -Recurse -File -Filter '*.pas' |
    ForEach-Object DirectoryName |
    Sort-Object -Unique
if (-not $dependencyPaths) {
    throw 'Horse dependency not found. Run Boss4D install or pass -Boss4DPath.'
}

$unitPath = @((Join-Path $projectRoot 'src')) + @($dependencyPaths)
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$compilerArguments = @(
    '-B'
    '-Q'
    '-DCI'
    '-NS"System;Xml;Data;Web;Soap;Winapi;System.Win"'
    "-U`"$($unitPath -join ';')`""
    "-E`"$outputPath`""
    "-N`"$outputPath`""
    'Tests.dpr'
) -join ' '
$compileCommand = "call `"$rsvarsPath`" && cd /d `"$PSScriptRoot`" && dcc32 $compilerArguments"

cmd.exe /d /c $compileCommand
if ($LASTEXITCODE -ne 0) {
    throw "Delphi test compilation failed with exit code $LASTEXITCODE."
}

& (Join-Path $outputPath 'Tests.exe')
if ($LASTEXITCODE -ne 0) {
    throw "Unit tests failed with exit code $LASTEXITCODE."
}
