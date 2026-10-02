param(
    [switch]$Install,
    [switch]$Production
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$ManiaScriptProject = Join-Path $ProjectRoot 'ManiaScript\RecordsPlusPlus.ManiaScript\RecordsPlusPlus.ManiaScript.csproj'

if ($Production) {
    Write-Host "if production then add property to is used in c# code to ignore debugging..."
    dotnet build $ManiaScriptProject -p:ProductionBuild=true
}
else {
    Write-Host "if debugging then dont add property to is used in c# code to ignore debugging..."
    dotnet build $ManiaScriptProject
}

if ($LASTEXITCODE -ne 0) {
    throw 'ManiaScript build failed.'
}

$WrapperScript = Join-Path $ProjectRoot 'MyASWrapper.ps1'

Write-Host "Generating AngelScript wrapper..."
& $WrapperScript

if ($LASTEXITCODE -ne 0) {
    throw 'MyASWrapper.ps1 failed.'
}

$InfoPath = Join-Path $ProjectRoot 'info.toml'
$Info = Get-Content -LiteralPath $InfoPath -Raw
$VersionMatch = [regex]::Match($Info, '(?m)^version\s*=\s*"([^"]+)"')
if (-not $VersionMatch.Success) { throw 'Could not read plugin version from info.toml.' }

$Version = $VersionMatch.Groups[1].Value
$PluginId = 'RecordsPlusPlus'
$BuildDir = Join-Path $ProjectRoot 'build'
$StageDir = Join-Path $BuildDir $PluginId
$Output = Join-Path $BuildDir "$PluginId-$Version.op"

if (Test-Path -LiteralPath $StageDir) { Remove-Item -LiteralPath $StageDir -Recurse -Force }
if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

$SourceDir = Join-Path $ProjectRoot 'src'
$SourcePrefix = $SourceDir.TrimEnd('\') + '\'

# Openplanet compiles all .as files in the plugin together, including files in
# sub-folders. Copy the source tree as separate files instead of combining it
# all into Main.as.
Get-ChildItem -Path $SourceDir -Recurse -File -Filter '*.as' | ForEach-Object {
    $RelativePath = $_.FullName.Substring($SourcePrefix.Length)

    # during dev, ignore the prod.as
    if (-not $Production -and $RelativePath -eq 'Debug\DebugProd.as') {
        return
    }

    # during prod, ignore the debug.as
    if ($Production -and $RelativePath -eq 'Debug\Debug.as') {
        return
    }

    $Destination = Join-Path $StageDir $RelativePath
    $DestinationDir = Split-Path -Parent $Destination

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $Destination
}

Copy-Item -LiteralPath $InfoPath -Destination (Join-Path $StageDir 'info.toml')

$Zip = [System.IO.Path]::ChangeExtension($Output, '.zip')
Compress-Archive -Path (Join-Path $StageDir '*') -DestinationPath $Zip -CompressionLevel Optimal
Move-Item -LiteralPath $Zip -Destination $Output

Write-Host "Built package: $Output"

if ($Install) {
    $OpenplanetPlugins = Join-Path $env:USERPROFILE 'OpenplanetNext\Plugins'
    $PluginDir = Join-Path $OpenplanetPlugins $PluginId
    $LegacyPluginDir = Join-Path $OpenplanetPlugins 'FriendsGhostLeaderboard'

    if (Test-Path -LiteralPath $LegacyPluginDir) { Remove-Item -LiteralPath $LegacyPluginDir -Recurse -Force }
    if (Test-Path -LiteralPath $PluginDir) { Remove-Item -LiteralPath $PluginDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
    Copy-Item -Path (Join-Path $StageDir '*') -Destination $PluginDir -Recurse
    Write-Host "Installed dev plugin: $PluginDir"
}
