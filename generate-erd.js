const fs = require('fs');
const { execSync } = require('child_process');

console.log('Reading ERD source from thilan-month3-erd.md...');
const content = fs.readFileSync('thilan-month3-erd.md', 'utf8');
const match = content.match(/```mermaid\n([\s\S]*?)\n```/);

if (!match) {
    console.error('ERROR: Could not find mermaid block in thilan-month3-erd.md');
    process.exit(1);
}

fs.writeFileSync('erd-temp.mmd', match[1]);
console.log('Mermaid block extracted OK');

console.log('Generating PNG...');
try {
    execSync('mmdc -i erd-temp.mmd -o thilan-month3-erd.png -t dark -b white --width 2400 --height 1800', {
        stdio: 'inherit'
    });
    if (fs.existsSync('erd-temp.mmd')) fs.unlinkSync('erd-temp.mmd');
    const size = (fs.statSync('thilan-month3-erd.png').size / 1024).toFixed(0);
    console.log(`\nthilan-month3-erd.png generated successfully (${size} KB)`);
} catch (err) {
    if (fs.existsSync('erd-temp.mmd')) fs.unlinkSync('erd-temp.mmd');
    console.error('ERROR generating PNG:', err.message);
    process.exit(1);
}
