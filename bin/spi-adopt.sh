#!/usr/bin/env bash
# spi-adopt.sh — force-stamp a shipped Sybase connector plugin so it passes a target Trino/SEP server's
# exact plugin-version guard (the "SPI version <X> does not match the version <Y> connector was compiled for"
# error). No source, no rebuild — it rewrites the version markers inside the already-built connector jar.
#
# WHAT IT PATCHES
#   The strict-version guard io.trino.plugin.base.Versions.checkStrictSpiVersionMatch compares the server's SPI
#   version against SpiVersionHolder.SPI_COMPILE_TIME_VERSION, which is loaded at class-init from a bundled
#   resource: io/trino/plugin/base/trino-spi-compile-time-version.txt (inside the trino-plugin-toolkit jar). THAT
#   resource is what clears the "SPI version X does not match Y" error, so this script rewrites it to the target.
#   It ALSO stamps the connector jar's own recorded version (harmless; other tooling reads it):
#     1. META-INF/MANIFEST.MF   Specification-Version:  and  Implementation-Version:
#     2. META-INF/maven/<g>/<a>/pom.properties  version=   and  pom.xml project/parent <version>
#   NOTE: the manifest/pom values are NOT read by the strict-version guard — only the toolkit resource is; the
#   manifest/pom stamping is retained for compatibility with any tooling that inspects those fields.
#
# IMPORTANT — this only clears GATE 1 (the version string). It does NOT prove the plugin actually LINKS
#   against the server's SPI (GATE 2 — ABI). Pass --server-lib and this runs spi-linkage-check.sh right after
#   stamping so you get both in one shot. A green stamp on a red linkage is still unsafe to ship.
#
# A fixed stamp matches ONE server version. To serve several 480-e.x.y builds, re-run adopt per node against
#   each server (it reads the current stamp and re-stamps to the new target). Keep a pristine copy; the first
#   run saves <jar>.trino-adopt.bak so --restore can revert.
#
# START FROM THE RIGHT BASE ZIP. Stamping only fixes the version STRING, never the ABI. Use the connector zip
#   whose base matches the server's Trino base — the 480 zip for a 480-e.* server, the 483 zip for 483-e.*. A
#   483 zip will not LINK against a 480-e server; pass --server-lib so the chained linkage check catches it.
#
# REQUIREMENTS: bash 4+, the JDK `jar`, plus sed/grep/awk/find. `curl` only if you use --info-url.
#
# USAGE
#   spi-adopt.sh --plugin <deployed-plugin-dir> ( --version <str> | --server-lib <dir> | --info-url <url> ) [opts]
#
#   --plugin DIR       The DEPLOYED, unzipped plugin directory (e.g. /usr/lib/trino/plugin/sybase).
#                      Defaults to the current directory — cd into the deployed plugin dir and omit this.
#   --version STR      Stamp exactly this version string (e.g. 480-e.2.89). Highest precedence.
#   --server-lib DIR   Read the target version from a server jar in this lib dir (trino-spi-<ver>.jar or
#                      trino-main-<ver>.jar by name; else the version embedded in whichever jar carries
#                      io/trino/spi/Plugin.class), then (unless --no-verify) run the linkage probe against it.
#   --info-url URL     Read the running server version from Trino's REST info endpoint, e.g.
#                      http://coordinator:8080/v1/info  (parses nodeVersion.version; needs curl).
#   --restore          Revert every connector jar under --plugin from its .trino-adopt.bak and exit.
#   --no-verify        Skip the linkage probe even when --server-lib is given.
#   --probe PATH       Path to spi-linkage-check.sh (default: sibling of this script).
#   -v, --verbose · -h, --help
#
# EXIT: 0 = stamped (and, if run, linkage passed) · 1 = linkage failed after stamping · 2 = bad invocation
set -euo pipefail

PLUGIN="" ; TARGET="" ; SERVER_LIB="" ; INFO_URL="" ; RESTORE=0 ; NO_VERIFY=0 ; VERBOSE=0
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$SELF_DIR/spi-linkage-check.sh"
BAK_SUFFIX=".trino-adopt.bak"
# The resource Trino's strict SPI-version guard actually reads: io.trino.plugin.base.SpiVersionHolder loads
# SPI_COMPILE_TIME_VERSION from this file at class-init, and Versions.checkStrictSpiVersionMatch compares the
# server's SPI version against it. It lives in the bundled trino-plugin-toolkit jar, NOT the connector jar — so
# stamping the connector manifest/pom alone does NOT clear the "SPI version X does not match Y" error.
VERSION_RESOURCE="io/trino/plugin/base/trino-spi-compile-time-version.txt"

log()  { printf '>> %s\n' "$*" >&2; }
vlog() { [[ $VERBOSE == 1 ]] && printf '   %s\n' "$*" >&2 || true; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin)     PLUGIN="${2:?}"; shift 2;;
    --version)    TARGET="${2:?}"; shift 2;;
    --server-lib) SERVER_LIB="${2:?}"; shift 2;;
    --info-url)   INFO_URL="${2:?}"; shift 2;;
    --probe)      PROBE="${2:?}"; shift 2;;
    --restore)    RESTORE=1; shift;;
    --no-verify)  NO_VERIFY=1; shift;;
    -v|--verbose) VERBOSE=1; shift;;
    -h|--help)    sed -n '2,47p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *)            die "unknown argument: $1 (use --help)";;
  esac
done

command -v jar >/dev/null 2>&1 || [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/jar" ]] \
  || die "the JDK 'jar' tool is required (use the Trino/SEP node's bundled JDK, or set JAVA_HOME)"
JAR="$(command -v jar 2>/dev/null || echo "$JAVA_HOME/bin/jar")"

# --plugin defaults to the current directory, so you can just cd into the deployed plugin dir and run this.
PLUGIN="${PLUGIN:-.}"
[[ -d "$PLUGIN" ]] || die "--plugin is not a directory: $PLUGIN (run from the deployed plugin dir, or pass --plugin DIR)"
# Absolutise so stamps/backups and the chained linkage probe never depend on the working directory.
PLUGIN="$(cd "$PLUGIN" && pwd)"

# ---- find the connector jar(s): those carrying io.trino.plugin:trino-sybase[-iq] Maven metadata -------------
# (NOT trino-sybase-base, NOT the bundled trino-* libs.)
declare -a CONNECTOR_JARS=() CONNECTOR_ART=() CONNECTOR_CUR=()
tmp0="$(mktemp -d)"; trap 'rm -rf "$tmp0"' EXIT
while IFS= read -r jar; do
  pp="$("$JAR" tf "$jar" 2>/dev/null | grep -E '^META-INF/maven/io\.trino\.plugin/[^/]+/pom\.properties$' | head -1 || true)"
  [[ -n "$pp" ]] || continue
  rm -rf "$tmp0/x"; mkdir -p "$tmp0/x"; ( cd "$tmp0/x" && "$JAR" xf "$jar" "$pp" )
  art="$(grep -E '^artifactId=' "$tmp0/x/$pp" | cut -d= -f2- | tr -d '\r')"
  cur="$(grep -E '^version='    "$tmp0/x/$pp" | cut -d= -f2- | tr -d '\r')"
  case "$art" in
    trino-sybase|trino-sybase-iq) CONNECTOR_JARS+=("$jar"); CONNECTOR_ART+=("$art"); CONNECTOR_CUR+=("$cur");;
  esac
done < <(find "$PLUGIN" -maxdepth 2 -name '*.jar' ! -name '*-sources.jar' ! -name '*-tests.jar' | sort)

[[ ${#CONNECTOR_JARS[@]} -gt 0 ]] || die "no connector jar under --plugin (expected one carrying io.trino.plugin:trino-sybase[-iq])"

# ---- --restore path -----------------------------------------------------------------------------------------
if [[ $RESTORE == 1 ]]; then
  n=0
  # Restore every jar we backed up — the connector jar(s) AND the toolkit jar whose version resource we patch.
  while IFS= read -r bak; do
    [[ -e "$bak" ]] || continue
    mv -f "$bak" "${bak%"$BAK_SUFFIX"}"; log "restored $(basename "${bak%"$BAK_SUFFIX"}") from backup"; n=$((n+1))
  done < <(find "$PLUGIN" -maxdepth 2 -name "*$BAK_SUFFIX")
  [[ $n -gt 0 ]] || vlog "no $BAK_SUFFIX backups found under $PLUGIN"
  log "restore complete ($n jar(s))."; exit 0
fi

# ---- resolve the TARGET version -----------------------------------------------------------------------------
if [[ -z "$TARGET" && -n "$INFO_URL" ]]; then
  command -v curl >/dev/null 2>&1 || die "--info-url needs curl"
  raw="$(curl -fsS "$INFO_URL" 2>/dev/null)" || die "could not GET $INFO_URL"
  # {"nodeVersion":{"version":"480-e.2.89"}, ...}  — take the version inside nodeVersion.
  TARGET="$(printf '%s' "$raw" | sed -E 's/.*"nodeVersion"[^{]*\{[^}]*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  [[ -n "$TARGET" && "$TARGET" != "$raw" ]] || die "could not parse nodeVersion.version from $INFO_URL"
  log "server ($INFO_URL) reports version: $TARGET"
fi
if [[ -z "$TARGET" && -n "$SERVER_LIB" ]]; then
  [[ -d "$SERVER_LIB" ]] || die "--server-lib is not a directory: $SERVER_LIB"
  # (a) fast path: read the version from a well-known server jar's FILENAME. SEP does not always ship a
  #     trino-spi-*.jar by that name, so also try trino-main-*.jar (present in every install, versioned the same).
  vjar=""
  for pat in 'trino-spi-*.jar' 'trino-main-*.jar'; do
    vjar="$(find "$SERVER_LIB" -name "$pat" | head -1 || true)"
    [[ -n "$vjar" ]] && break
  done
  if [[ -n "$vjar" ]]; then
    TARGET="$(basename "$vjar")"; TARGET="${TARGET#trino-spi-}"; TARGET="${TARGET#trino-main-}"; TARGET="${TARGET%.jar}"
    log "server jar $(basename "$vjar") -> target version: $TARGET"
  else
    # (b) content fallback: when the SPI jar is renamed AND trino-main is absent, the version still lives INSIDE
    #     whichever jar carries io/trino/spi/Plugin.class — read pom.properties version=, else Implementation-Version.
    spijar=""
    while IFS= read -r cj; do
      if "$JAR" tf "$cj" 2>/dev/null | grep -qxF 'io/trino/spi/Plugin.class'; then spijar="$cj"; break; fi
    done < <(find "$SERVER_LIB" -name '*.jar' | sort)
    [[ -n "$spijar" ]] || die "could not infer version from $SERVER_LIB (no trino-spi-*/trino-main-*.jar and no jar carrying io/trino/spi/Plugin.class) — pass --version"
    pp="$("$JAR" tf "$spijar" 2>/dev/null | grep -E '^META-INF/maven/[^/]+/[^/]+/pom\.properties$' | head -1 || true)"
    ex="$(mktemp -d)"
    ( cd "$ex" && "$JAR" xf "$spijar" ${pp:+"$pp"} META-INF/MANIFEST.MF ) 2>/dev/null || true
    [[ -n "$pp" ]] && TARGET="$(grep -E '^version=' "$ex/$pp" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' || true)"
    [[ -n "$TARGET" ]] || TARGET="$(grep -E '^Implementation-Version:' "$ex/META-INF/MANIFEST.MF" 2>/dev/null | head -1 | sed -E 's/^Implementation-Version:[[:space:]]*//' | tr -d '\r' || true)"
    rm -rf "$ex"
    [[ -n "$TARGET" ]] || die "found the SPI jar ($(basename "$spijar")) but could not read a version from it — pass --version"
    log "server SPI jar $(basename "$spijar") (content-matched io/trino/spi/Plugin) -> target version: $TARGET"
  fi
fi
[[ -n "$TARGET" ]] || die "no target version — pass --version, --server-lib, or --info-url"
[[ "$TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || die "refusing unsafe version string: '$TARGET'"

# ---- stamp each connector jar -------------------------------------------------------------------------------
stamp_one() {
  local jar="$1" cur="$2" work mf out pp pomxml
  if [[ "$cur" == "$TARGET" ]]; then log "$(basename "$jar") already stamped $TARGET — skip"; return 0; fi
  [[ -f "$jar$BAK_SUFFIX" ]] || { cp -p "$jar" "$jar$BAK_SUFFIX"; vlog "backup -> $(basename "$jar")$BAK_SUFFIX"; }

  work="$(mktemp -d)"; ( cd "$work" && "$JAR" xf "$jar" )

  # 1. manifest Implementation-Version AND Specification-Version (set, or append if absent). For a Trino plugin
  #    Specification-Version is the SPI-spec version SEP reads as "the version the connector was compiled for",
  #    so it MUST be stamped too — it is dotted-numeric by convention (e.g. 480.0) but the manifest reader accepts
  #    any string, so the SEP form (480-e.1.10) is fine.
  mf="$work/META-INF/MANIFEST.MF"
  if [[ -f "$mf" ]]; then
    local attr
    for attr in Implementation-Version Specification-Version; do
      if grep -qE "^$attr:" "$mf"; then
        sed -i -E "s/^$attr:.*/$attr: $TARGET/" "$mf"
      else
        printf '%s: %s\n' "$attr" "$TARGET" >> "$mf"
      fi
    done
  fi

  # 2. pom.properties version=  (3.) embedded pom.xml project/parent <version>CUR</version>
  while IFS= read -r pp; do
    sed -i -E "s/^version=.*/version=$TARGET/" "$work/$pp"
  done < <(cd "$work" && find META-INF/maven -name pom.properties)
  while IFS= read -r pomxml; do
    sed -i "s#<version>$cur</version>#<version>$TARGET</version>#g" "$work/$pomxml"
  done < <(cd "$work" && find META-INF/maven -name pom.xml)

  # repack: pass the edited manifest via `m`, and REMOVE it from the tree so it is not added twice.
  cp "$mf" "$work/../adopt-manifest.txt"; rm -f "$mf"
  out="$(mktemp -u).jar"
  ( cd "$work" && "$JAR" cfm "$out" "$work/../adopt-manifest.txt" . )
  rm -f "$work/../adopt-manifest.txt"
  mv -f "$out" "$jar"
  rm -rf "$work"
  log "stamped $(basename "$jar"): $cur -> $TARGET  (Specification-Version, Implementation-Version, pom.properties, pom.xml)"
}

# ---- patch the version resource the strict-version guard actually reads --------------------------------------
# This is THE fix for "Trino SPI version X does not match the version Y connector was compiled for": rewrite
# $VERSION_RESOURCE (read by SpiVersionHolder -> checkStrictSpiVersionMatch) inside whichever bundled jar carries
# it (the trino-plugin-toolkit jar). Located by CONTENT so a repackaged/renamed toolkit is still found.
patch_version_resource() {
  local jar="" cj cur work ex
  while IFS= read -r cj; do
    if "$JAR" tf "$cj" 2>/dev/null | grep -qxF "$VERSION_RESOURCE"; then jar="$cj"; break; fi
  done < <(find "$PLUGIN" -maxdepth 2 -name '*.jar' ! -name '*-sources.jar' ! -name '*-tests.jar' | sort)
  if [[ -z "$jar" ]]; then
    log "WARNING: no bundled jar carries $VERSION_RESOURCE — cannot clear the strict-version guard here."
    log "         (older trino-plugin-toolkit? the manifest/pom stamp above will NOT satisfy checkStrictSpiVersionMatch.)"
    return 0
  fi
  ex="$(mktemp -d)"; ( cd "$ex" && "$JAR" xf "$jar" "$VERSION_RESOURCE" ) 2>/dev/null || true
  cur="$(tr -d '\r\n' < "$ex/$VERSION_RESOURCE" 2>/dev/null || true)"; rm -rf "$ex"
  if [[ "$cur" == "$TARGET" ]]; then log "$(basename "$jar"): $VERSION_RESOURCE already $TARGET — skip"; return 0; fi
  [[ -f "$jar$BAK_SUFFIX" ]] || { cp -p "$jar" "$jar$BAK_SUFFIX"; vlog "backup -> $(basename "$jar")$BAK_SUFFIX"; }
  work="$(mktemp -d)"; mkdir -p "$work/$(dirname "$VERSION_RESOURCE")"
  printf '%s\n' "$TARGET" > "$work/$VERSION_RESOURCE"
  ( cd "$work" && "$JAR" uf "$jar" "$VERSION_RESOURCE" )
  rm -rf "$work"
  log "patched $(basename "$jar"): $VERSION_RESOURCE ${cur:-<empty>} -> $TARGET  (SpiVersionHolder.SPI_COMPILE_TIME_VERSION)"
}

log "adopting plugin at $PLUGIN to server version: $TARGET"
for i in "${!CONNECTOR_JARS[@]}"; do
  stamp_one "${CONNECTOR_JARS[$i]}" "${CONNECTOR_CUR[$i]}"
done
patch_version_resource

# ---- GATE 2: prove it links (only if we have the server jars) -----------------------------------------------
if [[ -n "$SERVER_LIB" && $NO_VERIFY == 0 ]]; then
  if [[ -x "$PROBE" ]]; then
    log "verifying ABI linkage against $SERVER_LIB (spi-linkage-check.sh) ..."
    if "$PROBE" --plugin "$PLUGIN" --server-lib "$SERVER_LIB"; then
      log "ADOPT OK: version stamped to $TARGET AND the plugin links against this server."
      exit 0
    else
      printf 'ERROR: version was stamped to %s, but the plugin does NOT link against %s.\n' "$TARGET" "$SERVER_LIB" >&2
      printf '       Do NOT start Trino with this plugin. The stamp is left in place (use --restore to revert).\n' >&2
      exit 1
    fi
  else
    log "WARNING: probe not found/executable at $PROBE — stamped only (GATE 1). Run spi-linkage-check.sh to prove linkage."
  fi
else
  log "stamped only (GATE 1). Pass --server-lib to also prove ABI linkage (GATE 2), or run spi-linkage-check.sh."
fi
log "done."
