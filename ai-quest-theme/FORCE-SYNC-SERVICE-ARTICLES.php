<?php
/**
 * Force Sync Service Articles
 * 
 * HƯỚNG DẪN:
 * 1. Copy toàn bộ code này
 * 2. Paste vào CUỐI file functions.php (trước dấu ?> nếu có)
 * 3. Reload bất kỳ trang nào trên website
 * 4. Kiểm tra Dashboard → Bài Viết Dịch Vụ
 * 5. SAU ĐÓ XÓA CODE NÀY ĐI
 */

add_action('init', function() {
    // Force sync service articles
    ai_quest_sync_service_articles();
    
    // Show admin notice
    add_action('admin_notices', function() {
        echo '<div class="notice notice-success is-dismissible">';
        echo '<p><strong>✅ Đã đồng bộ bài viết dịch vụ!</strong></p>';
        echo '<p>Vào <a href="' . admin_url('edit.php?post_type=service_article') . '">Bài Viết Dịch Vụ</a> để kiểm tra.</p>';
        echo '</div>';
    });
    
    // Log results
    error_log('=== FORCE SYNC SERVICE ARTICLES ===');
    error_log('Sync completed at: ' . current_time('mysql'));
    
    $articles = get_posts(array(
        'post_type' => 'service_article',
        'post_status' => 'any',
        'posts_per_page' => -1
    ));
    
    error_log('Total articles: ' . count($articles));
    
    foreach ($articles as $article) {
        $service_name = get_post_meta($article->ID, '_service_name', true);
        $page_key = get_post_meta($article->ID, '_service_page', true);
        error_log('- ' . $article->post_title . ' (' . $page_key . ' / ' . $service_name . ') - Status: ' . $article->post_status);
    }
    
    error_log('=== END SYNC ===');
}, 999);
