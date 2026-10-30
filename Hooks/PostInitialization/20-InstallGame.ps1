#Requires -Modules Hooks
#Requires -Modules Logging
#Requires -Modules OverlayFS
#Requires -Modules SteamCMD

# Replaces the SteamCMD image's install hook. HLDS (app 90) needs two things the
# generic Install-SteamGame doesn't do:
#   - "app_set_config 90 mod <mod>" to download a mod other than valve
#   - retries, since app 90 often reports "state is 0x..." before it's complete

if ($Env:STEAM_APP_UPDATE -notin @("true", "1")) {
    Write-Log "STEAM_APP_UPDATE is disabled. Skipping game installation."
    return
}

Write-Log "Updating SteamCMD"

Update-SteamCmd

Start-Sleep -Seconds 2

Write-Log "Starting game installation via SteamCMD (app $Env:STEAM_APP_ID, mod $Env:GAME_MOD)"

Invoke-Hook "PreSteamInstallGame"

New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null

$steamCmdArgs = @(
    "+@ShutdownOnFailedCommand", "1",
    "+@NoPromptForPassword", "1",
    "+@sSteamCmdForcePlatformType", "linux",
    "+force_install_dir", $Env:SERVER_DIR,
    "+login", $Env:STEAM_USERNAME
)

if ($Env:STEAM_USERNAME -ne "anonymous" -and $Env:STEAM_PASSWORD) {
    $steamCmdArgs += $Env:STEAM_PASSWORD
}

if ($Env:GAME_MOD -and $Env:GAME_MOD -ne "valve") {
    $steamCmdArgs += "+app_set_config", $Env:STEAM_APP_ID, "mod", $Env:GAME_MOD
}

$steamCmdArgs += "+app_update", $Env:STEAM_APP_ID

if ($Env:STEAM_BRANCH) {
    $steamCmdArgs += "-beta", $Env:STEAM_BRANCH
    if ($Env:STEAM_BRANCH_PASSWORD) {
        $steamCmdArgs += "-betapassword", $Env:STEAM_BRANCH_PASSWORD
    }
}

if ([System.Convert]::ToBoolean($Env:STEAM_VALIDATE)) {
    $steamCmdArgs += "validate"
}

$steamCmdArgs += "+quit"

$attempts = [int]$Env:STEAM_INSTALL_ATTEMPTS
if ($attempts -lt 1) { $attempts = 1 }

for ($attempt = 1; $attempt -le $attempts; $attempt++) {
    Write-Log "SteamCMD attempt $attempt of $attempts"

    Invoke-SteamCmd -Arguments $steamCmdArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Log "SteamCMD install completed"
        break
    }

    Write-Log -Level Warning "SteamCMD exited with code $LASTEXITCODE"
}

if ((id -u) -eq "0") {
    # SteamCMD ran as root, so hand the files to the server user
    chown -R "${Env:USER}:${Env:GROUP}" $Env:SERVER_DIR

    # The overlay was mounted before SteamCMD populated the lower dir, and
    # overlayfs doesn't reliably show lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT

    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue

        try {
            Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
            Write-Log "OverlayFS remounted"
        } catch {
            Write-Log -Level Error "Failed to remount OverlayFS: $($_.Exception.Message)"
        }
    }
}

Invoke-Hook "PostSteamInstallGame"
