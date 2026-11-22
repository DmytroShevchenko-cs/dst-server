# Don't Starve Together server with caves for Apple Silicon Macs

Runs the official **Linux** dedicated server of Don't Starve Together (surface + caves) in Docker on an Apple Silicon Mac.

## Why

On Apple Silicon Macs, a world with caves started from the in-game "Host Game" menu runs the macOS build of the dedicated server. On recent macOS versions it often rubber-bands the player: the character is pulled back to a previous position every minute or so. Worlds without caves are fine, and so is the same world hosted on Windows or Linux. See the Klei bug tracker: [periodic rubber-banding on macOS, caves worlds only](https://forums.kleientertainment.com/klei-bug-tracker/dont-starve-together/periodic-rubber-banding-position-rewind-on-macos-265-tahoe-caves-worlds-only-r52719/).

This project runs the Linux build of the server in an x86_64 container (through Rosetta) instead, and the rubber-banding is gone.

## Requirements

- An Apple Silicon Mac with [OrbStack](https://orbstack.dev) (recommended, tested, works without extra settings) or Docker Desktop (not tested).
- Don't Starve Together installed through Steam.
- About 5 GB of free disk space for the image.

With Docker Desktop, turn on two settings first:

- **Rosetta:** Settings → General → "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" (needs the Apple Virtualization framework). Without it the server runs under QEMU and is much slower.
- **Host networking:** Settings → Resources → Network → "Enable host networking". Without it the game cannot reach the server on `127.0.0.1`.

## Setup

1. **Create the world in the game.** Use "Host Game" with caves enabled once, then go back to the main menu. The game creates the cluster in `~/Documents/Klei/DoNotStarveTogether/<number>/Cluster_<N>`.

2. **Copy the cluster into this project:**
   ```
   mkdir -p data/DoNotStarveTogether
   cp -R ~/Documents/Klei/DoNotStarveTogether/<number>/Cluster_<N> data/DoNotStarveTogether/
   ```

3. **Set the cluster name** in a `.env` file next to `docker-compose.yml`:
   ```
   CLUSTER=Cluster_<N>
   ```

4. **Add a server token.** Create one at [accounts.klei.com](https://accounts.klei.com/account/game/servers?game=DontStarveTogether) ("Add New Server") and save it as one line in `data/DoNotStarveTogether/Cluster_<N>/cluster_token.txt`.

5. **Optional: make yourself admin.** Put your Klei user ID (`KU_...`, shown at accounts.klei.com) in `data/DoNotStarveTogether/Cluster_<N>/adminlist.txt`.

6. **Copy server mods, if the world uses any** (see [Mods](#mods)).

7. **Build and start:**
   ```
   docker compose up -d --build
   ```

## Playing

In the game main menu, press `~` to open the console and connect:

```
c_connect("127.0.0.1", 10999)
```

Do not rely on the "LAN" tab in "Browse Games". On a Mac with OrbStack network bridges or a VPN, the game often cannot send its LAN search broadcast, so the world does not show up there even though the server is running.

**While the container is running, you cannot host any world from the in-game menu** ("Host Game"). The container uses the same ports, and the game shows "Dedicated server failed to start". Run `docker compose down` first.

## Commands

```
docker compose up -d      # start (surface + caves)
docker compose down       # stop, the world is saved
docker compose logs -f    # follow the server output
```

Server logs are also in `data/DoNotStarveTogether/<cluster>/Master/server_log.txt` and `.../Caves/server_log.txt`.

## Switching worlds

Only one world can run in the container at a time. Put every world in `data/DoNotStarveTogether/` (setup steps 1–6, the same `cluster_token.txt` works for all of them) and switch like this:

```
docker compose down
# set CLUSTER=Cluster_<N> in .env
docker compose up -d
```

All mods live in the shared `mods/` folder. Each world loads only the mods enabled in its own `modoverrides.lua`.

## Saves and rollback

The server saves the world at the start of every in-game day and when the container stops. By default it keeps the last 6 saves. To keep more, add this to the `[MISC]` section of `cluster.ini` and restart:

```
max_snapshots = 20
```

To roll back, join the world as an admin (see setup step 5), press `~`, press Ctrl until the console says `Remote`, and run:

```
c_rollback(1)
```

`1` goes back one save (about one day), `3` goes back three. The surface and the caves roll back together, and players reconnect automatically. The "Rollback" button in the in-game host menu does not work for this server.

For a full backup, stop the container and copy the `data` folder. To restore it, stop the container and put the folder back.

## Game updates

The server version must match the game client. After the game updates, download the new server:

```
docker compose build --build-arg GAME_VERSION=$(date +%s) && docker compose up -d
```

## Mods

The server cannot download Workshop mods inside the container (the download times out), so mods are copied from the Mac instead. This also keeps them at the same version as the game client.

1. Enable the mod in the game once, so Steam downloads it.
2. Copy it to `mods/workshop-<id>`. Steam keeps mods in one of two places:
   - older mods: `~/Library/Application Support/Steam/steamapps/common/Don't Starve Together/dontstarve_steam.app/Contents/mods/workshop-<id>`
   - newer mods: `~/Library/Application Support/Steam/steamapps/workshop/content/322330/<id>`
3. Make sure the mod is enabled in `Master/modoverrides.lua` and `Caves/modoverrides.lua` of the cluster, then restart the container.

## How it works

- `Dockerfile` builds an x86_64 Debian image and downloads the dedicated server (Steam app 343050) with [DepotDownloader](https://github.com/SteamRE/DepotDownloader). SteamCMD is not used because it is 32-bit and crashes under Rosetta.
- `entrypoint.sh` copies the mods into the server folder, starts the Master and Caves shards, and stops both with a save when the container stops.
- `docker-compose.yml` runs the container on the host network, so the game sees the server on the usual ports (10999 for the surface, 10998 for the caves).
