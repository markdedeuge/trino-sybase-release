# Trino / Starburst (SEP) deployment tooling

Two scripts for deploying a **shipped** Sybase connector plugin onto a server whose SPI version string differs
from the community build it was compiled against (e.g. the community `480`/`483` zip onto Starburst Enterprise
`480-e.2.89`). No source, no rebuild — they operate on the already-built plugin jars and the target server's
jars, using only the JDK's `javap`/`jar`.

There are **two independent gates** to clear:

1. **Version string** — SEP refuses a plugin whose recorded version does not *exactly* match the server
   (`SPI version 480-e.2.89 does not match the version 483 connector was compiled for`). Fixed by
   **`spi-adopt.sh`** (stamps the plugin's version markers).
2. **ABI linkage** — even once it loads, the plugin's compiled references must resolve against the server's
   actual SPI classes, or it throws `NoSuchMethodError` / `AbstractMethodError` at query time. Proved by
   **`spi-linkage-check.sh`**.

`spi-adopt.sh --server-lib …` chains both: it stamps, then runs the linkage check.

## What you need

- The **plugin** you plan to deploy: the unzipped `trino-sybase-<v>` directory (or the `.zip`). **Start from
  the zip whose base matches the server's Trino base** — the **480** zip for a `480-e.*` server, the **483**
  zip for `483-e.*`. Stamping fixes the version string, never the ABI; a `483` zip will not link against a
  `480-e` server.
- The **target server's jars**: the SEP/Trino install `lib/` dir — it holds `trino-spi-<ver>.jar` and the
  other engine-provided jars. Copy it off the node if you run the checks elsewhere.
- A **JDK 25+** (`javap`, `jar`). `javap` must be at least the plugin's Java version (these builds are Java
  25), or it cannot read the class files. The Trino/SEP node's bundled JDK works; else pass `--java-home`.

## Typical install flow (SEP)

These scripts ship **inside the plugin zip** under `bin/`, so on a deployed node they are already at
`<plugin-dir>/bin/`. From the plugin dir you unzipped the matching-base zip into:

```bash
cd /usr/lib/trino/plugin/sybase
./bin/spi-adopt.sh --server-lib /usr/lib/trino/lib
# reads the target version from the server's trino-spi jar, stamps the three markers, then link-checks.
# 0 = stamped and links · 1 = linkage failed (do not start Trino) · 2 = bad invocation.
```

Then restart Trino. Run once per plugin dir (`sybase` and/or `sybase_iq` are separate zips), and re-run per
node and per SEP build. `--restore` reverts from the `.trino-adopt.bak` the first stamp saved.

## spi-adopt.sh — clear the version-string gate

Force-stamps the connector jar's version to the target so SEP loads it. It sets the three places SEP may read
(manifest `Implementation-Version`, `META-INF/maven/.../pom.properties`, embedded `pom.xml` `<version>`),
leaves the format-constrained `Specification-Version` alone, and stamps only the connector jar (never the
bundled `trino-base-jdbc` / toolkit / jTDS).

- Target version from: `--server-lib <dir>` (reads the `trino-spi-<ver>.jar` name), `--version 480-e.2.89`
  (explicit), or `--info-url http://<coordinator>:8080/v1/info` (the running server's `nodeVersion`).
- A fixed stamp matches **one** server version — re-run per node for each `480-e.x.y`.
- `--no-verify` stamps without the linkage check; `--restore` reverts. See `spi-adopt.sh --help`.

## spi-linkage-check.sh — prove the ABI gate

Statically checks that the compiled plugin will link against the server — the JVM's runtime resolution step,
done ahead of time. Three checks:

1. **class** — every engine-provided class the plugin references exists in the server.
2. **forward** — every SPI method/field the plugin *calls* exists in the server, with the exact descriptor
   (catches `NoSuchMethodError` / `NoSuchFieldError`).
3. **reverse** — every *abstract* SPI method the server declares on a type the plugin implements has a
   concrete implementation in the plugin's runtime hierarchy (catches `AbstractMethodError` from
   server-**added** abstract methods — a call-site scan alone misses these).

```bash
./spi-linkage-check.sh --plugin /usr/lib/trino/plugin/sybase --server-lib /usr/lib/trino/lib
```

`--plugin` defaults to the current directory. Runtime: the forward pass is ~30s; the full run (with the
reverse phase) is a few minutes, because it disassembles every bundled class. It parallelises across cores by
default (`nproc`); pass `--jobs N` to cap it, or `--forward-only` for the fast pass. See
`spi-linkage-check.sh --help` for `--scan-all`, `--java-home`, `-v`.

### SPI-footprint self-check (wrong/old jars)

Each zip bundles a `bin/spi-refs.expected` fingerprint (the exact SPI member/class counts for that build).
On every run the check compares the live scan to it, and if they differ it prints a **loud WARNING** — it does
**not** fail (the run continues). A lower count almost always means an **older or partially-copied** connector
jar is in the plugin dir instead of this release's — so you'd otherwise be validating (and stamping) the wrong
jars. Fix it by wiping the plugin dir and re-unzipping the matching release.

- `--count-only` prints `members=N / classes=M` for a plugin dir (no `--server-lib` needed) — used to
  regenerate `spi-refs.expected` if you build against different Trino artifacts.
- `--expect-members N` / `--expect-classes M` override the bundled fingerprint (or supply one when running the
  script standalone). Absent both, and with no bundled file, the footprint check is skipped.

### The boundary it polices

Only the packages the Trino `PluginClassLoader` delegates to the server (the "SPI packages") can drift under
SEP: `io.trino.spi`, `io.airlift.slice`, `org.openjdk.jol`, `io.opentelemetry.api/context`,
`com.fasterxml.jackson.annotation`. Everything else in the zip (`base-jdbc`, `plugin-toolkit`, guava,
jackson-databind, jTDS, …) is bundled and self-consistent, so it is out of scope by construction.

## What these do NOT prove

- **Behaviour.** A method with the same signature but changed semantics passes the linkage check and can still
  be wrong at runtime. Real queries against the target server remain the only proof of behaviour.
- Members reached by reflection rather than a typed bytecode reference are invisible. The Sybase connectors
  only reflect into their own/bundled classes (jConnect, `SybaseIqPlugin`), so this is not a gap in practice.
- Descriptor matching is on erased JVM descriptors; exotic covariant-return/bridge cases could produce a false
  "missing" — treat any hit as "review against the reported class".

Community Trino (`trinodb/trino:483`) needs neither script.
