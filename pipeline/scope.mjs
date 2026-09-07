// Wyznacza zakres NJ Transit na mapie Nowego Jorku. Feed autobusowy NJT
// obejmuje CAŁE New Jersey — 263 linie od Atlantic City po Port Jervis — a
// mapa sięga po drugiej stronie Hudsonu tylko do Jersey City, Hoboken i
// Newark. Reguła (data/scope.json → lista route_id):
//   - linia należy do mapy, gdy >=50% jej przystanków leży w promieniu 12 km
//     od punktu między Newark a Jersey City (40.73, -74.10) — to sieć miejska
//     Newark (1–99), Jersey City / Hoboken / Bayonne / Union City (80–89,
//     119–129), ekspresy z Hudson do Port Authority (320–378) i GO-busy;
//   - odpada linia z przystankiem dalej niż 35 km — jeden kurs do Willowbrook
//     czy Toms River rozciągałby kadr na pół stanu.
// Kolej NJT (Northeast Corridor, Morris & Essex…) zostaje poza mapą w całości:
// to sieć stanowa jak V/Line w Melbourne; z feedu kolejowego wchodzą tylko
// dwie linie lekkie (HBLR, Newark Light Rail) — patrz build.mjs.
//
// Uruchamiane przez download.sh po pobraniu GTFS; build.mjs wymaga wyniku.
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { iterCsv, readCsv } from './lib/csv.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const GD = join(ROOT, 'data/gtfs-njbus');

const CX = -74.10, CY = 40.73;
const CORE_KM = 12, CORE_SHARE = 0.5, CAP_KM = 35;

const t0 = Date.now();
const log = (m) => console.log(`[scope ${((Date.now() - t0) / 1000).toFixed(0)}s] ${m}`);

const candidates = new Map();
for (const r of await readCsv(join(GD, 'routes.txt'))) {
  if ((r.route_type || '').trim() === '3') candidates.set(r.route_id, (r.route_short_name || '').trim());
}
log(`kandydatów: ${candidates.size} linii NJ Transit`);

const mx = 111320 * Math.cos(CY * Math.PI / 180), my = 111132;
const stopKm = new Map();
for await (const s of iterCsv(join(GD, 'stops.txt'))) {
  const lat = Number(s.stop_lat), lon = Number(s.stop_lon);
  if (Number.isFinite(lat) && Number.isFinite(lon)) {
    stopKm.set(s.stop_id, Math.hypot((lon - CX) * mx, (lat - CY) * my) / 1000);
  }
}
const t2r = new Map();
for await (const t of iterCsv(join(GD, 'trips.txt'))) {
  if (candidates.has(t.route_id)) t2r.set(t.trip_id, t.route_id);
}
const rStops = new Map();
for await (const st of iterCsv(join(GD, 'stop_times.txt'))) {
  const rid = t2r.get(st.trip_id);
  if (!rid) continue;
  let s = rStops.get(rid);
  if (!s) rStops.set(rid, (s = new Set()));
  s.add(st.stop_id);
}

const nj = [];
let cut = 0;
for (const [rid, stops] of rStops) {
  let n = 0, inside = 0, max = 0;
  for (const sid of stops) {
    const d = stopKm.get(sid);
    if (d === undefined) continue;
    n++; if (d <= CORE_KM) inside++; if (d > max) max = d;
  }
  if (!n || inside / n < CORE_SHARE) continue;
  if (max > CAP_KM) { cut++; continue; }
  nj.push(rid);
}
nj.sort();
log(`wybrano: ${nj.length} linii NJ Transit (odrzucone limitem ${CAP_KM} km: ${cut}): `
  + nj.map((id) => candidates.get(id)).sort().join(', '));
writeFileSync(join(ROOT, 'data/scope.json'), JSON.stringify({ nj }, null, 0));
log('zapisano data/scope.json');
