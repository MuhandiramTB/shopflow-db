-- =============================================================================
-- ShopFlow E-Commerce Platform - Database Migrations
-- Author: Thilan Buddhika
-- Date: 2026-04-28
-- PostgreSQL 15+
-- =============================================================================

-- Enable UUID extension for alternative PKs if needed
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- TABLE 1: users
-- =============================================================================
CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    phone           VARCHAR(20),
    date_of_birth   DATE,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    is_verified     BOOLEAN NOT NULL DEFAULT false,
    role            VARCHAR(20) NOT NULL DEFAULT 'customer'
                        CHECK (role IN ('customer', 'admin', 'seller')),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email       ON users(email);
CREATE INDEX idx_users_active      ON users(is_active) WHERE is_active = true;
CREATE INDEX idx_users_role        ON users(role);
CREATE INDEX idx_users_created_at  ON users(created_at);

-- =============================================================================
-- TABLE 2: addresses
-- =============================================================================
CREATE TABLE addresses (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            VARCHAR(20) NOT NULL DEFAULT 'shipping'
                        CHECK (type IN ('shipping', 'billing', 'both')),
    full_name       VARCHAR(200) NOT NULL,
    phone           VARCHAR(20),
    address_line1   VARCHAR(255) NOT NULL,
    address_line2   VARCHAR(255),
    city            VARCHAR(100) NOT NULL,
    state           VARCHAR(100) NOT NULL,
    postal_code     VARCHAR(20) NOT NULL,
    country         VARCHAR(100) NOT NULL DEFAULT 'US',
    is_default      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_default ON addresses(user_id, is_default) WHERE is_default = true;

-- =============================================================================
-- TABLE 3: categories (self-referencing for hierarchy)
-- =============================================================================
CREATE TABLE categories (
    id              SERIAL PRIMARY KEY,
    parent_id       INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    name            VARCHAR(150) NOT NULL,
    slug            VARCHAR(150) NOT NULL UNIQUE,
    description     TEXT,
    image_url       VARCHAR(500),
    sort_order      INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_parent    ON categories(parent_id);
CREATE INDEX idx_categories_slug      ON categories(slug);
CREATE INDEX idx_categories_active    ON categories(is_active) WHERE is_active = true;

-- =============================================================================
-- TABLE 4: products
-- =============================================================================
CREATE TABLE products (
    id              SERIAL PRIMARY KEY,
    category_id     INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(255) NOT NULL UNIQUE,
    description     TEXT,
    short_description VARCHAR(500),
    brand           VARCHAR(150),
    sku             VARCHAR(100) UNIQUE,
    base_price      DECIMAL(10, 2) NOT NULL CHECK (base_price >= 0),
    compare_price   DECIMAL(10, 2) CHECK (compare_price >= 0),
    cost_price      DECIMAL(10, 2) CHECK (cost_price >= 0),
    weight          DECIMAL(8, 3),
    is_active       BOOLEAN NOT NULL DEFAULT true,
    is_featured     BOOLEAN NOT NULL DEFAULT false,
    meta_title      VARCHAR(255),
    meta_description VARCHAR(500),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_products_category    ON products(category_id);
CREATE INDEX idx_products_slug        ON products(slug);
CREATE INDEX idx_products_sku         ON products(sku);
CREATE INDEX idx_products_active      ON products(is_active) WHERE is_active = true;
CREATE INDEX idx_products_featured    ON products(is_featured) WHERE is_featured = true;
CREATE INDEX idx_products_brand       ON products(brand);
CREATE INDEX idx_products_price       ON products(base_price);
CREATE INDEX idx_products_created_at  ON products(created_at);

-- =============================================================================
-- TABLE 5: product_variants
-- =============================================================================
CREATE TABLE product_variants (
    id              SERIAL PRIMARY KEY,
    product_id      INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    sku             VARCHAR(100) NOT NULL UNIQUE,
    name            VARCHAR(255) NOT NULL,
    size            VARCHAR(50),
    color           VARCHAR(50),
    material        VARCHAR(100),
    price           DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    compare_price   DECIMAL(10, 2) CHECK (compare_price >= 0),
    weight          DECIMAL(8, 3),
    image_url       VARCHAR(500),
    is_active       BOOLEAN NOT NULL DEFAULT true,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_variants_product     ON product_variants(product_id);
CREATE INDEX idx_variants_sku         ON product_variants(sku);
CREATE INDEX idx_variants_active      ON product_variants(is_active) WHERE is_active = true;
CREATE INDEX idx_variants_color_size  ON product_variants(color, size);

-- =============================================================================
-- TABLE 6: inventory
-- =============================================================================
CREATE TABLE inventory (
    id              SERIAL PRIMARY KEY,
    variant_id      INTEGER NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity        INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    reserved        INTEGER NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    low_stock_threshold INTEGER NOT NULL DEFAULT 10,
    warehouse_location VARCHAR(100),
    last_restocked  TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inv_variant_unique UNIQUE (variant_id),
    CONSTRAINT inv_reserved_lte_qty CHECK (reserved <= quantity)
);

CREATE INDEX idx_inventory_variant    ON inventory(variant_id);
CREATE INDEX idx_inventory_low_stock  ON inventory(quantity) WHERE quantity < 10;

-- =============================================================================
-- TABLE 7: carts
-- =============================================================================
CREATE TABLE carts (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_id      VARCHAR(255),
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'merged', 'ordered', 'abandoned')),
    expires_at      TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '30 days'),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT cart_owner CHECK (user_id IS NOT NULL OR session_id IS NOT NULL)
);

CREATE INDEX idx_carts_user_id        ON carts(user_id);
CREATE INDEX idx_carts_session        ON carts(session_id);
CREATE INDEX idx_carts_status         ON carts(status);
CREATE INDEX idx_carts_active         ON carts(user_id, status) WHERE status = 'active';

-- =============================================================================
-- TABLE 8: cart_items
-- =============================================================================
CREATE TABLE cart_items (
    id              SERIAL PRIMARY KEY,
    cart_id         INTEGER NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    variant_id      INTEGER NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity        INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price      DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    added_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT cart_item_unique UNIQUE (cart_id, variant_id)
);

CREATE INDEX idx_cart_items_cart      ON cart_items(cart_id);
CREATE INDEX idx_cart_items_variant   ON cart_items(variant_id);

-- =============================================================================
-- TABLE 9: promotions
-- =============================================================================
CREATE TABLE promotions (
    id              SERIAL PRIMARY KEY,
    code            VARCHAR(50) NOT NULL UNIQUE,
    description     VARCHAR(500),
    type            VARCHAR(20) NOT NULL CHECK (type IN ('percentage', 'fixed', 'free_shipping')),
    value           DECIMAL(10, 2) NOT NULL CHECK (value >= 0),
    min_order_amount DECIMAL(10, 2) CHECK (min_order_amount >= 0),
    max_discount_amount DECIMAL(10, 2) CHECK (max_discount_amount >= 0),
    usage_limit     INTEGER,
    usage_count     INTEGER NOT NULL DEFAULT 0,
    per_user_limit  INTEGER,
    starts_at       TIMESTAMP NOT NULL,
    expires_at      TIMESTAMP,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT promo_dates CHECK (expires_at IS NULL OR expires_at > starts_at)
);

CREATE INDEX idx_promotions_code      ON promotions(code);
CREATE INDEX idx_promotions_active    ON promotions(is_active, starts_at, expires_at)
                                        WHERE is_active = true;

-- =============================================================================
-- TABLE 10: orders
-- =============================================================================
CREATE TABLE orders (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    promotion_id    INTEGER REFERENCES promotions(id) ON DELETE SET NULL,
    shipping_address_id INTEGER REFERENCES addresses(id) ON DELETE SET NULL,
    billing_address_id  INTEGER REFERENCES addresses(id) ON DELETE SET NULL,
    order_number    VARCHAR(50) NOT NULL UNIQUE,
    status          VARCHAR(30) NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'confirmed', 'processing',
                                          'shipped', 'delivered', 'completed',
                                          'cancelled', 'refunded')),
    subtotal        DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0),
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    shipping_cost   DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    tax_amount      DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    total_amount    DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    currency        CHAR(3) NOT NULL DEFAULT 'USD',
    payment_status  VARCHAR(20) NOT NULL DEFAULT 'pending'
                        CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    payment_method  VARCHAR(50),
    tracking_number VARCHAR(100),
    notes           TEXT,
    shipped_at      TIMESTAMP,
    delivered_at    TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_orders_user_id       ON orders(user_id);
CREATE INDEX idx_orders_status        ON orders(status);
CREATE INDEX idx_orders_order_number  ON orders(order_number);
CREATE INDEX idx_orders_created_at    ON orders(created_at);
CREATE INDEX idx_orders_payment       ON orders(payment_status);
CREATE INDEX idx_orders_user_status   ON orders(user_id, status);

-- =============================================================================
-- TABLE 11: order_items
-- =============================================================================
CREATE TABLE order_items (
    id              SERIAL PRIMARY KEY,
    order_id        INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    variant_id      INTEGER NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    product_id      INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name    VARCHAR(255) NOT NULL,
    variant_name    VARCHAR(255) NOT NULL,
    sku             VARCHAR(100) NOT NULL,
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    total_price     DECIMAL(10, 2) NOT NULL CHECK (total_price >= 0),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_order_items_order    ON order_items(order_id);
CREATE INDEX idx_order_items_variant  ON order_items(variant_id);
CREATE INDEX idx_order_items_product  ON order_items(product_id);

-- =============================================================================
-- TABLE 12: reviews
-- =============================================================================
CREATE TABLE reviews (
    id              SERIAL PRIMARY KEY,
    product_id      INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id        INTEGER REFERENCES orders(id) ON DELETE SET NULL,
    rating          SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title           VARCHAR(255),
    body            TEXT,
    is_verified     BOOLEAN NOT NULL DEFAULT false,
    is_approved     BOOLEAN NOT NULL DEFAULT false,
    helpful_count   INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT review_unique UNIQUE (product_id, user_id)
);

CREATE INDEX idx_reviews_product      ON reviews(product_id);
CREATE INDEX idx_reviews_user         ON reviews(user_id);
CREATE INDEX idx_reviews_rating       ON reviews(product_id, rating);
CREATE INDEX idx_reviews_approved     ON reviews(is_approved) WHERE is_approved = true;

-- =============================================================================
-- TABLE 13: wishlists (bonus)
-- =============================================================================
CREATE TABLE wishlists (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id      INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    variant_id      INTEGER REFERENCES product_variants(id) ON DELETE SET NULL,
    added_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT wishlist_unique UNIQUE (user_id, product_id)
);

CREATE INDEX idx_wishlists_user       ON wishlists(user_id);
CREATE INDEX idx_wishlists_product    ON wishlists(product_id);

-- =============================================================================
-- TRIGGERS: auto-update updated_at
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users', 'addresses', 'categories', 'products',
        'product_variants', 'carts', 'cart_items',
        'promotions', 'orders', 'reviews'
    ]
    LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%s_updated_at
             BEFORE UPDATE ON %s
             FOR EACH ROW EXECUTE FUNCTION update_updated_at();',
            t, t
        );
    END LOOP;
END;
$$;

-- =============================================================================
-- COMPLEX QUERIES
-- =============================================================================

-- Query 1: Top selling products by category (last 30 days)
SELECT
    c.name                                    AS category,
    p.name                                    AS product,
    SUM(oi.quantity)                          AS total_sold,
    SUM(oi.quantity * oi.unit_price)          AS revenue,
    RANK() OVER (
        PARTITION BY c.id
        ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    )                                         AS rank_in_category
FROM order_items oi
JOIN products  p  ON oi.product_id = p.id
JOIN categories c ON p.category_id = c.id
JOIN orders    o  ON oi.order_id   = o.id
WHERE o.status     = 'completed'
  AND o.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.id, c.name, p.id, p.name
ORDER BY revenue DESC
LIMIT 10;

-- Query 2: Customer lifetime value with segmentation
WITH customer_stats AS (
    SELECT
        u.id,
        u.first_name || ' ' || u.last_name AS full_name,
        u.email,
        COUNT(o.id)                         AS total_orders,
        SUM(o.total_amount)                 AS lifetime_value,
        AVG(o.total_amount)                 AS avg_order_value,
        MIN(o.created_at)                   AS first_order,
        MAX(o.created_at)                   AS last_order,
        CURRENT_DATE - MAX(o.created_at)::DATE AS days_since_last_order
    FROM users u
    JOIN orders o ON u.id = o.user_id
    WHERE o.status IN ('completed', 'delivered')
    GROUP BY u.id, u.first_name, u.last_name, u.email
)
SELECT
    *,
    CASE
        WHEN lifetime_value >= 5000 THEN 'VIP'
        WHEN lifetime_value >= 1000 THEN 'Gold'
        WHEN lifetime_value >= 500  THEN 'Silver'
        ELSE 'Bronze'
    END AS segment,
    NTILE(4) OVER (ORDER BY lifetime_value DESC) AS value_quartile
FROM customer_stats
ORDER BY lifetime_value DESC;

-- Query 3: Inventory low stock alert with reorder recommendation
SELECT
    p.name                                    AS product_name,
    pv.sku,
    pv.color,
    pv.size,
    inv.quantity                              AS current_stock,
    inv.reserved,
    inv.quantity - inv.reserved               AS available_stock,
    inv.low_stock_threshold,
    COALESCE(recent.avg_daily_sales, 0)       AS avg_daily_sales,
    CASE
        WHEN COALESCE(recent.avg_daily_sales, 0) > 0
        THEN ROUND((inv.quantity - inv.reserved) / recent.avg_daily_sales)
        ELSE NULL
    END                                       AS days_of_stock_remaining
FROM inventory inv
JOIN product_variants pv ON inv.variant_id = pv.id
JOIN products          p  ON pv.product_id  = p.id
LEFT JOIN (
    SELECT
        oi.variant_id,
        SUM(oi.quantity)::DECIMAL / 30 AS avg_daily_sales
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    WHERE o.created_at >= CURRENT_DATE - INTERVAL '30 days'
      AND o.status IN ('completed', 'delivered', 'shipped')
    GROUP BY oi.variant_id
) recent ON inv.variant_id = recent.variant_id
WHERE inv.quantity - inv.reserved <= inv.low_stock_threshold
ORDER BY available_stock ASC;

-- Query 4: Review statistics per product (with sentiment distribution)
SELECT
    p.id,
    p.name,
    COUNT(r.id)                                          AS total_reviews,
    ROUND(AVG(r.rating), 2)                              AS avg_rating,
    COUNT(*) FILTER (WHERE r.rating = 5)                 AS five_star,
    COUNT(*) FILTER (WHERE r.rating = 4)                 AS four_star,
    COUNT(*) FILTER (WHERE r.rating = 3)                 AS three_star,
    COUNT(*) FILTER (WHERE r.rating <= 2)                AS low_star,
    COUNT(*) FILTER (WHERE r.is_verified = true)         AS verified_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE r.rating >= 4)
        / NULLIF(COUNT(r.id), 0), 1
    )                                                    AS positive_pct
FROM products p
LEFT JOIN reviews r ON p.id = r.product_id AND r.is_approved = true
WHERE p.is_active = true
GROUP BY p.id, p.name
ORDER BY total_reviews DESC;

-- Query 5: Cart abandonment analysis (carts active > 24h with items)
WITH abandoned_carts AS (
    SELECT
        c.id,
        c.user_id,
        c.session_id,
        c.created_at,
        c.updated_at,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - c.updated_at)) / 3600 AS hours_idle,
        COUNT(ci.id)                   AS item_count,
        SUM(ci.quantity * ci.unit_price) AS cart_value
    FROM carts c
    JOIN cart_items ci ON c.id = ci.cart_id
    WHERE c.status = 'active'
      AND c.updated_at < CURRENT_TIMESTAMP - INTERVAL '24 hours'
    GROUP BY c.id, c.user_id, c.session_id, c.created_at, c.updated_at
)
SELECT
    DATE_TRUNC('day', created_at)   AS abandoned_date,
    COUNT(*)                         AS abandoned_carts,
    COUNT(user_id)                   AS logged_in_carts,
    ROUND(AVG(cart_value), 2)        AS avg_cart_value,
    ROUND(SUM(cart_value), 2)        AS total_lost_revenue,
    ROUND(AVG(item_count), 1)        AS avg_items
FROM abandoned_carts
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY abandoned_date DESC;

-- Query 6: Order status breakdown with revenue
SELECT
    status,
    COUNT(*)                                AS order_count,
    ROUND(SUM(total_amount), 2)             AS total_revenue,
    ROUND(AVG(total_amount), 2)             AS avg_order_value,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY status
ORDER BY order_count DESC;

-- Query 7: Full category hierarchy with product counts
WITH RECURSIVE category_tree AS (
    -- anchor: root categories
    SELECT
        id, parent_id, name, slug, 0 AS depth,
        ARRAY[id] AS path,
        name::TEXT AS full_path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    -- recursive: children
    SELECT
        c.id, c.parent_id, c.name, c.slug,
        ct.depth + 1,
        ct.path || c.id,
        ct.full_path || ' > ' || c.name
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT
    ct.id,
    ct.full_path,
    ct.depth,
    COUNT(DISTINCT p.id) AS direct_products,
    COUNT(DISTINCT p2.id) AS total_products_in_subtree
FROM category_tree ct
LEFT JOIN products p  ON p.category_id = ct.id AND p.is_active = true
LEFT JOIN products p2 ON p2.category_id = ANY(ct.path) AND p2.is_active = true
GROUP BY ct.id, ct.full_path, ct.depth
ORDER BY ct.path;

-- Query 8: User purchase history with running total
SELECT
    o.id            AS order_id,
    o.order_number,
    o.status,
    o.total_amount,
    o.created_at    AS order_date,
    COUNT(oi.id)    AS items_count,
    SUM(o.total_amount) OVER (
        PARTITION BY o.user_id
        ORDER BY o.created_at
        ROWS UNBOUNDED PRECEDING
    )               AS running_lifetime_value,
    ROW_NUMBER() OVER (
        PARTITION BY o.user_id
        ORDER BY o.created_at
    )               AS order_number_seq
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.user_id = :user_id          -- replace with actual user id
  AND o.status != 'cancelled'
GROUP BY o.id, o.order_number, o.status, o.total_amount, o.created_at, o.user_id
ORDER BY o.created_at DESC;

-- Query 9: Promotion usage report
SELECT
    pr.code,
    pr.type,
    pr.value,
    pr.usage_limit,
    COUNT(o.id)                       AS times_used,
    ROUND(SUM(o.discount_amount), 2)  AS total_discount_given,
    ROUND(SUM(o.total_amount), 2)     AS revenue_with_promo,
    ROUND(AVG(o.total_amount), 2)     AS avg_order_with_promo,
    pr.expires_at,
    CASE
        WHEN pr.expires_at < CURRENT_TIMESTAMP THEN 'expired'
        WHEN pr.usage_limit IS NOT NULL AND COUNT(o.id) >= pr.usage_limit THEN 'exhausted'
        WHEN pr.is_active = false THEN 'inactive'
        ELSE 'active'
    END AS promo_status
FROM promotions pr
LEFT JOIN orders o ON o.promotion_id = pr.id AND o.status != 'cancelled'
GROUP BY pr.id, pr.code, pr.type, pr.value, pr.usage_limit,
         pr.expires_at, pr.is_active
ORDER BY times_used DESC;

-- Query 10: Revenue by time period (daily / weekly / monthly rollup)
SELECT
    DATE_TRUNC('month', o.created_at)     AS period,
    COUNT(DISTINCT o.id)                  AS total_orders,
    COUNT(DISTINCT o.user_id)             AS unique_customers,
    COUNT(DISTINCT CASE
        WHEN prev.user_id IS NULL THEN o.user_id
    END)                                  AS new_customers,
    ROUND(SUM(o.subtotal), 2)             AS gross_revenue,
    ROUND(SUM(o.discount_amount), 2)      AS total_discounts,
    ROUND(SUM(o.total_amount), 2)         AS net_revenue,
    ROUND(AVG(o.total_amount), 2)         AS avg_order_value,
    LAG(ROUND(SUM(o.total_amount), 2)) OVER (
        ORDER BY DATE_TRUNC('month', o.created_at)
    )                                     AS prev_period_revenue,
    ROUND(
        100.0 * (SUM(o.total_amount) - LAG(SUM(o.total_amount)) OVER (
            ORDER BY DATE_TRUNC('month', o.created_at)
        )) / NULLIF(LAG(SUM(o.total_amount)) OVER (
            ORDER BY DATE_TRUNC('month', o.created_at)
        ), 0), 2
    )                                     AS revenue_growth_pct
FROM orders o
LEFT JOIN (
    SELECT DISTINCT user_id,
           MIN(created_at) AS first_order_date
    FROM orders
    WHERE status != 'cancelled'
    GROUP BY user_id
) prev ON prev.user_id = o.user_id
       AND prev.first_order_date < DATE_TRUNC('month', o.created_at)
WHERE o.status IN ('completed', 'delivered', 'shipped')
  AND o.created_at >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', o.created_at)
ORDER BY period;
