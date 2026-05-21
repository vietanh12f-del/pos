<?php
/**
 * Sync All Service Articles (Both Parent and Detail)
 * 
 * HƯỚNG DẪN:
 * 1. Copy toàn bộ code này
 * 2. Paste vào CUỐI file functions.php
 * 3. Reload bất kỳ trang nào trên website
 * 4. Kiểm tra Dashboard:
 *    - Bài Viết Dịch Vụ (service_article)
 *    - Bài Viết Chi Tiết DV (service_detail_article)
 * 5. SAU ĐÓ XÓA CODE NÀY ĐI
 */

add_action('init', function() {
    // Sync parent service articles
    ai_quest_sync_service_articles();
    
    // Sync detail service articles
    ai_quest_sync_service_detail_articles();
    
    // Flush rewrite rules
    flush_rewrite_rules();
    
    // Show admin notice
    add_action('admin_notices', function() {
        $parent_count = wp_count_posts('service_article')->draft + wp_count_posts('service_article')->publish;
        $detail_count = wp_count_posts('service_detail_article')->draft + wp_count_posts('service_detail_article')->publish;
        
        echo '<div class="notice notice-success is-dismissible">';
        echo '<p><strong>✅ Đã đồng bộ tất cả bài viết dịch vụ!</strong></p>';
        echo '<ul style="margin-left: 20px;">';
        echo '<li>Bài Viết Dịch Vụ (mục con): <strong>' . $parent_count . '</strong> bài viết</li>';
        echo '<li>Bài Viết Chi Tiết DV (dịch vụ nhỏ): <strong>' . $detail_count . '</strong> bài viết</li>';
        echo '</ul>';
        echo '<p>Vào Dashboard để chỉnh sửa và Publish các bài viết.</p>';
        echo '</div>';
    });
    
    error_log('=== SYNC ALL SERVICE ARTICLES ===');
    error_log('Sync completed at: ' . current_time('mysql'));
    error_log('=== END SYNC ===');
}, 999);
