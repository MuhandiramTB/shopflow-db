# ShopFlow E-Commerce Platform — Database Design & Optimization
**Month 3 Challenge | Author: Thilan Buddhika | [MuhandiramTB](https://github.com/MuhandiramTB)**

---

## Project Overview

Fully normalized PostgreSQL database for a large-scale e-commerce platform supporting 10K+ products, 50K+ users and 100K+ orders. Includes schema design, migration scripts, complex analytical queries, seed data and query optimization.

---

## Submission Files

| File | Description |
|---|---|
| `thilan-month3-migrations.sql` | 13 tables, 25+ indexes, FK/CHECK constraints, triggers, 10 complex queries |
| `thilan-month3-seed.sql` | Realistic test data — 1K users, 500 products, 5K orders, 13K+ order items |
| `thilan-month3-optimization-report.md` | 5 queries optimized with EXPLAIN ANALYZE — 89–96% improvement each |
| `thilan-month3-erd.png` | ERD diagram — all 13 tables with relationships |

---

## Schema — 13 Tables

```
users ──────── addresses
  │
  ├── orders ──────── order_items ──── product_variants ──── inventory
  │      │                                   │
  │   promotions                   products ─┤──── categories (hierarchical)
  │                                          │
  ├── reviews                                └──── wishlists
  │
  └── carts ──────── cart_items ──── product_variants
```

| Table | Purpose |
|---|---|
| `users` | Customer and admin accounts |
| `addresses` | Shipping and billing addresses |
| `categories` | Hierarchical product taxonomy (self-referencing) |
| `products` | Master product catalog |
| `product_variants` | Size, color, material variations per product |
| `inventory` | Real-time stock levels per variant |
| `carts` | Shopping sessions (logged-in and guest) |
| `cart_items` | Products in a cart |
| `promotions` | Discount codes and rules |
| `orders` | Placed customer orders |
| `order_items` | Denormalized line items per order |
| `reviews` | Product ratings and text reviews |
| `wishlists` | Saved products per user |

---

## 10 Complex Queries

| # | Query | Techniques Used |
|---|---|---|
| 1 | Top selling products by category | JOIN x4, SUM, RANK() OVER |
| 2 | Customer lifetime value | CTE, AVG, NTILE() window |
| 3 | Low stock inventory alert | 3-table JOIN, computed column |
| 4 | Review statistics per product | FILTER clause, LEFT JOIN, AVG |
| 5 | Cart abandonment analysis | Subquery aggregate, DATE_TRUNC |
| 6 | Order status breakdown | SUM OVER() for % of total |
| 7 | Category hierarchy with counts | **Recursive CTE** |
| 8 | User purchase history | **Running total**, ROW_NUMBER window |
| 9 | Promotion usage report | LEFT JOIN, CASE expression |
| 10 | Monthly revenue with growth % | **LAG()** for MoM comparison |

---

## Quick Start (No psql needed)

```bash
# 1. Clone the repo
git clone https://github.com/MuhandiramTB/shopflow-db.git
cd shopflow-db

# 2. Install dependencies
npm install pg

# 3. Reset → Migrate → Seed → Fix
node reset-db.js
node run-sql.js thilan-month3-migrations.sql
node run-sql.js thilan-month3-seed.sql
node fix-data.js
node fix-order-items.js

# 4. Verify row counts
node demo.js 3
```

---

## Demo Runner

```bash
node demo.js all        # Full demo — all steps
node demo.js 1          # Connection test
node demo.js 2          # Show 13 tables
node demo.js 3          # Row counts
node demo.js 4          # Constraint tests
node demo.js queries    # All 10 complex queries
node demo.js q7         # Recursive CTE category hierarchy
node demo.js q10        # Monthly revenue with LAG() growth %
node demo.js explain    # EXPLAIN ANALYZE — before vs after optimization
node demo.js stats      # Database size and table stats
```

---

## Helper Scripts

| Script | What it does |
|---|---|
| `reset-db.js` | Drops all tables, recreates clean schema |
| `run-sql.js` | Executes any .sql file against the database |
| `fix-data.js` | Fixes orders total_amount, inventory reserved, inserts reviews |
| `fix-order-items.js` | Inserts 13K+ order items with proper random distribution |
| `generate-erd.js` | Generates `thilan-month3-erd.png` from Mermaid source |
| `demo.js` | Colored terminal demo runner for evaluation |

---

## Database Stats

| Metric | Value |
|---|---|
| Tables | 13 |
| Indexes | 25+ |
| Users | 1,000 |
| Products | 500 |
| Variants | 2,000 |
| Orders | 5,000 |
| Order Items | 13,700+ |
| Reviews | 3,000 |

---

## Tech Stack

- **Database:** PostgreSQL 17 (hosted on [Neon](https://neon.tech))
- **Client:** Node.js + `pg` driver
- **ERD:** Mermaid → PNG via `@mermaid-js/mermaid-cli`
