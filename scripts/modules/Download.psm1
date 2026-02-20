function Get-0ADInstaller {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [string]$BaseUrl = "https://releases.wildfiregames.com"
    )
    
    Write-Host "=== Downloading 0 A.D. Installer ===" -ForegroundColor Cyan
    
    # Ensure output directory exists
    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Construct download URL
    $filename = "0ad-$Version-win32.exe"
    $url = "$BaseUrl/$filename"
    
    Write-Host "Version: $Version" -ForegroundColor Gray
    Write-Host "URL: $url" -ForegroundColor Gray
    Write-Host "Output: $OutputPath" -ForegroundColor Gray
    
    try {
        # Download with progress
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $OutputPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-Host "✓ Download complete: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
            return $true
        } else {
            Write-Error "Download failed: File not found at $OutputPath"
            return $false
        }
    }
    catch {
        Write-Error "Failed to download installer: $_"
        return $false
    }
}

Export-ModuleMember -Function Get-0ADInstaller
