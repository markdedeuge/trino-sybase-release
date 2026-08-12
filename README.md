# trino-sybase-release

Compiled plugin bundles for the two Trino connectors built in [`trino-sybase`](https://github.com/markdedeuge/trino-sybase):

- **trino-sybase (ASE)** — Trino to Sybase ASE 16, catalog `sybase`, jTDS driver bundled.
- **trino-sybase-iq (IQ)** — Trino to SAP IQ, catalog `sybase_iq`, no JDBC driver bundled (jConnect is loaded reflectively at runtime).

This repo holds **binaries only**. Source, issues and CI live in `trino-sybase`.

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
