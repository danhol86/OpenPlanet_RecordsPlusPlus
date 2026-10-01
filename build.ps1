param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
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

Copy-Item -LiteralPath (Join-Path $ProjectRoot 'src\Main.as') -Destination (Join-Path $StageDir 'Main.as')
Copy-Item -LiteralPath $InfoPath -Destination (Join-Path $StageDir 'info.toml')

$Zip = [System.IO.Path]::ChangeExtension($Output, '.zip')
Compress-Archive -Path (Join-Path $StageDir '*') -DestinationPath $Zip -CompressionLevel Optimal
Move-Item -LiteralPath $Zip -Destination $Output

Write-Host "Built package: $Output"

if ($Install) {
    $OpenplanetPlugins = 'C:\Users\danho\OpenplanetNext\Plugins'
    $PluginDir = Join-Path $OpenplanetPlugins $PluginId
    $LegacyPluginDir = Join-Path $OpenplanetPlugins 'FriendsGhostLeaderboard'

    if (Test-Path -LiteralPath $LegacyPluginDir) { Remove-Item -LiteralPath $LegacyPluginDir -Recurse -Force }
    if (Test-Path -LiteralPath $PluginDir) { Remove-Item -LiteralPath $PluginDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
    Copy-Item -Path (Join-Path $StageDir '*') -Destination $PluginDir -Recurse
    Write-Host "Installed dev plugin: $PluginDir"
}