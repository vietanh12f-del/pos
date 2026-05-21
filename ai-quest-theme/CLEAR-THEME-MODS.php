<?php
/**
 * Clear Banner Values from THEME_MODS
 * 
 * This script removes banner-related values from theme_mods table.
 * Upload to theme root and access via:
 * https://yourdomain.com/wp-content/themes/ai-quest-theme/CLEAR-THEME-MODS.php
 * 
 * DELETE THIS FILE after running for security!
 */

// Load WordPress
require_once('../../../wp-load.php');

// Check if user is admin
if (!current_user_can('manage_options')) {
    die('Access denied. You must be an administrator.');
}

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html>
<head>
    <title>Clear Theme Mods</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 5px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #6B7D3A; padding-bottom: 10px; }
        .success { background: #d4edda; border-left: 4px solid #28a745; padding: 15px; margin: 20px 0; }
        .info { background: #d1ecf1; border-left: 4px solid #17a2b8; padding: 15px; margin: 20px 0; }
        .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #6B7D3A; color: white; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🧹 Clear Banner Theme Mods</h1>

        <?php
        $banner_keys = array(
            'ai_quest_banner_enabled',
            'ai_quest_banner_badge',
            'ai_quest_banner_title',
            'ai_quest_banner_description',
            'ai_quest_banner_button_text',
            'ai_quest_banner_button_url',
            'ai_quest_banner_bg_url'
        );

        echo '<div class="info"><strong>📋 Checking theme_mods...</strong></div>';

        $found_values = array();
        foreach ($banner_keys as $key) {
            $value = get_theme_mod($key, null);
            if ($value !== null) {
                $found_values[$key] = $value;
            }
        }

        if (empty($found_values)) {
            echo '<div class="success"><strong>✓ No banner values found in theme_mods!</strong><br>Theme mods are already clean.</div>';
        } else {
            echo '<div class="warning"><strong>⚠️ Found ' . count($found_values) . ' banner value(s) in theme_mods:</strong></div>';
            echo '<table>';
            echo '<tr><th>Key</th><th>Value</th></tr>';
            foreach ($found_values as $key => $value) {
                $display_value = is_string($value) ? esc_html($value) : print_r($value, true);
                if ($display_value === '') {
                    $display_value = '(empty string)';
                }
                echo '<tr><td><code>' . esc_html($key) . '</code></td><td>' . $display_value . '</td></tr>';
            }
            echo '</table>';

            // Remove the values
            echo '<div class="info"><strong>🔄 Removing values from theme_mods...</strong></div>';
            
            foreach ($banner_keys as $key) {
                remove_theme_mod($key);
            }

            echo '<div class="success"><strong>✓ Successfully removed all banner values from theme_mods!</strong></div>';

            // Verify
            $remaining = array();
            foreach ($banner_keys as $key) {
                $value = get_theme_mod($key, null);
                if ($value !== null) {
                    $remaining[$key] = $value;
                }
            }

            if (empty($remaining)) {
                echo '<div class="success"><strong>✓ Verification: All values successfully removed!</strong></div>';
            } else {
                echo '<div class="warning"><strong>⚠️ Warning: Some values still remain:</strong><br>';
                echo '<pre>' . print_r($remaining, true) . '</pre></div>';
            }
        }
        ?>

        <div class="info">
            <strong>📝 What was done:</strong>
            <ul>
                <li>Checked for banner-related values in theme_mods table</li>
                <li>Removed any found values using <code>remove_theme_mod()</code></li>
                <li>Verified the removal was successful</li>
            </ul>
        </div>

        <div class="warning">
            <strong>⚠️ IMPORTANT - Next Steps:</strong>
            <ol>
                <li>Clear your browser cache (Ctrl+Shift+Delete)</li>
                <li>If using a caching plugin (WP Super Cache, W3 Total Cache, etc.), clear it</li>
                <li>Check if banner content is still showing on the homepage</li>
                <li><strong>DELETE THIS FILE</strong> for security: <code>CLEAR-THEME-MODS.php</code></li>
            </ol>
        </div>

        <div class="info">
            <strong>🔍 Still seeing content?</strong>
            <p>If banner content still appears after clearing theme_mods and browser cache, run the <code>DEBUG-BANNER-VALUES.php</code> script to see where the values are coming from.</p>
        </div>
    </div>
</body>
</html>
