# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/steamcmd:local
ARG BASE_IMAGE=lancommander/steamcmd:latest
FROM ${BASE_IMAGE}

# SteamCMD settings
# App 90 is the shared GoldSrc dedicated server (HLDS). Other GoldSrc games use
# the same app and select their content with GAME_MOD (cstrike, dod, tfc, ...).
ENV STEAM_APP_ID="90"
ENV STEAM_INSTALL_ATTEMPTS="3"
ENV GAME_MOD="valve"
ENV START_EXE="hlds_run"
ENV START_ARGS="-game valve -console -port 27015 +maxplayers 16 +map crossfire"
ENV HTTP_FILESERVER_ENABLED="false"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged/valve"
ENV HTTP_FILESERVER_FILE_PATTERN="^/(maps|models|sound|sprites|gfx|overviews)/.*\.(bsp|res|txt|wad|mdl|wav|spr|tga|bmp)$"

# ----------------------------
# Dependencies
# ----------------------------
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    lib32z1 \
  && rm -rf /var/lib/apt/lists/*

EXPOSE 27015/udp
EXPOSE 80/tcp

# Replaces the SteamCMD image's PostInitialization/20-InstallGame.ps1
COPY Hooks/ "${BASE_HOOKS}/"

USER lancommander

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
