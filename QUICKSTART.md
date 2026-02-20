# Quick Start Guide

## What You Have

A complete GitHub Actions-based build system for packaging 0 A.D. for the Microsoft Store.

## Next Steps

### 1. Add Visual Assets (REQUIRED)

The build will fail without proper logo images. You need to create these PNG files:

```
assets/logos/
├── Square150x150Logo.png   (150x150 px)
├── Square44x44Logo.png     (44x44 px)  
├── Wide310x150Logo.png     (310x150 px)
└── StoreLogo.png           (50x50 px)
```

You can:
- Use the official 0 A.D. logo and resize it
- Create custom icons following Windows 11 design guidelines
- Use a design tool like Figma, Photoshop, or even online tools

### 2. Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit: 0 A.D. MS Store packaging"
git branch -M main
git remote add origin https://github.com/yourusername/0ad-ms-store.git
git push -u origin main
```

### 3. Run the Workflow

1. Go to your GitHub repository
2. Click **Actions** tab
3. Click **Build 0 A.D. MS Store Package**
4. Click **Run workflow** (green button)
5. Click **Run workflow** again to confirm

### 4. Download Your Package

After ~10-15 minutes (depending on download speeds):
1. Go to the workflow run
2. Scroll to **Artifacts**
3. Download **0AD-MSStore-Package-0.28.0**
4. Extract the ZIP to get your `.msix` file

## Testing the Package

On a Windows 10/11 machine:

```powershell
# Enable Developer Mode first (Settings → For developers)
Add-AppxPackage -Path "0AD-0.28.0.msix"
```

## Customization

Edit `config/config.json` to change:
- Version to build
- Package name and publisher
- Display name

## Need Help?

See the full README.md for:
- Detailed documentation
- Troubleshooting guide
- Publishing to Microsoft Store
- Advanced configuration

## Important Notes

⚠️ **Assets Required**: Build will fail without logo images
⚠️ **Certificate Optional**: Signing is optional for testing, required for Store
⚠️ **Windows Runners**: Everything runs on GitHub's Windows runners (no local Windows needed)

---

**Current Status**: ✅ All implementation complete, ready to run once assets are added
