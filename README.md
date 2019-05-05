# Migrate all your `Chrome` extensions to `Edge Chromium`

## Usage

```powershell
$env:ChromeChannel = "Stable"; # Can be "Stable", "Dev" or "Canary"
$env:EdgeChannel = "Dev"; # Can be "Stable", "Dev" or "Canary"
$env:WhenConflict = "PreferEdge"; # Can be "PreferChrome" or "PreferEdge"
Set-ExecutionPolicy Bypass -Scope Process -Force;
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/yhvicey/MigrateChromeExtensions/master/Migrate-ChromeExtensions.ps1'));
```