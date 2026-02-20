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
    
    # Find 7-Zip
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
    
    # Try to find 7z in PATH
    if (-not $7zipExe) {
        $7zipExe = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
    }
    
    if (-not $7zipExe) {
        Write-Error "7-Zip not found. Please install 7-Zip."
        return $false
    }
    
    Write-Host "Using 7-Zip: $7zipExe" -ForegroundColor Gray
    
    try {
        # Extract NSIS installer
        Write-Host "Extracting..." -ForegroundColor Yellow
        & $7zipExe x "$InstallerPath" -o"$OutputPath" -y | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Extraction complete" -ForegroundColor Green
            
            # List extracted contents
            $items = Get-ChildItem $OutputPath -Recurse | Measure-Object
            Write-Host "  Extracted $($items.Count) items" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Error "7-Zip extraction failed with exit code $LASTEXITCODE"
            return $false
        }
    }
    catch {
        Write-Error "Failed to extract installer: $_"
        return $false
    }
}

Export-ModuleMember -Function Expand-NSISInstaller
