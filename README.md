# ShopFlow E-Commerce Platform — Database Design Challenge
**Month 3 | Author: Thilan Buddhika**

## Deliverables

| File | Description |
|---|---|
| `thilan-month3-migrations.sql` | All 13 table DDL + indexes + 10 complex queries |
| `thilan-month3-seed.sql` | 1K users, 500 products, 5K orders, 15K order items |
| `thilan-month3-optimization-report.md` | 5 query optimizations with before/after analysis |
| `thilan-month3-erd.md` | ERD in Mermaid (paste into mermaid.live → export PNG) |

## Quick Start

```bash
# 1. Create database
createdb shopflow

# 2. Run migrations (creates all tables + indexes + queries)
psql -d shopflow -f thilan-month3-migrations.sql

# 3. Load seed data (~30 seconds)
psql -d shopflow -f thilan-month3-seed.sql

# 4. Verify row counts (last query in seed file)
psql -d shopflow -c "SELECT tbl, rows FROM (
  SELECT 'users' AS tbl, COUNT(*) AS rows FROM users
  UNION ALL SELECT 'orders', COUNT(*) FROM orders
  UNION ALL SELECT 'products', COUNT(*) FROM products
) t ORDER BY tbl;"
```

## Schema Overview (13 tables)

```
users ──── addresses
  │
  ├── orders ──── order_items ──── product_variants ──── inventory
  │      │                              │
  │   promotions              products ─┤── categories (hierarchical)
  │                                     │
  ├── reviews                           └── wishlists
  │
  └── carts ──── cart_items ──── product_variants
```

## Tech Stack
- **Database:** PostgreSQL 15+
- **Extensions:** `pgcrypto`, `pg_trgm` (for full-text search)
