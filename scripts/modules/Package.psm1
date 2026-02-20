function New-AppxPackageStructure {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$StagingPath,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    Write-Host "=== Preparing Package Structure ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $SourcePath)) {
        Write-Error "Source path not found: $SourcePath"
        return $false
    }
    
    # Create staging directory
    if (Test-Path $StagingPath) {
        Write-Host "Cleaning existing staging directory..." -ForegroundColor Yellow
        Remove-Item -Path $StagingPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $StagingPath -Force | Out-Null
    
    Write-Host "Source: $SourcePath" -ForegroundColor Gray
    Write-Host "Staging: $StagingPath" -ForegroundColor Gray
    
    try {
        # Copy game files
        Write-Host "Copying game files..." -ForegroundColor Yellow
        
        # Find the actual game installation directory within extracted files
        $gameRoot = $null
        $possiblePaths = @(
            (Join-Path $SourcePath "binaries"),
            (Join-Path $SourcePath "$`$INSTDIR"),
            $SourcePath
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $binariesPath = Join-Path $path "binaries"
                if (Test-Path $binariesPath) {
                    $gameRoot = $path
                    break
                }
            }
        }
        
        if (-not $gameRoot) {
            Write-Error "Could not find game installation directory"
            return $false
        }
        
        Write-Host "  Game root: $gameRoot" -ForegroundColor Gray
        
        # Copy all game content
        Copy-Item -Path "$gameRoot\*" -Destination $StagingPath -Recurse -Force
        
        # Generate AppxManifest.xml from template
        Write-Host "Generating AppxManifest.xml..." -ForegroundColor Yellow
        $templatePath = Join-Path $PSScriptRoot "..\..\config\AppxManifest.xml.template"
        $template = Get-Content $templatePath -Raw
        
        $manifest = $template `
            -replace '{{IDENTITY_NAME}}', $Config.package.identityName `
            -replace '{{IDENTITY_PUBLISHER}}', $Config.package.identityPublisher `
            -replace '{{VERSION}}', $Config.msix.version `
            -replace '{{DISPLAY_NAME}}', $Config.package.displayName `
            -replace '{{PUBLISHER_DISPLAY_NAME}}', $Config.package.publisherDisplayName `
            -replace '{{DESCRIPTION}}', $Config.package.description `
            -replace '{{TARGET_DEVICE_FAMILY}}', $Config.msix.targetDeviceFamily `
            -replace '{{MIN_VERSION}}', $Config.msix.minVersion `
            -replace '{{STORE_LOGO}}', $Config.assets.storeLogo `
            -replace '{{SQUARE_150X150_LOGO}}', $Config.assets.square150x150Logo `
            -replace '{{SQUARE_44X44_LOGO}}', $Config.assets.square44x44Logo `
            -replace '{{WIDE_310X150_LOGO}}', $Config.assets.wide310x150Logo
        
        $manifestPath = Join-Path $StagingPath "AppxManifest.xml"
        Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8
        
        # Copy assets
        Write-Host "Copying assets..." -ForegroundColor Yellow
        $assetsSourcePath = Join-Path $PSScriptRoot "..\..\assets"
        $assetsStagingPath = Join-Path $StagingPath "assets"
        
        if (Test-Path $assetsSourcePath) {
            Copy-Item -Path $assetsSourcePath -Destination $assetsStagingPath -Recurse -Force
        } else {
            Write-Warning "Assets directory not found, package may need visual assets"
        }
        
        Write-Host "✓ Package structure prepared" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to prepare package structure: $_"
        return $false
    }
}

function New-MsixPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StagingPath,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$false)]
        [string]$CertificatePath,
        
        [Parameter(Mandatory=$false)]
        [string]$CertificatePassword
    )
    
    Write-Host "=== Creating MSIX Package ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $StagingPath)) {
        Write-Error "Staging path not found: $StagingPath"
        return $false
    }
    
    # Ensure output directory exists
    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    Write-Host "Staging: $StagingPath" -ForegroundColor Gray
    Write-Host "Output: $OutputPath" -ForegroundColor Gray
    
    try {
        # Find MakeAppx.exe
        $makeAppxPaths = @(
            "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe",
            "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makeappx.exe"
        )
        
        $makeAppx = $null
        foreach ($pathPattern in $makeAppxPaths) {
            $found = Get-ChildItem $pathPattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                $makeAppx = $found.FullName
                break
            }
        }
        
        if (-not $makeAppx) {
            Write-Error "MakeAppx.exe not found. Windows SDK required."
            return $false
        }
        
        Write-Host "Using MakeAppx: $makeAppx" -ForegroundColor Gray
        
        # Create MSIX package
        Write-Host "Creating package..." -ForegroundColor Yellow
        & $makeAppx pack /d "$StagingPath" /p "$OutputPath" /o
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "MakeAppx failed with exit code $LASTEXITCODE"
            return $false
        }
        
        Write-Host "✓ MSIX package created" -ForegroundColor Green
        
        # Sign package if certificate provided
        if ($CertificatePath -and (Test-Path $CertificatePath)) {
            Write-Host "Signing package..." -ForegroundColor Yellow
            
            # Find SignTool.exe
            $signToolPaths = @(
                "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
                "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe"
            )
            
            $signTool = $null
            foreach ($pathPattern in $signToolPaths) {
                $found = Get-ChildItem $pathPattern -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $signTool = $found.FullName
                    break
                }
            }
            
            if ($signTool) {
                $signArgs = @("sign", "/f", $CertificatePath, "/fd", "SHA256")
                if ($CertificatePassword) {
                    $signArgs += @("/p", $CertificatePassword)
                }
                $signArgs += $OutputPath
                
                & $signTool $signArgs
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ Package signed" -ForegroundColor Green
                } else {
                    Write-Warning "Package signing failed, continuing with unsigned package"
                }
            } else {
                Write-Warning "SignTool.exe not found, skipping signing"
            }
        } else {
            Write-Warning "No certificate provided, package is unsigned"
        }
        
        $fileSize = (Get-Item $OutputPath).Length / 1MB
        Write-Host "Package size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
        
        return $true
    }
    catch {
        Write-Error "Failed to create MSIX package: $_"
        return $false
    }
}

Export-ModuleMember -Function New-AppxPackageStructure, New-MsixPackage
