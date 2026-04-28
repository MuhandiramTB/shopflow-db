-- =============================================================================
-- ShopFlow E-Commerce Platform - Seed Data
-- Author: Thilan Buddhika
-- Date: 2026-04-28
-- Generates realistic test data: 1000 users, 50 categories, 500 products,
-- 2000 variants, 5000 orders, 15000 order_items, 3000 reviews
-- =============================================================================

-- Utility: repeatable random helpers
CREATE OR REPLACE FUNCTION random_between(lo INT, hi INT)
RETURNS INT AS $$
    SELECT floor(random() * (hi - lo + 1) + lo)::INT;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION random_decimal(lo NUMERIC, hi NUMERIC, decimals INT DEFAULT 2)
RETURNS NUMERIC AS $$
    SELECT round((random() * (hi - lo) + lo)::NUMERIC, decimals);
$$ LANGUAGE sql;

-- =============================================================================
-- CATEGORIES (50 rows, 3-level hierarchy)
-- =============================================================================
INSERT INTO categories (id, parent_id, name, slug, sort_order) VALUES
-- Level 1: Root
(1,  NULL, 'Electronics',       'electronics',       1),
(2,  NULL, 'Clothing',          'clothing',          2),
(3,  NULL, 'Home & Garden',     'home-garden',       3),
(4,  NULL, 'Sports & Outdoors', 'sports-outdoors',   4),
(5,  NULL, 'Books & Media',     'books-media',       5),
(6,  NULL, 'Beauty & Personal', 'beauty-personal',   6),
(7,  NULL, 'Toys & Games',      'toys-games',        7),
(8,  NULL, 'Automotive',        'automotive',        8),
(9,  NULL, 'Food & Grocery',    'food-grocery',      9),
(10, NULL, 'Health & Wellness', 'health-wellness',  10),
-- Level 2: Electronics sub
(11,  1, 'Smartphones',    'smartphones',     1),
(12,  1, 'Laptops',        'laptops',         2),
(13,  1, 'Audio',          'audio',           3),
(14,  1, 'Cameras',        'cameras',         4),
(15,  1, 'Tablets',        'tablets',         5),
-- Level 2: Clothing sub
(16,  2, 'Men''s Clothing',   'mens-clothing',   1),
(17,  2, 'Women''s Clothing', 'womens-clothing', 2),
(18,  2, 'Kids Clothing',    'kids-clothing',   3),
(19,  2, 'Shoes',            'shoes',           4),
(20,  2, 'Accessories',      'accessories',     5),
-- Level 2: Home & Garden sub
(21,  3, 'Furniture',      'furniture',       1),
(22,  3, 'Kitchen',        'kitchen',         2),
(23,  3, 'Bedding',        'bedding',         3),
(24,  3, 'Garden',         'garden',          4),
(25,  3, 'Lighting',       'lighting',        5),
-- Level 2: Sports sub
(26,  4, 'Fitness',        'fitness',         1),
(27,  4, 'Outdoor',        'outdoor',         2),
(28,  4, 'Team Sports',    'team-sports',     3),
(29,  4, 'Water Sports',   'water-sports',    4),
(30,  4, 'Cycling',        'cycling',         5),
-- Level 3: Smartphones sub
(31, 11, 'Android Phones', 'android-phones',  1),
(32, 11, 'iPhones',        'iphones',         2),
(33, 11, 'Phone Cases',    'phone-cases',     3),
-- Level 3: Laptops sub
(34, 12, 'Gaming Laptops', 'gaming-laptops',  1),
(35, 12, 'Ultrabooks',     'ultrabooks',      2),
(36, 12, 'Chromebooks',    'chromebooks',     3),
-- Level 3: Audio sub
(37, 13, 'Headphones',     'headphones',      1),
(38, 13, 'Speakers',       'speakers',        2),
(39, 13, 'Earbuds',        'earbuds',         3),
-- Level 3: Men's sub
(40, 16, 'T-Shirts',       'mens-tshirts',    1),
(41, 16, 'Pants',          'mens-pants',      2),
(42, 16, 'Jackets',        'mens-jackets',    3),
-- Level 3: Women's sub
(43, 17, 'Dresses',        'womens-dresses',  1),
(44, 17, 'Tops',           'womens-tops',     2),
(45, 17, 'Skirts',         'womens-skirts',   3),
-- Level 3: Fitness sub
(46, 26, 'Gym Equipment',  'gym-equipment',   1),
(47, 26, 'Yoga',           'yoga',            2),
(48, 26, 'Running Gear',   'running-gear',    3),
-- Remaining to reach 50
(49,  5, 'Fiction Books',  'fiction-books',   1),
(50,  5, 'Non-Fiction',    'non-fiction',     2);

SELECT setval('categories_id_seq', 50);

-- =============================================================================
-- USERS (1000 rows)
-- =============================================================================
INSERT INTO users (email, password_hash, first_name, last_name, phone, is_active, is_verified, role)
SELECT
    'user' || n || '@shopflow-test.com',
    '$2a$12$hashed_password_placeholder_' || n,
    (ARRAY['James','Mary','John','Patricia','Robert','Jennifer','Michael',
           'Linda','William','Barbara','David','Elizabeth','Richard','Susan',
           'Joseph','Jessica','Thomas','Sarah','Charles','Karen'])[
        (n % 20) + 1
    ],
    (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller',
           'Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez',
           'Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'])[
        (n % 20) + 1
    ],
    '+1-555-' || LPAD(n::TEXT, 7, '0'),
    CASE WHEN n % 20 = 0 THEN false ELSE true END,
    CASE WHEN n % 5  = 0 THEN false ELSE true END,
    CASE WHEN n = 1 THEN 'admin'
         WHEN n % 50 = 0 THEN 'seller'
         ELSE 'customer' END
FROM generate_series(1, 1000) n;

-- =============================================================================
-- ADDRESSES (2000 rows, ~2 per user)
-- =============================================================================
INSERT INTO addresses (user_id, type, full_name, phone, address_line1, city, state, postal_code, country, is_default)
SELECT
    u.id,
    CASE WHEN s.n % 2 = 0 THEN 'shipping' ELSE 'billing' END,
    u.first_name || ' ' || u.last_name,
    '+1-555-' || LPAD((u.id * 2 + s.n)::TEXT, 7, '0'),
    (random_between(1, 9999))::TEXT || ' ' ||
    (ARRAY['Main St','Oak Ave','Maple Dr','Cedar Ln','Pine Rd',
           'Elm St','Birch Blvd','Walnut Way','Cherry Ct','Spruce Pl'])[
        ((u.id + s.n) % 10) + 1
    ],
    (ARRAY['New York','Los Angeles','Chicago','Houston','Phoenix',
           'Philadelphia','San Antonio','San Diego','Dallas','San Jose',
           'Austin','Jacksonville','Fort Worth','Columbus','Charlotte'])[
        ((u.id + s.n) % 15) + 1
    ],
    (ARRAY['NY','CA','IL','TX','AZ','PA','TX','CA','TX','CA',
           'TX','FL','TX','OH','NC'])[
        ((u.id + s.n) % 15) + 1
    ],
    LPAD((10000 + (u.id * 3 + s.n) % 89999)::TEXT, 5, '0'),
    'US',
    s.n = 1
FROM users u, generate_series(1, 2) s(n)
WHERE u.role = 'customer';

-- =============================================================================
-- PRODUCTS (500 rows)
-- =============================================================================
INSERT INTO products (
    id, category_id, name, slug, description, brand, sku,
    base_price, compare_price, is_active, is_featured
)
SELECT
    n,
    (ARRAY[11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,
           26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
           41,42,43,44,45,46,47,48,49,50])[
        ((n - 1) % 40) + 1
    ],
    (ARRAY['Pro','Ultra','Elite','Flex','Core','Max','Mini','Lite',
           'Plus','Air','Edge','Prime','Smart','Quick','Power'])[
        ((n - 1) % 15) + 1
    ] || ' ' ||
    (ARRAY['Series','Edition','Model','Version','Collection',
           'Line','Range','Pack','Kit','Bundle'])[
        ((n - 1) % 10) + 1
    ] || ' ' || n,
    'product-' || n || '-' ||
    lower((ARRAY['alpha','beta','gamma','delta','epsilon',
                 'zeta','eta','theta','iota','kappa'])[
        ((n - 1) % 10) + 1
    ]),
    'High-quality product ' || n || '. Features advanced technology and premium build quality. ' ||
    'Perfect for everyday use. Includes 1-year warranty and free shipping on orders over $50.',
    (ARRAY['TechBrand','StyleCo','HomeBase','SportPro','NatureFit',
           'UrbanEdge','ClassicWear','ModernLiving','ActiveLife','EcoChoice'])[
        ((n - 1) % 10) + 1
    ],
    'SKU-PROD-' || LPAD(n::TEXT, 6, '0'),
    random_decimal(9.99, 999.99),
    CASE WHEN n % 3 = 0 THEN random_decimal(50, 1200) ELSE NULL END,
    CASE WHEN n % 15 = 0 THEN false ELSE true END,
    n % 10 = 0
FROM generate_series(1, 500) n;

SELECT setval('products_id_seq', 500);

-- =============================================================================
-- PRODUCT_VARIANTS (2000 rows, ~4 per product)
-- =============================================================================
INSERT INTO product_variants (product_id, sku, name, size, color, price, is_active, sort_order)
SELECT
    p.id,
    'SKU-VAR-' || LPAD(p.id::TEXT, 6, '0') || '-' || v.n,
    p.name || ' / ' ||
    (ARRAY['Small','Medium','Large','XL','XXL','One Size'])[v.n % 6 + 1] || ' / ' ||
    (ARRAY['Black','White','Red','Blue','Green','Gray','Navy','Beige'])[
        (p.id + v.n) % 8 + 1
    ],
    (ARRAY['S','M','L','XL','XXL','OS'])[v.n % 6 + 1],
    (ARRAY['Black','White','Red','Blue','Green','Gray','Navy','Beige'])[
        (p.id + v.n) % 8 + 1
    ],
    p.base_price + random_decimal(-5, 50),
    CASE WHEN v.n = 5 AND p.id % 7 = 0 THEN false ELSE true END,
    v.n
FROM products p, generate_series(1, 4) v(n);

-- =============================================================================
-- INVENTORY (one row per variant)
-- =============================================================================
INSERT INTO inventory (variant_id, quantity, reserved, low_stock_threshold, warehouse_location)
SELECT
    pv.id,
    random_between(0, 500),
    0,
    CASE WHEN pv.id % 5 = 0 THEN 5 ELSE 10 END,
    'WH-' || ((pv.id % 5) + 1)::TEXT || '-' ||
    CHR(65 + (pv.id % 26)) || '-' || (pv.id % 50 + 1)
FROM product_variants pv;

-- Update some inventory to be low stock for testing
UPDATE inventory SET quantity = random_between(0, 8)
WHERE variant_id % 20 = 0;

-- =============================================================================
-- PROMOTIONS (20 rows)
-- =============================================================================
INSERT INTO promotions (code, description, type, value, min_order_amount, max_discount_amount,
                         usage_limit, starts_at, expires_at, is_active)
VALUES
('WELCOME10',   'Welcome 10% off',          'percentage',    10,   0,    50,  NULL, '2025-01-01', '2027-12-31', true),
('SAVE20',      '20% off orders $100+',     'percentage',    20,  100,  100,  5000, '2025-06-01', '2026-12-31', true),
('FLAT15',      '$15 off any order',        'fixed',         15,   30,   15,  1000, '2025-01-01', '2026-06-30', true),
('SUMMER25',    'Summer 25% sale',          'percentage',    25,   50,  200,  2000, '2025-06-01', '2025-08-31', false),
('FREESHIP',    'Free shipping',            'free_shipping',  0,    0,    0,  NULL, '2025-01-01', '2027-12-31', true),
('FLASH50',     'Flash 50% off',            'percentage',    50,  200,  300,   500, '2026-04-01', '2026-04-30', true),
('VIP30',       'VIP customer 30% off',     'percentage',    30,  100,  150,   200, '2025-01-01', '2027-12-31', true),
('BACK2SCHOOL', 'Back to school 15% off',   'percentage',    15,   40,   80,  3000, '2025-08-01', '2025-09-15', false),
('HOLIDAY20',   'Holiday season 20% off',   'percentage',    20,   75,  150,  NULL, '2025-11-01', '2026-01-05', false),
('NEWUSER',     'New user $10 off',         'fixed',         10,   25,   10,  NULL, '2025-01-01', '2027-12-31', true),
('LOYALTY5',    'Loyalty 5% cash back',     'percentage',     5,    0,   25,  NULL, '2025-01-01', '2027-12-31', true),
('WEEKEND10',   'Weekend 10% flash',        'percentage',    10,   20,   30,  1000, '2026-04-25', '2026-04-27', false),
('APP15',       'App order 15% off',        'percentage',    15,   35,   60,  NULL, '2025-03-01', '2027-12-31', true),
('BUNDLE25',    'Bundle deal 25% off',      'percentage',    25,  150,  200,   750, '2025-01-01', '2026-12-31', true),
('REFERRAL',    'Referral $20 off',         'fixed',         20,   50,   20,  NULL, '2025-01-01', '2027-12-31', true),
('CLEARANCE',   'Clearance 40% off',        'percentage',    40,    0,  500,  NULL, '2026-03-01', '2026-05-31', true),
('FIRSTBUY',    'First purchase $5 off',    'fixed',          5,   15,    5,  NULL, '2025-01-01', '2027-12-31', true),
('TECH10',      'Electronics 10% off',      'percentage',    10,   50,  100,  2000, '2025-01-01', '2026-12-31', true),
('FASHION15',   'Fashion 15% off',          'percentage',    15,   30,   75,  3000, '2025-01-01', '2026-12-31', true),
('MEGA30',      'Mega sale 30% off',        'percentage',    30,  100,  300,  1000, '2026-04-15', '2026-04-30', true);

-- =============================================================================
-- ORDERS (5000 rows)
-- =============================================================================
-- Create orders spread over last 18 months
INSERT INTO orders (
    id, user_id, promotion_id, order_number, status,
    subtotal, discount_amount, shipping_cost, tax_amount, total_amount,
    payment_status, payment_method, created_at
)
SELECT
    n,
    (SELECT id FROM users ORDER BY random() LIMIT 1),   -- random customer
    CASE WHEN n % 6 = 0
         THEN (1 + (n % 20))::INTEGER
         ELSE NULL END,
    'ORD-' || TO_CHAR(
        CURRENT_DATE - (random() * 548)::INT,
        'YYYYMMDD'
    ) || '-' || LPAD(n::TEXT, 6, '0'),
    (ARRAY['pending','confirmed','processing','shipped','delivered',
           'completed','cancelled','refunded'])[
        CASE
            WHEN n % 100 < 5  THEN 1   -- 5%  pending
            WHEN n % 100 < 8  THEN 7   -- 3%  cancelled
            WHEN n % 100 < 10 THEN 2   -- 2%  confirmed
            WHEN n % 100 < 15 THEN 3   -- 5%  processing
            WHEN n % 100 < 25 THEN 4   -- 10% shipped
            WHEN n % 100 < 40 THEN 5   -- 15% delivered
            WHEN n % 100 < 41 THEN 8   -- 1%  refunded
            ELSE 6                      -- 59% completed
        END
    ],
    random_decimal(20, 800),
    CASE WHEN n % 6 = 0 THEN random_decimal(5, 100) ELSE 0 END,
    CASE WHEN random() < 0.3 THEN 0 ELSE random_decimal(5, 25) END,
    0,  -- will update below
    0,  -- will update below
    CASE
        WHEN n % 100 < 3 THEN 'pending'
        WHEN n % 100 < 5 THEN 'failed'
        ELSE 'paid'
    END,
    (ARRAY['credit_card','debit_card','paypal','apple_pay','google_pay','bank_transfer'])[
        (n % 6) + 1
    ],
    CURRENT_TIMESTAMP - (random() * 548 || ' days')::INTERVAL
FROM generate_series(1, 5000) n;

-- Calculate tax and total
UPDATE orders
SET tax_amount    = ROUND((subtotal - discount_amount + shipping_cost) * 0.08, 2),
    total_amount  = ROUND(subtotal - discount_amount + shipping_cost +
                          ROUND((subtotal - discount_amount + shipping_cost) * 0.08, 2), 2)
WHERE total_amount = 0;

SELECT setval('orders_id_seq', 5000);

-- =============================================================================
-- ORDER_ITEMS (15000 rows, ~3 per order)
-- =============================================================================
INSERT INTO order_items (order_id, variant_id, product_id, product_name, variant_name, sku, quantity, unit_price, total_price)
SELECT
    o.id,
    pv.id,
    p.id,
    p.name,
    pv.name,
    pv.sku,
    random_between(1, 5),
    pv.price,
    pv.price * random_between(1, 5)
FROM (
    SELECT o.id, ROW_NUMBER() OVER () AS rn
    FROM orders o, generate_series(1, 3) s
) o
JOIN LATERAL (
    SELECT pv.id, pv.name, pv.sku, pv.price, pv.product_id
    FROM product_variants pv
    WHERE pv.is_active = true
    ORDER BY random()
    LIMIT 1
) pv ON true
JOIN products p ON pv.product_id = p.id
WHERE o.id <= 5000;

-- =============================================================================
-- REVIEWS (3000 rows)
-- =============================================================================
INSERT INTO reviews (product_id, user_id, order_id, rating, title, body, is_verified, is_approved)
SELECT
    p.id,
    u.id,
    o.id,
    -- Realistic rating distribution: mostly 4-5 stars
    (ARRAY[1,1,2,2,3,3,3,4,4,4,4,5,5,5,5,5])[
        floor(random() * 16 + 1)::INT
    ],
    (ARRAY[
        'Great product!', 'Exceeded expectations', 'Good value for money',
        'Highly recommend', 'Average product', 'Not what I expected',
        'Amazing quality', 'Fast shipping', 'Perfect fit', 'Love it!',
        'Decent but pricey', 'Good but not great', 'Excellent!',
        'Would buy again', 'Outstanding quality'
    ])[floor(random() * 15 + 1)::INT],
    'Review body for product ' || p.id || '. ' ||
    (ARRAY[
        'The quality is excellent and it arrived quickly.',
        'I was a bit skeptical but this product really delivers.',
        'Solid build quality. Would recommend to anyone looking for this type of product.',
        'Good product overall but shipping took a bit longer than expected.',
        'Exactly as described. Very happy with my purchase.',
        'Not the best quality for the price but it gets the job done.',
        'Fantastic! Exceeded all my expectations.'
    ])[floor(random() * 7 + 1)::INT],
    o.id IS NOT NULL,
    CASE WHEN random() < 0.85 THEN true ELSE false END
FROM (
    SELECT DISTINCT ON (product_id, user_id)
           product_id, user_id, order_id
    FROM (
        SELECT
            oi.product_id,
            o.user_id,
            o.id AS order_id,
            ROW_NUMBER() OVER (ORDER BY random()) AS rn
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        WHERE o.status IN ('completed', 'delivered')
        ORDER BY random()
        LIMIT 4000
    ) t
    ORDER BY product_id, user_id
    LIMIT 3000
) rv
JOIN products p ON rv.product_id = p.id
JOIN users    u ON rv.user_id    = u.id
LEFT JOIN orders o ON rv.order_id = o.id;

-- =============================================================================
-- CARTS (simulate abandoned carts and active carts)
-- =============================================================================
INSERT INTO carts (user_id, session_id, status, expires_at, created_at, updated_at)
SELECT
    CASE WHEN n <= 800 THEN n ELSE NULL END,
    CASE WHEN n > 800 THEN 'sess-' || gen_random_uuid() ELSE NULL END,
    CASE
        WHEN n % 10 < 4 THEN 'active'
        WHEN n % 10 < 7 THEN 'ordered'
        WHEN n % 10 < 9 THEN 'abandoned'
        ELSE 'merged'
    END,
    CURRENT_TIMESTAMP + INTERVAL '30 days',
    CURRENT_TIMESTAMP - (random() * 60 || ' days')::INTERVAL,
    CURRENT_TIMESTAMP - (random() * 30 || ' days')::INTERVAL
FROM generate_series(1, 1000) n;

-- Add items to active/abandoned carts
INSERT INTO cart_items (cart_id, variant_id, quantity, unit_price)
SELECT
    c.id,
    pv.id,
    random_between(1, 5),
    pv.price
FROM carts c
JOIN LATERAL (
    SELECT pv.id, pv.price
    FROM product_variants pv
    WHERE pv.is_active = true
    ORDER BY random()
    LIMIT random_between(1, 4)
) pv ON true
WHERE c.status IN ('active', 'abandoned')
ON CONFLICT (cart_id, variant_id) DO NOTHING;

-- =============================================================================
-- WISHLISTS
-- =============================================================================
INSERT INTO wishlists (user_id, product_id)
SELECT DISTINCT
    u.id,
    p.id
FROM (SELECT id FROM users WHERE role = 'customer' ORDER BY random() LIMIT 500) u
JOIN LATERAL (
    SELECT id FROM products WHERE is_active = true ORDER BY random() LIMIT random_between(1, 8)
) p ON true
ON CONFLICT (user_id, product_id) DO NOTHING;

-- =============================================================================
-- UPDATE inventory reserved counts based on pending/processing orders
-- =============================================================================
UPDATE inventory inv
SET reserved = COALESCE(pending_qty.qty, 0)
FROM (
    SELECT oi.variant_id, SUM(oi.quantity) AS qty
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status IN ('pending', 'confirmed', 'processing')
    GROUP BY oi.variant_id
) pending_qty
WHERE inv.variant_id = pending_qty.variant_id;

-- Clamp reserved to not exceed quantity
UPDATE inventory
SET reserved = quantity
WHERE reserved > quantity;

-- =============================================================================
-- CLEANUP: drop helper functions
-- =============================================================================
DROP FUNCTION IF EXISTS random_between(INT, INT);
DROP FUNCTION IF EXISTS random_decimal(NUMERIC, NUMERIC, INT);

-- =============================================================================
-- VERIFICATION COUNTS
-- =============================================================================
SELECT 'users'            AS tbl, COUNT(*) AS rows FROM users
UNION ALL SELECT 'addresses',       COUNT(*) FROM addresses
UNION ALL SELECT 'categories',      COUNT(*) FROM categories
UNION ALL SELECT 'products',        COUNT(*) FROM products
UNION ALL SELECT 'product_variants',COUNT(*) FROM product_variants
UNION ALL SELECT 'inventory',       COUNT(*) FROM inventory
UNION ALL SELECT 'promotions',      COUNT(*) FROM promotions
UNION ALL SELECT 'orders',          COUNT(*) FROM orders
UNION ALL SELECT 'order_items',     COUNT(*) FROM order_items
UNION ALL SELECT 'reviews',         COUNT(*) FROM reviews
UNION ALL SELECT 'carts',           COUNT(*) FROM carts
UNION ALL SELECT 'cart_items',      COUNT(*) FROM cart_items
UNION ALL SELECT 'wishlists',       COUNT(*) FROM wishlists
ORDER BY tbl;
