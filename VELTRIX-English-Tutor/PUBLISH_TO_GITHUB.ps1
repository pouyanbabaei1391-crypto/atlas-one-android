# VELTRIX AI — Windows one-click GitHub publisher
# Only updates VELTRIX-English-Tutor/ and a dedicated workflow in the owner's repository.
# Each click creates a new build marker, so GitHub Actions triggers even if code is unchanged.
# It never force-pushes or deletes unrelated Atlas One files.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = 'pouyanbabaei1391-crypto/atlas-one-android'
$repoURL = 'https://github.com/' + $repo + '.git'
$repoPage = 'https://github.com/' + $repo
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('veltrix-upload-' + [guid]::NewGuid().ToString('N'))
$log = Join-Path $projectRoot 'VELTRIX_UPLOAD_LOG.txt'
$transcript = $false
function Invoke-GitCommand([string[]]$A) {
    & git.exe @A
    if ($LASTEXITCODE -ne 0) { throw ('Git error (' + $LASTEXITCODE + ') from git ' + ($A -join ' ')) }
}
function Header([string]$s) { Write-Host $s -ForegroundColor Cyan }
function WaitForGitHubApk([string]$sha) {
    # Optional: GitHub CLI enables automatic build monitoring and APK download.
    # The site opens normally if GitHub CLI is unavailable.
    $ghExe = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghExe) {
        Write-Host 'The build is now queued on GitHub. To auto-download the APK on this PC, install GitHub CLI and run gh auth login.' -ForegroundColor Yellow
        Write-Host ('Live Actions: ' + $repoPage + '/actions/workflows/veltrix-english-tutor.yml')
        Start-Process ($repoPage + '/actions/workflows/veltrix-english-tutor.yml')
        return
    }
    & gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'GitHub CLI is installed but not authenticated. Run: gh auth login' -ForegroundColor Yellow
        Start-Process ($repoPage + '/actions/workflows/veltrix-english-tutor.yml')
        return
    }
    Header '[5/6] Waiting for the GitHub Actions run to appear...'
    $id = $null
    for ($attempt=0; $attempt -lt 30; $attempt++) {
        $raw = & gh run list --repo $repo --workflow veltrix-english-tutor.yml --commit $sha --limit 1 --json databaseId,status,conclusion 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            try { $item = @($raw | ConvertFrom-Json)[0]; if ($item.databaseId) { $id = [string]$item.databaseId; break } } catch {}
        }
        Start-Sleep -Seconds 4
    }
    if (-not $id) {
        Write-Host 'GitHub did not show a run within 2 minutes. Open Actions and check permissions/branch or manually use Run workflow.' -ForegroundColor Yellow
        Start-Process ($repoPage + '/actions/workflows/veltrix-english-tutor.yml')
        return
    }
    Header ('[6/6] Watching build #' + $id + '; please keep this window open...')
    & gh run watch $id --repo $repo --exit-status
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'APK BUILD FAILED on GitHub. This is a compiler/workflow error, NOT a Git upload problem.' -ForegroundColor Red
        Write-Host ('Error log: ' + $repoPage + '/actions/runs/' + $id)
        & gh run view $id --repo $repo --log-failed
        throw 'GitHub Actions build failed; see failed logs above.'
    }
    $output = Join-Path $projectRoot 'VELTRIX_APK_DOWNLOAD'
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    & gh run download $id --repo $repo --name 'VELTRIX-English-Tutor-Android-APK' --dir $output
    if ($LASTEXITCODE -ne 0) { throw 'Build succeeded but artifact download failed. Find APK in Actions > Artifacts.' }
    $apk = Join-Path $output 'app-debug.apk'
    if (-not (Test-Path $apk)) { throw 'Build succeeded but app-debug.apk was not found in the downloaded artifact.' }
    Copy-Item $apk (Join-Path $output 'VELTRIX-English-Tutor.apk') -Force
    Write-Host ('SUCCESS: Android APK downloaded to ' + (Join-Path $output 'VELTRIX-English-Tutor.apk')) -ForegroundColor Green
    Start-Process explorer.exe $output
}
try {
    Start-Transcript -Path $log -Force -ErrorAction Stop | Out-Null
    $transcript = $true
    Header '====================================================='
    Header '       VELTRIX AI  |  GITHUB TO APK  |  ONE CLICK'
    Header '====================================================='
    Write-Host ('DESTINATION: ' + $repoPage)
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { throw 'Git for Windows is missing: https://git-scm.com/download/win' }
    if (-not (Test-Path (Join-Path $projectRoot 'app\src\main\AndroidManifest.xml'))) {
        throw 'Missing Android project. Extract the entire ZIP before running this BAT.'
    }
    $workflow = Join-Path $projectRoot 'deploy\veltrix-english-tutor.yml'
    if (-not (Test-Path $workflow)) { throw 'Build workflow source missing from the extracted folder.' }
    # If gh is installed, explicitly authenticate with GitHub in the user's browser
    # before any upload. If gh is absent, Git for Windows/Git Credential Manager
    # should prompt for authentication on the push operation (no passwords in scripts).
    Header '[0/6] Checking GitHub authentication...'
    $ghTool = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghTool) {
        & cmd.exe /d /c 'gh auth status -h github.com >NUL 2>&1'
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Opening GitHub sign-in. Sign into the account with write access to this repository.' -ForegroundColor Yellow
            & gh auth login --hostname github.com --git-protocol https --web
            if ($LASTEXITCODE -ne 0) { throw 'GitHub sign-in was cancelled or failed. Try running: gh auth login' }
        }
        & gh auth setup-git
        if ($LASTEXITCODE -ne 0) { Write-Host 'Note: gh auth setup-git failed; git may ask for credentials during push.' -ForegroundColor Yellow }
    } else {
        Write-Host 'GitHub CLI is not installed. Git Credential Manager may open a browser on push.' -ForegroundColor Yellow
        Write-Host 'If no login window appears and access is denied, install GitHub CLI and run gh auth login.' -ForegroundColor Yellow
    }
    Header '[1/6] Cloning the EXISTING repository without changing its history...'
    Invoke-GitCommand @('clone','--depth','1','--',$repoURL,$tmp)
    if (-not (Test-Path (Join-Path $tmp '.git'))) { throw 'Cannot clone destination. Check the repository URL, visibility, internet and GitHub login.' }
    $headCheck = & git.exe -C $tmp symbolic-ref --quiet --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Could not detect the target branch. Open GitHub to inspect the repository before retrying.' }
    # Git author info is local to this temporary clone, not global to Windows.
    $authorName = [string](& git.exe config --global user.name 2>$null)
    $authorEmail = [string](& git.exe config --global user.email 2>$null)
    if ([string]::IsNullOrWhiteSpace($authorName)) { $authorName = 'Parham Babaei' }
    if ([string]::IsNullOrWhiteSpace($authorEmail) -or $authorEmail -notmatch '^\S+@\S+\.\S+$') { $authorEmail = 'pbabaei925@gmail.com' }
    Invoke-GitCommand @('-C',$tmp,'config','user.name',$authorName.Trim())
    Invoke-GitCommand @('-C',$tmp,'config','user.email',$authorEmail.Trim())
    Header '[2/6] Copying ONLY the VELTRIX Android folder...'
    $destination = Join-Path $tmp 'VELTRIX-English-Tutor'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $x = @('/XD','.git','.gradle','.idea','vendor','node_modules','build','.venv','/XF','*.zip','*.apk','*.gguf','*.jks','*.keystore','local.properties','VELTRIX_UPLOAD_LOG.txt','/R:1','/W:1','/NFL','/NDL','/NJH','/NJS','/NP')
    & robocopy.exe $projectRoot $destination /E @x | Out-Null
    if ($LASTEXITCODE -gt 7) { throw ('Robocopy failed, exit code: ' + $LASTEXITCODE) }
    Header '[3/6] Installing an isolated GitHub Actions workflow...'
    $wdir = Join-Path $tmp '.github\workflows'
    New-Item -ItemType Directory -Force -Path $wdir | Out-Null
    Copy-Item -LiteralPath $workflow -Destination (Join-Path $wdir 'veltrix-english-tutor.yml') -Force
    # Always change a harmless file under the VELTRIX directory, even if all other files match.
    # This guarantees the push-path GitHub workflow is triggered on each successful upload.
    $marker = Join-Path $destination 'LAST_BUILD_REQUEST.txt'
    Set-Content -LiteralPath $marker -Encoding UTF8 -Value ('Build requested (UTC): ' + [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ') + [Environment]::NewLine + 'Source: one-click VELTRIX publisher')
    Header '[4/6] Committing and pushing changes WITHOUT force-push...'
    Invoke-GitCommand @('-C',$tmp,'add','--','VELTRIX-English-Tutor','.github/workflows/veltrix-english-tutor.yml')
    # Check staging with Git pathspec exclusions instead of parsing displayed filenames.
    # Git quotes non-ASCII names as octal (for example Persian UTF-8), which made the
    # previous name-based safety check falsely reject valid VELTRIX project files.
    # Exit 0 = nothing staged outside allowed paths; exit 1 = unsafe paths present.
    & git.exe -C $tmp diff --cached --quiet -- . ':(exclude)VELTRIX-English-Tutor/**' ':(exclude).github/workflows/veltrix-english-tutor.yml'
    if ($LASTEXITCODE -eq 1) {
        throw 'Safety check: staged changes outside VELTRIX-English-Tutor or its dedicated workflow were detected. Commit cancelled.'
    }
    if ($LASTEXITCODE -ne 0) { throw 'Git staged-path safety check failed.' }
    Write-Host '[OK] Safe staged paths verified, including Unicode/Persian filenames.' -ForegroundColor Green
    Invoke-GitCommand @('-C',$tmp,'commit','-m','Build VELTRIX English Tutor APK')
    $sha = (& git.exe -C $tmp rev-parse HEAD).Trim()
    Write-Host 'If prompted, finish the GitHub login in the browser, then return here.' -ForegroundColor Cyan
    Invoke-GitCommand @('-C',$tmp,'push','origin','HEAD')
    Write-Host ('PUSH SUCCESSFUL. Commit: ' + $sha) -ForegroundColor Green
    Write-Host 'GitHub Actions will now build the APK; it may take many minutes.'
    Write-Host ('Actions: ' + $repoPage + '/actions/workflows/veltrix-english-tutor.yml')
    Write-Host ('Artifacts: ' + $repoPage + '/actions')
    Write-Host ('Releases: ' + $repoPage + '/releases')
    WaitForGitHubApk $sha
    Write-Host 'GitHub update completed.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('See diagnostic log: ' + $log) -ForegroundColor Yellow
    Write-Host 'No force-push or destructive update was attempted.' -ForegroundColor Yellow
    exit 1
} finally {
    if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    if ($transcript) { try { Stop-Transcript | Out-Null } catch {} }
}
