#!/bin/bash
# Starts both shards (Master and Caves) of one cluster and stops them together.
set -e

CLUSTER="${CLUSTER:-Cluster_1}"
SERVER_DIR=/home/dst/server

# Workshop downloads time out under Rosetta, so mods are copied from ./mods (same versions as the game client).
cp -R /config/mods/. "$SERVER_DIR/mods/"
mkdir -p /data/ugc_mods

ARGS=(
    -persistent_storage_root /data
    -conf_dir DoNotStarveTogether
    -cluster "$CLUSTER"
    -ugc_directory /data/ugc_mods
)

cd "$SERVER_DIR/bin64"
./dontstarve_dedicated_server_nullrenderer_x64 "${ARGS[@]}" -shard Master &
MASTER_PID=$!
./dontstarve_dedicated_server_nullrenderer_x64 "${ARGS[@]}" -shard Caves &
CAVES_PID=$!

stop_servers() {
    kill -INT "$MASTER_PID" "$CAVES_PID" 2>/dev/null || true
    wait
}
trap stop_servers INT TERM

wait
