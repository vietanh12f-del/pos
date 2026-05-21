<?php
/**
 * Flush Permalinks
 * 
 * Truy cập file này qua browser để flush rewrite rules
 * URL: http://your-site.com/wp-content/themes/ai-quest-theme/FLUSH-PERMALINKS.php
 */

require_once('../../../wp-load.php');

if (!current_user_can('manage_options')) {
    wp_die('Bạn không có quyền truy cập.');
}

// Reset flush options
delete_option('ai_quest_service_article_rewrite_flushed');
delete_option('ai_quest_svc_detail_rewrite_flushed');

// Flush rewrite rules
flush_rewrite_rules();

echo '<h1>✅ Đã flush permalinks thành công!</h1>';
echo '<p>URL structure mới:</p>';
echo '<ul>';
echo '<li>Dịch vụ con: <code>/dich-vu/cham-soc-da/cham-soc-da-mun/</code></li>';
echo '<li>Dịch vụ chi tiết: <code>/dich-vu/cham-soc-da/cham-soc-da-mun/mun-co-ban/</code></li>';
echo '</ul>';
echo '<p><a href="' . admin_url() . '">← Quay lại Dashboard</a></p>';
echo '<p><strong>Lưu ý:</strong> Xóa file này sau khi chạy xong.</p>';
