$InputFile = Join-Path $PSScriptRoot 'src\Generated\FriendsRecords.Script.txt'
$OutputFile = Join-Path $PSScriptRoot 'src\MyScript.as'

$script = [System.IO.File]::ReadAllText($InputFile)

$script = ($script -split "\r?\n" | ForEach-Object {
    " $_"
}) -join "`r`n"

$output = @"
const string script = """
$script
""";
"@

[System.IO.File]::WriteAllText(
    $OutputFile,
    $output,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Generated: $OutputFile"
