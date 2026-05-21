<?php
/**
 * DEBUG: Check Banner Values in Database
 * 
 * Upload this file to your theme root and access it via:
 * https://yourdomain.com/wp-content/themes/ai-quest-theme/DEBUG-BANNER-VALUES.php
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
    <title>Debug Banner Values</title>
    <style>
        body { font-family: monospace; padding: 20px; background: #f5f5f5; }
        .section { background: white; padding: 20px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        h2 { color: #333; border-bottom: 2px solid #6B7D3A; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #6B7D3A; color: white; }
        .empty { color: #999; font-style: italic; }
        .has-value { color: #d9534f; font-weight: bold; }
        .null { color: #999; }
        pre { background: #f9f9f9; padding: 10px; border-left: 3px solid #6B7D3A; overflow-x: auto; }
        .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .success { background: #d4edda; border-left: 4px solid #28a745; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>🔍 Debug Banner Values</h1>
    
    <div class="section">
        <h2>1. Banner Values from OPTIONS Table</h2>
        <table>
            <tr>
                <th>Setting Key</th>
                <th>Value</th>
                <th>Status</th>
            </tr>
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
            
            $has_options_values = false;
            foreach ($banner_keys as $key) {
                $value = get_option($key, null);
                $display_value = $value;
                $status_class = 'null';
                $status_text = 'Not in database';
                
                if ($value !== null) {
                    if ($value === '' || $value === false) {
                        $display_value = '(empty string)';
                        $status_class = 'empty';
                        $status_text = 'Empty';
                    } else {
                        $display_value = esc_html($value);
                        $status_class = 'has-value';
                        $status_text = 'HAS VALUE';
                        $has_options_values = true;
                    }
                } else {
                    $display_value = 'NULL';
                }
                
                echo "<tr>";
                echo "<td><code>{$key}</code></td>";
                echo "<td><span class='{$status_class}'>{$display_value}</span></td>";
                echo "<td><span class='{$status_class}'>{$status_text}</span></td>";
                echo "</tr>";
            }
            ?>
        </table>
    </div>

    <div class="section">
        <h2>2. Banner Values from THEME_MODS</h2>
        <table>
            <tr>
                <th>Setting Key</th>
                <th>Value</th>
                <th>Status</th>
            </tr>
            <?php
            $has_theme_mod_values = false;
            foreach ($banner_keys as $key) {
                $value = get_theme_mod($key, null);
                $display_value = $value;
                $status_class = 'null';
                $status_text = 'Not in theme_mods';
                
                if ($value !== null) {
                    if ($value === '' || $value === false) {
                        $display_value = '(empty string)';
                        $status_class = 'empty';
                        $status_text = 'Empty';
                    } else {
                        $display_value = esc_html($value);
                        $status_class = 'has-value';
                        $status_text = 'HAS VALUE';
                        $has_theme_mod_values = true;
                    }
                } else {
                    $display_value = 'NULL';
                }
                
                echo "<tr>";
                echo "<td><code>{$key}</code></td>";
                echo "<td><span class='{$status_class}'>{$display_value}</span></td>";
                echo "<td><span class='{$status_class}'>{$status_text}</span></td>";
                echo "</tr>";
            }
            ?>
        </table>
    </div>

    <div class="section">
        <h2>3. Values Retrieved by ai_quest_get_setting()</h2>
        <p>This shows what the theme actually sees when calling <code>ai_quest_get_setting()</code>:</p>
        <table>
            <tr>
                <th>Setting Key</th>
                <th>Returned Value</th>
                <th>Source</th>
            </tr>
            <?php
            foreach ($banner_keys as $key) {
                $value = ai_quest_get_setting($key, '');
                $display_value = $value;
                $status_class = 'null';
                
                if ($value === '' || $value === false) {
                    $display_value = '(empty string)';
                    $status_class = 'empty';
                } elseif ($value === null) {
                    $display_value = 'NULL';
                } else {
                    $display_value = esc_html($value);
                    $status_class = 'has-value';
                }
                
                // Determine source
                $option_value = get_option($key, null);
                $theme_mod_value = get_theme_mod($key, null);
                
                if ($option_value !== null) {
                    $source = 'OPTIONS table';
                } elseif ($theme_mod_value !== null) {
                    $source = 'THEME_MODS';
                } else {
                    $source = 'Default parameter';
                }
                
                echo "<tr>";
                echo "<td><code>{$key}</code></td>";
                echo "<td><span class='{$status_class}'>{$display_value}</span></td>";
                echo "<td>{$source}</td>";
                echo "</tr>";
            }
            ?>
        </table>
    </div>

    <div class="section">
        <h2>4. Complete THEME_MODS Array</h2>
        <p>All theme modifications stored in the database:</p>
        <pre><?php print_r(get_theme_mods()); ?></pre>
    </div>

    <?php if ($has_options_values || $has_theme_mod_values): ?>
        <div class="warning">
            <strong>⚠️ WARNING:</strong> Banner values found in database! This is why content is still showing even though Customizer appears empty.
            <?php if ($has_theme_mod_values): ?>
                <br><br>Values found in <strong>THEME_MODS</strong> - these need to be cleared.
            <?php endif; ?>
            <?php if ($has_options_values): ?>
                <br><br>Values found in <strong>OPTIONS</strong> table - these need to be cleared.
            <?php endif; ?>
        </div>
    <?php else: ?>
        <div class="success">
            <strong>✓ SUCCESS:</strong> No banner values found in database. If content is still showing, check for caching plugins or browser cache.
        </div>
    <?php endif; ?>

    <div class="section">
        <h2>5. Diagnosis & Next Steps</h2>
        <ul>
            <li><strong>Current Status:</strong> 
                <?php if ($has_options_values || $has_theme_mod_values): ?>
                    <span class="has-value">Values still exist in database</span>
                <?php else: ?>
                    <span class="empty">Database is clean</span>
                <?php endif; ?>
            </li>
            <li><strong>Customizer Behavior:</strong> When you save empty values in Customizer, WordPress stores them as empty strings, not NULL</li>
            <li><strong>The Problem:</strong> The <code>ai_quest_get_setting()</code> function checks both OPTIONS and THEME_MODS</li>
            <li><strong>Solution:</strong> Need to clear values from both locations, or modify the function to treat empty strings as "no content"</li>
        </ul>
    </div>

    <p style="margin-top: 40px; padding: 20px; background: #f0f0f0; border-radius: 5px;">
        <strong>📝 Note:</strong> After reviewing this debug info, delete this file for security:<br>
        <code>wp-content/themes/ai-quest-theme/DEBUG-BANNER-VALUES.php</code>
    </p>
</body>
</html>
