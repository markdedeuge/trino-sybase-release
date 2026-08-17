# Pushdown benchmark — Trino 483 (warm)

> **Committed snapshot** of the warm pushdown benchmark (Trino 483).

_Generated 2026-08-17 against a federated stack — one ASE 16, two Postgres, one baked 5M SAP IQ. Full IQ matrix, `CASE_SENSITIVE`._

**Reading the timing columns.** Each topology renders its source-rows collapse (`OFF→ON`) beside its warm pushdown-ON
wall-clock as the trimmed **`mean ± std` over 12 runs** (single best + worst dropped). A trailing **`!`** flags a NOISY
cell (`std ≥ 25%` of the mean) — the measurement-contention signature on this shared host; read its **`Min ms`** (the
detail table) as the uncontended floor. In this run the residual `!` cells are the ASE 13–30 s row-store 5M scans
(`sales-star:A2`/`A8`, `complex-join-star:CJ_MIXED` on `T1 ASE`/`T3a`), which the host load perturbed — the pushdown is
correct (source-rows → 1); the wall is ASE engine speed (IQ runs the identical pushed query in ~0.1 s). `abs Δ vs PG`
is `0` on every shape (the two float aggregates aside, within the result tolerance `1e-7`), so the timing measurement never moved a
result.

---

## Source-rows-read cost + warm ON wall-clock per query type × topology

_IQ columns: full-matrix_

| Query type | Class | abs Δ vs PG | T1 ASE | T1 ms | T2 PG | T2 ms | T3 ASE+PG | T3 ms | T3a PG+ASE | T3a ms | T4 PG+PG | T4 ms | T5 IQ | T5 ms | T6 IQ+PG | T6 ms | T7 PG+IQ | T7 ms |
|---|---|--:|---|--:|---|--:|---|--:|---|--:|---|--:|---|--:|---|--:|---|--:|
| sales-star:A1 | star join (2 FULL dims) | 0 | 5.0M→1 | 56 ± 8 | 5.0M→1 | 35 ± 8 | 5.0M→1.3k | 56 ± 3 | 5.0M→1.3k | 45 ± 2 | 5.0M→1.3k | 42 ± 7 | 5.0M→1.3k | 157 ± 13 | 5.0M→1.3k | 92 ± 7 | 5.0M→1.3k | 91 ± 17 |
| sales-star:A2 | agg over join | 0 | 5.0M→1 | 30,324 ± 9,545 ! | 5.0M→1 | 772 ± 20 | 5.0M→5.0M | 26,157 ± 2,270 | 5.0M→5.0M | 1,616 ± 56 | 5.0M→5.0M | 1,622 ± 37 | 5.0M→1 | 144 ± 22 | 5.0M→5.0M | 6,053 ± 1,653 ! | 5.0M→5.0M | 1,611 ± 37 |
| sales-star:A3 | DF int band | 0 | 5.0M→1 | 30 ± 2 | 5.0M→1 | 26 ± 2 | 5.0M→25k | 48 ± 5 | 5.0M→25k | 40 ± 5 | 5.0M→25k | 41 ± 4 | 5.0M→25k | 119 ± 8 | 5.0M→25k | 84 ± 6 | 5.0M→25k | 82 ± 8 |
| sales-star:A4 | DF smallint band | 0 | 5.0M→1 | 33 ± 1 | 5.0M→1 | 30 ± 2 | 5.0M→200k | 1,305 ± 180 | 5.0M→200k | 101 ± 3 | 5.0M→200k | 103 ± 8 | 5.0M→200k | 267 ± 13 | 5.0M→200k | 215 ± 22 | 5.0M→200k | 101 ± 7 |
| sales-star:A5 | DF scattered (region) | 0 | 5.0M→1 | 1,478 ± 115 | 5.0M→1 | 96 ± 2 | 5.0M→5.0M | 1,440 ± 226 | 5.0M→5.0M | 772 ± 27 | 5.0M→5.0M | 774 ± 29 | 5.0M→5.0M | 3,874 ± 41 | 5.0M→5.0M | 3,786 ± 55 | 5.0M→5.0M | 895 ± 24 |
| sales-star:A6 | DF 3-key | 0 | 5.0M→1 | 935 ± 53 | 5.0M→1 | 38 ± 9 | 5.0M→1.2k | 202 ± 10 | 5.0M→1.2k | 99 ± 7 | 5.0M→1.2k | 87 ± 2 | 5.0M→1.2k | 179 ± 11 | 5.0M→1.2k | 126 ± 4 | 5.0M→1.2k | 122 ± 3 |
| sales-star:A7 | DF int (scattered category) | 0 | 5.0M→1 | 803 ± 20 | 5.0M→1 | 51 ± 3 | 5.0M→5.0M | 1,420 ± 503 ! | 5.0M→5.0M | 713 ± 28 | 5.0M→5.0M | 723 ± 25 | 5.0M→5.0M | 3,811 ± 41 | 5.0M→5.0M | 3,770 ± 38 | 5.0M→5.0M | 709 ± 12 |
| sales-star:A8_STDDEV | stddev_pop | 9.7e-13 | 5.0M→1 | 18,054 ± 8,786 ! | 5.0M→5.0M | 903 ± 28 | 5.0M→1 | 14,527 ± 886 | 5.0M→5.0M | 906 ± 46 | 5.0M→5.0M | 871 ± 25 | 5.0M→1 | 75 ± 8 | 5.0M→1 | 72 ± 12 | 5.0M→5.0M | 919 ± 21 |
| sales-star:A8_VAR | var_pop | 5.6e-11 | 5.0M→1 | 14,187 ± 1,165 | 5.0M→5.0M | 915 ± 39 | 5.0M→1 | 16,427 ± 7,057 ! | 5.0M→5.0M | 861 ± 54 | 5.0M→5.0M | 866 ± 21 | 5.0M→1 | 66 ± 6 | 5.0M→1 | 61 ± 3 | 5.0M→5.0M | 922 ± 29 |
| mixed-key-star:B1 | char join (channel) | 0 | 5.0M→1 | 816 ± 7 | 5.0M→1 | 363 ± 2 | 5.0M→2.5M | 860 ± 14 | 5.0M→2.5M | 534 ± 28 | 5.0M→2.5M | 526 ± 12 | 5.0M→2.5M | 2,463 ± 61 | 5.0M→2.5M | 2,444 ± 68 | 5.0M→2.5M | 536 ± 25 |
| mixed-key-star:B2 | FULL + char join | 0 | 5.0M→1 | 40,562 ± 1,173 | 5.0M→1 | 32 ± 1 | 5.0M→13k | 113 ± 8 | 5.0M→13k | 49 ± 5 | 5.0M→13k | 43 ± 2 | 5.0M→13k | 136 ± 11 | 5.0M→13k | 93 ± 14 | 5.0M→13k | 86 ± 4 |
| mixed-key-star:B3 | char join (region) | 0 | 5.0M→1 | 439 ± 3 | 5.0M→1 | 69 ± 1 | 5.0M→1.3M | 469 ± 14 | 5.0M→1.3M | 253 ± 7 | 5.0M→1.3M | 255 ± 6 | 5.0M→1.3M | 1,303 ± 64 | 5.0M→1.3M | 1,272 ± 38 | 5.0M→1.3M | 259 ± 8 |
| snowflake-star:C1 | DF 2-hop chain | 0 | 5.0M→1 | 706 ± 85 | 5.0M→1 | 54 ± 2 | 5.0M→835k | 741 ± 24 | 5.0M→835k | 192 ± 4 | 5.0M→835k | 187 ± 9 | 5.0M→1 | 95 ± 8 | 5.0M→835k | 736 ± 23 | 5.0M→835k | 198 ± 12 |
| snowflake-star:C2 | semi-join DF | 0 | 5.0M→1 | 23 ± 2 | 5.0M→1 | 28 ± 8 | 5.0M→25k | 39 ± 2 | 5.0M→25k | 43 ± 9 | 5.0M→25k | 38 ± 1 | 5.0M→25k | 127 ± 13 | 5.0M→25k | 88 ± 5 | 5.0M→25k | 79 ± 7 |
| snowflake-star:C3 | anti-join | 0 | 5.0M→5.0M | 1,375 ± 17 | 5.0M→5.0M | 720 ± 34 | 5.0M→5.0M | 1,282 ± 21 | 5.0M→5.0M | 726 ± 28 | 5.0M→5.0M | 723 ± 21 | 5.0M→5.0M | 3,775 ± 34 | 5.0M→5.0M | 3,738 ± 37 | 5.0M→5.0M | 782 ± 39 |
| snowflake-star:C4 | count(DISTINCT int) | 0 | 5.0M→1 | 22 ± 1 | 5.0M→1 | 23 ± 1 | 5.0M→25k | 40 ± 2 | 5.0M→25k | 33 ± 2 | 5.0M→25k | 36 ± 1 | 5.0M→25k | 119 ± 17 | 5.0M→25k | 91 ± 7 | 5.0M→25k | 75 ± 4 |
| snowflake-star:C5 | char outrigger join | 0 | 5.1M→1 | 1,368 ± 67 | 5.1M→1 | 104 ± 8 | 5.1M→5.0M | 1,752 ± 332 | 5.1M→5.0M | 829 ± 43 | 5.1M→5.0M | 758 ± 15 | 5.1M→1.3M | 1,313 ± 39 | 5.1M→5.0M | 3,811 ± 54 | 5.1M→5.0M | 882 ± 26 |
| taxonomy-bridge:D1 | bridge fan-out sum | 0 | 55k→1 | 140 ± 3 | 55k→1 | 21 ± 2 | 55k→1 | 21 ± 1 | 55k→1 | 135 ± 4 | 55k→1 | 19 ± 2 | 55k→1 | 55 ± 4 | 55k→1 | 23 ± 2 | 55k→1 | 67 ± 16 |
| taxonomy-bridge:D2 | DISTINCT de-fan | 0 | 55k→1 | 141 ± 9 | 55k→1 | 22 ± 2 | 55k→1 | 24 ± 1 | 55k→1 | 143 ± 7 | 55k→1 | 23 ± 2 | 55k→1 | 57 ± 4 | 55k→1 | 23 ± 2 | 55k→1 | 55 ± 5 |
| taxonomy-bridge:D3 | 3-way co-located join | 0 | 55k→1 | 1,833 ± 173 | 55k→1 | 23 ± 1 | 55k→1 | 21 ± 1 | 55k→1 | 1,900 ± 284 | 55k→1 | 21 ± 2 | 55k→13k | 131 ± 23 | 55k→1 | 22 ± 1 | 55k→13k | 107 ± 6 |
| taxonomy-bridge:D4 | bridge semi-join DF | 0 | 5.0M→1 | 156 ± 3 | 5.0M→1 | 26 ± 1 | 5.0M→100k | 51 ± 7 | 5.0M→100k | 201 ± 90 | 5.0M→100k | 48 ± 1 | 5.0M→100k | 209 ± 19 | 5.0M→100k | 146 ± 6 | 5.0M→100k | 127 ± 18 |
| taxonomy-bridge:D5 | bridge anti-join | 0 | 5.0M→5.0M | 1,362 ± 74 | 5.0M→5.0M | 765 ± 28 | 5.0M→5.0M | 1,209 ± 45 | 5.0M→5.0M | 870 ± 48 | 5.0M→5.0M | 741 ± 22 | 5.0M→5.0M | 3,817 ± 32 | 5.0M→5.0M | 3,755 ± 38 | 5.0M→5.0M | 837 ± 44 |
| orders-ledger:E1 | varchar range | 0 | 100k→100k | 122 ± 3 | 100k→100k | 33 ± 2 | 100k→100k | 32 ± 4 | 100k→100k | 33 ± 1 | 100k→100k | 33 ± 2 | 100k→100k | 165 ± 5 | 100k→100k | 164 ± 25 | 100k→100k | 35 ± 4 |
| orders-ledger:E2 | varchar TopN | 0 | 100k→20 | 1,322 ± 12 | 100k→20 | 25 ± 2 | 100k→20 | 1,327 ± 18 | 100k→20 | 27 ± 5 | 100k→20 | 24 ± 2 | 100k→20 | 46 ± 3 | 100k→20 | 43 ± 4 | 100k→20 | 24 ± 2 |
| orders-ledger:E3 | char GROUP BY (§P4b) | 0 | 50k→50k | 31 ± 3 | 50k→50k | 35 ± 2 | 50k→50k | 28 ± 2 | 50k→50k | 35 ± 2 | 50k→50k | 35 ± 2 | 50k→50k | 113 ± 8 | 50k→50k | 107 ± 9 | 50k→50k | 35 ± 3 |
| orders-ledger:E4 | orders→account DF | 0 | 100k→1 | 177 ± 9 | 100k→1 | 23 ± 1 | 100k→750 | 592 ± 24 | 100k→750 | 31 ± 1 | 100k→750 | 34 ± 1 | 100k→750 | 84 ± 6 | 100k→750 | 60 ± 4 | 100k→750 | 85 ± 16 |
| complex-join-star:CJ_MIXED | mixed equi+inequality join (complex-only) | 0 | 5.1M→1 | 31,621 ± 17,184 ! | 5.1M→1 | 898 ± 31 | 5.1M→1 | 850 ± 29 | 5.1M→1 | 28,634 ± 11,237 ! | 5.1M→1 | 921 ± 29 | 5.1M→1 | 122 ± 6 | 5.1M→1 | 887 ± 24 | 5.1M→1 | 124 ± 12 |
| complex-join-star:CJ_EQUI | plain equi join (parity) | 0 | 5.1M→1 | 1,417 ± 23 | 5.1M→1 | 466 ± 4 | 5.1M→1 | 463 ± 5 | 5.1M→1 | 1,410 ± 21 | 5.1M→1 | 470 ± 4 | 5.1M→1 | 90 ± 4 | 5.1M→1 | 470 ± 4 | 5.1M→1 | 89 ± 5 |
| composite-key-star:CK1 | composite (int,smallint) equi-join fold | 0 | 5.0M→1 | 21 ± 2 | 5.0M→1 | 17 ± 2 | 5.0M→30k | 70 ± 5 | 5.0M→30k | 246 ± 4 | 5.0M→30k | 243 ± 5 | 5.0M→1 | 65 ± 4 | 5.0M→30k | 100 ± 6 | 5.0M→30k | 269 ± 5 |
| composite-key-star:CK2 | composite +date equi-join fold | 0 | 5.0M→1 | 21 ± 1 | 5.0M→1 | 25 ± 1 | 5.0M→13k | 780 ± 19 | 5.0M→13k | 95 ± 3 | 5.0M→13k | 98 ± 3 | 5.0M→1 | 68 ± 2 | 5.0M→13k | 94 ± 7 | 5.0M→13k | 116 ± 6 |
| composite-key-star:CK3 | composite +timestamp: ASE declines / PG folds | 0 | 5.0M→600 | 60 ± 3 | 5.0M→1 | 25 ± 2 | 5.0M→600 | 59 ± 2 | 5.0M→600 | 30 ± 4 | 5.0M→600 | 28 ± 2 | 5.0M→600 | 111 ± 7 | 5.0M→600 | 90 ± 5 | 5.0M→30k | 281 ± 5 |
| agg-expression-star:M1 | sum(int*int): driver1 folds / PG declines | 0 | 100k→1 | 114 ± 3 | 100k→100k | 33 ± 1 | 100k→1 | 120 ± 2 | 100k→100k | 34 ± 1 | 100k→100k | 33 ± 2 | 100k→1 | 42 ± 5 | 100k→1 | 41 ± 5 | 100k→100k | 32 ± 1 |
| agg-expression-star:M2 | sum(decimal*int): ASE+IQ fold (P4 item 24) / PG declines | 0 | 100k→1 | 124 ± 3 | 100k→100k | 35 ± 1 | 100k→1 | 126 ± 2 | 100k→100k | 35 ± 1 | 100k→100k | 38 ± 3 | 100k→1 | 56 ± 4 | 100k→1 | 52 ± 4 | 100k→100k | 36 ± 2 |
| agg-expression-star:M3 | GROUP BY grp_acct + HAVING push | 0 | 100k→10 | 129 ± 2 | 100k→10 | 27 ± 1 | 100k→10 | 132 ± 2 | 100k→10 | 26 ± 1 | 100k→10 | 27 ± 2 | 100k→10 | 45 ± 4 | 100k→10 | 49 ± 7 | 100k→10 | 26 ± 1 |
| agg-expression-star:M4 | grp_acct FK dynamic filter | 0 | 100k→1 | 199 ± 3 | 100k→1 | 22 ± 2 | 100k→5.3k | 629 ± 9 | 100k→5.3k | 32 ± 2 | 100k→5.3k | 35 ± 2 | 100k→5.3k | 97 ± 9 | 100k→5.3k | 63 ± 5 | 100k→5.3k | 73 ± 6 |
| numeric-typekey-star:N1_DEC | decimal(12,2) join key fold | 0 | 100k→1 | 116 ± 9 | 100k→1 | 21 ± 1 | 100k→5.0k | 125 ± 2 | 100k→5.0k | 73 ± 3 | 100k→5.0k | 74 ± 1 | 100k→1 | 55 ± 6 | 100k→5.0k | 57 ± 5 | 100k→5.0k | 101 ± 6 |
| numeric-typekey-star:N2_REAL | real join key fold | 0 | 100k→1 | 114 ± 3 | 100k→1 | 20 ± 2 | 100k→13k | 126 ± 3 | 100k→13k | 35 ± 2 | 100k→13k | 37 ± 4 | 100k→1 | 55 ± 5 | 100k→13k | 62 ± 5 | 100k→13k | 33 ± 1 |
| numeric-typekey-star:N5_DOUBLE | double join key fold | 0 | 100k→1 | 113 ± 2 | 100k→1 | 24 ± 2 | 100k→25k | 127 ± 4 | 100k→25k | 37 ± 2 | 100k→25k | 38 ± 3 | 100k→1 | 56 ± 5 | 100k→25k | 75 ± 5 | 100k→25k | 35 ± 2 |
| numeric-typekey-star:N3_BIT | bit join key (correctness) | 0 | 100k→1 | 113 ± 2 | 100k→1 | 20 ± 2 | 100k→20k | 124 ± 3 | 100k→20k | 33 ± 2 | 100k→20k | 34 ± 2 | 100k→1 | 63 ± 9 | 100k→20k | 66 ± 3 | 100k→20k | 33 ± 3 |
| numeric-typekey-star:N4_LABEL | varchar join key: ASE declines / PG folds | 0 | 100k→25k | 128 ± 4 | 100k→1 | 22 ± 2 | 100k→25k | 127 ± 3 | 100k→25k | 41 ± 2 | 100k→25k | 42 ± 3 | 100k→25k | 109 ± 5 | 100k→25k | 84 ± 4 | 100k→25k | 42 ± 3 |
| text-function-gap:G1 | LIKE: PG pushes / ASE retains | 0 | 25k→25k | 25 ± 3 | 25k→25k | 207 ± 3 | 25k→25k | 22 ± 3 | 25k→25k | 202 ± 4 | 25k→25k | 203 ± 5 | 5.0M→5.0M | 4,829 ± 20 | 5.0M→5.0M | 4,845 ± 18 | 25k→25k | 209 ± 5 |
| text-function-gap:G2 | lower(): declines both | 0 | 5.0M→5.0M | 1,701 ± 14 | 5.0M→5.0M | 789 ± 14 | 5.0M→5.0M | 1,713 ± 14 | 5.0M→5.0M | 781 ± 11 | 5.0M→5.0M | 775 ± 15 | 5.0M→5.0M | 4,855 ± 44 | 5.0M→5.0M | 4,956 ± 42 | 5.0M→5.0M | 788 ± 6 |
| text-function-gap:G3 | substring(): declines both | 0 | 5.0M→5.0M | 1,701 ± 13 | 5.0M→5.0M | 757 ± 10 | 5.0M→5.0M | 1,705 ± 5 | 5.0M→5.0M | 759 ± 8 | 5.0M→5.0M | 764 ± 10 | 5.0M→5.0M | 4,809 ± 18 | 5.0M→5.0M | 4,938 ± 16 | 5.0M→5.0M | 773 ± 11 |
| multikey-semijoin:M1 | 2-column (acct,store) DF | 0 | 5.0M→1 | 19 ± 1 | 5.0M→1 | 17 ± 2 | 5.0M→20k | 99 ± 2 | 5.0M→20k | 34 ± 3 | 5.0M→20k | 31 ± 1 | 5.0M→1 | 57 ± 4 | 5.0M→20k | 85 ± 10 | 5.0M→20k | 60 ± 2 |
| multikey-semijoin:M2 | composite EXISTS | 0 | 5.0M→1 | 23 ± 3 | 5.0M→1 | 17 ± 2 | 5.0M→20k | 100 ± 3 | 5.0M→20k | 34 ± 2 | 5.0M→20k | 34 ± 2 | 5.0M→1 | 62 ± 4 | 5.0M→20k | 89 ± 7 | 5.0M→20k | 65 ± 2 |
| multikey-semijoin:M3 | SemiJoin token (count_if IN) | 0 | 5.0M→5.0M | 1,242 ± 4 | 5.0M→5.0M | 702 ± 9 | 5.0M→5.0M | 1,256 ± 22 | 5.0M→5.0M | 699 ± 14 | 5.0M→5.0M | 700 ± 5 | 5.0M→5.0M | 3,766 ± 37 | 5.0M→5.0M | 3,767 ± 34 | 5.0M→5.0M | 726 ± 9 |
| multikey-semijoin:M4 | composite NOT EXISTS anti | 0 | 5.0M→5.0M | 1,275 ± 26 | 5.0M→5.0M | 1,109 ± 18 | 5.0M→5.0M | 1,277 ± 25 | 5.0M→5.0M | 1,117 ± 24 | 5.0M→5.0M | 1,105 ± 13 | 5.0M→5.0M | 4,274 ± 37 | 5.0M→5.0M | 4,254 ± 28 | 5.0M→5.0M | 1,233 ± 12 |
| distinct-agg-star:DA1 | count(DISTINCT varchar): CS byte-exact fold | 0 | 5.0M→5.0M | 1,722 ± 31 | 5.0M→5.0M | 842 ± 13 | 5.0M→5.0M | 1,709 ± 17 | 5.0M→5.0M | 836 ± 13 | 5.0M→5.0M | 835 ± 11 | 5.0M→5.0M | 4,918 ± 86 | 5.0M→5.0M | 4,897 ± 55 | 5.0M→5.0M | 837 ± 11 |
| distinct-agg-star:DA2 | count(DISTINCT int-expr): ASE folds | 0 | 5.0M→1 | 12,689 ± 118 | 5.0M→5.0M | 875 ± 20 | 5.0M→1 | 12,680 ± 61 | 5.0M→5.0M | 843 ± 16 | 5.0M→5.0M | 870 ± 18 | 5.0M→1 | 73 ± 5 | 5.0M→1 | 69 ± 5 | 5.0M→5.0M | 843 ± 22 |

### Legend

- `abs Δ vs PG` = worst absolute difference between any engine's result and the Postgres (T2) baseline for this query. `0` = bit-exact on every engine; only the two float aggregates (`stddev_pop`/`var_pop`) drift (~1e-11), all within the result tolerance = 1e-7. `MISMATCH` would flag a genuine divergence.
- `<tier> ms` = warm pushdown-ON wall-clock, trimmed `mean ± std` over 12 runs (best+worst dropped). A trailing `!` = NOISY (std >= 25% of the mean, mean > 250 ms): a shared-host stall signature — the mean is unreliable, so read the `Min ms` column (the uncontended floor) in the detail table instead.
- `T1 ASE` = `SYBASE_ONLY`
- `T2 PG` = `POSTGRES_ONLY`
- `T3 ASE+PG` = `SYBASE_POSTGRES`
- `T3a PG+ASE` = `POSTGRES_SYBASE`
- `T4 PG+PG` = `POSTGRES_POSTGRES`
- `T5 IQ` = `SYBASE_IQ_ONLY`
- `T6 IQ+PG` = `SYBASE_IQ_POSTGRES`
- `T7 PG+IQ` = `POSTGRES_SYBASE_IQ`

## Detail — exact rows + warm ON wall-clock (mean ± std, min) + setup (planning) time

`Wall ms ON (mean ± std)` = the warm pushdown-ON wall-clock as the trimmed mean ± sample std-dev over 12 runs (the single best and worst run dropped), so one GC/cold-buffer outlier cannot move it and the spread is visible; a trailing `!` flags a NOISY cell (std >= 25% of the mean, mean > 250 ms — a shared-host stall signature). `Min ms` = the fastest of the 12 runs — the uncontended steady-state floor to read when a cell is flagged `!`. `Wall ms OFF` is a single pushdown-OFF full scan (source-rows only; not the headline). `Setup ms (ON)` = p50 Trino planningTime — warm steady-state planning (analysis+optimization; connector metadata + pushdown negotiation, excludes the scan). Each cell is warmed before measuring. `% of T4 setup` = setup vs the PG+PG (T4) control for the same shape.

| Query type | Topology | Rows OFF | Rows ON | Row × | Wall ms OFF | Wall ms ON (mean ± std) | Min ms | Setup ms (ON) | % of T4 setup |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|
| sales-star:A1 | T1 ASE | 5,000,260 | 1 | 5000260.0 | 1,430 | 56 ± 8 | 47 | 15 | 125% |
| sales-star:A1 | T2 PG | 5,000,260 | 1 | 5000260.0 | 1,080 | 35 ± 8 | 26 | 14 | 117% |
| sales-star:A1 | T3 ASE+PG | 5,000,260 | 1,260 | 3968.5 | 1,270 | 56 ± 3 | 49 | 18 | 150% |
| sales-star:A1 | T3a PG+ASE | 5,000,260 | 1,260 | 3968.5 | 1,110 | 45 ± 2 | 39 | 13 | 108% |
| sales-star:A1 | T4 PG+PG | 5,000,260 | 1,260 | 3968.5 | 1,050 | 42 ± 7 | 35 | 12 | 100% |
| sales-star:A1 | T5 IQ | 5,000,260 | 1,260 | 3968.5 | 4,510 | 157 ± 13 | 141 | 49 | 408% |
| sales-star:A1 | T6 IQ+PG | 5,000,260 | 1,260 | 3968.5 | 4,440 | 92 ± 7 | 82 | 16 | 133% |
| sales-star:A1 | T7 PG+IQ | 5,000,260 | 1,260 | 3968.5 | 1,170 | 91 ± 17 | 70 | 30 | 250% |
| sales-star:A2 | T1 ASE | 5,000,250 | 1 | 5000250.0 | 13,520 | 30,324 ± 9,545 ! | 25,550 | 7 | 175% |
| sales-star:A2 | T2 PG | 5,000,250 | 1 | 5000250.0 | 1,500 | 772 ± 20 | 748 | 9 | 225% |
| sales-star:A2 | T3 ASE+PG | 5,000,250 | 5,000,250 | 1.0 | 17,270 | 26,157 ± 2,270 | 24,300 | 5 | 125% |
| sales-star:A2 | T3a PG+ASE | 5,000,250 | 5,000,250 | 1.0 | 1,490 | 1,616 ± 56 | 1,550 | 4 | 100% |
| sales-star:A2 | T4 PG+PG | 5,000,250 | 5,000,250 | 1.0 | 1,570 | 1,622 ± 37 | 1,570 | 4 | 100% |
| sales-star:A2 | T5 IQ | 5,000,250 | 1 | 5000250.0 | 5,500 | 144 ± 22 | 117 | 12 | 300% |
| sales-star:A2 | T6 IQ+PG | 5,000,250 | 5,000,250 | 1.0 | 5,260 | 6,053 ± 1,653 ! | 5,310 | 4 | 100% |
| sales-star:A2 | T7 PG+IQ | 5,000,250 | 5,000,250 | 1.0 | 1,580 | 1,611 ± 37 | 1,560 | 4 | 100% |
| sales-star:A3 | T1 ASE | 5,000,250 | 1 | 5000250.0 | 1,270 | 30 ± 2 | 25 | 7 | 70% |
| sales-star:A3 | T2 PG | 5,000,250 | 1 | 5000250.0 | 913 | 26 ± 2 | 22 | 11 | 110% |
| sales-star:A3 | T3 ASE+PG | 5,000,250 | 25,250 | 198.0 | 1,410 | 48 ± 5 | 42 | 11 | 110% |
| sales-star:A3 | T3a PG+ASE | 5,000,250 | 25,250 | 198.0 | 744 | 40 ± 5 | 34 | 6 | 60% |
| sales-star:A3 | T4 PG+PG | 5,000,250 | 25,250 | 198.0 | 705 | 41 ± 4 | 36 | 10 | 100% |
| sales-star:A3 | T5 IQ | 5,000,250 | 25,250 | 198.0 | 3,840 | 119 ± 8 | 106 | 23 | 230% |
| sales-star:A3 | T6 IQ+PG | 5,000,250 | 25,250 | 198.0 | 3,710 | 84 ± 6 | 72 | 9 | 90% |
| sales-star:A3 | T7 PG+IQ | 5,000,250 | 25,250 | 198.0 | 787 | 82 ± 8 | 70 | 24 | 240% |
| sales-star:A4 | T1 ASE | 5,000,010 | 1 | 5000010.0 | 928 | 33 ± 1 | 32 | 7 | 70% |
| sales-star:A4 | T2 PG | 5,000,010 | 1 | 5000010.0 | 747 | 30 ± 2 | 26 | 10 | 100% |
| sales-star:A4 | T3 ASE+PG | 5,000,010 | 200,010 | 25.0 | 979 | 1,305 ± 180 | 1,110 | 11 | 110% |
| sales-star:A4 | T3a PG+ASE | 5,000,010 | 200,010 | 25.0 | 707 | 101 ± 3 | 97 | 10 | 100% |
| sales-star:A4 | T4 PG+PG | 5,000,010 | 200,010 | 25.0 | 697 | 103 ± 8 | 96 | 10 | 100% |
| sales-star:A4 | T5 IQ | 5,000,010 | 200,010 | 25.0 | 3,640 | 267 ± 13 | 237 | 26 | 260% |
| sales-star:A4 | T6 IQ+PG | 5,000,010 | 200,010 | 25.0 | 3,540 | 215 ± 22 | 194 | 9 | 90% |
| sales-star:A4 | T7 PG+IQ | 5,000,010 | 200,010 | 25.0 | 745 | 101 ± 7 | 93 | 9 | 90% |
| sales-star:A5 | T1 ASE | 5,012,500 | 1 | 5012500.0 | 1,600 | 1,478 ± 115 | 1,380 | 7 | 78% |
| sales-star:A5 | T2 PG | 5,012,500 | 1 | 5012500.0 | 779 | 96 ± 2 | 91 | 11 | 122% |
| sales-star:A5 | T3 ASE+PG | 5,012,500 | 5,012,200 | 1.0 | 1,770 | 1,440 ± 226 | 1,290 | 11 | 122% |
| sales-star:A5 | T3a PG+ASE | 5,012,500 | 5,012,200 | 1.0 | 741 | 772 ± 27 | 734 | 5 | 56% |
| sales-star:A5 | T4 PG+PG | 5,012,500 | 5,012,200 | 1.0 | 736 | 774 ± 29 | 731 | 9 | 100% |
| sales-star:A5 | T5 IQ | 5,012,500 | 5,012,200 | 1.0 | 3,880 | 3,874 ± 41 | 3,780 | 25 | 278% |
| sales-star:A5 | T6 IQ+PG | 5,012,500 | 5,012,200 | 1.0 | 3,720 | 3,786 ± 55 | 3,660 | 9 | 100% |
| sales-star:A5 | T7 PG+IQ | 5,012,500 | 5,012,200 | 1.0 | 960 | 895 ± 24 | 818 | 22 | 244% |
| sales-star:A6 | T1 ASE | 5,000,626 | 1 | 5000626.0 | 13,950 | 935 ± 53 | 868 | 13 | 87% |
| sales-star:A6 | T2 PG | 5,000,626 | 1 | 5000626.0 | 2,020 | 38 ± 9 | 32 | 16 | 107% |
| sales-star:A6 | T3 ASE+PG | 5,000,626 | 1,196 | 4181.1 | 12,760 | 202 ± 10 | 183 | 21 | 140% |
| sales-star:A6 | T3a PG+ASE | 5,000,626 | 1,196 | 4181.1 | 1,710 | 99 ± 7 | 88 | 15 | 100% |
| sales-star:A6 | T4 PG+PG | 5,000,626 | 1,196 | 4181.1 | 1,860 | 87 ± 2 | 81 | 15 | 100% |
| sales-star:A6 | T5 IQ | 5,000,626 | 1,196 | 4181.1 | 5,140 | 179 ± 11 | 161 | 51 | 340% |
| sales-star:A6 | T6 IQ+PG | 5,000,626 | 1,196 | 4181.1 | 4,960 | 126 ± 4 | 120 | 17 | 113% |
| sales-star:A6 | T7 PG+IQ | 5,000,626 | 1,196 | 4181.1 | 1,880 | 122 ± 3 | 118 | 34 | 227% |
| sales-star:A7 | T1 ASE | 5,001,250 | 1 | 5001250.0 | 1,180 | 803 ± 20 | 783 | 6 | 67% |
| sales-star:A7 | T2 PG | 5,001,250 | 1 | 5001250.0 | 754 | 51 ± 3 | 46 | 10 | 111% |
| sales-star:A7 | T3 ASE+PG | 5,001,250 | 4,997,750 | 1.0 | 1,190 | 1,420 ± 503 ! | 1,190 | 11 | 122% |
| sales-star:A7 | T3a PG+ASE | 5,001,250 | 4,997,750 | 1.0 | 733 | 713 ± 28 | 673 | 9 | 100% |
| sales-star:A7 | T4 PG+PG | 5,001,250 | 4,997,750 | 1.0 | 760 | 723 ± 25 | 690 | 9 | 100% |
| sales-star:A7 | T5 IQ | 5,001,250 | 4,997,750 | 1.0 | 3,860 | 3,811 ± 41 | 3,690 | 22 | 244% |
| sales-star:A7 | T6 IQ+PG | 5,001,250 | 4,997,750 | 1.0 | 3,650 | 3,770 ± 38 | 3,710 | 9 | 100% |
| sales-star:A7 | T7 PG+IQ | 5,001,250 | 4,997,750 | 1.0 | 718 | 709 ± 12 | 662 | 9 | 100% |
| sales-star:A8_STDDEV | T1 ASE | 5,000,000 | 1 | 5000000.0 | 12,770 | 18,054 ± 8,786 ! | 11,570 | 3 | 38% |
| sales-star:A8_STDDEV | T2 PG | 5,000,000 | 5,000,000 | 1.0 | 907 | 903 ± 28 | 864 | 8 | 100% |
| sales-star:A8_STDDEV | T3 ASE+PG | 5,000,000 | 1 | 5000000.0 | 15,110 | 14,527 ± 886 | 13,390 | 3 | 38% |
| sales-star:A8_STDDEV | T3a PG+ASE | 5,000,000 | 5,000,000 | 1.0 | 836 | 906 ± 46 | 815 | 7 | 88% |
| sales-star:A8_STDDEV | T4 PG+PG | 5,000,000 | 5,000,000 | 1.0 | 843 | 871 ± 25 | 837 | 8 | 100% |
| sales-star:A8_STDDEV | T5 IQ | 5,000,000 | 1 | 5000000.0 | 3,990 | 75 ± 8 | 60 | 7 | 88% |
| sales-star:A8_STDDEV | T6 IQ+PG | 5,000,000 | 1 | 5000000.0 | 3,870 | 72 ± 12 | 58 | 6 | 75% |
| sales-star:A8_STDDEV | T7 PG+IQ | 5,000,000 | 5,000,000 | 1.0 | 981 | 919 ± 21 | 893 | 6 | 75% |
| sales-star:A8_VAR | T1 ASE | 5,000,000 | 1 | 5000000.0 | 13,080 | 14,187 ± 1,165 | 13,310 | 3 | 43% |
| sales-star:A8_VAR | T2 PG | 5,000,000 | 5,000,000 | 1.0 | 890 | 915 ± 39 | 883 | 8 | 114% |
| sales-star:A8_VAR | T3 ASE+PG | 5,000,000 | 1 | 5000000.0 | 12,580 | 16,427 ± 7,057 ! | 13,470 | 3 | 43% |
| sales-star:A8_VAR | T3a PG+ASE | 5,000,000 | 5,000,000 | 1.0 | 836 | 861 ± 54 | 819 | 7 | 100% |
| sales-star:A8_VAR | T4 PG+PG | 5,000,000 | 5,000,000 | 1.0 | 935 | 866 ± 21 | 839 | 7 | 100% |
| sales-star:A8_VAR | T5 IQ | 5,000,000 | 1 | 5000000.0 | 4,060 | 66 ± 6 | 57 | 5 | 71% |
| sales-star:A8_VAR | T6 IQ+PG | 5,000,000 | 1 | 5000000.0 | 3,880 | 61 ± 3 | 54 | 5 | 71% |
| sales-star:A8_VAR | T7 PG+IQ | 5,000,000 | 5,000,000 | 1.0 | 975 | 922 ± 29 | 881 | 7 | 100% |
| mixed-key-star:B1 | T1 ASE | 5,000,002 | 1 | 5000002.0 | 1,610 | 816 ± 7 | 809 | 4 | 50% |
| mixed-key-star:B1 | T2 PG | 5,000,002 | 1 | 5000002.0 | 1,100 | 363 ± 2 | 358 | 8 | 100% |
| mixed-key-star:B1 | T3 ASE+PG | 5,000,002 | 2,500,002 | 2.0 | 1,610 | 860 ± 14 | 843 | 10 | 125% |
| mixed-key-star:B1 | T3a PG+ASE | 5,000,002 | 2,500,002 | 2.0 | 916 | 534 ± 28 | 509 | 8 | 100% |
| mixed-key-star:B1 | T4 PG+PG | 5,000,002 | 2,500,002 | 2.0 | 889 | 526 ± 12 | 504 | 8 | 100% |
| mixed-key-star:B1 | T5 IQ | 5,000,002 | 2,500,002 | 2.0 | 4,880 | 2,463 ± 61 | 2,360 | 10 | 125% |
| mixed-key-star:B1 | T6 IQ+PG | 5,000,002 | 2,500,002 | 2.0 | 4,850 | 2,444 ± 68 | 2,340 | 9 | 113% |
| mixed-key-star:B1 | T7 PG+IQ | 5,000,002 | 2,500,002 | 2.0 | 974 | 536 ± 25 | 507 | 8 | 100% |
| mixed-key-star:B2 | T1 ASE | 5,000,252 | 1 | 5000252.0 | 12,730 | 40,562 ± 1,173 | 39,150 | 6 | 55% |
| mixed-key-star:B2 | T2 PG | 5,000,252 | 1 | 5000252.0 | 1,370 | 32 ± 1 | 29 | 10 | 91% |
| mixed-key-star:B2 | T3 ASE+PG | 5,000,252 | 12,752 | 392.1 | 13,970 | 113 ± 8 | 99 | 15 | 136% |
| mixed-key-star:B2 | T3a PG+ASE | 5,000,252 | 12,752 | 392.1 | 1,410 | 49 ± 5 | 42 | 11 | 100% |
| mixed-key-star:B2 | T4 PG+PG | 5,000,252 | 12,752 | 392.1 | 1,350 | 43 ± 2 | 40 | 11 | 100% |
| mixed-key-star:B2 | T5 IQ | 5,000,252 | 12,752 | 392.1 | 5,570 | 136 ± 11 | 121 | 26 | 236% |
| mixed-key-star:B2 | T6 IQ+PG | 5,000,252 | 12,752 | 392.1 | 5,560 | 93 ± 14 | 77 | 15 | 136% |
| mixed-key-star:B2 | T7 PG+IQ | 5,000,252 | 12,752 | 392.1 | 1,460 | 86 ± 4 | 75 | 29 | 264% |
| mixed-key-star:B3 | T1 ASE | 5,000,001 | 1 | 5000001.0 | 1,740 | 439 ± 3 | 434 | 4 | 44% |
| mixed-key-star:B3 | T2 PG | 5,000,001 | 1 | 5000001.0 | 853 | 69 ± 1 | 68 | 7 | 78% |
| mixed-key-star:B3 | T3 ASE+PG | 5,000,001 | 1,250,001 | 4.0 | 1,790 | 469 ± 14 | 455 | 9 | 100% |
| mixed-key-star:B3 | T3a PG+ASE | 5,000,001 | 1,250,001 | 4.0 | 842 | 253 ± 7 | 239 | 9 | 100% |
| mixed-key-star:B3 | T4 PG+PG | 5,000,001 | 1,250,001 | 4.0 | 812 | 255 ± 6 | 242 | 9 | 100% |
| mixed-key-star:B3 | T5 IQ | 5,000,001 | 1,250,001 | 4.0 | 5,250 | 1,303 ± 64 | 1,250 | 22 | 244% |
| mixed-key-star:B3 | T6 IQ+PG | 5,000,001 | 1,250,001 | 4.0 | 4,810 | 1,272 ± 38 | 1,220 | 9 | 100% |
| mixed-key-star:B3 | T7 PG+IQ | 5,000,001 | 1,250,001 | 4.0 | 807 | 259 ± 8 | 246 | 8 | 89% |
| snowflake-star:C1 | T1 ASE | 5,000,735 | 1 | 5000735.0 | 2,220 | 706 ± 85 | 665 | 5 | 56% |
| snowflake-star:C1 | T2 PG | 5,000,735 | 1 | 5000735.0 | 1,040 | 54 ± 2 | 51 | 9 | 100% |
| snowflake-star:C1 | T3 ASE+PG | 5,000,735 | 834,562 | 6.0 | 2,130 | 741 ± 24 | 710 | 11 | 122% |
| snowflake-star:C1 | T3a PG+ASE | 5,000,735 | 834,562 | 6.0 | 1,030 | 192 ± 4 | 179 | 10 | 111% |
| snowflake-star:C1 | T4 PG+PG | 5,000,735 | 834,562 | 6.0 | 933 | 187 ± 9 | 178 | 9 | 100% |
| snowflake-star:C1 | T5 IQ | 5,000,735 | 1 | 5000735.0 | 4,010 | 95 ± 8 | 80 | 17 | 189% |
| snowflake-star:C1 | T6 IQ+PG | 5,000,735 | 834,562 | 6.0 | 4,080 | 736 ± 23 | 684 | 10 | 111% |
| snowflake-star:C1 | T7 PG+IQ | 5,000,735 | 834,562 | 6.0 | 970 | 198 ± 12 | 179 | 10 | 111% |
| snowflake-star:C2 | T1 ASE | 5,000,250 | 1 | 5000250.0 | 1,510 | 23 ± 2 | 20 | 6 | 55% |
| snowflake-star:C2 | T2 PG | 5,000,250 | 1 | 5000250.0 | 727 | 28 ± 8 | 18 | 12 | 109% |
| snowflake-star:C2 | T3 ASE+PG | 5,000,250 | 25,250 | 198.0 | 1,270 | 39 ± 2 | 36 | 10 | 91% |
| snowflake-star:C2 | T3a PG+ASE | 5,000,250 | 25,250 | 198.0 | 717 | 43 ± 9 | 34 | 6 | 55% |
| snowflake-star:C2 | T4 PG+PG | 5,000,250 | 25,250 | 198.0 | 808 | 38 ± 1 | 36 | 11 | 100% |
| snowflake-star:C2 | T5 IQ | 5,000,250 | 25,250 | 198.0 | 3,720 | 127 ± 13 | 107 | 25 | 227% |
| snowflake-star:C2 | T6 IQ+PG | 5,000,250 | 25,250 | 198.0 | 4,000 | 88 ± 5 | 77 | 11 | 100% |
| snowflake-star:C2 | T7 PG+IQ | 5,000,250 | 25,250 | 198.0 | 783 | 79 ± 7 | 69 | 23 | 209% |
| snowflake-star:C3 | T1 ASE | 5,000,250 | 5,000,250 | 1.0 | 1,370 | 1,375 ± 17 | 1,360 | 8 | 73% |
| snowflake-star:C3 | T2 PG | 5,000,250 | 5,000,250 | 1.0 | 698 | 720 ± 34 | 695 | 11 | 100% |
| snowflake-star:C3 | T3 ASE+PG | 5,000,250 | 5,000,250 | 1.0 | 1,300 | 1,282 ± 21 | 1,260 | 11 | 100% |
| snowflake-star:C3 | T3a PG+ASE | 5,000,250 | 5,000,250 | 1.0 | 697 | 726 ± 28 | 689 | 7 | 64% |
| snowflake-star:C3 | T4 PG+PG | 5,000,250 | 5,000,250 | 1.0 | 694 | 723 ± 21 | 697 | 11 | 100% |
| snowflake-star:C3 | T5 IQ | 5,000,250 | 5,000,250 | 1.0 | 3,730 | 3,775 ± 34 | 3,680 | 24 | 218% |
| snowflake-star:C3 | T6 IQ+PG | 5,000,250 | 5,000,250 | 1.0 | 3,790 | 3,738 ± 37 | 3,640 | 11 | 100% |
| snowflake-star:C3 | T7 PG+IQ | 5,000,250 | 5,000,250 | 1.0 | 772 | 782 ± 39 | 735 | 24 | 218% |
| snowflake-star:C4 | T1 ASE | 5,000,250 | 1 | 5000250.0 | 1,970 | 22 ± 1 | 20 | 5 | 56% |
| snowflake-star:C4 | T2 PG | 5,000,250 | 1 | 5000250.0 | 724 | 23 ± 1 | 19 | 9 | 100% |
| snowflake-star:C4 | T3 ASE+PG | 5,000,250 | 25,250 | 198.0 | 1,330 | 40 ± 2 | 37 | 10 | 111% |
| snowflake-star:C4 | T3a PG+ASE | 5,000,250 | 25,250 | 198.0 | 704 | 33 ± 2 | 30 | 5 | 56% |
| snowflake-star:C4 | T4 PG+PG | 5,000,250 | 25,250 | 198.0 | 701 | 36 ± 1 | 34 | 9 | 100% |
| snowflake-star:C4 | T5 IQ | 5,000,250 | 25,250 | 198.0 | 3,680 | 119 ± 17 | 102 | 22 | 244% |
| snowflake-star:C4 | T6 IQ+PG | 5,000,250 | 25,250 | 198.0 | 3,760 | 91 ± 7 | 82 | 10 | 111% |
| snowflake-star:C4 | T7 PG+IQ | 5,000,250 | 25,250 | 198.0 | 813 | 75 ± 4 | 64 | 22 | 244% |
| snowflake-star:C5 | T1 ASE | 5,050,001 | 1 | 5050001.0 | 1,360 | 1,368 ± 67 | 1,310 | 5 | 56% |
| snowflake-star:C5 | T2 PG | 5,050,001 | 1 | 5050001.0 | 852 | 104 ± 8 | 95 | 9 | 100% |
| snowflake-star:C5 | T3 ASE+PG | 5,050,001 | 5,012,201 | 1.0 | 1,270 | 1,752 ± 332 | 1,300 | 11 | 122% |
| snowflake-star:C5 | T3a PG+ASE | 5,050,001 | 5,012,201 | 1.0 | 830 | 829 ± 43 | 769 | 10 | 111% |
| snowflake-star:C5 | T4 PG+PG | 5,050,001 | 5,012,200 | 1.0 | 893 | 758 ± 15 | 708 | 9 | 100% |
| snowflake-star:C5 | T5 IQ | 5,050,001 | 1,250,001 | 4.0 | 3,850 | 1,313 ± 39 | 1,270 | 26 | 289% |
| snowflake-star:C5 | T6 IQ+PG | 5,050,001 | 5,012,201 | 1.0 | 3,770 | 3,811 ± 54 | 3,720 | 10 | 111% |
| snowflake-star:C5 | T7 PG+IQ | 5,050,001 | 5,012,201 | 1.0 | 987 | 882 ± 26 | 832 | 11 | 122% |
| taxonomy-bridge:D1 | T1 ASE | 55,200 | 1 | 55200.0 | 160 | 140 ± 3 | 134 | 3 | 43% |
| taxonomy-bridge:D1 | T2 PG | 55,200 | 1 | 55200.0 | 51 | 21 ± 2 | 18 | 7 | 100% |
| taxonomy-bridge:D1 | T3 ASE+PG | 55,200 | 1 | 55200.0 | 84 | 21 ± 1 | 19 | 7 | 100% |
| taxonomy-bridge:D1 | T3a PG+ASE | 55,200 | 1 | 55200.0 | 146 | 135 ± 4 | 125 | 3 | 43% |
| taxonomy-bridge:D1 | T4 PG+PG | 55,200 | 1 | 55200.0 | 42 | 19 ± 2 | 17 | 7 | 100% |
| taxonomy-bridge:D1 | T5 IQ | 55,200 | 1 | 55200.0 | 89 | 55 ± 4 | 46 | 8 | 114% |
| taxonomy-bridge:D1 | T6 IQ+PG | 55,200 | 1 | 55200.0 | 46 | 23 ± 2 | 18 | 7 | 100% |
| taxonomy-bridge:D1 | T7 PG+IQ | 55,200 | 1 | 55200.0 | 122 | 67 ± 16 | 47 | 10 | 143% |
| taxonomy-bridge:D2 | T1 ASE | 55,200 | 1 | 55200.0 | 162 | 141 ± 9 | 128 | 3 | 43% |
| taxonomy-bridge:D2 | T2 PG | 55,200 | 1 | 55200.0 | 35 | 22 ± 2 | 19 | 7 | 100% |
| taxonomy-bridge:D2 | T3 ASE+PG | 55,200 | 1 | 55200.0 | 36 | 24 ± 1 | 21 | 7 | 100% |
| taxonomy-bridge:D2 | T3a PG+ASE | 55,200 | 1 | 55200.0 | 145 | 143 ± 7 | 136 | 3 | 43% |
| taxonomy-bridge:D2 | T4 PG+PG | 55,200 | 1 | 55200.0 | 37 | 23 ± 2 | 18 | 7 | 100% |
| taxonomy-bridge:D2 | T5 IQ | 55,200 | 1 | 55200.0 | 92 | 57 ± 4 | 47 | 10 | 143% |
| taxonomy-bridge:D2 | T6 IQ+PG | 55,200 | 1 | 55200.0 | 35 | 23 ± 2 | 20 | 7 | 100% |
| taxonomy-bridge:D2 | T7 PG+IQ | 55,200 | 1 | 55200.0 | 90 | 55 ± 5 | 48 | 10 | 143% |
| taxonomy-bridge:D3 | T1 ASE | 55,216 | 1 | 55216.0 | 151 | 1,833 ± 173 | 1,710 | 5 | 63% |
| taxonomy-bridge:D3 | T2 PG | 55,216 | 1 | 55216.0 | 42 | 23 ± 1 | 18 | 10 | 125% |
| taxonomy-bridge:D3 | T3 ASE+PG | 55,216 | 1 | 55216.0 | 37 | 21 ± 1 | 18 | 8 | 100% |
| taxonomy-bridge:D3 | T3a PG+ASE | 55,216 | 1 | 55216.0 | 438 | 1,900 ± 284 | 1,630 | 5 | 63% |
| taxonomy-bridge:D3 | T4 PG+PG | 55,216 | 1 | 55216.0 | 53 | 21 ± 2 | 17 | 8 | 100% |
| taxonomy-bridge:D3 | T5 IQ | 55,216 | 12,516 | 4.4 | 136 | 131 ± 23 | 99 | 28 | 350% |
| taxonomy-bridge:D3 | T6 IQ+PG | 55,216 | 1 | 55216.0 | 41 | 22 ± 1 | 19 | 9 | 113% |
| taxonomy-bridge:D3 | T7 PG+IQ | 55,216 | 12,516 | 4.4 | 138 | 107 ± 6 | 97 | 25 | 313% |
| taxonomy-bridge:D4 | T1 ASE | 5,045,201 | 1 | 5045201.0 | 1,310 | 156 ± 3 | 151 | 6 | 50% |
| taxonomy-bridge:D4 | T2 PG | 5,045,201 | 1 | 5045201.0 | 836 | 26 ± 1 | 22 | 11 | 92% |
| taxonomy-bridge:D4 | T3 ASE+PG | 5,045,201 | 100,200 | 50.4 | 1,160 | 51 ± 7 | 40 | 12 | 100% |
| taxonomy-bridge:D4 | T3a PG+ASE | 5,045,201 | 100,200 | 50.4 | 890 | 201 ± 90 | 157 | 7 | 58% |
| taxonomy-bridge:D4 | T4 PG+PG | 5,045,201 | 100,200 | 50.4 | 908 | 48 ± 1 | 46 | 12 | 100% |
| taxonomy-bridge:D4 | T5 IQ | 5,045,201 | 100,201 | 50.4 | 3,770 | 209 ± 19 | 191 | 25 | 208% |
| taxonomy-bridge:D4 | T6 IQ+PG | 5,045,201 | 100,200 | 50.4 | 3,840 | 146 ± 6 | 132 | 12 | 100% |
| taxonomy-bridge:D4 | T7 PG+IQ | 5,045,201 | 100,201 | 50.4 | 880 | 127 ± 18 | 110 | 25 | 208% |
| taxonomy-bridge:D5 | T1 ASE | 5,045,201 | 5,000,200 | 1.0 | 1,400 | 1,362 ± 74 | 1,300 | 8 | 73% |
| taxonomy-bridge:D5 | T2 PG | 5,045,201 | 5,000,200 | 1.0 | 724 | 765 ± 28 | 698 | 12 | 109% |
| taxonomy-bridge:D5 | T3 ASE+PG | 5,045,201 | 5,000,200 | 1.0 | 1,330 | 1,209 ± 45 | 1,170 | 13 | 118% |
| taxonomy-bridge:D5 | T3a PG+ASE | 5,045,201 | 5,000,200 | 1.0 | 818 | 870 ± 48 | 816 | 8 | 73% |
| taxonomy-bridge:D5 | T4 PG+PG | 5,045,201 | 5,000,200 | 1.0 | 734 | 741 ± 22 | 719 | 11 | 100% |
| taxonomy-bridge:D5 | T5 IQ | 5,045,201 | 5,000,201 | 1.0 | 3,850 | 3,817 ± 32 | 3,690 | 26 | 236% |
| taxonomy-bridge:D5 | T6 IQ+PG | 5,045,201 | 5,000,200 | 1.0 | 3,760 | 3,755 ± 38 | 3,650 | 12 | 109% |
| taxonomy-bridge:D5 | T7 PG+IQ | 5,045,201 | 5,000,201 | 1.0 | 802 | 837 ± 44 | 796 | 28 | 255% |
| orders-ledger:E1 | T1 ASE | 100,000 | 100,000 | 1.0 | 121 | 122 ± 3 | 117 | 3 | 43% |
| orders-ledger:E1 | T2 PG | 100,000 | 100,000 | 1.0 | 46 | 33 ± 2 | 29 | 7 | 100% |
| orders-ledger:E1 | T3 ASE+PG | 100,000 | 100,000 | 1.0 | 30 | 32 ± 4 | 27 | 3 | 43% |
| orders-ledger:E1 | T3a PG+ASE | 100,000 | 100,000 | 1.0 | 31 | 33 ± 1 | 31 | 7 | 100% |
| orders-ledger:E1 | T4 PG+PG | 100,000 | 100,000 | 1.0 | 39 | 33 ± 2 | 31 | 7 | 100% |
| orders-ledger:E1 | T5 IQ | 100,000 | 100,000 | 1.0 | 163 | 165 ± 5 | 156 | 18 | 257% |
| orders-ledger:E1 | T6 IQ+PG | 100,000 | 100,000 | 1.0 | 185 | 164 ± 25 | 146 | 16 | 229% |
| orders-ledger:E1 | T7 PG+IQ | 100,000 | 100,000 | 1.0 | 37 | 35 ± 4 | 29 | 6 | 86% |
| orders-ledger:E2 | T1 ASE | 100,000 | 20 | 5000.0 | 60 | 1,322 ± 12 | 1,300 | 3 | 43% |
| orders-ledger:E2 | T2 PG | 100,000 | 20 | 5000.0 | 43 | 25 ± 2 | 21 | 6 | 86% |
| orders-ledger:E2 | T3 ASE+PG | 100,000 | 20 | 5000.0 | 269 | 1,327 ± 18 | 1,300 | 3 | 43% |
| orders-ledger:E2 | T3a PG+ASE | 100,000 | 20 | 5000.0 | 39 | 27 ± 5 | 21 | 7 | 100% |
| orders-ledger:E2 | T4 PG+PG | 100,000 | 20 | 5000.0 | 38 | 24 ± 2 | 20 | 7 | 100% |
| orders-ledger:E2 | T5 IQ | 100,000 | 20 | 5000.0 | 149 | 46 ± 3 | 37 | 2 | 29% |
| orders-ledger:E2 | T6 IQ+PG | 100,000 | 20 | 5000.0 | 134 | 43 ± 4 | 36 | 2 | 29% |
| orders-ledger:E2 | T7 PG+IQ | 100,000 | 20 | 5000.0 | 38 | 24 ± 2 | 21 | 7 | 100% |
| orders-ledger:E3 | T1 ASE | 49,995 | 49,995 | 1.0 | 26 | 31 ± 3 | 26 | 3 | 43% |
| orders-ledger:E3 | T2 PG | 49,995 | 49,995 | 1.0 | 31 | 35 ± 2 | 31 | 6 | 86% |
| orders-ledger:E3 | T3 ASE+PG | 49,995 | 49,995 | 1.0 | 26 | 28 ± 2 | 26 | 3 | 43% |
| orders-ledger:E3 | T3a PG+ASE | 49,995 | 49,995 | 1.0 | 36 | 35 ± 2 | 32 | 7 | 100% |
| orders-ledger:E3 | T4 PG+PG | 49,995 | 49,995 | 1.0 | 31 | 35 ± 2 | 30 | 7 | 100% |
| orders-ledger:E3 | T5 IQ | 49,995 | 49,995 | 1.0 | 111 | 113 ± 8 | 101 | 5 | 71% |
| orders-ledger:E3 | T6 IQ+PG | 49,995 | 49,995 | 1.0 | 106 | 107 ± 9 | 92 | 5 | 71% |
| orders-ledger:E3 | T7 PG+IQ | 49,995 | 49,995 | 1.0 | 34 | 35 ± 3 | 32 | 7 | 100% |
| orders-ledger:E4 | T1 ASE | 100,250 | 1 | 100250.0 | 146 | 177 ± 9 | 166 | 4 | 50% |
| orders-ledger:E4 | T2 PG | 100,250 | 1 | 100250.0 | 45 | 23 ± 1 | 20 | 7 | 88% |
| orders-ledger:E4 | T3 ASE+PG | 100,250 | 750 | 133.7 | 48 | 592 ± 24 | 566 | 8 | 100% |
| orders-ledger:E4 | T3a PG+ASE | 100,250 | 750 | 133.7 | 55 | 31 ± 1 | 27 | 4 | 50% |
| orders-ledger:E4 | T4 PG+PG | 100,250 | 750 | 133.7 | 44 | 34 ± 1 | 30 | 8 | 100% |
| orders-ledger:E4 | T5 IQ | 100,250 | 750 | 133.7 | 151 | 84 ± 6 | 77 | 20 | 250% |
| orders-ledger:E4 | T6 IQ+PG | 100,250 | 750 | 133.7 | 152 | 60 ± 4 | 54 | 8 | 100% |
| orders-ledger:E4 | T7 PG+IQ | 100,250 | 750 | 133.7 | 71 | 85 ± 16 | 61 | 21 | 263% |
| complex-join-star:CJ_MIXED | T1 ASE | 5,050,000 | 1 | 5050000.0 | 12,590 | 31,621 ± 17,184 ! | 23,450 | 4 | 57% |
| complex-join-star:CJ_MIXED | T2 PG | 5,050,000 | 1 | 5050000.0 | 1,540 | 898 ± 31 | 866 | 7 | 100% |
| complex-join-star:CJ_MIXED | T3 ASE+PG | 5,050,000 | 1 | 5050000.0 | 1,990 | 850 ± 29 | 814 | 8 | 114% |
| complex-join-star:CJ_MIXED | T3a PG+ASE | 5,050,000 | 1 | 5050000.0 | 12,700 | 28,634 ± 11,237 ! | 24,710 | 4 | 57% |
| complex-join-star:CJ_MIXED | T4 PG+PG | 5,050,000 | 1 | 5050000.0 | 2,010 | 921 ± 29 | 861 | 7 | 100% |
| complex-join-star:CJ_MIXED | T5 IQ | 5,050,000 | 1 | 5050000.0 | 5,350 | 122 ± 6 | 101 | 10 | 143% |
| complex-join-star:CJ_MIXED | T6 IQ+PG | 5,050,000 | 1 | 5050000.0 | 1,970 | 887 ± 24 | 842 | 7 | 100% |
| complex-join-star:CJ_MIXED | T7 PG+IQ | 5,050,000 | 1 | 5050000.0 | 5,300 | 124 ± 12 | 109 | 10 | 143% |
| complex-join-star:CJ_EQUI | T1 ASE | 5,050,000 | 1 | 5050000.0 | 1,350 | 1,417 ± 23 | 1,390 | 3 | 43% |
| complex-join-star:CJ_EQUI | T2 PG | 5,050,000 | 1 | 5050000.0 | 812 | 466 ± 4 | 459 | 7 | 100% |
| complex-join-star:CJ_EQUI | T3 ASE+PG | 5,050,000 | 1 | 5050000.0 | 821 | 463 ± 5 | 455 | 6 | 86% |
| complex-join-star:CJ_EQUI | T3a PG+ASE | 5,050,000 | 1 | 5050000.0 | 1,350 | 1,410 ± 21 | 1,390 | 3 | 43% |
| complex-join-star:CJ_EQUI | T4 PG+PG | 5,050,000 | 1 | 5050000.0 | 825 | 470 ± 4 | 462 | 7 | 100% |
| complex-join-star:CJ_EQUI | T5 IQ | 5,050,000 | 1 | 5050000.0 | 3,760 | 90 ± 4 | 79 | 9 | 129% |
| complex-join-star:CJ_EQUI | T6 IQ+PG | 5,050,000 | 1 | 5050000.0 | 834 | 470 ± 4 | 463 | 7 | 100% |
| complex-join-star:CJ_EQUI | T7 PG+IQ | 5,050,000 | 1 | 5050000.0 | 3,720 | 89 ± 5 | 76 | 9 | 129% |
| composite-key-star:CK1 | T1 ASE | 5,000,300 | 1 | 5000300.0 | 1,290 | 21 ± 2 | 18 | 4 | 100% |
| composite-key-star:CK1 | T2 PG | 5,000,300 | 1 | 5000300.0 | 1,090 | 17 ± 2 | 14 | 7 | 175% |
| composite-key-star:CK1 | T3 ASE+PG | 5,000,300 | 30,300 | 165.0 | 1,220 | 70 ± 5 | 63 | 4 | 100% |
| composite-key-star:CK1 | T3a PG+ASE | 5,000,300 | 30,300 | 165.0 | 1,050 | 246 ± 4 | 239 | 4 | 100% |
| composite-key-star:CK1 | T4 PG+PG | 5,000,300 | 30,300 | 165.0 | 1,060 | 243 ± 5 | 232 | 4 | 100% |
| composite-key-star:CK1 | T5 IQ | 5,000,300 | 1 | 5000300.0 | 4,390 | 65 ± 4 | 56 | 10 | 250% |
| composite-key-star:CK1 | T6 IQ+PG | 5,000,300 | 30,300 | 165.0 | 4,320 | 100 ± 6 | 93 | 4 | 100% |
| composite-key-star:CK1 | T7 PG+IQ | 5,000,300 | 30,300 | 165.0 | 1,090 | 269 ± 5 | 257 | 4 | 100% |
| composite-key-star:CK2 | T1 ASE | 5,000,300 | 1 | 5000300.0 | 12,810 | 21 ± 1 | 18 | 4 | 100% |
| composite-key-star:CK2 | T2 PG | 5,000,300 | 1 | 5000300.0 | 1,740 | 25 ± 1 | 22 | 7 | 175% |
| composite-key-star:CK2 | T3 ASE+PG | 5,000,300 | 12,618 | 396.3 | 12,940 | 780 ± 19 | 759 | 4 | 100% |
| composite-key-star:CK2 | T3a PG+ASE | 5,000,300 | 12,618 | 396.3 | 1,750 | 95 ± 3 | 88 | 4 | 100% |
| composite-key-star:CK2 | T4 PG+PG | 5,000,300 | 12,618 | 396.3 | 1,780 | 98 ± 3 | 93 | 4 | 100% |
| composite-key-star:CK2 | T5 IQ | 5,000,300 | 1 | 5000300.0 | 5,120 | 68 ± 2 | 56 | 10 | 250% |
| composite-key-star:CK2 | T6 IQ+PG | 5,000,300 | 12,618 | 396.3 | 5,080 | 94 ± 7 | 80 | 4 | 100% |
| composite-key-star:CK2 | T7 PG+IQ | 5,000,300 | 12,618 | 396.3 | 1,720 | 116 ± 6 | 103 | 4 | 100% |
| composite-key-star:CK3 | T1 ASE | 5,000,300 | 600 | 8333.8 | 12,660 | 60 ± 3 | 56 | 5 | 125% |
| composite-key-star:CK3 | T2 PG | 5,000,300 | 1 | 5000300.0 | 2,730 | 25 ± 2 | 22 | 8 | 200% |
| composite-key-star:CK3 | T3 ASE+PG | 5,000,300 | 600 | 8333.8 | 12,770 | 59 ± 2 | 55 | 4 | 100% |
| composite-key-star:CK3 | T3a PG+ASE | 5,000,300 | 600 | 8333.8 | 2,840 | 30 ± 4 | 24 | 4 | 100% |
| composite-key-star:CK3 | T4 PG+PG | 5,000,300 | 600 | 8333.8 | 2,780 | 28 ± 2 | 26 | 4 | 100% |
| composite-key-star:CK3 | T5 IQ | 5,000,300 | 600 | 8333.8 | 10,380 | 111 ± 7 | 96 | 9 | 225% |
| composite-key-star:CK3 | T6 IQ+PG | 5,000,300 | 600 | 8333.8 | 10,190 | 90 ± 5 | 78 | 6 | 150% |
| composite-key-star:CK3 | T7 PG+IQ | 5,000,300 | 30,300 | 165.0 | 2,680 | 281 ± 5 | 269 | 6 | 150% |
| agg-expression-star:M1 | T1 ASE | 100,000 | 1 | 100000.0 | 207 | 114 ± 3 | 111 | 2 | 100% |
| agg-expression-star:M1 | T2 PG | 100,000 | 100,000 | 1.0 | 41 | 33 ± 1 | 31 | 2 | 100% |
| agg-expression-star:M1 | T3 ASE+PG | 100,000 | 1 | 100000.0 | 138 | 120 ± 2 | 116 | 2 | 100% |
| agg-expression-star:M1 | T3a PG+ASE | 100,000 | 100,000 | 1.0 | 35 | 34 ± 1 | 31 | 2 | 100% |
| agg-expression-star:M1 | T4 PG+PG | 100,000 | 100,000 | 1.0 | 35 | 33 ± 2 | 30 | 2 | 100% |
| agg-expression-star:M1 | T5 IQ | 100,000 | 1 | 100000.0 | 126 | 42 ± 5 | 34 | 5 | 250% |
| agg-expression-star:M1 | T6 IQ+PG | 100,000 | 1 | 100000.0 | 131 | 41 ± 5 | 34 | 5 | 250% |
| agg-expression-star:M1 | T7 PG+IQ | 100,000 | 100,000 | 1.0 | 42 | 32 ± 1 | 30 | 2 | 100% |
| agg-expression-star:M2 | T1 ASE | 100,000 | 1 | 100000.0 | 131 | 124 ± 3 | 121 | 2 | 100% |
| agg-expression-star:M2 | T2 PG | 100,000 | 100,000 | 1.0 | 35 | 35 ± 1 | 33 | 3 | 150% |
| agg-expression-star:M2 | T3 ASE+PG | 100,000 | 1 | 100000.0 | 140 | 126 ± 2 | 123 | 2 | 100% |
| agg-expression-star:M2 | T3a PG+ASE | 100,000 | 100,000 | 1.0 | 34 | 35 ± 1 | 33 | 2 | 100% |
| agg-expression-star:M2 | T4 PG+PG | 100,000 | 100,000 | 1.0 | 36 | 38 ± 3 | 33 | 2 | 100% |
| agg-expression-star:M2 | T5 IQ | 100,000 | 1 | 100000.0 | 147 | 56 ± 4 | 46 | 6 | 300% |
| agg-expression-star:M2 | T6 IQ+PG | 100,000 | 1 | 100000.0 | 147 | 52 ± 4 | 46 | 5 | 250% |
| agg-expression-star:M2 | T7 PG+IQ | 100,000 | 100,000 | 1.0 | 33 | 36 ± 2 | 33 | 2 | 100% |
| agg-expression-star:M3 | T1 ASE | 100,000 | 10 | 10000.0 | 139 | 129 ± 2 | 123 | 3 | 43% |
| agg-expression-star:M3 | T2 PG | 100,000 | 10 | 10000.0 | 63 | 27 ± 1 | 25 | 7 | 100% |
| agg-expression-star:M3 | T3 ASE+PG | 100,000 | 10 | 10000.0 | 132 | 132 ± 2 | 129 | 3 | 43% |
| agg-expression-star:M3 | T3a PG+ASE | 100,000 | 10 | 10000.0 | 59 | 26 ± 1 | 25 | 7 | 100% |
| agg-expression-star:M3 | T4 PG+PG | 100,000 | 10 | 10000.0 | 59 | 27 ± 2 | 23 | 7 | 100% |
| agg-expression-star:M3 | T5 IQ | 100,000 | 10 | 10000.0 | 153 | 45 ± 4 | 37 | 6 | 86% |
| agg-expression-star:M3 | T6 IQ+PG | 100,000 | 10 | 10000.0 | 170 | 49 ± 7 | 37 | 6 | 86% |
| agg-expression-star:M3 | T7 PG+IQ | 100,000 | 10 | 10000.0 | 55 | 26 ± 1 | 23 | 6 | 86% |
| agg-expression-star:M4 | T1 ASE | 100,250 | 1 | 100250.0 | 142 | 199 ± 3 | 195 | 4 | 50% |
| agg-expression-star:M4 | T2 PG | 100,250 | 1 | 100250.0 | 50 | 22 ± 2 | 19 | 8 | 100% |
| agg-expression-star:M4 | T3 ASE+PG | 100,250 | 5,250 | 19.1 | 137 | 629 ± 9 | 616 | 9 | 113% |
| agg-expression-star:M4 | T3a PG+ASE | 100,250 | 5,250 | 19.1 | 41 | 32 ± 2 | 28 | 4 | 50% |
| agg-expression-star:M4 | T4 PG+PG | 100,250 | 5,250 | 19.1 | 41 | 35 ± 2 | 30 | 8 | 100% |
| agg-expression-star:M4 | T5 IQ | 100,250 | 5,250 | 19.1 | 154 | 97 ± 9 | 85 | 21 | 263% |
| agg-expression-star:M4 | T6 IQ+PG | 100,250 | 5,250 | 19.1 | 145 | 63 ± 5 | 56 | 8 | 100% |
| agg-expression-star:M4 | T7 PG+IQ | 100,250 | 5,250 | 19.1 | 89 | 73 ± 6 | 63 | 20 | 250% |
| numeric-typekey-star:N1_DEC | T1 ASE | 100,001 | 1 | 100001.0 | 134 | 116 ± 9 | 111 | 3 | 38% |
| numeric-typekey-star:N1_DEC | T2 PG | 100,001 | 1 | 100001.0 | 56 | 21 ± 1 | 18 | 7 | 88% |
| numeric-typekey-star:N1_DEC | T3 ASE+PG | 100,001 | 5,001 | 20.0 | 127 | 125 ± 2 | 122 | 8 | 100% |
| numeric-typekey-star:N1_DEC | T3a PG+ASE | 100,001 | 5,001 | 20.0 | 53 | 73 ± 3 | 69 | 4 | 50% |
| numeric-typekey-star:N1_DEC | T4 PG+PG | 100,001 | 5,001 | 20.0 | 51 | 74 ± 1 | 70 | 8 | 100% |
| numeric-typekey-star:N1_DEC | T5 IQ | 100,001 | 1 | 100001.0 | 155 | 55 ± 6 | 45 | 11 | 138% |
| numeric-typekey-star:N1_DEC | T6 IQ+PG | 100,001 | 5,001 | 20.0 | 144 | 57 ± 5 | 46 | 8 | 100% |
| numeric-typekey-star:N1_DEC | T7 PG+IQ | 100,001 | 5,001 | 20.0 | 63 | 101 ± 6 | 89 | 6 | 75% |
| numeric-typekey-star:N2_REAL | T1 ASE | 100,001 | 1 | 100001.0 | 128 | 114 ± 3 | 110 | 4 | 50% |
| numeric-typekey-star:N2_REAL | T2 PG | 100,001 | 1 | 100001.0 | 67 | 20 ± 2 | 17 | 8 | 100% |
| numeric-typekey-star:N2_REAL | T3 ASE+PG | 100,001 | 12,501 | 8.0 | 126 | 126 ± 3 | 118 | 9 | 113% |
| numeric-typekey-star:N2_REAL | T3a PG+ASE | 100,001 | 12,501 | 8.0 | 46 | 35 ± 2 | 30 | 8 | 100% |
| numeric-typekey-star:N2_REAL | T4 PG+PG | 100,001 | 12,501 | 8.0 | 43 | 37 ± 4 | 31 | 8 | 100% |
| numeric-typekey-star:N2_REAL | T5 IQ | 100,001 | 1 | 100001.0 | 139 | 55 ± 5 | 47 | 11 | 138% |
| numeric-typekey-star:N2_REAL | T6 IQ+PG | 100,001 | 12,501 | 8.0 | 139 | 62 ± 5 | 53 | 9 | 113% |
| numeric-typekey-star:N2_REAL | T7 PG+IQ | 100,001 | 12,501 | 8.0 | 43 | 33 ± 1 | 31 | 8 | 100% |
| numeric-typekey-star:N5_DOUBLE | T1 ASE | 100,001 | 1 | 100001.0 | 134 | 113 ± 2 | 109 | 4 | 50% |
| numeric-typekey-star:N5_DOUBLE | T2 PG | 100,001 | 1 | 100001.0 | 74 | 24 ± 2 | 20 | 8 | 100% |
| numeric-typekey-star:N5_DOUBLE | T3 ASE+PG | 100,001 | 25,001 | 4.0 | 122 | 127 ± 4 | 119 | 8 | 100% |
| numeric-typekey-star:N5_DOUBLE | T3a PG+ASE | 100,001 | 25,001 | 4.0 | 43 | 37 ± 2 | 31 | 8 | 100% |
| numeric-typekey-star:N5_DOUBLE | T4 PG+PG | 100,001 | 25,001 | 4.0 | 46 | 38 ± 3 | 32 | 8 | 100% |
| numeric-typekey-star:N5_DOUBLE | T5 IQ | 100,001 | 1 | 100001.0 | 144 | 56 ± 5 | 48 | 11 | 138% |
| numeric-typekey-star:N5_DOUBLE | T6 IQ+PG | 100,001 | 25,001 | 4.0 | 128 | 75 ± 5 | 65 | 8 | 100% |
| numeric-typekey-star:N5_DOUBLE | T7 PG+IQ | 100,001 | 25,001 | 4.0 | 43 | 35 ± 2 | 29 | 7 | 88% |
| numeric-typekey-star:N3_BIT | T1 ASE | 100,001 | 1 | 100001.0 | 130 | 113 ± 2 | 111 | 4 | 50% |
| numeric-typekey-star:N3_BIT | T2 PG | 100,001 | 1 | 100001.0 | 66 | 20 ± 2 | 17 | 7 | 88% |
| numeric-typekey-star:N3_BIT | T3 ASE+PG | 100,001 | 20,001 | 5.0 | 121 | 124 ± 3 | 119 | 8 | 100% |
| numeric-typekey-star:N3_BIT | T3a PG+ASE | 100,001 | 20,001 | 5.0 | 34 | 33 ± 2 | 27 | 8 | 100% |
| numeric-typekey-star:N3_BIT | T4 PG+PG | 100,001 | 20,001 | 5.0 | 35 | 34 ± 2 | 29 | 8 | 100% |
| numeric-typekey-star:N3_BIT | T5 IQ | 100,001 | 1 | 100001.0 | 172 | 63 ± 9 | 52 | 11 | 138% |
| numeric-typekey-star:N3_BIT | T6 IQ+PG | 100,001 | 20,001 | 5.0 | 122 | 66 ± 3 | 60 | 8 | 100% |
| numeric-typekey-star:N3_BIT | T7 PG+IQ | 100,001 | 20,001 | 5.0 | 32 | 33 ± 3 | 27 | 8 | 100% |
| numeric-typekey-star:N4_LABEL | T1 ASE | 100,004 | 25,004 | 4.0 | 118 | 128 ± 4 | 123 | 4 | 50% |
| numeric-typekey-star:N4_LABEL | T2 PG | 100,004 | 1 | 100004.0 | 49 | 22 ± 2 | 19 | 7 | 88% |
| numeric-typekey-star:N4_LABEL | T3 ASE+PG | 100,004 | 25,004 | 4.0 | 118 | 127 ± 3 | 120 | 8 | 100% |
| numeric-typekey-star:N4_LABEL | T3a PG+ASE | 100,004 | 25,004 | 4.0 | 60 | 41 ± 2 | 37 | 8 | 100% |
| numeric-typekey-star:N4_LABEL | T4 PG+PG | 100,004 | 25,004 | 4.0 | 39 | 42 ± 3 | 36 | 8 | 100% |
| numeric-typekey-star:N4_LABEL | T5 IQ | 100,004 | 25,004 | 4.0 | 163 | 109 ± 5 | 98 | 20 | 250% |
| numeric-typekey-star:N4_LABEL | T6 IQ+PG | 100,004 | 25,004 | 4.0 | 139 | 84 ± 4 | 77 | 8 | 100% |
| numeric-typekey-star:N4_LABEL | T7 PG+IQ | 100,004 | 25,004 | 4.0 | 40 | 42 ± 3 | 38 | 8 | 100% |
| text-function-gap:G1 | T1 ASE | 25,000 | 25,000 | 1.0 | 24 | 25 ± 3 | 21 | 4 | 57% |
| text-function-gap:G1 | T2 PG | 25,000 | 25,000 | 1.0 | 204 | 207 ± 3 | 202 | 8 | 114% |
| text-function-gap:G1 | T3 ASE+PG | 25,000 | 25,000 | 1.0 | 26 | 22 ± 3 | 19 | 4 | 57% |
| text-function-gap:G1 | T3a PG+ASE | 25,000 | 25,000 | 1.0 | 205 | 202 ± 4 | 193 | 8 | 114% |
| text-function-gap:G1 | T4 PG+PG | 25,000 | 25,000 | 1.0 | 211 | 203 ± 5 | 195 | 7 | 100% |
| text-function-gap:G1 | T5 IQ | 5,000,000 | 5,000,000 | 1.0 | 4,870 | 4,829 ± 20 | 4,760 | 20 | 286% |
| text-function-gap:G1 | T6 IQ+PG | 5,000,000 | 5,000,000 | 1.0 | 4,840 | 4,845 ± 18 | 4,750 | 16 | 229% |
| text-function-gap:G1 | T7 PG+IQ | 25,000 | 25,000 | 1.0 | 214 | 209 ± 5 | 202 | 7 | 100% |
| text-function-gap:G2 | T1 ASE | 5,000,000 | 5,000,000 | 1.0 | 1,720 | 1,701 ± 14 | 1,690 | 3 | 43% |
| text-function-gap:G2 | T2 PG | 5,000,000 | 5,000,000 | 1.0 | 788 | 789 ± 14 | 761 | 7 | 100% |
| text-function-gap:G2 | T3 ASE+PG | 5,000,000 | 5,000,000 | 1.0 | 1,700 | 1,713 ± 14 | 1,700 | 4 | 57% |
| text-function-gap:G2 | T3a PG+ASE | 5,000,000 | 5,000,000 | 1.0 | 791 | 781 ± 11 | 747 | 8 | 114% |
| text-function-gap:G2 | T4 PG+PG | 5,000,000 | 5,000,000 | 1.0 | 764 | 775 ± 15 | 750 | 7 | 100% |
| text-function-gap:G2 | T5 IQ | 5,000,000 | 5,000,000 | 1.0 | 4,900 | 4,855 ± 44 | 4,810 | 18 | 257% |
| text-function-gap:G2 | T6 IQ+PG | 5,000,000 | 5,000,000 | 1.0 | 4,910 | 4,956 ± 42 | 4,860 | 18 | 257% |
| text-function-gap:G2 | T7 PG+IQ | 5,000,000 | 5,000,000 | 1.0 | 801 | 788 ± 6 | 775 | 7 | 100% |
| text-function-gap:G3 | T1 ASE | 5,000,000 | 5,000,000 | 1.0 | 1,700 | 1,701 ± 13 | 1,690 | 3 | 43% |
| text-function-gap:G3 | T2 PG | 5,000,000 | 5,000,000 | 1.0 | 757 | 757 ± 10 | 739 | 7 | 100% |
| text-function-gap:G3 | T3 ASE+PG | 5,000,000 | 5,000,000 | 1.0 | 1,740 | 1,705 ± 5 | 1,690 | 3 | 43% |
| text-function-gap:G3 | T3a PG+ASE | 5,000,000 | 5,000,000 | 1.0 | 771 | 759 ± 8 | 751 | 7 | 100% |
| text-function-gap:G3 | T4 PG+PG | 5,000,000 | 5,000,000 | 1.0 | 748 | 764 ± 10 | 747 | 7 | 100% |
| text-function-gap:G3 | T5 IQ | 5,000,000 | 5,000,000 | 1.0 | 4,780 | 4,809 ± 18 | 4,770 | 16 | 229% |
| text-function-gap:G3 | T6 IQ+PG | 5,000,000 | 5,000,000 | 1.0 | 4,970 | 4,938 ± 16 | 4,900 | 19 | 271% |
| text-function-gap:G3 | T7 PG+IQ | 5,000,000 | 5,000,000 | 1.0 | 791 | 773 ± 11 | 760 | 8 | 114% |
| multikey-semijoin:M1 | T1 ASE | 5,000,200 | 1 | 5000200.0 | 1,260 | 19 ± 1 | 17 | 3 | 75% |
| multikey-semijoin:M1 | T2 PG | 5,000,200 | 1 | 5000200.0 | 1,070 | 17 ± 2 | 14 | 7 | 175% |
| multikey-semijoin:M1 | T3 ASE+PG | 5,000,200 | 20,100 | 248.8 | 1,420 | 99 ± 2 | 94 | 4 | 100% |
| multikey-semijoin:M1 | T3a PG+ASE | 5,000,200 | 20,100 | 248.8 | 1,060 | 34 ± 3 | 29 | 4 | 100% |
| multikey-semijoin:M1 | T4 PG+PG | 5,000,200 | 20,100 | 248.8 | 1,080 | 31 ± 1 | 28 | 4 | 100% |
| multikey-semijoin:M1 | T5 IQ | 5,000,200 | 1 | 5000200.0 | 4,200 | 57 ± 4 | 48 | 9 | 225% |
| multikey-semijoin:M1 | T6 IQ+PG | 5,000,200 | 20,100 | 248.8 | 4,220 | 85 ± 10 | 70 | 4 | 100% |
| multikey-semijoin:M1 | T7 PG+IQ | 5,000,200 | 20,100 | 248.8 | 1,110 | 60 ± 2 | 52 | 4 | 100% |
| multikey-semijoin:M2 | T1 ASE | 5,000,200 | 1 | 5000200.0 | 1,270 | 23 ± 3 | 20 | 5 | 50% |
| multikey-semijoin:M2 | T2 PG | 5,000,200 | 1 | 5000200.0 | 1,070 | 17 ± 2 | 14 | 9 | 90% |
| multikey-semijoin:M2 | T3 ASE+PG | 5,000,200 | 20,100 | 248.8 | 1,270 | 100 ± 3 | 95 | 10 | 100% |
| multikey-semijoin:M2 | T3a PG+ASE | 5,000,200 | 20,100 | 248.8 | 1,040 | 34 ± 2 | 30 | 6 | 60% |
| multikey-semijoin:M2 | T4 PG+PG | 5,000,200 | 20,100 | 248.8 | 1,120 | 34 ± 2 | 29 | 10 | 100% |
| multikey-semijoin:M2 | T5 IQ | 5,000,200 | 1 | 5000200.0 | 4,200 | 62 ± 4 | 54 | 12 | 120% |
| multikey-semijoin:M2 | T6 IQ+PG | 5,000,200 | 20,100 | 248.8 | 4,250 | 89 ± 7 | 74 | 10 | 100% |
| multikey-semijoin:M2 | T7 PG+IQ | 5,000,200 | 20,100 | 248.8 | 1,090 | 65 ± 2 | 58 | 8 | 80% |
| multikey-semijoin:M3 | T1 ASE | 5,000,200 | 5,000,200 | 1.0 | 1,250 | 1,242 ± 4 | 1,240 | 5 | 125% |
| multikey-semijoin:M3 | T2 PG | 5,000,200 | 5,000,200 | 1.0 | 696 | 702 ± 9 | 682 | 4 | 100% |
| multikey-semijoin:M3 | T3 ASE+PG | 5,000,200 | 5,000,200 | 1.0 | 1,290 | 1,256 ± 22 | 1,220 | 4 | 100% |
| multikey-semijoin:M3 | T3a PG+ASE | 5,000,200 | 5,000,200 | 1.0 | 704 | 699 ± 14 | 677 | 4 | 100% |
| multikey-semijoin:M3 | T4 PG+PG | 5,000,200 | 5,000,200 | 1.0 | 719 | 700 ± 5 | 682 | 4 | 100% |
| multikey-semijoin:M3 | T5 IQ | 5,000,200 | 5,000,200 | 1.0 | 3,770 | 3,766 ± 37 | 3,700 | 4 | 100% |
| multikey-semijoin:M3 | T6 IQ+PG | 5,000,200 | 5,000,200 | 1.0 | 3,750 | 3,767 ± 34 | 3,690 | 4 | 100% |
| multikey-semijoin:M3 | T7 PG+IQ | 5,000,200 | 5,000,200 | 1.0 | 724 | 726 ± 9 | 708 | 4 | 100% |
| multikey-semijoin:M4 | T1 ASE | 5,000,200 | 5,000,200 | 1.0 | 1,320 | 1,275 ± 26 | 1,250 | 7 | 64% |
| multikey-semijoin:M4 | T2 PG | 5,000,200 | 5,000,200 | 1.0 | 1,100 | 1,109 ± 18 | 1,080 | 11 | 100% |
| multikey-semijoin:M4 | T3 ASE+PG | 5,000,200 | 5,000,200 | 1.0 | 1,250 | 1,277 ± 25 | 1,250 | 11 | 100% |
| multikey-semijoin:M4 | T3a PG+ASE | 5,000,200 | 5,000,200 | 1.0 | 1,120 | 1,117 ± 24 | 1,090 | 6 | 55% |
| multikey-semijoin:M4 | T4 PG+PG | 5,000,200 | 5,000,200 | 1.0 | 1,110 | 1,105 ± 13 | 1,080 | 11 | 100% |
| multikey-semijoin:M4 | T5 IQ | 5,000,200 | 5,000,200 | 1.0 | 4,220 | 4,274 ± 37 | 4,180 | 11 | 100% |
| multikey-semijoin:M4 | T6 IQ+PG | 5,000,200 | 5,000,200 | 1.0 | 4,290 | 4,254 ± 28 | 4,210 | 11 | 100% |
| multikey-semijoin:M4 | T7 PG+IQ | 5,000,200 | 5,000,200 | 1.0 | 1,160 | 1,233 ± 12 | 1,210 | 11 | 100% |
| distinct-agg-star:DA1 | T1 ASE | 5,000,000 | 5,000,000 | 1.0 | 1,730 | 1,722 ± 31 | 1,680 | 2 | 100% |
| distinct-agg-star:DA1 | T2 PG | 5,000,000 | 5,000,000 | 1.0 | 861 | 842 ± 13 | 822 | 2 | 100% |
| distinct-agg-star:DA1 | T3 ASE+PG | 5,000,000 | 5,000,000 | 1.0 | 1,740 | 1,709 ± 17 | 1,690 | 2 | 100% |
| distinct-agg-star:DA1 | T3a PG+ASE | 5,000,000 | 5,000,000 | 1.0 | 834 | 836 ± 13 | 810 | 2 | 100% |
| distinct-agg-star:DA1 | T4 PG+PG | 5,000,000 | 5,000,000 | 1.0 | 867 | 835 ± 11 | 809 | 2 | 100% |
| distinct-agg-star:DA1 | T5 IQ | 5,000,000 | 5,000,000 | 1.0 | 4,890 | 4,918 ± 86 | 4,810 | 2 | 100% |
| distinct-agg-star:DA1 | T6 IQ+PG | 5,000,000 | 5,000,000 | 1.0 | 4,840 | 4,897 ± 55 | 4,810 | 2 | 100% |
| distinct-agg-star:DA1 | T7 PG+IQ | 5,000,000 | 5,000,000 | 1.0 | 840 | 837 ± 11 | 823 | 2 | 100% |
| distinct-agg-star:DA2 | T1 ASE | 5,000,000 | 1 | 5000000.0 | 12,600 | 12,689 ± 118 | 12,530 | 3 | 100% |
| distinct-agg-star:DA2 | T2 PG | 5,000,000 | 5,000,000 | 1.0 | 874 | 875 ± 20 | 851 | 3 | 100% |
| distinct-agg-star:DA2 | T3 ASE+PG | 5,000,000 | 1 | 5000000.0 | 12,550 | 12,680 ± 61 | 12,520 | 2 | 67% |
| distinct-agg-star:DA2 | T3a PG+ASE | 5,000,000 | 5,000,000 | 1.0 | 839 | 843 ± 16 | 817 | 3 | 100% |
| distinct-agg-star:DA2 | T4 PG+PG | 5,000,000 | 5,000,000 | 1.0 | 856 | 870 ± 18 | 847 | 3 | 100% |
| distinct-agg-star:DA2 | T5 IQ | 5,000,000 | 1 | 5000000.0 | 4,060 | 73 ± 5 | 63 | 7 | 233% |
| distinct-agg-star:DA2 | T6 IQ+PG | 5,000,000 | 1 | 5000000.0 | 3,940 | 69 ± 5 | 58 | 7 | 233% |
| distinct-agg-star:DA2 | T7 PG+IQ | 5,000,000 | 5,000,000 | 1.0 | 849 | 843 ± 22 | 825 | 3 | 100% |
