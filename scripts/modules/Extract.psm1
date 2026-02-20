function Expand-NSISInstaller {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallerPath,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    Write-Host "=== Extracting NSIS Installer ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $InstallerPath)) {
        Write-Error "Installer not found: $InstallerPath"
        return $false
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    Write-Host "Installer: $InstallerPath" -ForegroundColor Gray
    Write-Host "Output: $OutputPath" -ForegroundColor Gray
    
    try {
        # Try 7-Zip first for win32 installers
        $7zipPaths = @(
            "C:\Program Files\7-Zip\7z.exe",
            "C:\Program Files (x86)\7-Zip\7z.exe",
            "$env:ProgramFiles\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )
        
        $7zipExe = $null
        foreach ($path in $7zipPaths) {
            if (Test-Path $path) {
                $7zipExe = $path
                break
            }
        }
        
        if (-not $7zipExe) {
            $7zipExe = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
        }
        
        if ($7zipExe) {
            Write-Host "Attempting 7-Zip extraction..." -ForegroundColor Yellow
            & $7zipExe x "$InstallerPath" -o"$OutputPath" -y 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                $items = Get-ChildItem $OutputPath -Recurse -ErrorAction SilentlyContinue | Measure-Object
                if ($items.Count -gt 0) {
                    Write-Host "✓ Extraction complete (7-Zip)" -ForegroundColor Green
                    Write-Host "  Extracted $($items.Count) items" -ForegroundColor Gray
                    return $true
                }
            }
        }
        
        # 7-Zip failed or not available - use silent install method
        Write-Host "7-Zip extraction failed, using silent install method..." -ForegroundColor Yellow
        
        # Create a temporary install directory
        $tempInstallDir = Join-Path $env:TEMP "0ad-extract-$(Get-Random)"
        
        Write-Host "Running silent installer..." -ForegroundColor Yellow
        Write-Host "  Temp install: $tempInstallDir" -ForegroundColor Gray
        
        # Run NSIS installer with silent flags
        $process = Start-Process -FilePath $InstallerPath -ArgumentList "/S","/D=$tempInstallDir" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            Write-Error "Installer failed with exit code $($process.ExitCode)"
            return $false
        }
        
        # Check if installation succeeded
        if (-not (Test-Path $tempInstallDir)) {
            Write-Error "Installation directory not created: $tempInstallDir"
            return $false
        }
        
        # Copy installed files to output directory
        Write-Host "Copying installed files..." -ForegroundColor Yellow
        Copy-Item -Path "$tempInstallDir\*" -Destination $OutputPath -Recurse -Force
        
        # Cleanup temp install
        Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
        Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        
        # Verify extraction
        $items = Get-ChildItem $OutputPath -Recurse | Measure-Object
        if ($items.Count -gt 0) {
            Write-Host "✓ Extraction complete (silent install)" -ForegroundColor Green
            Write-Host "  Extracted $($items.Count) items" -ForegroundColor Gray
            return $true
        } else {
            Write-Error "No files extracted"
            return $false
        }
    }
    catch {
        Write-Error "Failed to extract installer: $_"
        return $false
    }
}

Export-ModuleMember -Function Expand-NSISInstaller
