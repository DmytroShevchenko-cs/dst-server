FROM --platform=linux/amd64 debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip libicu72 libcurl3-gnutls \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m dst
USER dst
WORKDIR /home/dst

# SteamCMD is 32-bit and crashes under Rosetta, so the game is downloaded with DepotDownloader (64-bit).
ARG DEPOT_DOWNLOADER_VERSION=3.4.0
RUN mkdir depotdownloader \
    && curl -fsSL -o dd.zip "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-x64.zip" \
    && unzip -q dd.zip -d depotdownloader \
    && rm dd.zip \
    && chmod +x depotdownloader/DepotDownloader

# Change GAME_VERSION (any value) to force a fresh download of the game server.
ARG GAME_VERSION=1
RUN ./depotdownloader/DepotDownloader -app 343050 -os linux -osarch 64 -dir /home/dst/server \
    && chmod +x /home/dst/server/bin64/dontstarve_dedicated_server_nullrenderer_x64

COPY --chown=dst entrypoint.sh /home/dst/entrypoint.sh
ENTRYPOINT ["/home/dst/entrypoint.sh"]
