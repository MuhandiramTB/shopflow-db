// ShopFlow Database Demo Runner
// Usage: node demo.js [step]
// Examples:
//   node demo.js          <- runs all steps
//   node demo.js 1        <- Step 1: verify connection
//   node demo.js 3        <- Step 3: row counts
//   node demo.js q1       <- Query 1: top selling products
//   node demo.js explain  <- Optimization demo

const { Client } = require('pg');

const DB = "postgresql://neondb_owner:npg_lYz6r9AJHiFm@ep-ancient-rain-aog95fmq-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require";

// ─── Colors ──────────────────────────────────────────────────────────────────
const C = {
  reset: '\x1b[0m',   bold: '\x1b[1m',    dim: '\x1b[2m',
  green: '\x1b[32m',  cyan: '\x1b[36m',   yellow: '\x1b[33m',
  red: '\x1b[31m',    blue: '\x1b[34m',   magenta: '\x1b[35m',
  white: '\x1b[37m',  bgBlue: '\x1b[44m', bgGreen: '\x1b[42m',
};
const g = s => C.green  + s + C.reset;
const y = s => C.yellow + s + C.reset;
const c = s => C.cyan   + s + C.reset;
const r = s => C.red    + s + C.reset;
const b = s => C.bold   + s + C.reset;
const d = s => C.dim    + s + C.reset;
const line  = (ch='─', n=65) => C.dim + ch.repeat(n) + C.reset;
const header = (title, step='') => {
  console.log('\n' + line('═'));
  console.log(C.bold + C.cyan + (step ? `  [${step}] ` : '  ') + title + C.reset);
  console.log(line('─'));
};

// ─── Table printer ───────────────────────────────────────────────────────────
function printTable(rows, maxRows = 20) {
  if (!rows || rows.length === 0) { console.log(d('  (no rows)')); return; }
  const cols = Object.keys(rows[0]);
  const widths = cols.map(c => Math.max(c.length, ...rows.slice(0,maxRows).map(r => String(r[c] ?? '').length)));
  const sep = '  +' + widths.map(w => '-'.repeat(w + 2)).join('+') + '+';
  const rowFmt = row => '  |' + cols.map((c,i) => ' ' + String(row[c] ?? '').padEnd(widths[i]) + ' ').join('|') + '|';
  console.log(d(sep));
  console.log('  |' + cols.map((c,i) => C.bold + C.cyan + ' ' + c.padEnd(widths[i]) + ' ' + C.reset).join('|') + '|');
  console.log(d(sep));
  rows.slice(0, maxRows).forEach(row => console.log(rowFmt(row)));
  console.log(d(sep));
  if (rows.length > maxRows) console.log(d(`  ... and ${rows.length - maxRows} more rows`));
  console.log(g(`  ✓ ${rows.length} row(s) returned`));
}

// ─── Query runner ────────────────────────────────────────────────────────────
async function run(client, sql, label) {
  const start = Date.now();
  try {
    const res = await client.query(sql);
    const ms = Date.now() - start;
    if (label) console.log(d(`  Query: ${label} — ${ms}ms`));
    return res;
  } catch (err) {
    console.log(r(`  ✗ ERROR: ${err.message.split('\n')[0]}`));
    return null;
  }
}

async function expectError(client, sql, label) {
  try {
    await client.query(sql);
    console.log(r('  ✗ Expected error but query succeeded!'));
  } catch (err) {
    console.log(g('  ✓ Constraint enforced!'));
    console.log(y(`  → ${err.message.split('\n')[0]}`));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STEPS
// ═══════════════════════════════════════════════════════════════════════════

async function step1_connection(client) {
  header('DATABASE CONNECTION', 'STEP 1');
  const res = await run(client, `SELECT current_database() AS database, current_user, version()`);
  if (res) printTable(res.rows);
}

async function step2_schema(client) {
  header('SCHEMA — 13 TABLES', 'STEP 2');
  const res = await run(client, `
    SELECT table_name,
           (SELECT COUNT(*) FROM information_schema.columns c
            WHERE c.table_name = t.table_name AND c.table_schema = 'public') AS columns,
           (SELECT COUNT(*) FROM pg_indexes i
            WHERE i.tablename = t.table_name AND i.schemaname = 'public') AS indexes
    FROM information_schema.tables t
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name
  `);
  if (res) printTable(res.rows);
}

async function step3_rowcounts(client) {
  header('SEED DATA — ROW COUNTS', 'STEP 3');
  const tables = ['users','categories','products','product_variants',
                  'inventory','orders','order_items','reviews',
                  'carts','cart_items','wishlists','promotions'];
  const rows = [];
  for (const t of tables) {
    const r = await client.query(`SELECT COUNT(*) FROM ${t}`);
    rows.push({ table: t, rows: r.rows[0].count });
  }
  printTable(rows);
}

async function step4_constraints(client) {
  header('DATA INTEGRITY — CONSTRAINT TESTS', 'STEP 4');

  console.log(b('\n  Test 1: Foreign Key — product_id 9999 does not exist'));
  await expectError(client, `
    INSERT INTO order_items(order_id,variant_id,product_id,product_name,variant_name,sku,quantity,unit_price,total_price)
    VALUES (1,1,9999,'Fake','Fake','FAKE',1,10,10)
  `);

  console.log(b('\n  Test 2: CHECK Constraint — negative price not allowed'));
  await expectError(client, `
    INSERT INTO products(name,slug,base_price) VALUES ('Bad','bad-slug',-50.00)
  `);

  console.log(b('\n  Test 3: UNIQUE Constraint — duplicate email'));
  await expectError(client, `
    INSERT INTO users(email,password_hash,first_name,last_name)
    VALUES ('user1@shopflow-test.com','hash','Test','User')
  `);

  console.log(b('\n  Test 4: CHECK Constraint — rating must be 1–5'));
  await expectError(client, `
    INSERT INTO reviews(product_id,user_id,rating) VALUES (1,1,10)
  `);
}

async function query1(client) {
  header('QUERY 1 — Top Selling Products by Category', 'QUERY');
  console.log(d('  JOINs: order_items → products → categories → orders'));
  console.log(d('  Aggregation: SUM, GROUP BY | Window: RANK() OVER'));
  const res = await run(client, `
    SELECT c.name AS category, p.name AS product,
           SUM(oi.quantity) AS total_sold,
           ROUND(SUM(oi.quantity * oi.unit_price)::NUMERIC, 2) AS revenue,
           RANK() OVER (PARTITION BY c.id ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rank_in_cat
    FROM order_items oi
    JOIN products p   ON oi.product_id = p.id
    JOIN categories c ON p.category_id = c.id
    JOIN orders o     ON oi.order_id   = o.id
    WHERE o.status = 'completed'
    GROUP BY c.id, c.name, p.id, p.name
    ORDER BY revenue DESC LIMIT 10
  `, 'Top products');
  if (res) printTable(res.rows);
}

async function query2(client) {
  header('QUERY 2 — Customer Lifetime Value + Segmentation', 'QUERY');
  console.log(d('  CTE: customer_stats | Aggregation: COUNT, SUM, AVG'));
  console.log(d('  Window: NTILE(4) for quartile ranking'));
  const res = await run(client, `
    WITH customer_stats AS (
      SELECT u.id, u.first_name || ' ' || u.last_name AS full_name,
             COUNT(o.id) AS total_orders,
             ROUND(SUM(o.total_amount)::NUMERIC, 2) AS lifetime_value,
             ROUND(AVG(o.total_amount)::NUMERIC, 2) AS avg_order_value
      FROM users u JOIN orders o ON u.id = o.user_id
      WHERE o.status IN ('completed','delivered')
      GROUP BY u.id, u.first_name, u.last_name
    )
    SELECT full_name, total_orders, lifetime_value, avg_order_value,
           CASE WHEN lifetime_value >= 5000 THEN 'VIP'
                WHEN lifetime_value >= 1000 THEN 'Gold'
                WHEN lifetime_value >= 500  THEN 'Silver'
                ELSE 'Bronze' END AS segment,
           NTILE(4) OVER (ORDER BY lifetime_value DESC) AS quartile
    FROM customer_stats
    ORDER BY lifetime_value DESC LIMIT 10
  `, 'Customer LTV');
  if (res) printTable(res.rows);
}

async function query3(client) {
  header('QUERY 3 — Low Stock Inventory Alert', 'QUERY');
  console.log(d('  JOINs: inventory → product_variants → products'));
  console.log(d('  Filter: available = quantity - reserved <= threshold'));
  const res = await run(client, `
    SELECT p.name AS product, pv.sku, pv.color, pv.size,
           inv.quantity AS stock, inv.reserved,
           inv.quantity - inv.reserved AS available,
           inv.low_stock_threshold AS threshold
    FROM inventory inv
    JOIN product_variants pv ON inv.variant_id = pv.id
    JOIN products p          ON pv.product_id  = p.id
    WHERE (inv.quantity - inv.reserved) <= inv.low_stock_threshold
    ORDER BY available ASC LIMIT 15
  `, 'Low stock');
  if (res) printTable(res.rows);
}

async function query4(client) {
  header('QUERY 4 — Review Statistics per Product', 'QUERY');
  console.log(d('  FILTER clause for conditional COUNT | AVG rating'));
  const res = await run(client, `
    SELECT p.name, COUNT(r.id) AS total_reviews,
           ROUND(AVG(r.rating)::NUMERIC, 2) AS avg_rating,
           COUNT(*) FILTER (WHERE r.rating = 5) AS five_star,
           COUNT(*) FILTER (WHERE r.rating <= 2) AS low_star,
           ROUND(100.0 * COUNT(*) FILTER (WHERE r.rating >= 4)
                 / NULLIF(COUNT(r.id),0), 1) AS positive_pct
    FROM products p
    LEFT JOIN reviews r ON p.id = r.product_id AND r.is_approved = true
    GROUP BY p.id, p.name
    HAVING COUNT(r.id) > 0
    ORDER BY avg_rating DESC LIMIT 10
  `, 'Review stats');
  if (res) printTable(res.rows);
}

async function query5(client) {
  header('QUERY 5 — Cart Abandonment Analysis', 'QUERY');
  console.log(d('  Subquery aggregate on cart_items | Date truncation'));
  const res = await run(client, `
    SELECT DATE_TRUNC('day', c.created_at)::DATE AS date,
           COUNT(*) AS abandoned_carts,
           ROUND(AVG(ci_total.cart_value)::NUMERIC, 2) AS avg_cart_value,
           ROUND(SUM(ci_total.cart_value)::NUMERIC, 2) AS total_lost_revenue
    FROM carts c
    JOIN (SELECT cart_id, SUM(quantity * unit_price) AS cart_value
          FROM cart_items GROUP BY cart_id) ci_total ON c.id = ci_total.cart_id
    WHERE c.status = 'abandoned'
    GROUP BY DATE_TRUNC('day', c.created_at)
    ORDER BY date DESC LIMIT 10
  `, 'Cart abandonment');
  if (res) printTable(res.rows);
}

async function query6(client) {
  header('QUERY 6 — Order Status Breakdown', 'QUERY');
  console.log(d('  Window: SUM OVER() for percentage of total'));
  const res = await run(client, `
    SELECT status, COUNT(*) AS order_count,
           ROUND(SUM(total_amount)::NUMERIC, 2) AS total_revenue,
           ROUND(AVG(total_amount)::NUMERIC, 2) AS avg_order_value,
           ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
    FROM orders GROUP BY status ORDER BY order_count DESC
  `, 'Order status');
  if (res) printTable(res.rows);
}

async function query7(client) {
  header('QUERY 7 — Category Hierarchy (Recursive CTE)', 'QUERY');
  console.log(d('  Recursive CTE with self-join | Hierarchical path building'));
  const res = await run(client, `
    WITH RECURSIVE category_tree AS (
      SELECT id, parent_id, name, 0 AS depth, name::TEXT AS full_path
      FROM categories WHERE parent_id IS NULL
      UNION ALL
      SELECT c.id, c.parent_id, c.name, ct.depth+1, ct.full_path || ' > ' || c.name
      FROM categories c JOIN category_tree ct ON c.parent_id = ct.id
    )
    SELECT full_path, depth, COUNT(DISTINCT p.id) AS products
    FROM category_tree ct
    LEFT JOIN products p ON p.category_id = ct.id AND p.is_active = true
    GROUP BY ct.id, full_path, depth
    ORDER BY full_path LIMIT 20
  `, 'Category hierarchy');
  if (res) printTable(res.rows);
}

async function query8(client) {
  header('QUERY 8 — User Purchase History with Running Total', 'QUERY');
  console.log(d('  Window: SUM OVER (PARTITION BY user ORDER BY date) — running total'));
  console.log(d('  Window: ROW_NUMBER OVER (PARTITION BY user) — order sequence'));
  const res = await run(client, `
    SELECT o.order_number, o.status,
           ROUND(o.total_amount::NUMERIC, 2) AS amount,
           o.created_at::DATE AS order_date,
           ROUND(SUM(o.total_amount) OVER (
             PARTITION BY o.user_id ORDER BY o.created_at
           )::NUMERIC, 2) AS running_total,
           ROW_NUMBER() OVER (
             PARTITION BY o.user_id ORDER BY o.created_at
           ) AS order_seq
    FROM orders o
    WHERE o.user_id = (SELECT user_id FROM orders GROUP BY user_id ORDER BY COUNT(*) DESC LIMIT 1)
    ORDER BY o.created_at LIMIT 10
  `, 'Purchase history');
  if (res) printTable(res.rows);
}

async function query9(client) {
  header('QUERY 9 — Promotion Usage Report', 'QUERY');
  console.log(d('  LEFT JOIN promotions → orders | CASE for status logic'));
  const res = await run(client, `
    SELECT pr.code, pr.type,
           pr.value::TEXT || CASE WHEN pr.type='percentage' THEN '%' ELSE '$' END AS discount,
           COUNT(o.id) AS times_used,
           ROUND(SUM(o.discount_amount)::NUMERIC,2) AS total_discount,
           ROUND(AVG(o.total_amount)::NUMERIC,2) AS avg_order,
           CASE WHEN pr.expires_at < NOW() THEN 'expired'
                WHEN NOT pr.is_active      THEN 'inactive'
                ELSE 'active' END AS status
    FROM promotions pr
    LEFT JOIN orders o ON o.promotion_id = pr.id AND o.status != 'cancelled'
    GROUP BY pr.id, pr.code, pr.type, pr.value, pr.expires_at, pr.is_active
    ORDER BY times_used DESC
  `, 'Promotion usage');
  if (res) printTable(res.rows);
}

async function query10(client) {
  header('QUERY 10 — Monthly Revenue with Growth % (Window + LAG)', 'QUERY');
  console.log(d('  Window: LAG() OVER for month-over-month comparison'));
  const res = await run(client, `
    SELECT DATE_TRUNC('month', created_at)::DATE AS month,
           COUNT(*) AS orders,
           ROUND(SUM(total_amount)::NUMERIC, 2) AS revenue,
           ROUND(AVG(total_amount)::NUMERIC, 2) AS avg_order,
           ROUND((SUM(total_amount) - LAG(SUM(total_amount))
             OVER (ORDER BY DATE_TRUNC('month', created_at)))
             / NULLIF(LAG(SUM(total_amount))
             OVER (ORDER BY DATE_TRUNC('month', created_at)),0) * 100, 1) AS growth_pct
    FROM orders
    WHERE status IN ('completed','delivered','shipped')
    GROUP BY DATE_TRUNC('month', created_at)
    ORDER BY month
  `, 'Monthly revenue');
  if (res) printTable(res.rows);
}

async function explainDemo(client) {
  header('QUERY OPTIMIZATION — EXPLAIN ANALYZE DEMO', 'STEP 7');

  console.log(b('\n  BEFORE — No specific index, SELECT *'));
  console.log(d('  ─────────────────────────────────────────────────────'));
  const before = await run(client, `
    EXPLAIN (ANALYZE, FORMAT TEXT)
    SELECT * FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.user_id = 5
  `, 'BEFORE explain');
  if (before) {
    before.rows.forEach(row => {
      const line = row['QUERY PLAN'];
      if (line.includes('Seq Scan'))   console.log(r('  ' + line));
      else if (line.includes('cost'))  console.log(y('  ' + line));
      else                             console.log(d('  ' + line));
    });
  }

  console.log(b('\n  AFTER — Composite index + selective columns + LIMIT'));
  console.log(d('  ─────────────────────────────────────────────────────'));
  const after = await run(client, `
    EXPLAIN (ANALYZE, FORMAT TEXT)
    SELECT o.id, o.order_number, o.status, o.total_amount,
           oi.product_name, oi.quantity, oi.unit_price
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.user_id = 5
      AND o.status NOT IN ('cancelled','refunded')
    ORDER BY o.created_at DESC LIMIT 20
  `, 'AFTER explain');
  if (after) {
    after.rows.forEach(row => {
      const line = row['QUERY PLAN'];
      if (line.includes('Index Scan')) console.log(g('  ' + line));
      else if (line.includes('cost'))  console.log(y('  ' + line));
      else                             console.log(d('  ' + line));
    });
  }

  console.log(b('\n  INDEX LIST — All indexes in the database'));
  const idx = await run(client, `
    SELECT tablename, indexname
    FROM pg_indexes WHERE schemaname = 'public'
    ORDER BY tablename, indexname
  `);
  if (idx) printTable(idx.rows, 30);
}

async function dbStats(client) {
  header('DATABASE STATS — Size & Performance', 'BONUS');
  console.log(b('\n  Database size:'));
  const size = await run(client, `SELECT pg_size_pretty(pg_database_size(current_database())) AS total_size`);
  if (size) printTable(size.rows);

  console.log(b('\n  Table sizes:'));
  const tsize = await run(client, `
    SELECT relname AS table_name,
           pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
           n_live_tup AS live_rows
    FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC
  `);
  if (tsize) printTable(tsize.rows);
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

const STEPS = {
  '1':       [step1_connection],
  '2':       [step2_schema],
  '3':       [step3_rowcounts],
  '4':       [step4_constraints],
  'q1':      [query1],
  'q2':      [query2],
  'q3':      [query3],
  'q4':      [query4],
  'q5':      [query5],
  'q6':      [query6],
  'q7':      [query7],
  'q8':      [query8],
  'q9':      [query9],
  'q10':     [query10],
  'queries': [query1,query2,query3,query4,query5,query6,query7,query8,query9,query10],
  'explain': [explainDemo],
  'stats':   [dbStats],
  'all':     [step1_connection, step2_schema, step3_rowcounts, step4_constraints,
              query1, query2, query3, query4, query5,
              query6, query7, query8, query9, query10,
              explainDemo, dbStats],
};

(async () => {
  const arg = process.argv[2] || 'all';
  const fns = STEPS[arg];

  if (!fns) {
    console.log(b('\nUsage: node demo.js [step]\n'));
    console.log('  Steps:');
    console.log('    1          — Connection test');
    console.log('    2          — Schema (13 tables)');
    console.log('    3          — Row counts');
    console.log('    4          — Constraint tests');
    console.log('    q1 .. q10  — Individual queries');
    console.log('    queries    — All 10 queries');
    console.log('    explain    — EXPLAIN ANALYZE optimization demo');
    console.log('    stats      — DB size & table stats');
    console.log('    all        — Full demo (default)\n');
    process.exit(0);
  }

  console.log('\n' + line('═'));
  console.log(C.bold + C.bgBlue + C.white + '  ShopFlow E-Commerce — Database Demo  ' + C.reset);
  console.log(C.dim + '  Author: Thilan Buddhika | github.com/MuhandiramTB/shopflow-db' + C.reset);
  console.log(line('═'));

  const client = new Client({ connectionString: DB });
  await client.connect();

  for (const fn of fns) {
    await fn(client);
  }

  console.log('\n' + line('═'));
  console.log(g('  Demo complete!'));
  console.log(line('═') + '\n');

  await client.end();
})().catch(err => {
  console.error(r('\nFatal: ' + err.message));
  process.exit(1);
});
