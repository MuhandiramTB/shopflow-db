const { Client } = require('pg');
const fs = require('fs');

const CONNECTION = "postgresql://neondb_owner:npg_lYz6r9AJHiFm@ep-ancient-rain-aog95fmq-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require";

async function runFile(filePath) {
    const client = new Client({ connectionString: CONNECTION });
    await client.connect();
    console.log(`\n✓ Connected to Neon`);
    console.log(`  Running: ${filePath}\n`);

    const sql = fs.readFileSync(filePath, 'utf8');
    const statements = splitStatements(sql);
    let success = 0, failed = 0, skipped = 0;

    for (let i = 0; i < statements.length; i++) {
        const stmt = statements[i].trim();
        if (!stmt) { skipped++; continue; }

        try {
            const result = await client.query(stmt);
            success++;
            if (result.rows && result.rows.length > 0 && result.rows.length <= 30) {
                const cols = Object.keys(result.rows[0]);
                console.log('  ' + cols.join('\t\t'));
                result.rows.forEach(r => console.log('  ' + cols.map(c => String(r[c] ?? '')).join('\t\t')));
                console.log();
            } else if (result.command) {
                const tag = result.rowCount != null ? `${result.command} ${result.rowCount}` : result.command;
                process.stdout.write(`  [${tag}]\n`);
            }
        } catch (err) {
            const msg = err.message.split('\n')[0];
            if (msg.includes('already exists')) {
                console.log(`  [SKIP] ${msg}`);
                skipped++;
            } else {
                failed++;
                console.error(`  [ERROR] ${msg}`);
                const preview = stmt.replace(/\s+/g, ' ').substring(0, 100);
                console.error(`         SQL: ${preview}...`);
            }
        }
    }

    await client.end();
    console.log(`\n${'='.repeat(60)}`);
    console.log(`  ✓ Success: ${success}  ✗ Failed: ${failed}  - Skipped: ${skipped}`);
    console.log(`${'='.repeat(60)}\n`);
    return failed === 0;
}

function splitStatements(sql) {
    // Remove single-line comments FIRST, then split on semicolons
    // But preserve dollar-quoted blocks (DO $$ ... $$)
    const statements = [];
    let current = '';
    let inDollarQuote = false;
    let dollarTag = '';
    let inSingleQuote = false;
    let i = 0;

    while (i < sql.length) {
        // Handle dollar-quoted blocks
        if (!inDollarQuote && !inSingleQuote) {
            const dollarMatch = sql.slice(i).match(/^(\$[^$]*\$)/);
            if (dollarMatch) {
                inDollarQuote = true;
                dollarTag = dollarMatch[1];
                current += dollarTag;
                i += dollarTag.length;
                continue;
            }
        }
        if (inDollarQuote) {
            if (sql.slice(i).startsWith(dollarTag)) {
                current += dollarTag;
                i += dollarTag.length;
                inDollarQuote = false;
                dollarTag = '';
                continue;
            }
            current += sql[i++];
            continue;
        }

        // Handle single-quoted strings
        if (!inSingleQuote && sql[i] === "'") {
            inSingleQuote = true;
            current += sql[i++];
            continue;
        }
        if (inSingleQuote) {
            if (sql[i] === "'" && sql[i + 1] === "'") {
                current += "''";
                i += 2;
            } else if (sql[i] === "'") {
                inSingleQuote = false;
                current += sql[i++];
            } else {
                current += sql[i++];
            }
            continue;
        }

        // Skip single-line comments (but keep the newline)
        if (sql[i] === '-' && sql[i + 1] === '-') {
            while (i < sql.length && sql[i] !== '\n') i++;
            current += '\n';
            continue;
        }

        // Split on semicolon
        if (sql[i] === ';') {
            current += ';';
            const trimmed = current.trim().replace(/^[\s;]+/, '');
            if (trimmed) statements.push(trimmed);
            current = '';
            i++;
            continue;
        }

        current += sql[i++];
    }

    if (current.trim()) statements.push(current.trim());
    return statements;
}

const file = process.argv[2];
if (!file) { console.error('Usage: node run-sql.js <file.sql>'); process.exit(1); }

runFile(file).then(ok => process.exit(ok ? 0 : 1)).catch(err => {
    console.error('Fatal:', err.message);
    process.exit(1);
});
