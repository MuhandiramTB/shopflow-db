const { Client } = require('pg');

const DB = "postgresql://neondb_owner:npg_lYz6r9AJHiFm@ep-ancient-rain-aog95fmq-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require";

async function main() {
    const client = new Client({ connectionString: DB });
    await client.connect();
    console.log('Connected to Neon\n');

    // Load all active variants with product info
    const vars = await client.query(`
        SELECT pv.id, pv.sku, pv.name, pv.price, pv.product_id, p.name AS product_name
        FROM product_variants pv
        JOIN products p ON pv.product_id = p.id
        WHERE pv.is_active = true
    `);
    const variants = vars.rows;

    // Load all customer user IDs
    const usersRes = await client.query(`SELECT id FROM users WHERE role = 'customer' ORDER BY id`);
    const userIds = usersRes.rows.map(r => r.id);
    console.log('Loaded', variants.length, 'variants and', userIds.length, 'users');

    // Randomize order user_ids so all orders don't belong to same user
    console.log('Randomizing order user_ids...');
    for (let batch = 1; batch <= 5000; batch += 500) {
        const updates = [];
        for (let i = batch; i < batch + 500 && i <= 5000; i++) {
            const uid = userIds[Math.floor(Math.random() * userIds.length)];
            updates.push(`(${i}, ${uid})`);
        }
        await client.query(`
            UPDATE orders SET user_id = v.uid
            FROM (VALUES ${updates.join(',')}) AS v(oid, uid)
            WHERE orders.id = v.oid
        `);
    }
    console.log('Order user_ids randomized');

    // Clear existing order_items and reviews
    await client.query('DELETE FROM reviews');
    await client.query('DELETE FROM order_items');
    console.log('Cleared old order_items and reviews\n');

    // Insert order_items with proper random distribution
    const itemsPerOrder = [1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 5];
    let total = 0;
    let batchRows = [];

    for (let orderId = 1; orderId <= 5000; orderId++) {
        const numItems = itemsPerOrder[Math.floor(Math.random() * itemsPerOrder.length)];
        const usedVariants = new Set();

        for (let j = 0; j < numItems; j++) {
            let v, tries = 0;
            do {
                v = variants[Math.floor(Math.random() * variants.length)];
                tries++;
            } while (usedVariants.has(v.id) && tries < 20);
            usedVariants.add(v.id);

            const qty = Math.floor(Math.random() * 4) + 1;
            const price = parseFloat(v.price);
            batchRows.push(
                `(${orderId}, ${v.id}, ${v.product_id}, ` +
                `${client.escapeLiteral(v.product_name)}, ` +
                `${client.escapeLiteral(v.name)}, ` +
                `${client.escapeLiteral(v.sku)}, ` +
                `${qty}, ${price}, ${(qty * price).toFixed(2)})`
            );
            total++;
        }

        if (batchRows.length >= 500 || orderId === 5000) {
            await client.query(`
                INSERT INTO order_items
                    (order_id, variant_id, product_id, product_name, variant_name, sku, quantity, unit_price, total_price)
                VALUES ${batchRows.join(',')}
            `);
            batchRows = [];
            if (orderId % 1000 === 0) {
                console.log(`  Progress: order ${orderId} / 5000 | items so far: ${total}`);
            }
        }
    }
    console.log(`\nTotal order_items inserted: ${total}`);

    // Insert reviews from the now-correct order_items
    const r = await client.query(`
        INSERT INTO reviews (product_id, user_id, order_id, rating, title, body, is_verified, is_approved)
        SELECT product_id, user_id, order_id,
            (ARRAY[1,2,3,3,4,4,4,5,5,5,5,5])[floor(random()*12+1)::int],
            (ARRAY[
                'Great product!', 'Excellent quality', 'Good value', 'Highly recommend',
                'Exceeded expectations', 'Very satisfied', 'Love it!', 'Amazing!',
                'Would buy again', 'Solid product', 'Fast delivery', 'Perfect!'
            ])[floor(random()*12+1)::int],
            'Quality is excellent. Arrived on time and exactly as described. Very happy with this purchase.',
            true,
            (random() < 0.85)
        FROM (
            SELECT oi.product_id, o.user_id, o.id AS order_id,
                   ROW_NUMBER() OVER (PARTITION BY oi.product_id, o.user_id ORDER BY o.id) AS rn
            FROM order_items oi
            JOIN orders o ON oi.order_id = o.id
            WHERE o.status IN ('completed', 'delivered')
        ) t
        WHERE rn = 1
        LIMIT 3000
        ON CONFLICT (product_id, user_id) DO NOTHING
    `);
    console.log(`Reviews inserted: ${r.rowCount} rows`);

    await client.end();
    console.log('\nDone!');
}

main().catch(err => { console.error('Error:', err.message); process.exit(1); });
