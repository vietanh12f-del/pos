<?php
$file = 'assets/css/custom.css';
$css = file_get_contents($file);

// Replace hardcoded #fff background
$css = preg_replace('/background:\s*#fff(fff)?(!important)?;/i', 'background: var(--bg-white)$2;', $css);
$css = preg_replace('/background-color:\s*#fff(fff)?(!important)?;/i', 'background-color: var(--bg-white)$2;', $css);

// Replace #eee and #f0f0f0
$css = preg_replace('/background:\s*#eee(eee)?(!important)?;/i', 'background: #222$2;', $css);
$css = preg_replace('/background-color:\s*#eee(eee)?(!important)?;/i', 'background-color: #222$2;', $css);
$css = preg_replace('/background:\s*#f0f0f0(!important)?;/i', 'background: #1a1a1a$2;', $css);
$css = preg_replace('/background-color:\s*#f0f0f0(!important)?;/i', 'background-color: #1a1a1a$2;', $css);
$css = preg_replace('/background:\s*#FFEFEE(!important)?;/i', 'background: #111$2;', $css);

// Text colors that are white to black (since primary color is now gold)
$css = preg_replace('/color:\s*#fff(!important)?;/i', 'color: #000$2;', $css);

// Make sure body has black background
$css = preg_replace('/body\s*\{[^}]*\}/', "body {\n    background: #000000;\n    color: var(--text-dark);\n    font-family: var(--font-sans);\n    font-weight: 400;\n    line-height: 1.7;\n    -webkit-font-smoothing: antialiased;\n}", $css);

file_put_contents($file, $css);
echo "done";
