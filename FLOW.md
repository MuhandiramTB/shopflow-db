# ShopFlow Database — Full Demo & Evaluation Guide
**Author: Thilan Buddhika | MuhandiramTB/shopflow-db**

> No psql needed. Every step is a simple `node <file>.js` command.

---

## One-Time Setup

```bash
# Open terminal and go to the project folder
cd "d:/Month 3/shopflow-db"

# Install the database driver (only needed once)
npm install pg
```

---

## PART 1 — FRESH START (Reset & Full Rebuild)

Run these 6 steps in order from top to bottom.

---

### Step 1 — Reset Database

Wipes the entire database clean (drops all tables).

```bash
node reset-db.js
```

Expected:
```
Connected to Neon
Database reset — all tables dropped, schema recreated clean
```

---

### Step 2 — Create All 13 Tables + Indexes

```bash
node run-sql.js thilan-month3-migrations.sql
```

Expected:
```
✓ Connected to Neon
  Running: thilan-month3-migrations.sql
  [CREATE]   ← repeated 62 times (tables + indexes)
  [DO]       ← triggers created
  [SELECT 0] ← 10 complex queries executed
============================================================
  ✓ Success: 72  ✗ Failed: 0  - Skipped: 0
============================================================
```

---

### Step 3 — Load Seed Data

```bash
node run-sql.js thilan-month3-seed.sql
```

Expected at the end:
```
  tbl               rows
  categories        50
  users             1000
  products          500
  inventory         2000
  orders            5000
  ...
============================================================
  ✓ Success: 23  ✗ Failed: 2  - Skipped: 0
============================================================
```

> The 2 failures are known edge cases in UPDATE statements — fixed in Step 4.

---

### Step 4 — Fix Orders, Inventory & Reviews

```bash
node fix-data.js
```

Expected:
```
Connected to Neon

Orders fixed: 5000 rows
Inventory reserved fixed: X rows
Reviews inserted: 3000 rows

All fixes applied successfully!
```

---

### Step 5 — Fix Order Items Distribution

Ensures all 5000 orders have realistic random products (not the same one).

```bash
node fix-order-items.js
```

Expected:
```
Connected to Neon

Loaded 2000 variants and 950 users
Randomizing order user_ids...
Order user_ids randomized
Cleared old order_items and reviews

  Progress: order 1000 / 5000 | items so far: 2750
  Progress: order 2000 / 5000 | items so far: 5512
  Progress: order 3000 / 5000 | items so far: 8278
  Progress: order 4000 / 5000 | items so far: 11044

Total order_items inserted: ~13700
Reviews inserted: 3000 rows

Done!
```

---

### Step 6 — Generate ERD PNG

```bash
node generate-erd.js
```

Expected:
```
Reading ERD source from thilan-month3-erd.md...
Mermaid block extracted OK
Generating PNG...
Generating single mermaid chart

thilan-month3-erd.png generated successfully (328 KB)
```

---

### Step 7 — Verify Final Row Counts

```bash
node demo.js 3
```

Expected:
```
  table             | rows
  ------------------+-------
  users             | 1000
  categories        | 50
  products          | 500
  product_variants  | 2000
  inventory         | 2000
  orders            | 5000
  order_items       | ~13700
  reviews           | 3000
  carts             | 1000
  cart_items        | 1200
  wishlists         | 2238
  promotions        | 20
```

---

## PART 2 — EVALUATION DEMO

### 1. Connection Test
```bash
node demo.js 1
```
Shows: database name, user, PostgreSQL version

---

### 2. Show All 13 Tables
```bash
node demo.js 2
```
Shows: each table with column count and index count

---

### 3. Row Counts
```bash
node demo.js 3
```
Shows: all 12 tables with record counts

---

### 4. Prove Constraints Work
```bash
node demo.js 4
```
Runs 4 tests — each shows **✓ Constraint enforced!**
- FK violation (foreign product ID that does not exist)
- CHECK violation (negative price)
- UNIQUE violation (duplicate email)
- CHECK violation (rating outside 1–5)

---

### 5. Run All 10 Complex Queries
```bash
node demo.js queries
```

Or run one at a time to explain each:

```bash
node demo.js q1    # Top selling products    — JOIN x4, SUM, RANK() window
node demo.js q2    # Customer lifetime value — CTE, NTILE() window
node demo.js q3    # Low stock alert         — 3-table JOIN, computed column
node demo.js q4    # Review statistics       — FILTER clause, AVG, LEFT JOIN
node demo.js q5    # Cart abandonment        — subquery aggregate, DATE_TRUNC
node demo.js q6    # Order status breakdown  — SUM OVER() percentage of total
node demo.js q7    # Category hierarchy      — RECURSIVE CTE with path building
node demo.js q8    # Purchase history        — running total + ROW_NUMBER window
node demo.js q9    # Promotion usage         — LEFT JOIN promotions → orders
node demo.js q10   # Monthly revenue         — LAG() for month-over-month growth %
```

---

### 6. Optimization Demo — EXPLAIN ANALYZE
```bash
node demo.js explain
```
Shows:
- **BEFORE** → `Seq Scan` highlighted in **red** (reads all 5000 rows)
- **AFTER** → `Index Scan` highlighted in **green** (uses index, fast)
- Full list of all 25+ indexes

---

### 7. Database Size & Stats
```bash
node demo.js stats
```
Shows total DB size and per-table storage sizes.

---

### Full Demo (Everything at Once)
```bash
node demo.js all
```
Runs all steps in order — takes about 20 seconds.

---

## PART 3 — EVALUATION CHECKLIST

| Criteria | Points | How to Show | What Evaluators See |
|---|---|---|---|
| Schema Design | 25 | `node demo.js 2` | 13 tables, normalized, all columns visible |
| Migration Quality | 20 | `node run-sql.js thilan-month3-migrations.sql` | 72 statements, 0 failures, indexes listed |
| Query Complexity | 25 | `node demo.js queries` | JOINs, CTEs, window functions, aggregations |
| Optimization | 20 | `node demo.js explain` | Seq Scan → Index Scan, 25+ indexes |
| Documentation | 10 | ERD PNG + GitHub + optimization report | All 4 files present |

**Total: 100 points**

---

## PART 4 — QUICK REFERENCE

### All Scripts
```bash
node reset-db.js                            # Wipe database
node run-sql.js thilan-month3-migrations.sql  # Create tables + indexes
node run-sql.js thilan-month3-seed.sql        # Load seed data
node fix-data.js                            # Fix orders + inventory + reviews
node fix-order-items.js                     # Fix order items distribution
node generate-erd.js                        # Generate ERD PNG
```

### All Demo Commands
```bash
node demo.js 1        # Connection test
node demo.js 2        # 13 tables
node demo.js 3        # Row counts
node demo.js 4        # Constraint tests
node demo.js q1       # Query 1
node demo.js q2       # Query 2
node demo.js q3       # Query 3
node demo.js q4       # Query 4
node demo.js q5       # Query 5
node demo.js q6       # Query 6
node demo.js q7       # Query 7 — Recursive CTE
node demo.js q8       # Query 8 — Window functions
node demo.js q9       # Query 9
node demo.js q10      # Query 10 — LAG() growth
node demo.js queries  # All 10 queries
node demo.js explain  # EXPLAIN ANALYZE optimization
node demo.js stats    # DB size stats
node demo.js all      # Everything
```

### Full Reset & Rebuild (Copy-Paste Ready)
```bash
node reset-db.js
node run-sql.js thilan-month3-migrations.sql
node run-sql.js thilan-month3-seed.sql
node fix-data.js
node fix-order-items.js
node generate-erd.js
node demo.js 3
```

---

## Project Files

| File | Purpose |
|---|---|
| `reset-db.js` | Wipes the database clean |
| `run-sql.js` | Runs any .sql file against Neon |
| `fix-data.js` | Fixes orders total_amount, inventory reserved, inserts reviews |
| `fix-order-items.js` | Inserts 13K+ order items with proper random distribution |
| `generate-erd.js` | Generates thilan-month3-erd.png from Mermaid source |
| `demo.js` | Colored terminal demo runner for all steps and queries |
| `thilan-month3-migrations.sql` | 13 tables + 25 indexes + 10 complex queries |
| `thilan-month3-seed.sql` | Realistic test data (1K users, 5K orders, 13K+ items) |
| `thilan-month3-optimization-report.md` | 5 queries optimized with 89–96% improvement |
| `thilan-month3-erd.png` | ERD diagram — all 13 tables and relationships |
| `thilan-month3-erd.md` | Mermaid source for ERD |

---

## GitHub Repository
```
https://github.com/MuhandiramTB/shopflow-db
```

## Neon Database
```
Host:     ep-ancient-rain-aog95fmq-pooler.c-2.ap-southeast-1.aws.neon.tech
Database: neondb
User:     neondb_owner
```
