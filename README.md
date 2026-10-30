# Half-Life Dedicated Server (Docker)

This repository provides a Dockerized **Half-Life** (GoldSrc) dedicated server.
The image is designed for **headless operation**, automatically downloads and updates HLDS via SteamCMD, and supports file overlaying using OverlayFS.

Every GoldSrc game shares the same dedicated server (Steam app `90`), so this image can also run Counter-Strike 1.6, Day of Defeat, Team Fortress Classic, Opposing Force and third-party mods by changing `GAME_MOD` and `START_ARGS`.

---

## Features

- Half-Life Deathmatch out of the box
- Any official GoldSrc game via `GAME_MOD` (uses SteamCMD's `app_set_config 90 mod <mod>`)
- Automatically downloads and updates HLDS via SteamCMD, with retries for app 90's flaky installs
- Supports file overlaying using OverlayFS (no file copying required)
- Optional HTTP file server for `sv_downloadurl` fast downloads

## Docker Compose Example

```yaml
services:
  halflife-server:
    image: lancommander/halflife:latest
    container_name: my-halflife-server

    ports:
      - "27015:27015/udp"

    volumes:
      - ./config:/config

    environment:
      STEAM_APP_UPDATE: "true"
      START_ARGS: "-game valve -port 27015 +maxplayers 16 +map crossfire"

    # Overlayfs needs SYS_ADMIN, and the entrypoint must run as root to mount it
    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Other GoldSrc Games

Set `GAME_MOD` to the game's directory and pass the same name to `-game`:

| Game | `GAME_MOD` | Example `START_ARGS` |
|------|------------|----------------------|
| Half-Life Deathmatch | `valve` | `-game valve +maxplayers 16 +map crossfire` |
| Counter-Strike 1.6 | `cstrike` | `-game cstrike +maxplayers 16 +map de_dust2` |
| Condition Zero | `czero` | `-game czero +maxplayers 16 +map de_dust2_cz` |
| Day of Defeat | `dod` | `-game dod +maxplayers 16 +map dod_anzio` |
| Team Fortress Classic | `tfc` | `-game tfc +maxplayers 16 +map 2fort` |
| Opposing Force | `gearbox` | `-game gearbox +maxplayers 16 +map op4_bootcamp` |
| Deathmatch Classic | `dmc` | `-game dmc +maxplayers 16 +map dmc_dm2` |
| Ricochet | `ricochet` | `-game ricochet +maxplayers 16 +map rc_arena` |

Third-party mods (Natural Selection, The Specialists, ...) aren't on SteamCMD. Leave `GAME_MOD` as `valve`, put the mod folder in `Overlay/<mod>/` and start with `-game <mod>`.

A derived image for a specific game only needs to override a few variables:

```dockerfile
FROM lancommander/halflife:latest

ENV GAME_MOD="cstrike"
ENV START_ARGS="-game cstrike -port 27015 +maxplayers 16 +map de_dust2"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged/cstrike"
```

---

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # HLDS files downloaded by SteamCMD (auto-created)
    │   ├── hlds_run
    │   └── valve/         # Half-Life game directory
    ├── Overlay/           # Files to overlay on the server directory
    │   └── valve/
    │       ├── maps/      # Custom maps
    │       ├── server.cfg # Server configuration
    │       └── ...
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── .overlay-work/     # Overlayfs work directory (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

Note that GoldSrc keeps `server.cfg` in the game directory itself (`valve/server.cfg`), not in a `cfg/` folder.

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STEAM_APP_UPDATE` | Run SteamCMD on startup (`true`/`false`) | `true` |
| `STEAM_INSTALL_ATTEMPTS` | How many times to run SteamCMD if it fails | `3` |
| `STEAM_BRANCH` | Steam beta branch, e.g. `steam_legacy` for the pre-25th-anniversary build | |
| `GAME_MOD` | Game content SteamCMD downloads | `valve` |
| `GAME_APP_ID` | Overrides the app ID written to `steam_appid.txt` | Derived from `GAME_MOD` |
| `START_EXE` | Server executable | `hlds_run` |
| `START_ARGS` | Arguments passed to the server | `-game valve -console -port 27015 +maxplayers 16 +map crossfire` |
| `HTTP_FILESERVER_ENABLED` | Serve game files on port 80 for `sv_downloadurl` | `false` |
| `HTTP_FILESERVER_WEB_ROOT` | Directory served by the HTTP file server | `/config/Merged/valve` |

Always include `+map` in `START_ARGS`. Without a map, HLDS starts but never loads a level.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## License

SteamCMD and game servers are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
