#!/usr/bin/pwsh
<#
.Description
    Migrate all chrome extensions to Edge (Chromiun)
#>

param(
    [ValidateSet("Stable", "Dev", "Canary")]
    [string]$ChromeChannel = "Stable",

    [ValidateSet("Stable", "Dev", "Canary")]
    [string]$EdgeChannel = "Dev",

    [ValidateSet("PreferChrome", "PreferEdge")]
    [string]$WhenConflict = "PreferEdge",

    [string]$Locale = ([System.Globalization.CultureInfo]::CurrentCulture).Name.Replace("-", "_")
)

# Prepare
$lang = $Locale.Split("_")[0];
$preferEdge = $WhenConflict -eq "PreferEdge";

# Blacklist
$blacklist = @{
    # Slides
    "aapocclcgogkmnckokdopfmhonfmgoek" = $true;
    # Docs
    "aohghmighlieiainnegkcijnfilokake" = $true;
    # Google Drive
    "apdfllckaahabafndbhieahigkjlhalf" = $true;
    # YouTube
    "blpcfgokakmgnkcojhhkbfbldkacnbeo" = $true;
    # Sheets
    "felcaaldnbdncclmgdcncolpebgiejap" = $true;
    # Google Docs Offline
    "ghbmnnjooekpmoecnnnilnnbdlolhkhi" = $true;
    # Chrome Web Store Payments
    "nmmhkkegccagdldgiimedpiccmgmieda" = $true;
    # Chrome Apps & Extensions Developer Tool
    "ohmmkhmmmpcnpikjeljgnaoabkaalbgc" = $true;
    # Gmail
    "pjkljhegncpnkpknbcohdijeoejaedia" = $true;
    # Chrome Media Router
    "pkedcjkdefgpdelpbcmbmeomcjbeemfm" = $true;
};

# I18N
$messages = @{
    "en" = @{
        BROWSER_NOT_INSTALLED    = "{0} is not installed.";
        PROMPT_MIGRATE_EXTENSION = "Migrate extension {0} from {1} ({2}) to {3} ({4})?";
        MIGRATING_EXTENSION      = "Migrating extension {0} from {1} to {2}...";
        SKIP_EXTENSION           = "Skipping extension {0}. ({1} = {2}, {3} = {4})";
    };
    "zh" = @{
        BROWSER_NOT_INSTALLED    = "{0} 未安装。";
        PROMPT_MIGRATE_EXTENSION = "将 {0} 从 {1}（{2}）迁移至{3}（{4}）？";
        MIGRATING_EXTENSION      = "正在将 {0} 从 {1} 迁移至 {2}...";
        SKIP_EXTENSION           = "跳过 {0}。（{1} = {2}, {3} = {4}）";
    };
};

function WriteMessage([string]$Key, [object[]]$Params) {
    $localeKey = $Locale;
    if (-not $messages.$localeKey) {
        $localeKey = $lang;
    }
    $msgPattern = $messages.$localeKey.$Key;
    if ([string]::IsNullOrEmpty($msgPattern)) {
        return $Key;
    }
    return [string]::Format($msgPattern, $Params);
}

# Functions
function GetFullName([string]$Name, [string]$Channel) {
    switch ($Channel) {
        "Stable" { return $Name; }
        "Dev" { return "$Name Dev"; }
        "Canary" { return "$Name Canary"; }
        Default { return $Name; }
    }
}

function GetExtVersion([string]$ExtRoot, [string]$ExtId) {
    $path = "$ExtRoot/$ExtId";
    if (-not (Test-Path $path)) {
        return $null;
    }
    $versionFolders = Get-ChildItem $path;
    if ($versionFolders.Length -eq 0) {
        return $null;
    }
    return $versionFolders[0].Name;
}

function GetExtFolder([string]$ExtRoot, [string]$ExtId, [string]$ExtVersion) {
    $path = "$ExtRoot/$ExtId/$ExtVersion";
    if (Test-Path $path) {
        return $path;
    }
    return $null;
}

function IsExtMsg([string]$Str) {
    return $Str -match "__MSG_(.+?)__";
}

function GetExtManifest([string]$ExtFolder) {
    $manifestJsonPath = "$ExtFolder/manifest.json";
    if (-not(Test-Path $manifestJsonPath)) {
        return $null;
    }
    return Get-Content $manifestJsonPath | ConvertFrom-Json;
}

function GetExtMsg([string]$ExtFolder, [string]$Key) {
    $localeFolders = Get-ChildItem "$ExtFolder/_locales" -Directory -Filter $Locale;
    if ($localeFolders.Length -eq 0) {
        $localeFolders = Get-ChildItem "$ExtFolder/_locales" -Directory -Filter "$lang*";
    }
    if ($localeFolders.Length -eq 0) {
        return $null;
    }
    $messageJsonPath = "$($localeFolders[0].FullName)/messages.json";
    if (-not (Test-Path $messageJsonPath)) {
        return $null;
    }
    if (-not($Key -match "__MSG_(.+?)__")) {
        return $null;
    }
    $msgKey = $Matches[1];
    return (Get-Content $messageJsonPath -Encoding Utf8 | ConvertFrom-Json).$msgKey.message;
}

function GetExtName([string]$ExtFolder) {
    $manifest = GetExtManifest $ExtFolder;
    if ($null -eq $manifest) {
        return $null;
    }
    if (IsExtMsg $manifest.name) {
        return GetExtMsg $ExtFolder $manifest.name;
    }
    else {
        return $manifest.name;
    }
}

function MigrateExtension(
    [string]$ExtId,
    [string]$ChromeExtVersion,
    [string]$ChromeExtFolder) {
    $edgeExtIdFolder = "$edgeExtsRoot/$ExtId";
    if (-not (Test-Path $edgeExtIdFolder)) {
        [void](New-Item -ItemType Directory $edgeExtIdFolder -Force);
    }
    $edgeExtFolder = "$edgeExtIdFolder/$ChromeExtVersion";
    Copy-Item $ChromeExtFolder $edgeExtFolder -Recurse -Force;
}


# Process
## Set props
$chromeFullName = GetFullName "Chrome" $ChromeChannel;
$edgeFullName = GetFullName "Edge" $EdgeChannel;
switch ($PSVersionTable.Platform) {
    "Unix" {
        # Unix/Linux
        # TODO: Set props for unix/linux
        #$chromeExtsRoot =
        #$edgeExtsRoot =
    }
    Default {
        # Windows
        $rootPath = $env:LOCALAPPDATA;
        $chromeExtsRoot = "$rootPath/Google/$chromeFullName/User Data/Default/Extensions";
        $edgeExtsRoot = "$rootPath/Microsoft/$edgeFullName/User Data/Default/Extensions";
    }
}

## Check if two browsers installed
if (-not (Test-Path $chromeExtsRoot)) {
    WriteMessage BROWSER_NOT_INSTALLED $chromeFullName;
    exit;
}
if (-not (Test-Path $edgeExtsRoot)) {
    WriteMessage BROWSER_NOT_INSTALLED $edgeFullName;
    exit;
}

foreach ($extIdFolder in (Get-ChildItem $chromeExtsRoot -Directory)) {
    $extId = $extIdFolder.Name;
    # Ext info
    $chromeExtVersion = GetExtVersion $chromeExtsRoot $extId;
    $chromeExtFolder = GetExtFolder $chromeExtsRoot $extId $chromeExtVersion;
    if (-not $chromeExtFolder) {
        continue;
    }
    $extName = GetExtName $chromeExtFolder;
    $edgeExtVersion = GetExtVersion $edgeExtsRoot $extId;

    # Check black list
    if ($blacklist.$extId) {
        WriteMessage SKIP_EXTENSION $extName, $chromeFullName, $ChromeExtVersion, $edgeFullName, $EdgeExtVersion;
        continue;
    }

    # Compare versions
    if ($edgeExtVersion) {
        if (($edgeExtVersion -ne $chromeExtVersion) -and $preferEdge) {
            WriteMessage SKIP_EXTENSION $extName, $chromeFullName, $ChromeExtVersion, $edgeFullName, $EdgeExtVersion;
            continue;
        }
        elseif ($edgeExtVersion -eq $chromeExtVersion) {
            WriteMessage SKIP_EXTENSION $extName, $chromeFullName, $ChromeExtVersion, $edgeFullName, $EdgeExtVersion;
            continue;
        }
        else {
            $edgeExtFolder = GetExtFolder $edgeExtsRoot $extId $chromeExtVersion;
            Remove-Item $edgeExtFolder -Recurse -Force;
        }
    }

    WriteMessage PROMPT_MIGRATE_EXTENSION $ExtName, $chromeFullName, $ChromeExtVersion, $edgeFullName, $EdgeExtVersion;
    if (!($(Read-Host -Prompt "[y/n]") -match "(y|Y)")) {
        WriteMessage SKIP_EXTENSION $extName, $chromeFullName, $ChromeExtVersion, $edgeFullName, $EdgeExtVersion;
        continue;
    }

    WriteMessage MIGRATING_EXTENSION $extName, $chromeFullName, $edgeFullName;
    MigrateExtension $extId $chromeExtVersion $chromeExtFolder;
}
