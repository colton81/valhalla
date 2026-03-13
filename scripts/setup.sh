#!/bin/sh
rm -rf valhalla_tiles
mkdir -p valhalla_tiles
CONFIG_PATH="${PWD}/valhalla.json"
if [ -f "$CONFIG_PATH" ]; then
    echo "Config found at $CONFIG_PATH, using existing config"
else
    echo "Config not found at $CONFIG_PATH, generating new config"
    "${PWD}"/build/valhalla_build_config \
    --mjolnir-tile-dir "${PWD}/valhalla_tiles" \
    --mjolnir-tile-extract "${PWD}/valhalla_tiles.tar" \
    --mjolnir-timezone "${PWD}/valhalla_tiles/timezones.sqlite" \
    --mjolnir-admin "${PWD}/valhalla_tiles/admins.sqlite" \
    --additional-data-elevation "${PWD}/data/contours" \
    --mjolnir-include-bicycle false \
    --mjolnir-include-pedestrian false \
    --mjolnir-use-lru-mem-cache true \
    --mjolnir-lru-mem-cache-hard-control true \
    --mjolnir-global-synchronized-cache true \
    --mjolnir-max-cache-size 4294967296 \
    --loki-actions route,sources_to_targets,locate,status \
    --httpd-service-timeout-seconds 90 \
    --service-limits-truck-max-distance 5000000 \
    --service-limits-truck-max-locations 20 \
    --service-limits-truck-max-matrix-distance 400000 \
    --service-limits-truck-max-matrix-location-pairs 2500 \
    -o valhalla.json
fi
# build timezones.sqlite to support time-dependent routing
"${PWD}"/build/valhalla_build_timezones > valhalla_tiles/timezones.sqlite
# build admins.sqlite to support admin-related properties such as access restrictions, driving side, ISO codes etc
"${PWD}"/build/valhalla_build_admins -c valhalla.json "${PWD}"/data/north-america-latest.osm
# build routing tiles
"${PWD}"/build/valhalla_build_tiles -c valhalla.json "${PWD}"/data/north-america-latest.osm
# build a tile index for faster graph loading times
"${PWD}"/build/valhalla_build_extract -c valhalla.json -v