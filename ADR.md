# Architecture Decision Records — ShopFlow Database
**Project:** ShopFlow E-Commerce Platform
**Author:** Thilan Buddhika
**Date:** 2026-04-28

> An ADR captures every important design decision — what was decided, why, and what alternatives were rejected.

---

## ADR-001 — Use PostgreSQL as the Database Engine

**Status:** Accepted

**Context:**
ShopFlow needs a database that supports complex relationships, enforces data integrity, handles financial data accurately, and scales to 100K+ orders.

**Decision:**
Use PostgreSQL 17.

**Reasons:**
- ACID transactions — if payment fails, the order must not be created
- Foreign key constraints — no orphan order items possible
- DECIMAL type — exact money arithmetic, no floating-point rounding errors
- Window functions, CTEs, recursive queries — needed for analytics
- Mature, battle-tested, widely used in e-commerce production systems

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| MySQL | Weaker support for window functions and recursive CTEs |
| MongoDB | Schema-less — no FK enforcement, risky for financial data |
| SQLite | Not suitable for multi-user concurrent access at scale |

---

## ADR-002 — Use Neon for Cloud Hosting Instead of Local PostgreSQL

**Status:** Accepted

**Context:**
Local PostgreSQL installation on Windows via binary zip required manual PATH configuration, data directory initialization, and service setup. Multiple attempts failed to complete the setup.

**Decision:**
Use Neon — free cloud-hosted PostgreSQL — connected via connection string from Node.js.

**Reasons:**
- No local installation required
- PostgreSQL 17 available immediately
- Free tier sufficient for development and testing
- Closer to real production environments — databases are always hosted, not local
- Connection string works directly with the `pg` Node.js driver

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| Local PostgreSQL (binary zip) | Manual setup failed — PATH, data dir, service config |
| Local PostgreSQL (installer) | Download incomplete at time of setup |
| Docker + PostgreSQL | Docker not available on this machine |
| Supabase | Neon was faster to set up |

**Consequence:**
All scripts use a hardcoded Neon connection string. In a real project this would be stored in an environment variable (`.env` file).

---

## ADR-003 — Self-Referencing Table for Category Hierarchy

**Status:** Accepted

**Context:**
Products belong to categories. Categories have parent categories (e.g. Electronics > Audio > Headphones). The depth of the hierarchy is not fixed.

**Decision:**
Use a single `categories` table with a `parent_id` column that references its own `id` (self-referencing foreign key). Query it with a Recursive CTE.

```sql
CREATE TABLE categories (
    id        SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES categories(id),
    name      VARCHAR(150) NOT NULL
);
```

**Reasons:**
- Supports unlimited depth — no schema change needed to add deeper levels
- Single table — simpler to query, maintain and seed
- Recursive CTE handles any depth in one SQL statement
- Industry standard pattern for tree-structured data

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| Separate tables per level (Level1Category, Level2Category) | Schema must change every time a new depth is added |
| Nested sets model | Complex to insert/update, harder to understand |
| Closure table | Requires a separate relationship table — more complexity |

---

## ADR-004 — Denormalize Product Name in order_items

**Status:** Accepted

**Context:**
`order_items` links to `product_variants` via `variant_id`. If the product name or SKU changes after an order is placed, the order history would show the new name — not what the customer actually bought.

**Decision:**
Store `product_name`, `variant_name`, and `sku` as snapshot columns directly in `order_items` at the time the order is placed.

```sql
CREATE TABLE order_items (
    ...
    product_name  VARCHAR(255) NOT NULL,  -- snapshot at order time
    variant_name  VARCHAR(255) NOT NULL,
    sku           VARCHAR(100) NOT NULL,
    ...
);
```

**Reasons:**
- Orders are historical records — they must reflect what was purchased, not current product data
- Protects against product edits, renames, or deletions affecting order history
- Legal and accounting requirement in most jurisdictions
- Standard practice in e-commerce (Shopify, WooCommerce use the same pattern)

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| Only store variant_id, join at query time | Order history breaks if product is edited or deleted |
| Store full product JSON snapshot | Too much storage, harder to query specific fields |

---

## ADR-005 — Separate quantity and reserved in inventory

**Status:** Accepted

**Context:**
When a customer places an order, stock should be held for them immediately — even before the order is shipped. Two customers must not be able to buy the last item simultaneously.

**Decision:**
Use two columns in `inventory`: `quantity` (total stock) and `reserved` (held for pending orders). Available stock = `quantity - reserved`.

```sql
CREATE TABLE inventory (
    variant_id          INTEGER UNIQUE NOT NULL,
    quantity            INTEGER NOT NULL DEFAULT 0,
    reserved            INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT inv_reserved_lte_qty CHECK (reserved <= quantity)
);
```

**Reasons:**
- Prevents overselling without locking rows
- `reserved` increases when order is placed, decreases when order ships
- CHECK constraint enforces `reserved <= quantity` at database level
- Clear separation between total stock and available stock

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| Decrement quantity immediately at order time | Quantity goes negative if order is cancelled |
| Application-level locking | Race conditions possible under concurrent load |
| Single available_quantity column | No way to distinguish total vs available |

---

## ADR-006 — Support Guest Carts via session_id

**Status:** Accepted

**Context:**
Customers should be able to add products to a cart without creating an account. When they later log in, the cart should merge with their account.

**Decision:**
The `carts` table accepts either a `user_id` (logged-in) or a `session_id` (guest). A CHECK constraint ensures at least one is always present.

```sql
CREATE TABLE carts (
    user_id    INTEGER REFERENCES users(id),
    session_id VARCHAR(255),
    CONSTRAINT cart_owner CHECK (user_id IS NOT NULL OR session_id IS NOT NULL)
);
```

**Reasons:**
- Reduces friction — customers browse and add to cart before registering
- Industry standard (Amazon, every major e-commerce site does this)
- Merge logic: when guest logs in, copy cart_items to user's cart, mark guest cart as `merged`

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| Require login before adding to cart | High friction — increases bounce rate |
| Separate guest_carts table | Duplicate logic, harder to maintain |

---

## ADR-007 — Use Node.js Scripts Instead of psql for Database Operations

**Status:** Accepted

**Context:**
`psql` (PostgreSQL command-line client) was not available — local PostgreSQL installation failed. All database operations needed to run without psql.

**Decision:**
Write all database tooling in Node.js using the `pg` driver — migration runner, seed runner, fix scripts, and demo runner.

**Scripts created:**

| Script | Purpose |
|---|---|
| `reset-db.js` | Drop and recreate schema |
| `run-sql.js` | Execute any .sql file statement by statement |
| `fix-data.js` | Patch data edge cases after seeding |
| `fix-order-items.js` | Insert order items with proper randomization |
| `generate-erd.js` | Generate ERD PNG from Mermaid source |
| `demo.js` | Colored terminal demo for evaluation |

**Reasons:**
- Node.js already available on the machine
- `pg` driver connects to Neon directly via connection string
- JavaScript gives full control over randomization (solved the seed data bug)
- Scripts are readable, maintainable, and version controlled

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| psql | Not installed — local PostgreSQL setup failed |
| pgAdmin GUI | Available but not scriptable for automation |
| Python + psycopg2 | Node.js already set up and available |

---

## ADR-008 — Fix Seed Data Randomization in Node.js Instead of SQL

**Status:** Accepted

**Context:**
The original SQL seed script used `ORDER BY random() LIMIT 1` inside a subquery to select a random product variant for each order item. PostgreSQL optimized the subquery to execute only once — resulting in all 13,000 order items having the same product.

**Decision:**
Move order item generation to `fix-order-items.js`. Use JavaScript's `Math.random()` to select random variants per order. Batch insert in groups of 500 rows.

**Reasons:**
- `Math.random()` is called fresh for every order — truly random per row
- Full control over distribution — items per order, unique variants per order
- Batch inserts of 500 rows — efficient for 13,000+ rows
- Separating data generation from SQL migrations is cleaner architecture

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| Fix SQL subquery with LATERAL | PostgreSQL still optimizes volatile functions in some cases |
| Use generate_series with complex SQL | Hard to control distribution and uniqueness per order |

**Lesson Learned:**
> SQL query optimizers treat subqueries that don't reference the outer query as constant — even if they contain `random()`. Always validate seed data distribution before using it.

---

## ADR-009 — Partial Indexes for Active Records and Low Stock

**Status:** Accepted

**Context:**
Most queries filter on `is_active = true` for products and variants, or `quantity < threshold` for inventory. Full indexes on these columns include inactive/normal rows that queries never touch.

**Decision:**
Use partial indexes with WHERE clauses.

```sql
CREATE INDEX idx_products_active   ON products(is_active) WHERE is_active = true;
CREATE INDEX idx_variants_active   ON product_variants(is_active) WHERE is_active = true;
CREATE INDEX idx_inventory_low     ON inventory(quantity) WHERE quantity < 10;
```

**Reasons:**
- Smaller index — only covers rows queries actually use
- Faster scans — less data to read from disk
- Lower storage cost
- PostgreSQL uses partial indexes automatically when WHERE clause matches

**Alternatives Rejected:**

| Alternative | Why Rejected |
|---|---|
| Full index on is_active | Includes inactive rows — larger, slower |
| No index, rely on sequential scan | Too slow at 500+ products, 2000+ variants |

---

## Summary Table

| ADR | Decision | Key Reason |
|---|---|---|
| ADR-001 | PostgreSQL | ACID, FK constraints, DECIMAL for money |
| ADR-002 | Neon cloud hosting | Local install failed, production-like setup |
| ADR-003 | Self-referencing categories | Unlimited hierarchy depth, no schema changes |
| ADR-004 | Denormalize order_items | Historical accuracy of orders |
| ADR-005 | quantity + reserved in inventory | Prevent overselling |
| ADR-006 | Guest carts via session_id | Reduce friction before login |
| ADR-007 | Node.js scripts over psql | psql not available, full scripting control |
| ADR-008 | JS randomization for seed data | SQL optimizer collapsed random() to one call |
| ADR-009 | Partial indexes | Smaller, faster indexes for filtered queries |
