<?php
/**
 * Clear ALL Banner Data (Options + Theme Mods)
 * 
 * This script removes banner values from BOTH options and theme_mods tables.
 * Upload to theme root and access via:
 * https://yourdomain.com/wp-content/themes/ai-quest-theme/CLEAR-ALL-BANNER-DATA.php
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
    <title>Clear All Banner Data</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 30px; border-radius: 5px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #6B7D3A; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .success { background: #d4edda; border-left: 4px solid #28a745; padding: 15px; margin: 20px 0; }
        .info { background: #d1ecf1; border-left: 4px solid #17a2b8; padding: 15px; margin: 20px 0; }
        .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .error { background: #f8d7da; border-left: 4px solid #dc3545; padding: 15px; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #6B7D3A; color: white; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
        .deleted { color: #dc3545; font-weight: bold; }
        .kept { color: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🧹 Clear All Banner Data</h1>
        <p>This script will remove banner content from both OPTIONS and THEME_MODS tables, while keeping the banner enabled/disabled setting.</p>

        <?php
        $banner_keys = array(
            'ai_quest_banner_badge',
            'ai_quest_banner_title',
            'ai_quest_banner_description',
            'ai_quest_banner_button_text',
            'ai_quest_banner_button_url',
            'ai_quest_banner_bg_url'
        );

        // Keep enabled setting
        $keep_keys = array('ai_quest_banner_enabled');

        // STEP 1: Check and clear OPTIONS table
        echo '<h2>📦 Step 1: OPTIONS Table</h2>';
        
        $options_found = array();
        foreach ($banner_keys as $key) {
            $value = get_option($key, null);
            if ($value !== null) {
                $options_found[$key] = $value;
            }
        }

        if (empty($options_found)) {
            echo '<div class="success">✓ No banner content found in OPTIONS table</div>';
        } else {
            echo '<div class="warning">Found ' . count($options_found) . ' value(s) in OPTIONS table:</div>';
            echo '<table><tr><th>Key</th><th>Current Value</th><th>Action</th></tr>';
            
            foreach ($options_found as $key => $value) {
                $display_value = is_string($value) ? esc_html($value) : print_r($value, true);
                if ($display_value === '') {
                    $display_value = '(empty string)';
                }
                
                // Delete the option
                $deleted = delete_option($key);
                $action = $deleted ? '<span class="deleted">DELETED</span>' : '<span class="error">Failed to delete</span>';
                
                echo '<tr>';
                echo '<td><code>' . esc_html($key) . '</code></td>';
                echo '<td>' . $display_value . '</td>';
                echo '<td>' . $action . '</td>';
                echo '</tr>';
            }
            echo '</table>';
            
            echo '<div class="success">✓ Cleared banner content from OPTIONS table</div>';
        }

        // STEP 2: Check and clear THEME_MODS
        echo '<h2>🎨 Step 2: THEME_MODS</h2>';
        
        $mods_found = array();
        foreach ($banner_keys as $key) {
            $value = get_theme_mod($key, null);
            if ($value !== null) {
                $mods_found[$key] = $value;
            }
        }

        if (empty($mods_found)) {
            echo '<div class="success">✓ No banner content found in THEME_MODS</div>';
        } else {
            echo '<div class="warning">Found ' . count($mods_found) . ' value(s) in THEME_MODS:</div>';
            echo '<table><tr><th>Key</th><th>Current Value</th><th>Action</th></tr>';
            
            foreach ($mods_found as $key => $value) {
                $display_value = is_string($value) ? esc_html($value) : print_r($value, true);
                if ($display_value === '') {
                    $display_value = '(empty string)';
                }
                
                // Remove the theme mod
                remove_theme_mod($key);
                $action = '<span class="deleted">REMOVED</span>';
                
                echo '<tr>';
                echo '<td><code>' . esc_html($key) . '</code></td>';
                echo '<td>' . $display_value . '</td>';
                echo '<td>' . $action . '</td>';
                echo '</tr>';
            }
            echo '</table>';
            
            echo '<div class="success">✓ Cleared banner content from THEME_MODS</div>';
        }

        // STEP 3: Verify
        echo '<h2>✅ Step 3: Verification</h2>';
        
        $remaining_options = array();
        $remaining_mods = array();
        
        foreach ($banner_keys as $key) {
            $opt_val = get_option($key, null);
            $mod_val = get_theme_mod($key, null);
            
            if ($opt_val !== null) {
                $remaining_options[$key] = $opt_val;
            }
            if ($mod_val !== null) {
                $remaining_mods[$key] = $mod_val;
            }
        }

        if (empty($remaining_options) && empty($remaining_mods)) {
            echo '<div class="success"><strong>✓ SUCCESS!</strong> All banner content has been removed from the database.</div>';
        } else {
            echo '<div class="error"><strong>⚠️ WARNING:</strong> Some values still remain in the database:</div>';
            if (!empty($remaining_options)) {
                echo '<p><strong>OPTIONS:</strong></p><pre>' . print_r($remaining_options, true) . '</pre>';
            }
            if (!empty($remaining_mods)) {
                echo '<p><strong>THEME_MODS:</strong></p><pre>' . print_r($remaining_mods, true) . '</pre>';
            }
        }

        // Show what was kept
        echo '<h2>🔒 Settings Preserved</h2>';
        echo '<p>The following settings were kept (not deleted):</p>';
        echo '<table><tr><th>Key</th><th>Current Value</th><th>Status</th></tr>';
        foreach ($keep_keys as $key) {
            $value = get_option($key, null);
            if ($value === null) {
                $value = get_theme_mod($key, null);
            }
            $display_value = $value !== null ? esc_html($value) : 'Not set';
            echo '<tr>';
            echo '<td><code>' . esc_html($key) . '</code></td>';
            echo '<td>' . $display_value . '</td>';
            echo '<td><span class="kept">KEPT</span></td>';
            echo '</tr>';
        }
        echo '</table>';
        ?>

        <div class="info">
            <strong>📝 What was done:</strong>
            <ul>
                <li>✓ Removed banner content fields from OPTIONS table</li>
                <li>✓ Removed banner content fields from THEME_MODS</li>
                <li>✓ Kept the banner enabled/disabled setting</li>
                <li>✓ Verified all content was removed</li>
            </ul>
        </div>

        <div class="warning">
            <strong>⚠️ IMPORTANT - Next Steps:</strong>
            <ol>
                <li><strong>Clear browser cache:</strong> Press Ctrl+Shift+Delete (or Cmd+Shift+Delete on Mac)</li>
                <li><strong>Clear WordPress cache:</strong> If using a caching plugin (WP Super Cache, W3 Total Cache, WP Rocket, etc.), clear it from the plugin settings</li>
                <li><strong>Clear server cache:</strong> If your hosting has server-level caching, clear it from your hosting control panel</li>
                <li><strong>Test the homepage:</strong> Visit your homepage in an incognito/private window to see if banner is gone</li>
                <li><strong>DELETE THIS FILE:</strong> Remove <code>CLEAR-ALL-BANNER-DATA.php</code> from your server for security</li>
            </ol>
        </div>

        <div class="info">
            <strong>🔍 Still seeing banner content?</strong>
            <p>If the banner still shows after clearing all caches:</p>
            <ul>
                <li>Run <code>DEBUG-BANNER-VALUES.php</code> to see where values are coming from</li>
                <li>Check if there's a CDN (Cloudflare, etc.) that needs cache clearing</li>
                <li>Try accessing the site from a different device/network</li>
            </ul>
        </div>

        <div class="success">
            <strong>✓ You can now add new banner content in the Customizer</strong>
            <p>Go to: <strong>Appearance → Customize → Khuyến Mãi (Banner)</strong></p>
            <p>When you leave fields empty, the banner section will not display on the homepage.</p>
        </div>
    </div>
</body>
</html>
