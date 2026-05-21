<?php
/**
 * Flush Rewrite Rules
 * 
 * HƯỚNG DẪN:
 * 1. Copy toàn bộ code này
 * 2. Paste vào CUỐI file functions.php (trước dấu ?> nếu có)
 * 3. Reload bất kỳ trang nào trên website
 * 4. Kiểm tra URL bài viết dịch vụ
 * 5. SAU ĐÓ XÓA CODE NÀY ĐI
 */

add_action('init', function() {
    // Force flush rewrite rules
    delete_option('ai_quest_service_article_rewrite_flushed');
    flush_rewrite_rules();
    
    // Show admin notice
    add_action('admin_notices', function() {
        echo '<div class="notice notice-success is-dismissible">';
        echo '<p><strong>✅ Đã cập nhật URL structure!</strong></p>';
        echo '<p>URL bài viết dịch vụ giờ sẽ có dạng: <code>/cham-soc-da/ten-dich-vu/</code></p>';
        echo '</div>';
    });
    
    error_log('=== FLUSH REWRITE RULES ===');
    error_log('Rewrite rules flushed at: ' . current_time('mysql'));
    error_log('=== END FLUSH ===');
}, 999);
