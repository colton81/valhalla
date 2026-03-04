#!/usr/bin/env bash
set -euo pipefail

############################################
# Resolve project root (parent of scripts/)
############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALHALLA_BUILD="$PROJECT_ROOT/build"
export PATH="$VALHALLA_BUILD:$PATH"
# Your repo appears to be:
# <repo>/valhalla/
#   scripts/
#   valhalla.json
#   valhalla_tiles/   <-- tiles live here (NOT nested)
#

TILES_DIR="$PROJECT_ROOT/valhalla_tiles"
TRAFFIC_DIR="$PROJECT_ROOT/traffic"
CONFIG="$PROJECT_ROOT/valhalla.json"
WAY_EDGES="$TILES_DIR/way_edges.txt"

PREDICTED_TRAFFIC_WAY_ID="131426303"
REALTIME_TRAFFIC_WAY_ID="1/43284/51877,20,$(date +%s)"

############################################
# Sanity checks
############################################
[[ -d "$TILES_DIR" ]] || { echo "ERROR: Tiles dir not found: $TILES_DIR" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "ERROR: Config not found: $CONFIG" >&2; exit 1; }
[[ -f "$SCRIPT_DIR/update_traffic.py" ]] || { echo "ERROR: update_traffic.py not found at: $SCRIPT_DIR/update_traffic.py" >&2; exit 1; }

############################################
# Create traffic directory hierarchy
############################################
echo "==> Creating traffic directory structure"
mkdir -p "$TRAFFIC_DIR"

cd "$TILES_DIR"
find . -type d -exec mkdir -p -- "$TRAFFIC_DIR/{}" \;

############################################
# Generate way -> edge mapping
############################################
echo "==> Generating way_edges.txt"
command -v /Users/colton/Documents/GitHub/valhalla/build/valhalla_ways_to_edges >/dev/null 2>&1 || {
    echo "ERROR: /Users/colton/Documents/GitHub/valhalla/build/valhalla_ways_to_edges not found in PATH"
    exit 1
}
/Users/colton/Documents/GitHub/valhalla/build/valhalla_ways_to_edges --config "$CONFIG"

############################################
# Copy update_traffic.py into traffic dir
############################################
echo "==> Copying update_traffic.py"
cp -f "$SCRIPT_DIR/update_traffic.py" "$TRAFFIC_DIR/update_traffic.py"

############################################
# Generate traffic.csv
############################################
echo "==> Generating traffic.csv for OSM way $PREDICTED_TRAFFIC_WAY_ID"
cd "$TRAFFIC_DIR"
python3 update_traffic.py "$PREDICTED_TRAFFIC_WAY_ID" "$WAY_EDGES"

############################################
# Move traffic.csv into correct tile folder
############################################
echo "==> Moving traffic.csv into tile hierarchy"

EDGE_ID="$(grep -m1 "^${PREDICTED_TRAFFIC_WAY_ID}," "$WAY_EDGES" | cut -d ',' -f3)"
[[ -n "$EDGE_ID" ]] || { echo "ERROR: No edge_id found for way $PREDICTED_TRAFFIC_WAY_ID"; exit 1; }

REL_PATH="$("$VALHALLA_BUILD/valhalla_traffic_demo_utils" --get-traffic-dir "$EDGE_ID")"
# REL_PATH is something like: 1/043/284.csv   (THIS IS A FILE PATH)

DEST_FILE="$TRAFFIC_DIR/$REL_PATH"
mkdir -p "$(dirname "$DEST_FILE")"
mv -f "$TRAFFIC_DIR/traffic.csv" "$DEST_FILE"

echo "Placed predicted traffic at: $DEST_FILE"
head -n 3 "$DEST_FILE"

############################################
# Add predicted traffic to tiles
############################################
echo "==> Injecting predicted traffic into routing tiles"
cd "$PROJECT_ROOT"
/Users/colton/Documents/GitHub/valhalla/build/valhalla_add_predicted_traffic -t traffic --config "$CONFIG"

############################################
# Generate live traffic archive
############################################
rm -f "$PROJECT_ROOT/traffic.tar"
## level    tile_id     edge_id     speed    epoch
## 1     /   43284   /   51877   ,     20,     $(date +%s)
## example grogans mill road 10200
echo "==> Generating live traffic archive"
/Users/colton/Documents/GitHub/valhalla/build/valhalla_traffic_demo_utils \
--config "$CONFIG" \
--generate-live-traffic "$REALTIME_TRAFFIC_WAY_ID"

echo "✅ Traffic generation complete"