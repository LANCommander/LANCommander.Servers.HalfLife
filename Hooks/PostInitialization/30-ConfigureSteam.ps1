#Requires -Modules Logging

# HLDS writes steam_appid.txt on its first run, but only after SteamAPI_Init()
# has already failed without it. Seed it so the first boot doesn't crash.
$appIds = @{
    "valve"    = "70"
    "cstrike"  = "10"
    "tfc"      = "20"
    "dod"      = "30"
    "dmc"      = "40"
    "gearbox"  = "50"
    "ricochet" = "60"
    "czero"    = "80"
}

$gameAppId = $Env:GAME_APP_ID

if (-not $gameAppId) {
    # Third-party mods run as Half-Life
    $gameAppId = $appIds[$Env:GAME_MOD] ?? "70"
}

$appIdFile = "$Env:SERVER_ROOT/steam_appid.txt"

if (-not (Test-Path -Path $appIdFile)) {
    Write-Log "Writing steam_appid.txt ($gameAppId)"
    Set-Content -Path $appIdFile -Value $gameAppId -NoNewline
    chown "${Env:USER}:${Env:GROUP}" $appIdFile
}

# The Steam API also looks for steamclient.so in ~/.steam/sdk32
$sdkDir = "$Env:HOME_DIR/.steam/sdk32"

if (-not (Test-Path -Path "$sdkDir/steamclient.so")) {
    New-Item -ItemType Directory -Path $sdkDir -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path "$sdkDir/steamclient.so" -Target "$Env:SERVER_ROOT/steamclient.so" | Out-Null
    chown -R "${Env:USER}:${Env:GROUP}" "$Env:HOME_DIR/.steam"
}
