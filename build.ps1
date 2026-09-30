$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir = Join-Path $ProjectRoot 'build'
$StageDir = Join-Path $BuildDir 'FriendsGhostLeaderboard'
$Output = Join-Path $BuildDir 'FriendsGhostLeaderboard-0.1.0.op'
$PluginDir = 'C:\Users\danho\OpenplanetNext\Plugins\FriendsGhostLeaderboard'

if (Test-Path -LiteralPath $StageDir) { Remove-Item -LiteralPath $StageDir -Recurse -Force }
if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

Copy-Item -LiteralPath (Join-Path $ProjectRoot 'src\Main.as') -Destination (Join-Path $StageDir 'Main.as')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'info.toml') -Destination (Join-Path $StageDir 'info.toml')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'README.md') -Destination (Join-Path $StageDir 'README.md')

if (Test-Path -LiteralPath $PluginDir) { Remove-Item -LiteralPath $PluginDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
Copy-Item -Path (Join-Path $StageDir '*') -Destination $PluginDir -Recurse

$Zip = [System.IO.Path]::ChangeExtension($Output, '.zip')
Compress-Archive -Path (Join-Path $StageDir '*') -DestinationPath $Zip -CompressionLevel Optimal
Move-Item -LiteralPath $Zip -Destination $Output

Write-Host "Installed dev plugin: $PluginDir"
Write-Host "Built package: $Output"
