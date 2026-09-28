$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Find-Git {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files\Git\bin\git.exe',
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    throw 'Git was not found. Install Git for Windows first.'
}

if (-not (Test-Path '.atlas_project_root')) {
    throw 'This script must stay inside the Atlas project folder.'
}
if (-not (Test-Path 'pubspec.yaml')) {
    throw 'pubspec.yaml is missing.'
}
if (-not (Test-Path '.github\workflows\build-android-apk.yml')) {
    throw 'Android cloud-build workflow is missing.'
}

$git = Find-Git
Write-Host "Git: $git" -ForegroundColor Green

$repoFile = Join-Path $PSScriptRoot '.atlas_repo_url'
$repo = ''
if (Test-Path $repoFile) {
    $repo = (Get-Content $repoFile -Raw).Trim()
}

if ([string]::IsNullOrWhiteSpace($repo)) {
    $repo = Read-Host 'Paste your GitHub repository URL (example: https://github.com/USER/atlas-one-android.git)'
}
if ([string]::IsNullOrWhiteSpace($repo)) { throw 'GitHub repository URL is required.' }
if ($repo -match '/USERNAME/' -or $repo -match 'YOUR_.*USERNAME') {
    throw 'Replace USERNAME with your real GitHub username.'
}
if ($repo -notmatch '^https://github\.com/[^/]+/[^/]+(?:\.git)?$') {
    Write-Warning 'The URL does not look like a normal GitHub repository URL. Continuing anyway.'
}
if (-not $repo.EndsWith('.git')) { $repo = "$repo.git" }
Set-Content -Path $repoFile -Value $repo -NoNewline

$publish = Join-Path $env:TEMP 'atlas_one_github_publish'
if (Test-Path $publish) { Remove-Item $publish -Recurse -Force }

Write-Host "`nPreparing a clean update clone..." -ForegroundColor Cyan
$cloneSucceeded = $true
try {
    & $git clone --depth 1 $repo $publish
    if ($LASTEXITCODE -ne 0) { $cloneSucceeded = $false }
} catch {
    $cloneSucceeded = $false
}

if (-not $cloneSucceeded) {
    Write-Host 'Repository may be empty. Creating a fresh local publishing clone...' -ForegroundColor Yellow
    if (Test-Path $publish) { Remove-Item $publish -Recurse -Force }
    New-Item -ItemType Directory -Force $publish | Out-Null
    & $git -C $publish init
    & $git -C $publish checkout -B main
    & $git -C $publish remote add origin $repo
}

Write-Host 'Copying Atlas project into publishing clone...' -ForegroundColor Cyan
$excludeDirs = @('.git', '.build', 'dist', '.dart_tool', '.idea', 'build')
$excludeFiles = @('.atlas_repo_url')

Get-ChildItem -Force $PSScriptRoot | ForEach-Object {
    if ($excludeDirs -contains $_.Name) { return }
    if ($excludeFiles -contains $_.Name) { return }
    $destination = Join-Path $publish $_.Name
    if (Test-Path $destination) { Remove-Item $destination -Recurse -Force }
    Copy-Item $_.FullName $destination -Recurse -Force
}

& $git -C $publish config user.name 'Atlas Builder'
& $git -C $publish config user.email 'atlas-builder@users.noreply.github.com'
& $git -C $publish checkout -B main
& $git -C $publish add -A

$hasChanges = $true
& $git -C $publish diff --cached --quiet
if ($LASTEXITCODE -eq 0) { $hasChanges = $false }

if ($hasChanges) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    & $git -C $publish commit -m "Atlas One update $stamp"
} else {
    Write-Host 'No source changes detected; pushing current main anyway.' -ForegroundColor Yellow
}

Write-Host "`nUpdating GitHub... Browser authentication may open." -ForegroundColor Cyan
& $git -C $publish push -u origin main
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub push failed. Complete browser authentication and run UPDATE_TO_GITHUB.bat again.'
}

$web = $repo -replace '\.git$',''
Write-Host "`nSUCCESS: GitHub repository updated." -ForegroundColor Green
Write-Host 'Android cloud build starts automatically on push.' -ForegroundColor Green
Write-Host "Actions: $web/actions" -ForegroundColor Cyan
Start-Process "$web/actions"
