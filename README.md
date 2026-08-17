# trino-sybase-release

Compiled plugin bundles for the two Trino connectors built in [`trino-sybase`](https://github.com/markdedeuge/trino-sybase):

- **trino-sybase (ASE)** — Trino to Sybase ASE 16, catalog `sybase`, jTDS driver bundled.
- **trino-sybase-iq (IQ)** — Trino to SAP IQ, catalog `sybase_iq`, no JDBC driver bundled (jConnect is loaded reflectively at runtime).

This repo holds **binaries only**. Source, issues and CI live in `trino-sybase`.

## What the connectors do

Both push work **down into the database** so the engine does it instead of the wire — filters, projections, aggregations, joins, TopN/LIMIT and dynamic filters. What can't be pushed safely, Trino computes locally; nothing lossy is ever pushed.

- **Predicate pushdown** — per-column-type controllers (full push for numerics/date/bit/varbinary; discrete- or range-recheck for char/temporal so results stay correct on any collation).
- **Aggregation pushdown** — `count`/`sum`/`avg`/`min`/`max`, numeric `count(DISTINCT)`, and `stddev`/`variance`. Both connectors fold integer-arithmetic and statistical aggregates (`sum(a*b)`, `var_pop`, `stddev_pop`) that the stock `trino-postgresql` connector leaves un-pushed.
- **Join pushdown** — cost-gated `AUTOMATIC` equi-joins over pushable keys, sized from connector-owned catalog statistics with no data scan (ASE `sysstatistics` density; IQ `sp_iqindexmetadata` FP-dictionary NDV).
- **Dynamic filtering** — build-side keys pushed into the 5M-row fact scan at runtime, collapsing it before rows cross the wire.
- **Char/collation pushdowns** — char predicate/join/`GROUP BY`/TopN under an opt-in `CASE_SENSITIVE` mode.

## Benchmark highlights

Measured on a federated stack (one ASE, two Postgres, one baked 5M SAP IQ) with one 49-shape query battery run on all eight topologies; every result is diffed against the Postgres baseline. Full methodology and the complete matrix live in the source repo: **[`docs/pushdown-bench-483.md`](https://github.com/markdedeuge/trino-sybase/blob/main/docs/pushdown-bench-483.md)** (per-topology source-rows + warm ON wall-clock `mean ± std`) and **[`docs/benchmarks.md`](https://github.com/markdedeuge/trino-sybase/blob/main/docs/benchmarks.md)**.

- **Correct, then fast.** `abs Δ vs Postgres = 0` on **47 of 49 shapes** — byte-identical results; only `stddev_pop`/`var_pop` drift (`~1e-11`, floating-point summation order, ~10⁶× inside the `1e-7` tolerance). Pushdown collapses source rows without ever changing the answer.
- **Source rows read, ON vs OFF** (fact = 5,000,000 rows):

  | Query shape | Rows OFF → ON | Reduction |
  |---|---|--:|
  | `count(*)` / aggregate over join | 5,000,000 → 1 | up to 5,000,000× |
  | indexed `WHERE acct_id = 42` (FULL predicate) | 5,000,000 → 100 | 50,000× |
  | dynamic-filter fact ⋈ dim | 5,000,000 → 25,250 | 198× |
  | `sum(int*int)` / `var_pop` (folded here, not by stock PG) | 100k / 5M → 1 | — |

- **Warm planning + execution.** Each cell is warmed and the ON wall-clock is the trimmed `mean ± std` over 12 runs. Warm planning is single-digit ms; pushed queries run in tens of ms on the IQ column store (e.g. an aggregate-over-join folds to ~145 ms on IQ vs a tens-of-seconds row-store scan on ASE — the pushdown is identical; the wall-clock is the engine, not the connector). See the committed matrix for every shape's exact `mean ± std`.

## Releases

- Each release attaches one zip per Trino target (`480` and `483`) plus a `SHA256SUMS.txt`.
- Tags are driver-scoped so the two connectors release independently:
  - `ase-vX.Y.Z` → the ASE zips (`trino-sybase-480.zip`, `trino-sybase-483.zip`).
  - `iq-vX.Y.Z` → the IQ zips (`trino-sybase-iq-480.zip`, `trino-sybase-iq-483.zip`).
- The same release is also published in the source repo; this repo is the dedicated distribution point.

Pick the zip that matches your Trino version.

## Install

1. Download the zip for your Trino target and driver.
2. Verify the checksum:
   ```bash
   sha256sum -c SHA256SUMS.txt
   ```
3. Unzip into the Trino plugin directory (a subdirectory per plugin):
   ```bash
   unzip trino-sybase-483.zip -d "$TRINO_HOME/plugin/"
   ```
4. Add a catalog properties file, e.g. `etc/catalog/sybase.properties` (ASE) or `sybase_iq.properties` (IQ), with the connector name and JDBC URL.
5. Restart the Trino coordinator and workers.

The IQ connector needs jConnect (`jconn4`, proprietary SAP, not redistributable) on the plugin classpath at runtime — supply it yourself. The ASE connector ships jTDS and needs no extra driver.

## Provenance

Every bundle passes `scripts/provenance.sh` in the source repo before release:

- versioned zip that unpacks to a matching `trino-sybase[-iq]-<target>/` directory;
- jConnect is never bundled by either driver;
- ASE bundles jTDS 1.3.1 (LGPL-2.1, license included); IQ bundles no JDBC driver;
- the bundled `trino-base-jdbc` matches the target label, with no cross-version Trino jar riding along;
- the ServiceLoader descriptor declares the expected `io.trino.spi.Plugin`;
- `LICENSE` and `NOTICE` (and `licenses/LGPL-2.1.txt` for ASE) ship inside the zip.

## License

Apache-2.0, matching the source project. See the `LICENSE`/`NOTICE` shipped inside each zip.
