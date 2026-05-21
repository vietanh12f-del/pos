<?php
/**
 * Script to update all HTTP URLs to HTTPS in WordPress database
 * 
 * INSTRUCTIONS:
 * 1. Upload this file to your WordPress root directory (same level as wp-config.php)
 * 2. Access it via browser: https://henieskinlab.com/update-urls-to-https.php
 * 3. The script will update all URLs in the database
 * 4. DELETE this file after running for security
 * 
 * IMPORTANT: Backup your database before running this script!
 */

// Load WordPress
require_once('wp-load.php');

// Check if user is admin
if (!current_user_can('manage_options')) {
    die('You must be logged in as administrator to run this script.');
}

// Security check - require confirmation
$confirm = isset($_GET['confirm']) && $_GET['confirm'] === 'yes';

if (!$confirm) {
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <title>Update URLs to HTTPS</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
            .warning { background: #fff3cd; border: 1px solid #ffc107; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
            .button { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }
            .button:hover { background: #0056b3; }
            .danger { background: #dc3545; }
            .danger:hover { background: #c82333; }
        </style>
    </head>
    <body>
        <h1>Update URLs to HTTPS</h1>
        
        <div class="warning">
            <h2>⚠️ WARNING</h2>
            <p><strong>This script will update ALL URLs in your WordPress database from HTTP to HTTPS.</strong></p>
            <p>Before proceeding:</p>
            <ul>
                <li>✅ Make sure you have a <strong>database backup</strong></li>
                <li>✅ Ensure your site has a valid <strong>SSL certificate</strong></li>
                <li>✅ Test that your site works with HTTPS</li>
            </ul>
        </div>
        
        <h2>What will be updated:</h2>
        <ul>
            <li>Site URL and Home URL</li>
            <li>All post content and excerpts</li>
            <li>All post meta data</li>
            <li>All options</li>
            <li>All comments</li>
            <li>Widget content</li>
        </ul>
        
        <p>
            <a href="?confirm=yes" class="button danger" onclick="return confirm('Are you sure? Have you backed up your database?')">
                Yes, Update All URLs to HTTPS
            </a>
            &nbsp;
            <a href="<?php echo admin_url(); ?>" class="button">Cancel</a>
        </p>
        
        <p><small>After running this script, please <strong>DELETE this file</strong> for security.</small></p>
    </body>
    </html>
    <?php
    exit;
}

// Run the update
global $wpdb;

$old_url = 'http://henieskinlab.com';
$new_url = 'https://henieskinlab.com';

echo '<!DOCTYPE html>
<html>
<head>
    <title>Updating URLs...</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .success { background: #d4edda; border: 1px solid #c3e6cb; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .info { background: #d1ecf1; border: 1px solid #bee5eb; padding: 10px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Updating URLs to HTTPS...</h1>';

// Update options table
$result = $wpdb->query(
    $wpdb->prepare(
        "UPDATE {$wpdb->options} SET option_value = REPLACE(option_value, %s, %s) WHERE option_value LIKE %s",
        $old_url,
        $new_url,
        '%' . $wpdb->esc_like($old_url) . '%'
    )
);
echo '<div class="success">✓ Updated ' . $result . ' rows in options table</div>';

// Update posts table
$result = $wpdb->query(
    $wpdb->prepare(
        "UPDATE {$wpdb->posts} SET post_content = REPLACE(post_content, %s, %s) WHERE post_content LIKE %s",
        $old_url,
        $new_url,
        '%' . $wpdb->esc_like($old_url) . '%'
    )
);
echo '<div class="success">✓ Updated ' . $result . ' rows in posts (content)</div>';

$result = $wpdb->query(
    $wpdb->prepare(
        "UPDATE {$wpdb->posts} SET post_excerpt = REPLACE(post_excerpt, %s, %s) WHERE post_excerpt LIKE %s",
        $old_url,
        $new_url,
        '%' . $wpdb->esc_like($old_url) . '%'
    )
);
echo '<div class="success">✓ Updated ' . $result . ' rows in posts (excerpt)</div>';

$result = $wpdb->query(
    $wpdb->prepare(
        "UPDATE {$wpdb->posts} SET guid = REPLACE(guid, %s, %s) WHERE guid LIKE %s",
        $old_url,
        $new_url,
        '%' . $wpdb->esc_like($old_url) . '%'
    )
);
echo '<div class="success">✓ Updated ' . $result . ' rows in posts (guid)</div>';

// Update postmeta table
$result = $wpdb->query(
    $wpdb->prepare(
        "UPDATE {$wpdb->postmeta} SET meta_value = REPLACE(meta_value, %s, %s) WHERE meta_value LIKE %s",
        $old_url,
        $new_url,
        '%' . $wpdb->esc_like($old_url) . '%'
    )
);
echo '<div class="success">✓ Updated ' . $result . ' rows in postmeta</div>';

// Update comments table
$result = $wpdb->query(
    $wpdb->prepare(
        "UPDATE {$wpdb->comments} SET comment_content = REPLACE(comment_content, %s, %s) WHERE comment_content LIKE %s",
        $old_url,
        $new_url,
        '%' . $wpdb->esc_like($old_url) . '%'
    )
);
echo '<div class="success">✓ Updated ' . $result . ' rows in comments</div>';

// Update site URL and home URL
update_option('siteurl', $new_url);
update_option('home', $new_url);
echo '<div class="success">✓ Updated site URL and home URL</div>';

// Clear cache
wp_cache_flush();
echo '<div class="success">✓ Cleared WordPress cache</div>';

echo '
    <div class="info">
        <h2>✅ Update Complete!</h2>
        <p>All URLs have been updated from HTTP to HTTPS.</p>
        <p><strong>IMPORTANT:</strong></p>
        <ul>
            <li>Please <strong>DELETE this file (update-urls-to-https.php)</strong> now for security</li>
            <li>Clear your browser cache</li>
            <li>Test your website thoroughly</li>
            <li>If you use a caching plugin, clear its cache too</li>
        </ul>
        <p><a href="' . admin_url() . '">Go to WordPress Admin</a></p>
    </div>
</body>
</html>';
