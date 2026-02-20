# 0 A.D. MS Store Packager

Builds x64 MSIX packages for [0 A.D.](https://play0ad.com/) automatically using GitHub Actions.

Downloads the NSIS installer from releases.wildfiregames.com, extracts it, and creates an MSIX package ready for Store submission. Everything runs on GitHub's Windows runners, so you can manage this from any OS.

## Project Structure

```
0ad-ms-store/
├── .github/
│   └── workflows/
│       └── build-msstore.yml      # Main GitHub Actions workflow
├── scripts/
│   ├── Build-0ADMSStore.ps1       # Main orchestration script
│   └── modules/
│       ├── Download.psm1          # Download functionality
│       ├── Extract.psm1           # NSIS extraction
│       └── Package.psm1           # MSIX packaging
├── config/
│   ├── config.json                # Build configuration
│   └── AppxManifest.xml.template  # MS Store manifest template
├── assets/
│   └── logos/                     # Store visual assets
├── build/
│   └── MSStore.proj               # MSBuild project (validation)
└── output/                        # Build outputs (created during build)
```

## Quick Start

### 1. Configure Store Identity

Edit `config/config.json` with your Store identity from Partner Center:

```json
{
  "package": {
    "identityName": "YourPublisher.0AD",
    "identityPublisher": "CN=YourPublisher",
    "displayName": "0 A.D. Empires Ascendant"
  }
}
```

Placeholder logos are already included in `assets/logos/`. Replace them with proper icons before Store submission.

### 2. Push to GitHub

```bash
git add .
git commit -m "Initial commit"
git push
```

### 3. Run the Workflow

Go to Actions → "Build 0 A.D. MS Store Package" → Run workflow. Takes ~15 minutes.

### 4. Get Your Package

Download the artifact from the workflow run. Extract the ZIP to get the `.msix` file.

## Code Signing (Optional)

The workflow creates unsigned MSIX packages by default. This is fine - Microsoft signs packages during Store certification.

If you need signed packages (for sideloading or testing), add these secrets in your repo:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add these secrets:
   - `CERTIFICATE_BASE64`: Your PFX certificate encoded as base64
   - `CERTIFICATE_PASSWORD`: Password for the certificate

To encode your certificate:
```powershell
# Windows
$cert = [Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.pfx"))
$cert | Set-Content cert-base64.txt

# macOS/Linux
base64 -i certificate.pfx -o cert-base64.txt
```

## Testing Locally

Enable Developer Mode on Windows 10/11 (Settings → For developers), then:

```powershell
Add-AppxPackage -Path "0AD-0.28.0.msix"
```

Or just double-click the `.msix` file.

## Changing the Version

Edit `config/config.json` and update the version numbers:

```json
{
  "release": {
    "version": "0.28.0"
  },
  "msix": {
    "version": "0.28.0.0"
  }
}
```

Or trigger the workflow manually and enter a version there.

If you have a Windows machine and want to test locally:

```powershell
# Clone repository
git clone https://github.com/yourusername/0ad-ms-store.git
cd 0ad-ms-store

# Run build script
.\scripts\Build-0ADMSStore.ps1 -Verbose

# With certificate
.\scripts\Build-0ADMSStore.ps1 -CertificatePath "cert.pfx" -CertificatePassword "pass"

# Skip steps for faster iteration
.\scripts\Build-0ADMSStore.ps1 -SkipDownload -SkipExtraction
```

### Customizing the Workflow

Edit `.github/workflows/build-msstore.yml`:

**Change schedule:**
```yaml
schedule:
  - cron: '0 0 * * 0'  # Weekly on Sunday at midnight UTC
```

**Add additional triggers:**
```yaml
on:
  push:
    tags:
      - 'v*'  # Trigger on version tags
```

**Modify retention:**
```yaml
- name: Upload MSIX package
  with:
    retention-days: 90  # Keep for 90 days instead of 30
```

## Troubleshooting

**Download fails**: Check the version exists at https://releases.wildfiregames.com/

**Extraction fails**: Shouldn't happen on GitHub runners (7-Zip is pre-installed)

**Package won't install**: Enable Developer Mode in Windows settings

**Missing assets**: Make sure all 4 PNG files exist in `assets/logos/`

**Symptom**: Package version doesn't match expected

**Solutions**:
- MSIX versions must be 4-part: "1.2.3.0" not "1.2.3"
- Update both `release.version` and `msix.version` in config
- Workflow automatically adds ".0" if needed

## Publishing to Microsoft Store

1. Log into [Partner Center](https://partner.microsoft.com/dashboard)
2. Create new submission for your app
3. Upload the `.msix` file
4. Fill in Store listing (description, screenshots, age rating, etc.)
5. Submit for certification (takes 1-3 business days)

For updates, just increment the version number and create a new submission with the new MSIX.

## How It Works

The workflow downloads the NSIS installer from releases.wildfiregames.com, extracts it with 7-Zip, copies the game files into the proper MSIX structure, and runs MakeAppx to create the package. MSIX is Microsoft's modern packaging format with clean install/uninstall and automatic updates.

Version note: 0 A.D. uses 3-part versions (0.28.0) but MSIX needs 4 parts (0.28.0.0). The workflow handles this automatically.

## Links

- [0 A.D. Official Site](https://play0ad.com/)
- [0 A.D. Releases](https://releases.wildfiregames.com/)
- [Partner Center](https://partner.microsoft.com/dashboard)

---

This is an unofficial packaging tool, not affiliated with Wildfire Games. 0 A.D. is GPL-2.0 licensed.
