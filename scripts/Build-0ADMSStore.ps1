[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = "config/config.json",
    
    [Parameter()]
    [string]$CertificatePath,
    
    [Parameter()]
    [string]$CertificatePassword,
    
    [Parameter()]
    [switch]$SkipDownload,
    
    [Parameter()]
    [switch]$SkipExtraction,
    
    [Parameter()]
    [switch]$CleanOutput
)

$ErrorActionPreference = "Stop"

# Script banner
Write-Host @"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     0 A.D. Microsoft Store Package Builder               ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Get script directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot

# Load configuration
Write-Host "`nLoading configuration..." -ForegroundColor Yellow
$configFile = Join-Path $projectRoot $ConfigPath
if (-not (Test-Path $configFile)) {
    Write-Error "Configuration file not found: $configFile"
    exit 1
}

$config = Get-Content $configFile -Raw | ConvertFrom-Json

# Convert to hashtable for easier access
$configHash = @{
    release = @{
        baseUrl = $config.release.baseUrl
        version = $config.release.version
    }
    package = @{
        name = $config.package.name
        publisher = $config.package.publisher
        publisherDisplayName = $config.package.publisherDisplayName
        displayName = $config.package.displayName
        description = $config.package.description
        identityName = $config.package.identityName
        identityPublisher = $config.package.identityPublisher
    }
    msix = @{
        version = $config.msix.version
        minVersion = $config.msix.minVersion
        targetDeviceFamily = $config.msix.targetDeviceFamily
    }
    assets = @{
        storeLogo = $config.assets.storeLogo
        square150x150Logo = $config.assets.square150x150Logo
        square44x44Logo = $config.assets.square44x44Logo
        wide310x150Logo = $config.assets.wide310x150Logo
    }
}

Write-Host "✓ Configuration loaded" -ForegroundColor Green
Write-Host "  Version: $($config.release.version)" -ForegroundColor Gray
Write-Host "  Package: $($config.package.displayName)" -ForegroundColor Gray

# Define paths
$downloadPath = Join-Path $projectRoot $config.paths.download
$extractPath = Join-Path $projectRoot $config.paths.extracted
$stagingPath = Join-Path $projectRoot $config.paths.staged
$packagePath = Join-Path $projectRoot $config.paths.package

$installerFile = Join-Path $downloadPath "0ad-$($config.release.version)-win32.exe"
$msixFile = Join-Path $packagePath "0AD-$($config.release.version).msix"

# Clean output directories if requested
if ($CleanOutput) {
    Write-Host "`nCleaning output directories..." -ForegroundColor Yellow
    @($downloadPath, $extractPath, $stagingPath, $packagePath) | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item -Path $_ -Recurse -Force
        }
    }
    Write-Host "✓ Cleanup complete" -ForegroundColor Green
}

# Import modules
Write-Host "`nLoading modules..." -ForegroundColor Yellow
$modulesPath = Join-Path $scriptRoot "modules"
Import-Module (Join-Path $modulesPath "Download.psm1") -Force
Import-Module (Join-Path $modulesPath "Extract.psm1") -Force
Import-Module (Join-Path $modulesPath "Package.psm1") -Force
Write-Host "✓ Modules loaded" -ForegroundColor Green

# Step 1: Download installer
if (-not $SkipDownload) {
    Write-Host ""
    $downloadSuccess = Get-0ADInstaller `
        -Version $config.release.version `
        -OutputPath $installerFile `
        -BaseUrl $config.release.baseUrl
    
    if (-not $downloadSuccess) {
        Write-Error "Download failed"
        exit 1
    }
} else {
    Write-Host "`nSkipping download (using existing file)" -ForegroundColor Yellow
    if (-not (Test-Path $installerFile)) {
        Write-Error "Installer not found: $installerFile"
        exit 1
    }
}

# Step 2: Extract installer
if (-not $SkipExtraction) {
    Write-Host ""
    $extractSuccess = Expand-NSISInstaller `
        -InstallerPath $installerFile `
        -OutputPath $extractPath
    
    if (-not $extractSuccess) {
        Write-Error "Extraction failed"
        exit 1
    }
} else {
    Write-Host "`nSkipping extraction (using existing files)" -ForegroundColor Yellow
    if (-not (Test-Path $extractPath)) {
        Write-Error "Extracted files not found: $extractPath"
        exit 1
    }
}

# Step 3: Prepare package structure
Write-Host ""
$prepareSuccess = New-AppxPackageStructure `
    -SourcePath $extractPath `
    -StagingPath $stagingPath `
    -Config $configHash

if (-not $prepareSuccess) {
    Write-Error "Package preparation failed"
    exit 1
}

# Step 4: Create MSIX package
Write-Host ""
$packageSuccess = New-MsixPackage `
    -StagingPath $stagingPath `
    -OutputPath $msixFile `
    -CertificatePath $CertificatePath `
    -CertificatePassword $CertificatePassword

if (-not $packageSuccess) {
    Write-Error "Package creation failed"
    exit 1
}

# Success summary
Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ✓ Build Complete!                                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Package: $msixFile

"@ -ForegroundColor Green

exit 0
