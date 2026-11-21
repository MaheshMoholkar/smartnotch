param(
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64',
    [switch]$Development
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Run release packaging on Windows with the .NET 10 SDK.' }
if (!$Development -and !(Get-Command python -ErrorAction SilentlyContinue)) { throw 'Install Python 3.10+ to verify and stage GitHub release assets.' }
$root = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $root 'release.json') -Raw | ConvertFrom-Json
if ($config.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw 'Set a three-part version in release.json.' }
if (!$Development) {
    $uri = $null
    if (![Uri]::TryCreate($config.updateBaseURL, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or !$uri.Host -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
        throw 'Set a permanent public HTTPS updateBaseURL in release.json before packaging a release.'
    }
}
$kind = if ($Development) { 'development' } else { 'updates\windows' }
$output = Join-Path $root "dist\$kind\$Runtime"
$staging = Join-Path ([IO.Path]::GetTempPath()) ('SmartNotch-publish-' + [guid]::NewGuid())
$build = Join-Path $staging 'publish'
try {
    New-Item -ItemType Directory -Path $staging, $output -Force | Out-Null
    dotnet publish (Join-Path $PSScriptRoot 'SmartNotch\SmartNotch.csproj') -c Release -r $Runtime --self-contained true -o $build
    if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }
    Push-Location $PSScriptRoot
    try {
        dotnet tool restore
        if ($LASTEXITCODE -ne 0) { throw 'Could not restore the pinned Velopack packaging tool.' }
        dotnet tool run vpk -- pack --packId SmartNotch --packVersion $config.version --packDir $build --mainExe SmartNotch.exe --packTitle SmartNotch --packAuthors SmartNotch --runtime $Runtime --channel win --outputDir $output --releaseNotes (Join-Path $root 'RELEASE_NOTES.md') --icon (Join-Path $PSScriptRoot 'SmartNotch\SmartNotch.ico')
        if ($LASTEXITCODE -ne 0) { throw 'Velopack packaging failed.' }
    } finally { Pop-Location }
    foreach ($file in (Get-ChildItem $output -File | Where-Object Extension -ne '.sha256')) {
        $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        Set-Content -Path ($file.FullName + '.sha256') -Value "$hash  $($file.Name)" -Encoding Ascii
    }
    if ($Development) { Write-Warning 'Development package only: in-app updates are not configured.' }
    if (!$Development) {
        # One verifier/stager for native Windows and cross-built releases.
        python (Join-Path $root 'scripts\stage_windows_release.py') $Runtime
        if ($LASTEXITCODE -ne 0) { throw 'Release verification or staging failed.' }
        Write-Output "Upload dist\github-release\$($config.version) to a GitHub Release; only the small feeds belong on Vercel."
    }
    Write-Output $output
} finally {
    if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
