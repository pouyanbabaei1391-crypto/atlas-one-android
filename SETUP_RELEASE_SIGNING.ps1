$ErrorActionPreference = 'Stop'

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool -and $env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
    if (Test-Path $candidate) { $keytool = $candidate }
}
if (-not $keytool) { throw 'keytool was not found. Install Java 17 first.' }

$secureStore = Read-Host 'Choose a strong keystore password' -AsSecureString
$secureKey = Read-Host 'Choose a strong key password' -AsSecureString
$storePtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureStore)
$keyPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try {
    $storePassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($storePtr)
    $keyPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPtr)
    if ($storePassword.Length -lt 12 -or $keyPassword.Length -lt 12) {
        throw 'Use passwords of at least 12 characters.'
    }
    $folder = Join-Path $env:USERPROFILE 'AtlasOneSigning'
    New-Item -ItemType Directory -Force $folder | Out-Null
    $keystore = Join-Path $folder 'atlas-release-upload.jks'
    if (Test-Path $keystore) {
        throw "A signing key already exists at $keystore. It was not overwritten."
    }
    & $keytool -genkeypair -v -keystore $keystore -storepass $storePassword `
        -alias atlas_upload -keypass $keyPassword -keyalg RSA -keysize 4096 `
        -storetype JKS -validity 10000 -dname 'CN=Atlas One Release, OU=Mobile, O=Atlas One'
    if ($LASTEXITCODE -ne 0) { throw 'keytool failed.' }
    $encoded = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore))
    $base64File = Join-Path $folder 'ATLAS_RELEASE_KEYSTORE_BASE64.txt'
    [IO.File]::WriteAllText($base64File, $encoded)
    Write-Host "Signing files created in: $folder" -ForegroundColor Green
    Write-Host 'Add these four GitHub Actions repository secrets:' -ForegroundColor Cyan
    Write-Host "ATLAS_RELEASE_KEYSTORE_BASE64 = contents of $base64File"
    Write-Host 'ATLAS_KEY_ALIAS = atlas_upload'
    Write-Host 'ATLAS_STORE_PASSWORD = the first password you entered'
    Write-Host 'ATLAS_KEY_PASSWORD = the second password you entered'
    Write-Host 'Back up the JKS and passwords offline. Losing them can prevent future updates.' -ForegroundColor Yellow
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($storePtr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPtr)
}
