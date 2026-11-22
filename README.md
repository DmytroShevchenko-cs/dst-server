# Fix Don't Starve Together caves lag and teleporting back on Apple Silicon Macs

If your character in Don't Starve Together (DST) keeps teleporting back, rubber-banding or lagging in a world with caves on a Mac with M1, M2, M3 or M4, this is a fix. It runs the official **Linux** dedicated server of DST (surface + caves) in Docker on the same Mac, and the teleports are gone.

## The problem

You host a Don't Starve Together world **with caves** on an Apple Silicon Mac (M1, M2, M3, M4), and your character keeps teleporting back: you walk, and every minute or so you are pulled back to where you were a moment ago (rubber-banding, position rewind). Turning off movement prediction stops the teleports, but then the character moves in jerks. The same world without caves is fine, and the same world hosted on Windows or on a Linux server is fine too.

The game log (`~/Documents/Klei/DoNotStarveTogether/client_log.txt`) shows lines like this every time it happens:

```
Locomotor: Waiting for server...
Locomotor: Buffering...
Locomotor: Reset
```

It is a known bug: [periodic rubber-banding on macOS, caves worlds only](https://forums.kleientertainment.com/klei-bug-tracker/dont-starve-together/periodic-rubber-banding-position-rewind-on-macos-265-tahoe-caves-worlds-only-r52719/).

## Why it happens only on a Mac, and only with caves

Without caves, the game you play in is also the server, in one process. Your character is moved directly, and nothing goes over the network.

With caves, the game starts two separate dedicated servers in the background, one for the surface and one for the caves, and your own game connects to the surface server over the network like any other player. From then on your movement is predicted on your side and confirmed by the server. When the server does not answer in time, the game throws the prediction away and puts your character back where the server last saw it. That is the teleport.

On a Mac these background servers are the macOS build of the dedicated server, and it does not answer in time every minute or so. The game is built for Intel, so on Apple Silicon it runs through Rosetta, but Rosetta alone is not the cause: the Linux build of the same server, also running through Rosetta in this container, has no such pauses. So the problem is in the macOS build of the server (Klei also fixed a similar bug once before, on macOS 15.4, and it came back).

This project runs the Linux build of the server in an x86_64 container instead, and the rubber-banding is gone.

## What was tried and did not help

All of this was tested on an M4 Pro Mac with macOS 26 before this project:

- **Turning off movement prediction** (Options → Settings → Movement Prediction). No teleports, but the character moves in jerks: without prediction it only moves when a server update arrives, 15 times a second.
- **Raising the network tick rate to 60** with `tick_rate = 60` in `cluster.ini`. The "Host Game" menu rewrites `cluster.ini` every time it starts a world and drops this setting.
- **Locking `cluster.ini` against writing**, so the menu keeps `tick_rate`. The menu then fails with "Dedicated server failed to start".
- **A client mod that adds `tick_rate` to the settings the menu sends to the server.** The game writes only the settings from its own menu and ignores the rest.
- **Starting the macOS servers with a script and `-tick 60`.** The tick rate really becomes 60, but with movement prediction on, the teleports stay.
- **Raising the priority of the server processes** with `taskpolicy` (out of background mode, lowest latency tier). No change.
- **Turning off heavy server mods** (Global Positions). No change.

Not tried, because it would not help: Wine or CrossOver also translate the Windows server through Rosetta, and full x86 emulators (UTM/QEMU) are much slower than Rosetta.

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
