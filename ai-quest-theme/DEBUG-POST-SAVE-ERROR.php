<?php
/**
 * Debug Script: Post Save Error
 * 
 * Thêm code này vào functions.php TẠM THỜI để debug lỗi "Cập nhật không thành công"
 * SAU KHI TÌM RA LỖI, XÓA CODE NÀY ĐI
 */

// Log all errors during post save
add_action('save_post', function($post_id) {
    error_log('=== SAVE POST DEBUG START ===');
    error_log('Post ID: ' . $post_id);
    error_log('Post Type: ' . get_post_type($post_id));
    error_log('Has Featured Image: ' . (has_post_thumbnail($post_id) ? 'Yes' : 'No'));
    error_log('=== SAVE POST DEBUG END ===');
}, 1); // Priority 1 - run before other hooks

// Log REST API errors
add_filter('rest_pre_echo_response', function($result, $server, $request) {
    if (is_wp_error($result)) {
        error_log('=== REST API ERROR ===');
        error_log('Error Code: ' . $result->get_error_code());
        error_log('Error Message: ' . $result->get_error_message());
        error_log('Request Route: ' . $request->get_route());
        error_log('Request Method: ' . $request->get_method());
        error_log('=== REST API ERROR END ===');
    }
    return $result;
}, 10, 3);

// Catch PHP errors
add_action('shutdown', function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        error_log('=== PHP FATAL ERROR ===');
        error_log('Type: ' . $error['type']);
        error_log('Message: ' . $error['message']);
        error_log('File: ' . $error['file']);
        error_log('Line: ' . $error['line']);
        error_log('=== PHP FATAL ERROR END ===');
    }
});

// Log WordPress errors
add_action('wp_error_added', function($code, $message, $data, $wp_error) {
    error_log('=== WP ERROR ===');
    error_log('Code: ' . $code);
    error_log('Message: ' . $message);
    error_log('Data: ' . print_r($data, true));
    error_log('=== WP ERROR END ===');
}, 10, 4);

/**
 * HƯỚNG DẪN SỬ DỤNG:
 * 
 * 1. Copy toàn bộ code trong file này
 * 2. Paste vào CUỐI file functions.php (trước dấu ?> nếu có)
 * 3. Lưu bài viết và gây ra lỗi "Cập nhật không thành công"
 * 4. Kiểm tra WordPress debug log:
 *    - Thường ở: wp-content/debug.log
 *    - Hoặc check PHP error log của hosting
 * 5. Tìm các dòng có "=== ... ===" để xem lỗi chi tiết
 * 6. SAU KHI TÌM RA LỖI, XÓA CODE NÀY ĐI
 * 
 * LƯU Ý: Để bật WordPress debug log, thêm vào wp-config.php:
 * 
 * define('WP_DEBUG', true);
 * define('WP_DEBUG_LOG', true);
 * define('WP_DEBUG_DISPLAY', false);
 */
