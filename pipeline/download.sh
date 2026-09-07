#!/usr/bin/env bash
# Downloads input data: thirteen GTFS feeds, three OSM extracts (Geofabrik), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# New York: the MTA serves its feeds from an S3 bucket (no key), NICE from its
# own site, PATH from Trillium; NJ Transit's are behind a developer login on
# njtransit.com, so they come from the MobilityDatabase mirror (mdb-508 bus,
# mdb-509 rail — files.mobilitydatabase.org serves them without a token).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/osm/tiles web/vendor

# pyosmium does the cutting; it is the one dependency outside Node here.
need_osmium () {
  python3 -c "import osmium" 2>/dev/null && return 0
  echo "brak pakietu osmium — zainstaluj: pip3 install --user osmium" >&2
  return 1
}

# 1) GTFS — tag, primary url, mirror
feed () {
  local tag=$1 url=$2 alt=$3
  [ -f "data/gtfs-$tag/routes.txt" ] && return 0
  echo "== GTFS $tag =="
  curl -fsSL --retry 3 --max-time 900 -A "Mozilla/5.0" -o "data/$tag.zip" "$url" \
    || curl -fsSL --retry 3 --max-time 900 -o "data/$tag.zip" "$alt"
  mkdir -p "data/gtfs-$tag"
  unzip -q -o "data/$tag.zip" -d "data/gtfs-$tag"
}
S3=https://rrgtfsfeeds.s3.amazonaws.com
MDB=https://files.mobilitydatabase.org
feed subway $S3/gtfs_subway.zip $MDB/mdb-516/latest.zip
feed m      $S3/gtfs_m.zip      $MDB/mdb-513/latest.zip
feed bx     $S3/gtfs_bx.zip     $MDB/mdb-528/latest.zip
feed b      $S3/gtfs_b.zip      $MDB/mdb-512/latest.zip
feed q      $S3/gtfs_q.zip      $MDB/mdb-520/latest.zip
feed si     $S3/gtfs_si.zip     $MDB/mdb-514/latest.zip
feed busco  $S3/gtfs_busco.zip  $MDB/mdb-510/latest.zip
feed lirr   $S3/gtfslirr.zip    $MDB/mdb-507/latest.zip
feed mnr    $S3/gtfsmnr.zip     $MDB/mdb-524/latest.zip
feed nice   https://www.nicebus.com/NICE/media/nicebus-gtfs/NICE_GTFS.zip $MDB/mdb-521/latest.zip
feed njbus  $MDB/mdb-508/latest.zip $MDB/mdb-508/latest.zip
feed njrail $MDB/mdb-509/latest.zip $MDB/mdb-509/latest.zip
feed path   https://data.trilliumtransit.com/gtfs/path-nj-us/path-nj-us.zip $MDB/mdb-517/latest.zip

# 1b) scope: which of the 263 NJ Transit bus lines belong on a NEW YORK map
if [ ! -f data/scope.json ]; then
  node --max-old-space-size=8192 pipeline/scope.mjs
fi

# 2) OSM — from the Geofabrik extracts, not Overpass. The road grid covers
#    the five boroughs, Nassau and the Hudson–Essex core (52 × 85 km, more
#    than the public mirrors serve in one go); the rail file reaches Montauk,
#    Poughkeepsie and New Haven with the LIRR and Metro-North, so three
#    state extracts are read in one pass. pipeline/pbf-tiles.py writes exactly
#    the JSON shape Overpass would have returned (ways with tags, NODE IDS and
#    geometry — buildGraph silently drops ways without el.nodes).
if [ ! -f data/osm/tiles/t25.json ] || [ ! -f data/osm/nyc-rail.json ]; then
  need_osmium
  for st in new-york new-jersey connecticut; do
    if [ ! -f "data/$st-latest.osm.pbf" ]; then
      echo "== Geofabrik $st-latest.osm.pbf =="
      curl -fL --retry 5 --retry-delay 5 -C - --max-time 3600 -o "data/$st-latest.osm.pbf" \
        "https://download.geofabrik.de/north-america/us/$st-latest.osm.pbf"
    fi
  done
  echo "== cutting OSM tiles out of the extracts =="
  python3 pipeline/pbf-tiles.py
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/gtfs-* data/osm 2>/dev/null || true
