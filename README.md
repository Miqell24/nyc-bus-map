# New York Public Transport — interactive map

Interactive, poster-grade map of public transport in **New York and its
region**: every MTA bus of the five boroughs and the MTA Bus Company, NICE in
Nassau County, NJ Transit's buses in the Hudson–Essex core of New Jersey
(Jersey City, Hoboken, Newark), the subway, PATH, the Hudson-Bergen and
Newark light rail, the Staten Island Railway, the Long Island Rail Road and
Metro-North — drawn along the real street and track geometry.

## Live

**https://miqell24.github.io/nyc-bus-map/** — GitHub Pages serves
`main:/docs`; local build on port 8182 (`npm run serve`).

Thirteen feeds, one network:

| feed | source | on the map | route_type | graph |
|---|---|---|---|---|
| NYCT buses ×5 (M, Bx, B, Q, SI) | MTA S3 bucket | all 255 local, limited, SBS and express routes | 3 | OSM roadways |
| MTA Bus Company | MTA S3 bucket | all 92 | 3 | OSM roadways |
| NICE (Nassau) | nicebus.com | all 45 | 3 | OSM roadways |
| NJ Transit bus | MobilityDatabase mirror (mdb-508) | 74 lines of the Hudson–Essex core (`pipeline/scope.mjs`) | 3 | OSM roadways |
| NJ Transit rail | MobilityDatabase mirror (mdb-509) | HBLR and Newark Light Rail only, family red | 0 | `railway=light_rail` |
| subway | MTA S3 bucket | all 28 routes in the MTA's trunk colours | 1 | `railway=subway` |
| PATH | Trillium | all 7 services in PATH's colours | 2 | `railway=subway` |
| Staten Island Railway | in the subway feed | SIR | 2 | `railway=rail` |
| LIRR | MTA S3 bucket | 12 branches in their colours | 2 | `railway=rail` |
| Metro-North | MTA S3 bucket | Hudson, Harlem, New Haven and its three branches | 2 | `railway=rail` |

The MTA publishes its feeds from an S3 bucket without a key; the five
borough bus feeds carry the same `routes.txt` and differ only in their trips,
so a route that crosses a borough line merges on its key by itself. NJ
Transit's feeds sit behind a developer login on njtransit.com and are read
from the MobilityDatabase mirror instead.

**Scope on the New Jersey side.** NJ Transit's bus feed covers the whole
state — 263 lines from Atlantic City to Port Jervis. A line is on the map
when at least half of its stops lie within 12 km of the point between Newark
and Jersey City and none farther than 35 km: the Newark locals (1–99), the
Jersey City / Hoboken / Bayonne / Union City lines (80–89, 119–129), the
Hudson expresses to Port Authority (320–378) and the GO buses. The NJT
commuter rail stays out as a state-scale network, like V/Line in Melbourne;
from the rail feed only the two light rail lines are drawn.

Cut deliberately: the subway shuttle buses (route_type 711 — B90, D99, J90…
are rail replacement, not lines); the LIRR "City Terminal Zone" route (Penn /
Grand Central / Atlantic Terminal ↔ Jamaica shuttles on track every branch
already draws); the River Line (Camden–Trenton); NYC Ferry, the Staten
Island Ferry and NY Waterway (the engine has no water graph).

**Line keys.** Every New York bus number already carries its borough letter
(M1, Bx1, B1, Q1, S40) and NICE writes n1–n80, so the only clash on the whole
map is NJ Transit's 1–99 against the subway's 1–7: the NJT keys carry an
`NJ` prefix and print the bare number the bus shows. The subway is keyed by
`route_id` because three shuttles share the short name "S" (GS, FS, H — all
print S); PATH by the terminal pairs its own map prints (HOB-33, JSQ-33,
NWK-WTC…); the LIRR by branch name without "Branch"; Metro-North by line
name.

**Colours** come from the feeds where the city has a colour code: the
subway's trunk colours, PATH's four, the LIRR branch colours, Metro-North's
Hudson green, Harlem blue and New Haven red, the SIR blue. Buses are the
family's navy whatever the feed paints them; the light rail is the family's
red.

**Names.** The MTA bus feeds and NJ Transit shout ("WILLIS AV/E 138 ST",
"MAIN ST AT ADAMS AVE", headsigns included); `usName` brings a fully
uppercase name to title case, keeps the abbreviations the pole flags use (Av,
St, Blvd, Pkwy…) and the acronyms that are names (JFK, LGA, NYU), and leaves
mixed-case names alone. NJ Transit's headsigns also drop their route number
and fare note.

**Branches.** The subway and the HBLR use `allVariants`: the A alone has
three ends, the 5 two, and the HBLR is one route with three services, so the
branches live only in the stop sequences. The LIRR and Metro-North publish
every branch as a route of its own, so the representative rule draws each one
whole.

## Pipeline

`npm run download` fetches the thirteen feeds, computes the NJ Transit scope
and cuts the OSM extracts. **The OSM data comes from Geofabrik, not
Overpass**: the road grid covers the five boroughs, Nassau and the
Hudson–Essex core (52 × 85 km), the rail file reaches Montauk, Poughkeepsie
and New Haven with the LIRR and Metro-North (150 × 210 km), and
`pipeline/pbf-tiles.py` (needs `pip3 install --user osmium`) reads the New
York, New Jersey and Connecticut extracts in one pass, writing exactly the
JSON shape Overpass would have returned, node ids included.

`npm run build` map-matches every line (HMM/Viterbi on the OSM graphs) and
writes GeoJSON to `data/out/`; `npm run lines` adds the line-by-line view;
`npm run audit` checks the drawn result. `npm run serve` hosts the map at
<http://localhost:8182>.

Data: MTA (New York City Transit, MTA Bus, Long Island Rail Road,
Metro-North Railroad) · Nassau Inter-County Express · NJ Transit · Port
Authority Trans-Hudson · base map © OpenFreeMap / OpenMapTiles /
OpenStreetMap contributors.
