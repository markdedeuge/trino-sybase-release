# Advanced usage — result-rule modes and the `system.query` pass-through

This page covers the opt-in features that go beyond the connector's default pushdown:

- **Result-rule modes (D / E / F)** — choosing between Trino's byte-exact string rules and SAP IQ's own
  (case-, blank- and collation-insensitive) rules for pushed char/varchar joins, `GROUP BY` and filters.
- **`system.query`** — sending a whole SQL statement straight to one IQ (or ASE) instance to run verbatim under the
  remote engine's own rules.

For the capability matrix and the collation model behind these, see the connector's pushdown and configuration
reference. All behaviour here is pinned by the connector's char-join live test lane.

## Scope and setup for the examples

- The runnable examples target the reference-workload lab database `iq1256ci` (collation `1256ARA`, `CaseSensitive=Off`,
  `BlankPadding=On` — i.e. a case- and collation-**insensitive** database). This is the case where Trino rules and IQ
  rules diverge, so it is the right database to demonstrate the difference.
- Catalog name: `sybase_iq`. Trino schema: `dba`. Fully-qualified table names are `sybase_iq.dba.<table>`. The bare form
  works when the session already targets that catalog and schema.
- On a byte-identical database (a `CASE RESPECT` / `ISO_BINENG`-class image), IQ rules already equal Trino rules, so the
  D / E / F results all coincide and the modes below make no visible difference.

Catalog properties used by these examples:

```properties
connector.name=sybase_iq
connection-url=jdbc:sybase:Tds:localhost:2638?ServiceName=iq1256ci
connection-user=...
connection-password=...
case-insensitive-name-matching=true
sybase-iq.string-pushdown.enabled=true
sybase-iq.string-pushdown.native-session-allowed=true
join-pushdown.strategy=EAGER
```

The fixture tables the examples use:

| Table | Rows | Key column | Notes |
|---|---|---|---|
| `ci_acct` | 50,000 | `acct_ref varchar(11)` (UNIQUE) | one uppercase spelling per key; `acct_label varchar(38)`, `acct_ref20 varchar(20)` |
| `ci_fact` | 5,000,002 | `acct_ref varchar(11)` (HG index) | 5,000,000 uppercase rows + 2 seeded lowercase rows (`acct0000001`, `acct0000003`) |
| `ci_variant_dim` | 9 | `k varchar(16)` (no index) | case / trailing-blank / collation variants; native distinct = 6, byte-exact distinct = 9 |
| `ci_variant_fact` | 7 | `k varchar(16)` (no index) | joins `ci_variant_dim` byte-exact = 7 rows, native = 13 rows |
| `ci_outer_dim` | 3 | `k varchar(16)` | keys `MATCH`, `DIMONLY`, `CASEONLY` |
| `ci_outer_fact` | 3 | `k varchar(16)` | keys `MATCH`, `FACTONLY`, `caseonly` |

## Part A — result-rule modes (D / E / F)

All three modes need the master switch `sybase-iq.string-pushdown.enabled`, which is **on by default** (mode D). They
differ in how a **pushed** char/varchar join or `GROUP BY` key is compared.

| Mode | Turned on by | Key compare | Results |
|---|---|---|---|
| Off | `sybase-iq.string-pushdown.enabled=false` | not pushed | Trino |
| **D (default)** | `sybase-iq.string-pushdown.enabled=true` (the default) | `CAST(.. AS varbinary(w))` (byte-exact) | Trino |
| **E** | operator lists columns in `sybase-iq.string-pushdown.trusted-native-columns` | raw `=` on listed columns | IQ native on those columns |
| **F** | catalog `sybase-iq.string-pushdown.native-session-allowed=true` **and** a query sets `native_string_joins=true` (or the catalog default `native-session-default=true`) | raw `=` | IQ native where pushed; Trino where not |

- **D** is the default fast path. It gives the same rows as running the query in Trino, and keeps IQ's hash join.
- **E** is per-column and permanent (a catalog config list).
- **F** is per-query and broad (a session property). Precedence per key pair is **F → E → D → decline**.

E and F change results on a case-/collation-insensitive database — by design. Verify a column has no variants before
trusting it (see [Part B → data checks](#data-checks-before-trusting-a-column)).

### The `native_string_joins` session property (mode F)

`native_string_joins` is the IQ connector's one session property. It is a boolean, default `false`, catalog-scoped
(always qualified by the catalog name).

**Prerequisites — the property does nothing unless all three hold** (the connector ANDs them in
`nativeStringJoinsActive`):

1. `sybase-iq.string-pushdown.enabled=true` (catalog)
2. `sybase-iq.string-pushdown.native-session-allowed=true` (catalog)
3. `native_string_joins=true` (per query or session)

…and the join must actually be **pushed** to IQ. Under the default `AUTOMATIC` strategy the cost gate can decline the
push; then the join runs in Trino and you silently get Trino's byte-exact rules. Use `EAGER` to force the push.

**Three equivalent ways to set it:**

```sql
-- 1. Inline, per query (Trino 470+; this repo targets 480 and 483)
WITH SESSION sybase_iq.native_string_joins = true
SELECT count(*) FROM sybase_iq.dba.ci_acct a JOIN sybase_iq.dba.ci_fact h ON a.acct_ref = h.acct_ref;

-- 2. Session-wide
SET SESSION sybase_iq.native_string_joins = true;
SELECT count(*) FROM sybase_iq.dba.ci_acct a JOIN sybase_iq.dba.ci_fact h ON a.acct_ref = h.acct_ref;
RESET SESSION sybase_iq.native_string_joins;

-- 3. Inline, plus force the push in the same clause
WITH SESSION sybase_iq.native_string_joins = true, sybase_iq.join_pushdown_strategy = 'EAGER'
SELECT count(*) FROM sybase_iq.dba.ci_acct a JOIN sybase_iq.dba.ci_fact h ON a.acct_ref = h.acct_ref;
```

The value must be the boolean literal `true`/`false`. The catalog qualifier (`sybase_iq`) is mandatory.

**Catalog default (F for a whole catalog).** To make IQ rules the default without a per-query property, set
`sybase-iq.string-pushdown.native-session-default=true` (it requires `native-session-allowed=true` and `enabled=true`, and
fails startup otherwise). A common shape is two catalogs over one server — a plain `sybase_iq` (mode D) and a
`sybase_iq_native` that defaults to F — with the catalog name selecting the rules; a query opts back out with
`WITH SESSION sybase_iq_native.native_string_joins = false`.

**What F changes, and what it does not:**

- Renders raw (IQ-native `=`): char/varchar **join keys**, **`GROUP BY`** keys, **`count(DISTINCT)`** inputs, and (join3)
  char/varchar **filters** — `=` / `IN`, and, when the catalog's dynamic filtering is off, ranges, `<>` and `LIKE`.
- A range / `<>` / `LIKE` filter pushes with IQ's own order only when `dynamic_filtering_enabled` is **off** for the
  catalog (`SET SESSION sybase_iq.dynamic_filtering_enabled = false`): IQ's range order differs from Trino's, and the
  connector cannot tell a user range from a dynamic-filter range, so it keeps every range in Trino while dynamic filtering
  is on. Discrete `=` / `IN` filters and joins are safe with dynamic filtering on (IQ `=` only ever adds rows).
- A `LIKE` pattern containing `[` always stays in Trino (IQ treats `[…]` as a character class; Trino does not).
- Unchanged (still byte-exact / Trino's rules): `ORDER BY … LIMIT` (TopN) and `lower()`.

**Worked examples (numbers are from the live lane):**

```sql
-- Inner equi-join. ci_fact has 2 lowercase variant rows of ci_acct keys.
-- native (F): IQ CASE IGNORE folds the 2 lowercase into their uppercase keys
WITH SESSION sybase_iq.native_string_joins = true
SELECT count(*) FROM sybase_iq.dba.ci_acct a JOIN sybase_iq.dba.ci_fact h ON a.acct_ref = h.acct_ref;   -- => 5,000,002

-- default (no property): byte-exact, the 2 lowercase rows do not match
SELECT count(*) FROM sybase_iq.dba.ci_acct a JOIN sybase_iq.dba.ci_fact h ON a.acct_ref = h.acct_ref;   -- => 5,000,000
```

```sql
-- FULL OUTER join. ci_outer_fact 'caseonly' vs ci_outer_dim 'CASEONLY'.
WITH SESSION sybase_iq.native_string_joins = true
SELECT count(*) FROM sybase_iq.dba.ci_outer_fact f FULL OUTER JOIN sybase_iq.dba.ci_outer_dim d ON f.k = d.k;  -- => 4

SELECT count(*) FROM sybase_iq.dba.ci_outer_fact f FULL OUTER JOIN sybase_iq.dba.ci_outer_dim d ON f.k = d.k;  -- => 5
-- (INNER JOIN variant of the same tables: native 2 vs byte-exact 1)
```

```sql
-- GROUP BY key is folded under F
WITH SESSION sybase_iq.native_string_joins = true
SELECT d.label, count(f.v)
FROM sybase_iq.dba.ci_outer_fact f LEFT JOIN sybase_iq.dba.ci_outer_dim d ON f.k = d.k
GROUP BY d.label;

-- count(DISTINCT) is folded under F
WITH SESSION sybase_iq.native_string_joins = true
SELECT count(DISTINCT k) FROM sybase_iq.dba.ci_variant_dim;   -- native => 6   (byte-exact => 9)
```

```sql
-- A join the AUTOMATIC cost gate declines (ci_variant_* have no index -> no NDV).
-- Force the push with EAGER, or nothing pushes and you get Trino rules.
WITH SESSION sybase_iq.native_string_joins = true, sybase_iq.join_pushdown_strategy = 'EAGER'
SELECT count(*) FROM sybase_iq.dba.ci_variant_dim d JOIN sybase_iq.dba.ci_variant_fact f ON d.k = f.k;
```

**The plan-dependence hazard.** F applies IQ's rules only to the parts IQ actually runs. If the join stays in Trino
(join pushdown off, the cost gate declined, or a cross-catalog reference), you get Trino's byte-exact result even with
the property on. For example, with `join_pushdown_enabled=false` the inner-join example above returns 5,000,000, not
5,000,002. To get IQ rules end-to-end, either force the push with `EAGER`, or use `system.query` (Part B).

## Part B — `system.query` full pass-through

`system.query` is the base-jdbc native-query table function, bound for both connectors (`sybase_iq.system.query` and
`sybase.system.query`). Binding it is what enables `SUPPORTS_NATIVE_QUERY`.

- Trino sends the SQL text **verbatim** to that one instance and runs it there.
- It runs under the **remote engine's own semantics** — on `iq1256ci` (case-insensitive) a join inside the text folds
  case, trailing blanks and collation-equal bytes, exactly as running it directly in IQ.
- This is the cleanest way to get the remote engine's behaviour for a whole section: everything inside the text runs on
  IQ, so there is nothing left for Trino to run under different rules (contrast with mode F, which is plan-dependent).

### Basic shape

```sql
-- IQ: the whole join runs on IQ under IQ's rules
SELECT c
FROM TABLE(sybase_iq.system.query(query =>
  'SELECT count(*) AS c FROM DBA.ci_acct a JOIN DBA.ci_fact h ON a.acct_ref = h.acct_ref'));

-- ASE: same table function on the ASE catalog
SELECT id, label
FROM TABLE(sybase.system.query(query =>
  'SELECT id AS id, label AS label FROM dbo.some_table WHERE label LIKE ''A%'''));
```

`query` is the (only) named argument, a single string of remote SQL. Trino describes it, then reads it as
`SELECT <described columns> FROM (<your text>) o`.

### Rules for the SQL text

#### 1. One `SELECT` statement only

The text is wrapped in a derived table, so it must be a single query expression — no `INSERT`/`UPDATE`/`DDL`, no
multiple statements, no trailing semicolon.

```sql
-- OK
'SELECT k AS k FROM DBA.ci_variant_dim'

-- Not OK: two statements
'SELECT 1 AS one; SELECT 2 AS two'
```

#### 2. A unique alias on every output column

An unaliased output **expression** (an aggregate, an arithmetic expression, a function call, a `CASE`) fails with IQ
error **-163**. A bare column reference is fine. Give every computed column an alias, and keep aliases distinct.

```sql
-- Fails (-163): count(*) has no alias
SELECT * FROM TABLE(sybase_iq.system.query(query =>
  'SELECT count(*) FROM DBA.ci_variant_dim'));

-- OK: aliased
SELECT c FROM TABLE(sybase_iq.system.query(query =>
  'SELECT count(*) AS c FROM DBA.ci_variant_dim'));

-- OK: bare column reference needs no alias, but aliasing it is harmless
SELECT k FROM TABLE(sybase_iq.system.query(query =>
  'SELECT k FROM DBA.ci_variant_dim'));
```

#### 3. Owner-qualify table names

The text runs in the remote connection's context, not your Trino schema. Qualify tables with the owner (`DBA.` on IQ,
`dbo.` on ASE), or the remote server cannot resolve them.

```sql
-- OK
'SELECT acct_ref AS acct_ref FROM DBA.ci_acct'

-- Likely fails on the remote side: unqualified
'SELECT acct_ref AS acct_ref FROM ci_acct'
```

#### 4. Double every single quote

The whole text is itself a single-quoted Trino string, so each literal quote inside must be doubled.

```sql
-- WHERE d.label = 'paid-canon' inside the text:
SELECT k FROM TABLE(sybase_iq.system.query(query =>
  'SELECT k AS k FROM DBA.ci_variant_dim d WHERE d.label = ''paid-canon'''));
```

#### 5. Inner `ORDER BY` — tolerated on IQ, rejected on ASE

IQ accepts an `ORDER BY` inside the derived table the PTF builds. ASE rejects a nested `ORDER BY` (Msg 154), so on the
ASE catalog do the ordering in the outer Trino query instead.

```sql
-- OK on IQ (returns all 9 rows)
SELECT k FROM TABLE(sybase_iq.system.query(query =>
  'SELECT k AS k FROM DBA.ci_variant_dim ORDER BY k'));

-- On ASE, order outside instead:
SELECT k FROM TABLE(sybase.system.query(query => 'SELECT k AS k FROM dbo.some_table')) ORDER BY k;
```

#### 6. Type fidelity is approximate

The PTF resolves output types from the described result set, which is coarser than the catalog path:

- `count()` comes back as `integer`, not `bigint`.
- A `CASE` returning string literals comes back as `char(n)`.
- **ASE only:** predicate pushdown is disabled for every temporal and every binary column reached **through** the PTF.
  The PTF path sees only the `java.sql.Types` code, which cannot tell a safe `datetime` from a lossy `bigdatetime`, or a
  safe `varbinary` from a padded `binary`, so it fails safe and pushes nothing for those columns. The IQ PTF path
  inherits the same conservative behaviour. The same column via the ordinary catalog path still pushes.

Cast in the outer Trino query when you need a specific type.

### It runs under the remote engine's rules

This is the point of the pass-through. The same join, folded inside the text, returns IQ's native (case- and
collation-insensitive) count; the connector's own byte-exact push of the same join returns fewer rows.

```sql
-- Inside the PTF: IQ native '=' folds the variant battery -> 13 matched rows
SELECT c FROM TABLE(sybase_iq.system.query(query =>
  'SELECT count(*) AS c FROM DBA.ci_variant_fact f JOIN DBA.ci_variant_dim d ON f.k = d.k'));   -- => 13

-- Connector push of the same join: byte-exact -> 7 matched rows
SELECT count(*) FROM sybase_iq.dba.ci_variant_fact f JOIN sybase_iq.dba.ci_variant_dim d ON f.k = d.k;  -- => 7
```

### Anything Trino wraps around it reverts to Trino rules

Only what is **inside** the text runs on IQ. An outer `WHERE`, `GROUP BY`, `DISTINCT`, `ORDER BY`, or a join to another
table runs in Trino, byte-exact. This is why the bijection self-check below returns a byte-exact result even against a
case-insensitive database — its outer `count(DISTINCT)` runs in Trino:

```sql
SELECT count(*), count(DISTINCT c), count_if(length(c) <> 1)
FROM TABLE(sybase_iq.system.query(query =>
  'SELECT CAST(CHAR(row_num) AS VARCHAR(4)) AS c FROM sa_rowgenerator(1,255)'));
-- => 255 / 255 / 0  on a clean single-byte charset
```

So: to get the remote engine's rules for a unit of work, put that whole unit (the join, the aggregation, the label
logic) **inside** the text.

### One instance only, and no cross-catalog references

The pass-through hits a single IQ/ASE server. You cannot reference another catalog's tables inside the text. Federating
across engines still happens in Trino, above the PTF, under Trino rules.

### No stats — put the whole join inside

A PTF relation carries no statistics, so under `AUTOMATIC` a join placed **on top** of a PTF result will not push. Fold
the entire join (and any aggregation you want native) into the text rather than joining the PTF output to a table.

### Data checks before trusting a column

Before relying on IQ-native rules (mode E/F, or a `system.query` fold) for a key, confirm the key has no
case/blank/collation variants — per column, and across every table joined on it. Run these read-only through the PTF:

```sql
-- per column: native distinct must equal byte-exact distinct (w = declared width)
SELECT * FROM TABLE(sybase_iq.system.query(query =>
  'SELECT count(*) AS n, count(DISTINCT acct_ref) AS d_native,
          count(DISTINCT CAST(acct_ref AS varbinary(11))) AS d_bytes FROM DBA.ci_acct'));

-- required across tables: the union's native distinct must equal its byte-exact distinct
SELECT * FROM TABLE(sybase_iq.system.query(query =>
  'SELECT count(DISTINCT acct_ref) AS d_native, count(DISTINCT CAST(acct_ref AS varbinary(11))) AS d_bytes
   FROM (SELECT acct_ref FROM DBA.ci_acct UNION ALL SELECT acct_ref FROM DBA.ci_fact) u'));
```

Equal counts mean native and Trino rules give the same rows today. `ci_acct.acct_ref` returns 50,000 == 50,000 (clean);
`ci_variant_dim.k` returns 6 vs 9 (folds — do not trust); the `ci_acct`/`ci_fact` union returns 50,000 vs 50,002 (the
cross-table check catches variants a per-column check misses). A snapshot check does not stay true if the source can
write new variants later.

### Governance

`system.query` runs arbitrary remote SQL. Restrict it with Trino access control if operators should not have the
ad-hoc escape hatch. Health and OpenAPI-style endpoints are unaffected; this is purely the SQL pass-through.

## Quick reference

| Goal | Use | Results | Notes |
|---|---|---|---|
| Fast char joins, same rows as Trino | Mode D (`string-pushdown.enabled=true`) | Trino byte-exact | default fast path |
| IQ-native rules on specific known-clean columns | Mode E (`trusted-native-columns`) | IQ native (listed columns) | per-column, permanent; verify the column first |
| IQ-native rules for one query where pushed | Mode F (`native_string_joins`) | IQ native where pushed | plan-dependent; force push with `EAGER` |
| Run a whole statement on one instance, IQ rules end-to-end | `system.query` | remote engine's rules (inside the text) | single instance; outer ops revert to Trino rules |

## Related

- [`../README.md`](../README.md) — connector overview, install, and provenance
- [`pushdown-bench-483.md`](pushdown-bench-483.md) — the full per-topology pushdown benchmark matrix
