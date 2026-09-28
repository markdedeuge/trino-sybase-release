#!/usr/bin/env bash
# spi-linkage-check.sh — prove a shipped Sybase connector plugin will LINK against a given Trino/SEP runtime.
#
# WHY THIS EXISTS
#   The connector zips are compiled against community Trino (io.trino:*:480 / :483 on Maven Central). A
#   Starburst Enterprise (SEP) server reports a different SPI version string (e.g. 480-e.2.89) and refuses
#   the plugin on an exact-match guard. If you force the plugin to load anyway (stamp its version), the only
#   remaining risk is ABI drift: SEP may have added/removed/re-signatured something on the engine-provided
#   SPI surface, which would blow up at runtime with NoSuchMethodError / NoSuchFieldError / AbstractMethodError.
#   This script checks for exactly that, with no source and no build — just the shipped plugin jars and the
#   target server's jars. Green = it will LINK. (It does NOT prove behaviour is identical — see LIMITS below.)
#
# WHAT IT CHECKS
#   1. class    — every engine-provided class the plugin references exists in the server.
#   2. forward  — every SPI method/field the plugin CALLS exists in the server (declared or inherited),
#                 with the exact bytecode descriptor. A miss here is a WARNING, not a failure: it only errors
#                 if the connector invokes that call site (most are evolved/unused SPI signatures).
#   3. reverse  — every ABSTRACT SPI method the server DECLARES on a type the plugin implements has a
#                 concrete override in the plugin. Catches AbstractMethodError from SEP-ADDED abstract methods
#                 (a call-site scan alone misses these, because the plugin never references them).
#
# THE BOUNDARY IT POLICES
#   Only the packages the Trino PluginClassLoader delegates to the server (the "SPI packages") can drift under
#   SEP. Everything else in the zip (base-jdbc, plugin-toolkit, guava, jackson-databind, jTDS, ...) is bundled
#   and self-consistent. The delegated set is the SPI_PREFIXES list below — it is exactly the set of io.trino
#   / airlift / otel / jackson jars that are NOT present in the plugin dir.
#
# REQUIREMENTS
#   bash 4+ (4.3+ for --jobs parallelism), and the JDK tools `javap` + `jar` (already on every Trino/SEP node).
#
# USAGE
#   spi-linkage-check.sh --plugin <plugin-dir-or-zip> --server-lib <trino/SEP lib dir> [options]
#
#   --plugin PATH        The shipped connector: the unzipped plugin directory (contains trino-sybase-<v>.jar +
#                        its bundled jars) OR the trino-sybase-<v>.zip. Defaults to the current directory, so
#                        you can cd into the deployed plugin dir and omit it. Run once per driver (ASE and IQ
#                        are separate zips).
#   --server-lib PATH    A directory holding the TARGET server's jars — the SEP/Trino install `lib/` dir, which
#                        contains trino-spi-<ver>.jar, slice, jackson-annotations, etc. Repeatable.
#   --scan-all           Scan every bundled jar for SPI references (default: only the trino-*.jar that actually
#                        call the SPI — the connector + base-jdbc + toolkit + cache + matching + base).
#   --forward-only       Skip the reverse (added-abstract-method) phase.
#   --jobs N             Fan the forward/reverse checks across N parallel workers (default: nproc). This is the
#                        main speed lever — the phases are ~linear in cores (10x on 16 cores). Needs bash 4.3+
#                        (older shells fall back to serial).
#   --count-only         Print the plugin's SPI footprint ("members=N / classes=M") and exit; no --server-lib
#                        needed. Used to generate the bundled bin/spi-refs.expected fingerprint.
#   --expect-members N   Loudly WARN (but keep going — never fails the run) if the scanned SPI-member / class
#   --expect-classes M   counts differ from N / M — catches a stale or partial deploy (older jars present). If
#                        unset, a bundled bin/spi-refs.expected (next to this script) is used automatically;
#                        absent that, the footprint check is skipped.
#   --java-home DIR      Use DIR/bin/javap and DIR/bin/jar (default: from PATH, else $JAVA_HOME).
#   -v, --verbose        Print progress.
#   -h, --help           This help.
#
# EXIT: 0 = links (missing MEMBERS only WARN); 1 = missing CLASS or unimplemented ABSTRACT; 2 = bad invocation.
#       A footprint mismatch also only WARNS, never fails.
#
# LIMITS (read before trusting a green run)
#   * Linkage != behaviour. A method with the same signature but changed semantics passes here and can still be
#     wrong at runtime. Real integration tests against the target server remain the only proof of behaviour.
#   * Members the connector reaches by reflection (not by a typed bytecode reference) are not seen. The Sybase
#     connectors only reflect into their OWN / bundled classes (jConnect, SybaseIqPlugin), not the SPI, so this
#     is not a gap in practice.
#   * Descriptor matching is on erased JVM descriptors; exotic covariant-return/bridge cases could produce a
#     false "missing". Treat any hit as "review this", verified against the reported class.
set -euo pipefail

# --- the engine-provided (PluginClassLoader parent-delegated) packages, in bytecode internal form ('/'). ----
# This is Trino's SPI_PACKAGES set. Keep it in step with the server you target; these are precisely the jars
# that are NOT bundled in the plugin dir (trino-spi, slice, jol, otel api/context, jackson-annotations).
SPI_PREFIXES=(
  io/trino/spi/
  io/airlift/slice/
  org/openjdk/jol/
  io/opentelemetry/api/
  io/opentelemetry/context/
  com/fasterxml/jackson/annotation/
)

PLUGIN=""
SERVER_LIBS=()
SCAN_ALL=0
FORWARD_ONLY=0
JAVA_HOME_OPT=""
VERBOSE=0
COUNT_ONLY=0
EXPECT_MEMBERS=""
EXPECT_CLASSES=""
JOBS=""
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '>> %s\n' "$*" >&2; }
vlog() { [[ $VERBOSE == 1 ]] && printf '   %s\n' "$*" >&2 || true; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }
warn() { printf '%s\n' "$*" >&2; }
die()  { err "$*"; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin)       PLUGIN="${2:?}"; shift 2;;
    --server-lib)   SERVER_LIBS+=("${2:?}"); shift 2;;
    --scan-all)     SCAN_ALL=1; shift;;
    --forward-only) FORWARD_ONLY=1; shift;;
    --count-only)     COUNT_ONLY=1; shift;;
    --expect-members) EXPECT_MEMBERS="${2:?}"; shift 2;;
    --expect-classes) EXPECT_CLASSES="${2:?}"; shift 2;;
    --jobs)         JOBS="${2:?}"; shift 2;;
    --java-home)    JAVA_HOME_OPT="${2:?}"; shift 2;;
    -v|--verbose)   VERBOSE=1; shift;;
    -h|--help)      sed -n '2,66p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *)              die "unknown argument: $1 (use --help)";;
  esac
done

# --- locate javap / jar --------------------------------------------------------------------------------------
if [[ -n "$JAVA_HOME_OPT" ]]; then
  JAVAP="$JAVA_HOME_OPT/bin/javap"; JAR="$JAVA_HOME_OPT/bin/jar"
elif command -v javap >/dev/null 2>&1; then
  JAVAP="$(command -v javap)"; JAR="$(command -v jar)"
elif [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/javap" ]]; then
  JAVAP="$JAVA_HOME/bin/javap"; JAR="$JAVA_HOME/bin/jar"
else
  die "javap not found. Point --java-home at a JDK (the Trino/SEP node's bundled JDK works)."
fi
[[ -x "$JAVAP" ]] || die "javap not executable at: $JAVAP"
command -v "$JAR" >/dev/null 2>&1 || [[ -x "$JAR" ]] || die "jar not found next to javap"

# Parallelism: the forward/reverse checks are independent per member/class, so fan them out across cores. `wait -n`
# needs bash 4.3+; older shells fall back to serial. --jobs overrides. This is where most of the wall-clock goes.
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
[[ "$JOBS" =~ ^[0-9]+$ && "$JOBS" -ge 1 ]] || JOBS=4
(( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 403 )) && JOBS=1
# Block until fewer than JOBS background workers are running. Always returns 0 (a bare `while ((..))` returns
# non-zero when it exits, which set -e would treat as a failure).
_throttle() { while (( $(jobs -rp | wc -l) >= JOBS )); do wait -n 2>/dev/null || true; done; return 0; }

# --plugin defaults to the current directory, so you can cd into the deployed plugin dir and run this.
PLUGIN="${PLUGIN:-.}"
[[ $COUNT_ONLY == 1 || ${#SERVER_LIBS[@]} -gt 0 ]] \
  || die "missing --server-lib (the target server's lib dir with trino-spi)"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
CACHE="$WORK/cache"; mkdir -p "$CACHE"

# --- resolve the plugin directory (unzip if a .zip was given) ------------------------------------------------
PLUGIN_DIR="$PLUGIN"
if [[ -f "$PLUGIN" && "$PLUGIN" == *.zip ]]; then
  vlog "unzipping $PLUGIN"
  "$JAR" xf "$PLUGIN" -C "$WORK" 2>/dev/null || { mkdir -p "$WORK/unz" && ( cd "$WORK/unz" && "$JAR" xf "$PLUGIN" ); PLUGIN_DIR="$WORK/unz"; }
  [[ -d "$PLUGIN_DIR" ]] || PLUGIN_DIR="$(dirname "$(find "$WORK" -name '*.jar' | head -1)")"
fi
[[ -d "$PLUGIN_DIR" ]] || die "--plugin is not a directory or .zip: $PLUGIN"
# Absolutise so the javap classpath (built from these jar paths) never depends on the working directory —
# a relative "." plugin dir otherwise yields "./foo.jar" entries that fail with NoSuchFileException.
PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"

mapfile -t PLUGIN_JARS < <(find "$PLUGIN_DIR" -maxdepth 2 -name '*.jar' \
  ! -name '*-sources.jar' ! -name '*-test-sources.jar' ! -name '*-tests.jar' | sort)
[[ ${#PLUGIN_JARS[@]} -gt 0 ]] || die "no jars under --plugin dir: $PLUGIN_DIR"
PLUGIN_CP="$(IFS=:; echo "${PLUGIN_JARS[*]}")"

# scan set: jars whose bytecode actually calls the SPI. Default = the trino-*.jar; --scan-all = everything.
if [[ $SCAN_ALL == 1 ]]; then
  SCAN_JARS=("${PLUGIN_JARS[@]}")
else
  mapfile -t SCAN_JARS < <(printf '%s\n' "${PLUGIN_JARS[@]}" | grep -E '/trino-[^/]*\.jar$' || true)
  [[ ${#SCAN_JARS[@]} -gt 0 ]] || SCAN_JARS=("${PLUGIN_JARS[@]}")
fi

# --- server classpath + a flat index of every class the server provides (skipped for --count-only) -----------
SERVER_CP=""; MERGED_CP=""; PLUGIN_LABEL="?"; SPI_JAR=""
if [[ $COUNT_ONLY == 0 ]]; then
mapfile -t SERVER_JARS < <(for d in "${SERVER_LIBS[@]}"; do find "$d" -name '*.jar'; done | sort -u)
[[ ${#SERVER_JARS[@]} -gt 0 ]] || die "no jars under --server-lib: ${SERVER_LIBS[*]}"
SERVER_CP="$(IFS=:; echo "${SERVER_JARS[*]}")"
# The plugin's ACTUAL runtime classpath = its own bundled jars + the server-provided (SPI-delegated) jars.
# The reverse phase resolves impls against this so a method satisfied by a provided super counts as implemented.
MERGED_CP="$PLUGIN_CP:$SERVER_CP"

log "indexing ${#SERVER_JARS[@]} server jars ..."
: > "$WORK/server_classes.txt"
for j in "${SERVER_JARS[@]}"; do "$JAR" tf "$j"; done \
  | grep -E '\.class$' | grep -v 'module-info' \
  | sed -e 's#\.class$##' -e 's#/#.#g' | sort -u > "$WORK/server_classes.txt"

grep -qxF 'io.trino.spi.Plugin' "$WORK/server_classes.txt" \
  || die "--server-lib has no io.trino.spi.Plugin — this does not look like a Trino/SEP lib dir: ${SERVER_LIBS[*]}"

# Identify the SPI jar by CONTENT — the jar that actually carries io/trino/spi/Plugin.class — not by filename.
# SEP frequently repackages/renames the engine SPI away from trino-spi-*.jar, so a filename match alone leaves
# the label blank even though the jar is right there. Break at the first match (trino-spi is small and early).
for j in "${SERVER_JARS[@]}"; do
  "$JAR" tf "$j" 2>/dev/null | grep -qxF 'io/trino/spi/Plugin.class' && { SPI_JAR="$j"; break; }
done
# Filename fallback only if the content probe was inconclusive (keeps the historic label as a last resort).
[[ -n "$SPI_JAR" ]] || SPI_JAR="$(printf '%s\n' "${SERVER_JARS[@]}" | grep -E '/trino-spi-[^/]*\.jar$' | head -1 || true)"
PLUGIN_LABEL="$(printf '%s\n' "${PLUGIN_JARS[@]}" | grep -oE 'trino-sybase(-iq)?-[0-9][^/]*\.jar' | head -1 || echo '?')"
spi_disp="<no jar carries io/trino/spi/Plugin.class>"
[[ -n "$SPI_JAR" ]] && spi_disp="$(basename "$SPI_JAR")"
log "plugin: ${PLUGIN_LABEL}    server SPI: $spi_disp"
fi

# --- javap helpers (memoised per class+classpath tag) --------------------------------------------------------
# key(): a filesystem-safe cache key for a (tag, class) pair.
key() { printf '%s__%s' "$1" "$(printf '%s' "$2" | tr './$' '___')"; }

# dump <tag> <cp> <class>  -> cached `javap -s -p` text (header + members + descriptors). Empty file if absent.
dump() {
  local tag="$1" cp="$2" cls="$3" f="$CACHE/$(key "$1" "$3").jv"
  # Atomic populate (write a per-worker temp, then rename) so parallel workers never read a half-written cache
  # file. Concurrent workers may redundantly javap the same class before it is cached — harmless (same content).
  if [[ ! -e "$f" ]]; then
    local t="$f.$BASHPID"
    "$JAVAP" -s -p -cp "$cp" "$cls" >"$t" 2>/dev/null || :
    mv -f "$t" "$f" 2>/dev/null || rm -f "$t"
  fi
  cat "$f" 2>/dev/null
}

# strip nested <...> generic groups from a header line.
strip_generics() {
  local s="$1"
  while [[ "$s" == *"<"* ]]; do s="$(printf '%s' "$s" | sed -E 's/<[^<>]*>//g')"; [[ "$s" != *"<"* ]] && break; done
  printf '%s' "$s"
}

# members <tag> <cp> <class>  -> one line per member:  kind<TAB>name<TAB>descriptor
#   kind in {abstract,default,static,concrete}. Descriptor is the erased JVM descriptor (matches bytecode refs).
members() {
  dump "$1" "$2" "$3" | awk '
    function emit(decl, desc,   d,head,nf,a,nm,kind) {
      d=decl
      sub(/[[:space:]]*throws[[:space:]].*/,"",d); sub(/;[[:space:]]*$/,"",d)
      gsub(/<[^>]*>/,"",d)
      kind="concrete"
      if (d ~ /(^|[[:space:]])abstract([[:space:]])/) kind="abstract"
      else if (d ~ /(^|[[:space:]])default([[:space:]])/) kind="default"
      else if (d ~ /(^|[[:space:]])static([[:space:]])/)  kind="static"
      if (index(d,"(")>0) { head=substr(d,1,index(d,"(")-1); nf=split(head,a," "); nm=a[nf]
                            if (index(nm,".")>0) nm="<init>" }
      else { nf=split(d,a," "); nm=a[nf]; sub(/\[\]$/,"",nm) }
      if (nm!="" && nm!="{}") print kind"\t"nm"\t"desc
    }
    /^[[:space:]]*descriptor:[[:space:]]/ {
      desc=$0; sub(/^[[:space:]]*descriptor:[[:space:]]*/,"",desc); if (prev!="") emit(prev,desc); next
    }
    /./ {
      line=$0; sub(/^[[:space:]]+/,"",line); sub(/[[:space:]]+$/,"",line)
      if (line ~ /(^|[[:space:]])(class|interface|enum|@interface)[[:space:]]/) { prev=""; next }
      if (line ~ /^[{}]/) next
      prev=line
    }'
}

# supers <tag> <cp> <class>  -> FQN of every superclass/interface named in the header (excluding the class itself)
supers() {
  local hdr
  hdr="$(dump "$1" "$2" "$3" | grep -E '(^|[[:space:]])(class|interface|enum|@interface)[[:space:]]' | head -1 || true)"
  [[ -n "$hdr" ]] || return 0
  hdr="${hdr%% permits *}"           # a sealed type lists SUBtypes after 'permits' — not supertypes
  hdr="$(strip_generics "$hdr")"
  printf '%s\n' "$hdr" | tr ' ,' '\n\n' | grep -F '.' | grep -vxF "$3" \
    | grep -vE '^(class|interface|enum|extends|implements|permits|abstract|final|public|private|protected|static|sealed|non-sealed)$' || true
}

# member_exists <tag> <cp> <name> <desc> <class>  -> 0 if class or any ancestor declares name+desc.
declare -A _seen
member_exists() {
  local tag="$1" cp="$2" name="$3" desc="$4" start="$5"
  # Seed with java.lang.Object: every reference type (incl. interfaces, whose javap header omits it) can
  # invoke Object's public methods — e.g. equals/hashCode/toString on an SPI interface reference.
  local -a q=("$start" "java.lang.Object"); local c
  local guard=0
  _seen=()
  while [[ ${#q[@]} -gt 0 ]]; do
    c="${q[0]}"; q=("${q[@]:1}")
    [[ -n "${_seen[$c]:-}" ]] && continue
    _seen[$c]=1
    (( ++guard > 200 )) && break
    if members "$tag" "$cp" "$c" | awk -F'\t' -v n="$name" -v d="$desc" '$2==n && $3==d{f=1} END{exit f?0:1}'; then
      return 0
    fi
    local s
    while IFS= read -r s; do [[ -n "$s" ]] && q+=("$s"); done < <(supers "$tag" "$cp" "$c")
  done
  return 1
}

# =============================================================================================================
# PHASE 1+2 — class existence + forward member references
# =============================================================================================================
log "extracting SPI references from ${#SCAN_JARS[@]} bundled jar(s) ..."

# List every scanned class name, then dump their constant pools in batches (amortise javap JVM startup).
: > "$WORK/scan_classes.txt"
for j in "${SCAN_JARS[@]}"; do "$JAR" tf "$j"; done \
  | grep -E '\.class$' | grep -v 'module-info' \
  | sed -e 's#\.class$##' -e 's#/#.#g' | sort -u > "$WORK/scan_classes.txt"
vlog "$(wc -l < "$WORK/scan_classes.txt") plugin classes to scan"

: > "$WORK/pool.txt"
# xargs feeds class names from the file (no shell $-expansion of inner-class '$'); -n batches per javap call.
xargs -n 400 "$JAVAP" -v -p -cp "$PLUGIN_CP" < "$WORK/scan_classes.txt" >> "$WORK/pool.txt" 2>/dev/null || true

# Build a grep alternation of the SPI prefixes, then pull constant-pool refs whose owner is engine-provided.
PREFIX_RE="$(IFS='|'; echo "${SPI_PREFIXES[*]}")"

# method + field refs -> "owner<TAB>name<TAB>desc"  (internal '/' form)
grep -E '=[[:space:]]*(Methodref|InterfaceMethodref|Fieldref)' "$WORK/pool.txt" \
  | sed -E 's#.*// ##' \
  | grep -E "^($PREFIX_RE)" \
  | awk -F'.' '{ owner=$1; rest=substr($0, length(owner)+2);
                 c=index(rest,":"); name=substr(rest,1,c-1); desc=substr(rest,c+1);
                 gsub(/"/,"",name); gsub(/"/,"",owner);   # special names print quoted, e.g. "<init>"
                 print owner"\t"name"\t"desc }' \
  | sort -u > "$WORK/refs_members.txt" || true

# type refs (new / checkcast / instanceof / class literals) + the owners of the member refs -> class set
{
  grep -E '=[[:space:]]*Class' "$WORK/pool.txt" | sed -E 's#.*// ##' \
    | sed -E 's#^"?\[+L?##; s#;?"?$##' | grep -E "^($PREFIX_RE)" || true
  cut -f1 "$WORK/refs_members.txt"
} | sort -u > "$WORK/refs_classes.txt"

# --- SPI-footprint self-check: the deployed jars must match the build these scripts shipped with --------------
MEMBERS_FOUND="$(grep -c . "$WORK/refs_members.txt" 2>/dev/null || true)"
CLASSES_FOUND="$(grep -c . "$WORK/refs_classes.txt" 2>/dev/null || true)"

# --count-only just emits the fingerprint (used to generate the bundled spi-refs.expected). No server needed.
if [[ $COUNT_ONLY == 1 ]]; then
  printf 'members=%s\nclasses=%s\n' "$MEMBERS_FOUND" "$CLASSES_FOUND"
  exit 0
fi

# Expected counts: --expect-* flags win; else a bundled spi-refs.expected next to this script (members=/classes=).
FOOTPRINT_WARN=0
EXPECTED_SRC=""
if [[ -z "$EXPECT_MEMBERS$EXPECT_CLASSES" && -f "$SELF_DIR/spi-refs.expected" ]]; then
  EXPECT_MEMBERS="$(sed -nE 's/^members=([0-9]+).*/\1/p' "$SELF_DIR/spi-refs.expected" | head -1)"
  EXPECT_CLASSES="$(sed -nE 's/^classes=([0-9]+).*/\1/p' "$SELF_DIR/spi-refs.expected" | head -1)"
  EXPECTED_SRC=" (from bin/spi-refs.expected)"
fi
if { [[ -n "$EXPECT_MEMBERS" ]] && [[ "$EXPECT_MEMBERS" != "$MEMBERS_FOUND" ]]; } \
   || { [[ -n "$EXPECT_CLASSES" ]] && [[ "$EXPECT_CLASSES" != "$CLASSES_FOUND" ]]; }; then
  FOOTPRINT_WARN=1
  # Loud WARNING only — the check still runs (the operator decides). It does NOT fail the run.
  warn ""
  warn "############################################################################################"
  warn "## WARNING: SPI footprint mismatch — the plugin dir is NOT the build these scripts shipped"
  warn "##          with${EXPECTED_SRC}."
  warn "##   scanned : ${MEMBERS_FOUND} members, ${CLASSES_FOUND} classes"
  warn "##   expected: ${EXPECT_MEMBERS:-<any>} members, ${EXPECT_CLASSES:-<any>} classes"
  warn "##   A LOWER count almost always means OLDER (or partially-copied) connector jars are sitting in"
  warn "##   the plugin dir instead of the ones from this release — so the results below may be for the"
  warn "##   WRONG jars. Wipe the plugin dir and re-unzip the matching release before trusting this run:"
  warn "##     rm -rf '${PLUGIN_DIR}'/* && unzip trino-sybase[-iq]-<ver>.zip -d '$(dirname "$PLUGIN_DIR")'/"
  warn "############################################################################################"
  warn ""
fi

# --- 1. class existence ---
: > "$WORK/miss_classes.txt"
while IFS= read -r ic; do
  [[ -z "$ic" ]] && continue
  dc="${ic//\//.}"
  grep -qxF "$dc" "$WORK/server_classes.txt" || echo "$dc" >> "$WORK/miss_classes.txt"
done < "$WORK/refs_classes.txt"

# --- 2. forward members (skip any whose owning class is already reported missing) ---
: > "$WORK/miss_members.txt"
# One member reference: does the server declare it (in the class or an ancestor)? Appends a miss line if not.
# Short appends (<PIPE_BUF) to miss_members.txt are atomic, so parallel workers do not corrupt it.
forward_one() {
  local owner="$1" name="$2" desc="$3" dc="${1//\//.}"
  grep -qxF "$dc" "$WORK/miss_classes.txt" && return 0
  member_exists SRV "$SERVER_CP" "$name" "$desc" "$dc" \
    || printf '%s\t%s\t%s\n' "$dc" "$name" "$desc" >> "$WORK/miss_members.txt"
}
mtot=$(grep -c . "$WORK/refs_members.txt" 2>/dev/null || true); mi=0
log "forward: resolving ${mtot} SPI member reference(s) against the server across ${JOBS} worker(s) ..."
while IFS=$'\t' read -r owner name desc; do
  [[ -z "$owner" ]] && continue
  mi=$((mi + 1)); (( mi % 200 == 0 )) && log "  forward: ${mi}/${mtot} members dispatched"
  if (( JOBS > 1 )); then forward_one "$owner" "$name" "$desc" & _throttle
  else forward_one "$owner" "$name" "$desc"; fi
done < "$WORK/refs_members.txt"
if (( JOBS > 1 )); then wait; fi
log "forward: done ($(grep -c . "$WORK/miss_members.txt" 2>/dev/null || true) missing)"

# =============================================================================================================
# PHASE 3 — reverse: server-added abstract methods the plugin does not implement
# =============================================================================================================
: > "$WORK/miss_abstract.txt"
if [[ $FORWARD_ONLY == 0 ]]; then
  rtot=$(grep -c . "$WORK/scan_classes.txt" 2>/dev/null || true); ri=0
  log "reverse: scanning ${rtot} plugin class(es) for server-added abstract methods (the slow phase) ..."

  # A base ConnectorFactory that a bundled subclass EXTENDS is never the factory the plugin registers (a Trino
  # Plugin returns the leaf subclass from getConnectorFactories(); the leaf is scanned on its own). Collect every
  # scanned class that another scanned class extends, so reverse_one can skip such a superseded base when it is a
  # ConnectorFactory — otherwise the bundled community io.trino.plugin.jdbc.JdbcConnectorFactory is falsely flagged
  # "must implement <SEP-added abstract>" even though the Sybase subclass shipped beside it implements it.
  declare -A SUPERSEDED=()
  while IFS= read -r sc; do
    [[ -z "$sc" ]] && continue
    while IFS= read -r sup; do
      [[ -z "$sup" ]] && continue
      if grep -qxF "$sup" "$WORK/scan_classes.txt"; then SUPERSEDED["$sup"]=1; fi
    done < <(supers PLG "$PLUGIN_CP" "$sc")
  done < "$WORK/scan_classes.txt"
  vlog "reverse: ${#SUPERSEDED[@]} scanned class(es) superseded by a bundled subclass"

  # One plugin class: does the server declare an abstract SPI method that NOTHING in this class's runtime
  # hierarchy implements? Appends "pc<TAB>name<TAB>desc" per such method. All state is local and the scratch
  # files are per-worker ($BASHPID), so it is parallel-safe; short appends to miss_abstract.txt are atomic.
  reverse_one() {
    local pc="$1" c="" s="" p="" ic="" n="" d="" g1=0 gf=0 req="" impl=""
    local -A seen1=() full=()
    local -a q=("$pc") spi_supers=() fq=()
    # skip abstract plugin classes — the server never instantiates them as the connector impl
    dump PLG "$PLUGIN_CP" "$pc" | grep -E '(^|[[:space:]])(class|interface|enum)[[:space:]]' | head -1 \
      | grep -qE '(^|[[:space:]])(abstract|interface)[[:space:]]' && return 0

    # (fast) SPI-package ancestors reachable through the PLUGIN-SIDE chain — the risk-relevant ones (a bundled or
    # plugin class that itself implements an SPI type). Reaching an SPI type only via a provided class is not a risk.
    while [[ ${#q[@]} -gt 0 ]]; do
      c="${q[0]}"; q=("${q[@]:1}")
      [[ -n "${seen1[$c]:-}" ]] && continue; seen1[$c]=1
      (( ++g1 > 300 )) && break
      while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        ic="${s//./\/}/"
        for p in "${SPI_PREFIXES[@]}"; do [[ "$ic" == "$p"* ]] && spi_supers+=("$s") && break; done
        q+=("$s")
      done < <(supers PLG "$PLUGIN_CP" "$c")
    done
    [[ ${#spi_supers[@]} -eq 0 ]] && return 0

    # Skip a superseded base ConnectorFactory — a bundled subclass overrides it and IS the registered factory, and
    # that subclass is checked in its own right. Only ConnectorFactory bases are dropped (the single-registered-
    # factory model); every other superseded class stays in scope.
    if [[ -n "${SUPERSEDED[$pc]:-}" ]] && printf '%s\n' "${spi_supers[@]}" | grep -qxF 'io.trino.spi.connector.ConnectorFactory'; then
      vlog "reverse: skip superseded base ConnectorFactory $pc"
      return 0
    fi

    req="$WORK/req.$BASHPID"; impl="$WORK/impl.$BASHPID"
    # required = all abstract methods (transitive) the SERVER declares on those SPI ancestors
    printf '%s\n' "${spi_supers[@]}" | sort -u | while IFS= read -r t; do
      local -A tseen=(); local -a tq=("$t"); local tg=0 tc="" ss=""
      while [[ ${#tq[@]} -gt 0 ]]; do
        tc="${tq[0]}"; tq=("${tq[@]:1}")
        [[ -n "${tseen[$tc]:-}" ]] && continue; tseen[$tc]=1
        (( ++tg > 300 )) && break
        members SRV "$SERVER_CP" "$tc" | awk -F'\t' '$1=="abstract"{print $2"\t"$3}'
        while IFS= read -r ss; do [[ -n "$ss" ]] && tq+=("$ss"); done < <(supers SRV "$SERVER_CP" "$tc")
      done
    done | sort -u > "$req"

    # implemented = concrete/default/static methods across pc's FULL RUNTIME hierarchy (merged classpath). KEY FIX:
    # an abstract satisfied by a PROVIDED concrete/default super (slice.SliceOutput, SPI Abstract* bases) counts.
    fq=("$pc")
    while [[ ${#fq[@]} -gt 0 ]]; do
      c="${fq[0]}"; fq=("${fq[@]:1}")
      [[ -n "${full[$c]:-}" ]] && continue; full[$c]=1
      (( ++gf > 300 )) && break
      while IFS= read -r s; do [[ -n "$s" ]] && fq+=("$s"); done < <(supers ALL "$MERGED_CP" "$c")
    done
    for c in "${!full[@]}"; do
      members ALL "$MERGED_CP" "$c" | awk -F'\t' '$1!="abstract"{print $2"\t"$3}'
    done | sort -u > "$impl"

    # any SERVER-declared abstract not implemented anywhere in pc's runtime hierarchy -> AbstractMethodError risk
    comm -23 "$req" "$impl" | while IFS=$'\t' read -r n d; do
      [[ -z "$n" ]] && continue
      printf '%s\t%s\t%s\n' "$pc" "$n" "$d" >> "$WORK/miss_abstract.txt"
    done
    rm -f "$req" "$impl"
  }

  while IFS= read -r pc; do
    [[ -z "$pc" ]] && continue
    ri=$((ri + 1)); (( ri % 200 == 0 )) && log "  reverse: ${ri}/${rtot} classes dispatched"
    if (( JOBS > 1 )); then reverse_one "$pc" & _throttle
    else reverse_one "$pc"; fi
  done < "$WORK/scan_classes.txt"
  if (( JOBS > 1 )); then wait; fi
  log "reverse: done ($(grep -c . "$WORK/miss_abstract.txt" 2>/dev/null || true) unimplemented)"
fi

# =============================================================================================================
# REPORT
# =============================================================================================================
# grep -c prints "0" AND exits 1 on an empty file; `|| true` keeps the single "0" and swallows the exit.
nc=$(grep -c . "$WORK/miss_classes.txt"  2>/dev/null || true)
nm=$(grep -c . "$WORK/miss_members.txt"  2>/dev/null || true)
na=$(grep -c . "$WORK/miss_abstract.txt" 2>/dev/null || true)

echo
echo "================ SPI linkage report ================"
echo "plugin        : $PLUGIN_LABEL   ($PLUGIN_DIR)"
echo "target server : ${SPI_JAR:-${SERVER_LIBS[*]}}"
echo "SPI refs found: ${MEMBERS_FOUND} members, ${CLASSES_FOUND} classes"
[[ $FOOTPRINT_WARN == 1 ]] && echo "!! FOOTPRINT WARNING: counts != expected (${EXPECT_MEMBERS:-?}/${EXPECT_CLASSES:-?}) — likely OLD/partial jars in the plugin dir; results below may be for the WRONG build."
echo

if [[ "$nc" -gt 0 ]]; then
  echo "MISSING CLASSES ($nc) — the server has no such engine class (package move / removal):"
  sed 's/^/  - /' "$WORK/miss_classes.txt"; echo
fi
if [[ "$nm" -gt 0 ]]; then
  echo "MISSING-MEMBER WARNINGS ($nm) — a bundled call site references an SPI member the server lacks, usually an"
  echo "                    SPI method whose SIGNATURE EVOLVED across versions (e.g. a ClassLoaderSafe* delegating"
  echo "                    wrapper, or an unused optional feature like materialized-view refresh). This is a"
  echo "                    NoSuchMethod/FieldError ONLY IF that exact call site executes — review each. It does"
  echo "                    NOT fail the run (a missing CLASS or unimplemented ABSTRACT does):"
  awk -F'\t' '{printf "  - %s#%s %s\n",$1,$2,$3}' "$WORK/miss_members.txt"; echo
fi
if [[ "$na" -gt 0 ]]; then
  echo "UNIMPLEMENTED ABSTRACTS ($na) — the server DECLARES these abstract; the plugin does not override"
  echo "                        them (AbstractMethodError when the engine calls them):"
  awk -F'\t' '{printf "  - %s must implement %s %s\n",$1,$2,$3}' "$WORK/miss_abstract.txt"; echo
fi

# FAIL only on the always-fatal findings: a missing CLASS (the engine class is gone) or an unimplemented ABSTRACT
# (the engine declares it abstract and WILL call it -> AbstractMethodError). A missing MEMBER is a warning: it
# only errors if the connector invokes that specific call site, and most are evolved/unused SPI signatures.
if [[ "$nc" -eq 0 && "$na" -eq 0 ]]; then
  if [[ "$nm" -eq 0 ]]; then
    echo "RESULT: PASS — every referenced SPI class/member resolves and every required abstract is implemented."
    echo "        The plugin will LINK against this server. (This does not prove behaviour — run real tests.)"
  else
    echo "RESULT: PASS (with $nm missing-member warning(s) to review) — no missing classes, no unimplemented"
    echo "        abstracts. The warnings above are evolved/unreachable SPI call sites; confirm the connector"
    echo "        never invokes them. (This does not prove behaviour — run real tests.)"
  fi
  echo "===================================================="
  exit 0
fi
echo "RESULT: FAIL — $nc missing classes, $na unimplemented abstracts ($nm missing-member warning(s), see above)."
echo "        Do NOT ship into this server; missing classes / unimplemented abstracts will fail at runtime."
echo "===================================================="
exit 1
