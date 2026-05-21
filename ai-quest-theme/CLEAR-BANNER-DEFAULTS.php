<?php
/**
 * Clear Banner Default Values
 * 
 * Script này sẽ xóa các giá trị mặc định của banner khỏi database
 * Truy cập: http://your-site.com/wp-content/themes/ai-quest-theme/CLEAR-BANNER-DEFAULTS.php
 */

require_once('../../../wp-load.php');

if (!current_user_can('manage_options')) {
    wp_die('Bạn không có quyền truy cập.');
}

echo '<h1>Xóa Giá Trị Mặc Định Banner</h1>';
echo '<hr>';

// Xóa các options banner
$banner_options = array(
    'ai_quest_banner_badge',
    'ai_quest_banner_title',
    'ai_quest_banner_description',
    'ai_quest_banner_button_text',
    'ai_quest_banner_button_url',
    'ai_quest_banner_bg_url',
);

echo '<h2>Đang xóa các options:</h2>';
echo '<ul>';
foreach ($banner_options as $option) {
    $deleted = delete_option($option);
    if ($deleted) {
        echo '<li>✅ Đã xóa option: <code>' . esc_html($option) . '</code></li>';
    } else {
        echo '<li>⚠️ Không tìm thấy option: <code>' . esc_html($option) . '</code></li>';
    }
    
    // Also remove from theme_mods
    $theme_mod_deleted = remove_theme_mod($option);
    if ($theme_mod_deleted) {
        echo '<li>✅ Đã xóa theme_mod: <code>' . esc_html($option) . '</code></li>';
    }
}
echo '</ul>';

echo '<hr>';
echo '<h2>✅ Hoàn thành!</h2>';
echo '<p>Bây giờ banner sẽ không hiển thị nội dung mặc định nữa.</p>';
echo '<p>Bạn có thể vào <strong>Customizer → Khuyến Mãi</strong> để thêm nội dung mới.</p>';
echo '<p><a href="' . admin_url('customize.php?autofocus[section]=ai_quest_banner_options') . '">→ Mở Customizer</a></p>';
echo '<p><a href="' . home_url() . '">→ Xem trang chủ</a></p>';
echo '<hr>';
echo '<p><strong>⚠️ Lưu ý:</strong> Xóa file này sau khi chạy xong để bảo mật.</p>';
