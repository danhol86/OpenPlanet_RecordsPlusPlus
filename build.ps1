param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$ManiaScriptProject = Join-Path $ProjectRoot 'ManiaScript\RecordsPlusPlus.ManiaScript\RecordsPlusPlus.ManiaScript.csproj'

Write-Host "Building ManiaScript..."
dotnet build $ManiaScriptProject

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

$MainPath = Join-Path $ProjectRoot 'src\Main.as'
$MyScriptPath = Join-Path $ProjectRoot 'src\MyScript.as'
$StageMainPath = Join-Path $StageDir 'Main.as'

$MainSource = Get-Content -LiteralPath $MainPath -Raw
$MyScriptSource = Get-Content -LiteralPath $MyScriptPath -Raw

$MainSource = $MainSource.Replace("const MYScriptReplacement", $MyScriptSource.TrimEnd())

[System.IO.File]::WriteAllText(
    $StageMainPath,
    $MainSource,
    [System.Text.UTF8Encoding]::new($false)
)

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
