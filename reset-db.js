const { Client } = require('pg');

const DB = "postgresql://neondb_owner:npg_lYz6r9AJHiFm@ep-ancient-rain-aog95fmq-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require";

async function main() {
    const client = new Client({ connectionString: DB });
    await client.connect();
    console.log('Connected to Neon');
    await client.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
    console.log('Database reset — all tables dropped, schema recreated clean');
    await client.end();
}

main().catch(err => { console.error('Error:', err.message); process.exit(1); });
