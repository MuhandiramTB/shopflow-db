const { Client } = require('pg');

const DB = "postgresql://neondb_owner:npg_lYz6r9AJHiFm@ep-ancient-rain-aog95fmq-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require";

async function main() {
    const client = new Client({ connectionString: DB });
    await client.connect();
    console.log('Connected to Neon\n');

    // Fix 1: orders total_amount
    const r1 = await client.query(`
        UPDATE orders
        SET tax_amount   = GREATEST(0, ROUND(GREATEST(0, subtotal - discount_amount + shipping_cost) * 0.08, 2)),
            total_amount = GREATEST(0, ROUND(
                GREATEST(0, subtotal - discount_amount + shipping_cost) +
                GREATEST(0, ROUND(GREATEST(0, subtotal - discount_amount + shipping_cost) * 0.08, 2))
            , 2))
        WHERE total_amount = 0
    `);
    console.log('Orders fixed:', r1.rowCount, 'rows');

    // Fix 2: inventory reserved
    const r2 = await client.query(`
        UPDATE inventory inv
        SET reserved = LEAST(COALESCE(pq.qty, 0), inv.quantity)
        FROM (
            SELECT oi.variant_id, SUM(oi.quantity) AS qty
            FROM order_items oi
            JOIN orders o ON oi.order_id = o.id
            WHERE o.status IN ('pending','confirmed','processing')
            GROUP BY oi.variant_id
        ) pq
        WHERE inv.variant_id = pq.variant_id
    `);
    console.log('Inventory reserved fixed:', r2.rowCount, 'rows');

    // Fix 3: reviews
    await client.query('DELETE FROM reviews');
    const r3 = await client.query(`
        INSERT INTO reviews (product_id, user_id, order_id, rating, title, body, is_verified, is_approved)
        SELECT product_id, user_id, order_id,
            (ARRAY[1,2,3,3,4,4,4,5,5,5,5,5])[floor(random()*12+1)::int],
            (ARRAY[
                'Great product!','Excellent quality','Good value','Highly recommend',
                'Exceeded expectations','Very satisfied','Love it!','Amazing!',
                'Would buy again','Solid product','Fast delivery','Perfect!'
            ])[floor(random()*12+1)::int],
            'Quality is excellent. Arrived on time and exactly as described. Very happy with this purchase.',
            true,
            (random() < 0.85)
        FROM (
            SELECT oi.product_id, o.user_id, o.id AS order_id,
                   ROW_NUMBER() OVER (PARTITION BY oi.product_id, o.user_id ORDER BY o.id) AS rn
            FROM order_items oi
            JOIN orders o ON oi.order_id = o.id
            WHERE o.status IN ('completed','delivered')
        ) t
        WHERE rn = 1
        LIMIT 3000
        ON CONFLICT (product_id, user_id) DO NOTHING
    `);
    console.log('Reviews inserted:', r3.rowCount, 'rows');

    await client.end();
    console.log('\nAll fixes applied successfully!');
}

main().catch(err => { console.error('Error:', err.message); process.exit(1); });
