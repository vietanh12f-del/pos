<?php
/**
 * Force Sync Service Detail Articles
 * 
 * HƯỚNG DẪN:
 * 1. Truy cập file này qua trình duyệt: http://your-site.com/wp-content/themes/ai-quest-theme/FORCE-SYNC-SERVICE-DETAIL-ARTICLES.php
 * 2. Script sẽ reset option và chạy sync function
 * 3. Xóa file này sau khi chạy xong
 */

// Load WordPress
require_once('../../../wp-load.php');

// Check if user is admin
if (!current_user_can('manage_options')) {
    wp_die('Bạn không có quyền truy cập trang này.');
}

echo '<h1>Force Sync Service Detail Articles</h1>';
echo '<hr>';

// Reset sync option
delete_option('ai_quest_svc_detail_articles_synced');
echo '<p>✓ Đã reset option: ai_quest_svc_detail_articles_synced</p>';

// Run sync function
if (function_exists('ai_quest_sync_service_detail_articles')) {
    echo '<p>→ Đang chạy sync function...</p>';
    ai_quest_sync_service_detail_articles();
    echo '<p>✓ Đã chạy xong sync function</p>';
} else {
    echo '<p>✗ Không tìm thấy function ai_quest_sync_service_detail_articles</p>';
}

// Check results
$articles = get_posts(array(
    'post_type' => 'svc_detail_article',
    'post_status' => 'any',
    'posts_per_page' => -1
));

echo '<hr>';
echo '<h2>Kết Quả</h2>';
echo '<p><strong>Tổng số bài viết chi tiết DV:</strong> ' . count($articles) . '</p>';

if (count($articles) > 0) {
    echo '<ul>';
    foreach ($articles as $article) {
        $service_key = get_post_meta($article->ID, '_service_key', true);
        $parent = get_post_meta($article->ID, '_parent_service', true);
        echo '<li>';
        echo '<strong>' . esc_html($article->post_title) . '</strong> ';
        echo '(Status: ' . $article->post_status . ') ';
        echo '<br>Parent: ' . esc_html($parent);
        echo '<br>Key: ' . esc_html($service_key);
        echo '</li>';
    }
    echo '</ul>';
} else {
    echo '<p style="color: red;">Không có bài viết nào được tạo. Kiểm tra lại dữ liệu trong Customizer.</p>';
}

echo '<hr>';
echo '<p><a href="' . admin_url('edit.php?post_type=svc_detail_article') . '">→ Xem danh sách bài viết</a></p>';
echo '<p><strong>Lưu ý:</strong> Xóa file này sau khi chạy xong để bảo mật.</p>';
