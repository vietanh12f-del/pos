const fs = require('fs');
const file = 'assets/css/custom.css';
let css = fs.readFileSync(file, 'utf8');

// replace hardcoded whites with var(--bg-white)
css = css.replace(/background:\s*#fff(fff)?(!important)?;/gi, 'background: var(--bg-white)$2;');
css = css.replace(/background-color:\s*#fff(fff)?(!important)?;/gi, 'background-color: var(--bg-white)$2;');

// replace other light backgrounds
css = css.replace(/background:\s*#eee(eee)?(!important)?;/gi, 'background: #222$2;');
css = css.replace(/background-color:\s*#eee(eee)?(!important)?;/gi, 'background-color: #222$2;');
css = css.replace(/background:\s*#f0f0f0(!important)?;/gi, 'background: #1a1a1a$2;');
css = css.replace(/background-color:\s*#f0f0f0(!important)?;/gi, 'background-color: #1a1a1a$2;');
css = css.replace(/background:\s*#FFEFEE(!important)?;/gi, 'background: #111$2;');

// Change text colors that are white to black, because they sit on gold now
css = css.replace(/color:\s*#fff(!important)?;/gi, 'color: #000$2;');

// Make sure body has black background
css = css.replace(/body\s*\{[^}]*\}/g, (match) => {
    return match.replace(/background:\s*linear-gradient[^;]+;/, 'background: #000000;');
});

fs.writeFileSync(file, css);
console.log('done');