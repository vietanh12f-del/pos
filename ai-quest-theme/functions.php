<?php
/**
 * Henie Skinlab Theme functions and definitions
 */

function ai_quest_setup() {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('html5', array('search-form', 'comment-form', 'comment-list', 'gallery', 'caption'));
    add_theme_support('custom-logo', array(
        'height'      => 120,
        'width'       => 220,
        'flex-height' => true,
        'flex-width'  => true,
    ));
    add_theme_support('site-icon');
    
    // Add Gutenberg editor styles support
    add_theme_support('editor-styles');
    add_theme_support('wp-block-styles');
    add_theme_support('align-wide');
    add_theme_support('responsive-embeds');
}
add_action('after_setup_theme', 'ai_quest_setup');

function ai_quest_get_setting($id, $default = '') {
    $value = get_option($id, null);
    if ($value !== null) {
        return $value;
    }

    // Don't fallback to theme_mods - we've migrated everything to options
    // If not in options table, return the default
    return $default;
}

function ai_quest_migrate_theme_mods_to_options() {
    if (get_option('aiq_migrated_settings_to_options', '0') === '1') {
        return;
    }

    $mods = get_theme_mods();
    if (is_array($mods)) {
        foreach ($mods as $key => $value) {
            if (strpos((string) $key, 'ai_quest_') !== 0) {
                continue;
            }

            if (get_option($key, null) !== null) {
                continue;
            }

            update_option($key, $value);
        }
    }

    update_option('aiq_migrated_settings_to_options', '1');
}
add_action('init', 'ai_quest_migrate_theme_mods_to_options', 5);

function ai_quest_seed_default_options() {
    $defaults = array(
        'ai_quest_homepage_title_color' => '#D4AF37',
        'ai_quest_banner_title_color' => '#111111',
        'ai_quest_banner_text_color' => '#666666',
        'ai_quest_home_slider_enabled' => 1,
        'ai_quest_home_slider_image_1' => 'https://images.unsplash.com/photo-1540555700478-4be289fbecee?auto=format&fit=crop&q=80&w=2000',
        'ai_quest_home_slider_image_2' => 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?auto=format&fit=crop&q=80&w=2000',
        'ai_quest_home_slider_image_3' => 'https://images.unsplash.com/photo-1519823551278-64ac92734fb1?auto=format&fit=crop&q=80&w=2000',
        'ai_quest_home_slider_image_4' => '',
        'ai_quest_home_slider_image_5' => '',
        'ai_quest_home_slider_image_6' => '',
        'ai_quest_home_slider_image_7' => '',
        'ai_quest_home_slider_image_8' => '',
        'ai_quest_home_slider_image_9' => '',
        'ai_quest_home_slider_image_10' => '',
        'ai_quest_home_slider_initial' => 1,
        'ai_quest_home_slider_interval' => 5,
        'ai_quest_products_enabled' => 1,
        'ai_quest_before_after_enabled' => 1,
        'ai_quest_video_enabled' => 1,
        'ai_quest_marketing_enabled' => 1,
        'ai_quest_features_enabled' => 1,
        'ai_quest_testimonials_enabled' => 1,
        'ai_quest_banner_enabled' => 1,
        // Removed banner default content - let users add their own
        'ai_quest_locations_enabled'          => 1,
        'ai_quest_locations_heading'          => 'Hệ Thống Henie Skinlab',
        'ai_quest_locations_logo_url'         => '',
        'ai_quest_locations_social_facebook_url'  => '#',
        'ai_quest_locations_social_instagram_url' => '#',
        'ai_quest_locations_social_tiktok_url'    => '#',
        'ai_quest_locations_time_text'        => 'Thứ Hai đến Chủ Nhật: 9:00 Sáng - 20:00 Tối',
        'ai_quest_locations_hotline'          => '096 235 94 65',
        'ai_quest_locations_website_label'    => 'henieskinlab.com',
        'ai_quest_locations_website_url'      => 'https://henieskinlab.com/',
        'ai_quest_location_1_title'           => 'Bình Thạnh, TP.HCM',
        'ai_quest_location_1_address'         => '21/5D, Bình Lợi, Bình Lợi Trung, Hồ Chí Minh 700000, Việt Nam',
        'ai_quest_location_1_map_embed_url'   => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3918.8028344097156!2d106.70298361125364!3d10.82639548928088!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x31752900161e84f1%3A0xf3284fbaaba2ba2e!2zSGVuaWUgU2tpbmxhYiAtIFNwYSBDaMSDbSBTw7NjIERhIELDrG5oIFRo4bqhbmg!5e0!3m2!1svi!2s!4v1776057224603!5m2!1svi!2s',
        'ai_quest_location_1_maps_url'        => 'https://www.google.com/maps?cid=17521342013446994478&g_mp=CiVnb29nbGUubWFwcy5wbGFjZXMudjEuUGxhY2VzLkdldFBsYWNlEAIYASAA&hl=vi&source=embed',
        'ai_quest_location_2_title'           => 'Lái Thiêu, TP.HCM',
        'ai_quest_location_2_address'         => '188 3 Tháng 2, KP Đông Tư, Lái Thiêu, Hồ Chí Minh, Việt Nam',
        'ai_quest_location_2_map_embed_url'   => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3917.6413645801354!2d106.69925931125468!3d10.914836689197623!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3174d9b18a1694d7%3A0x9981a3fbd49ef74!2zSGVuaWUgU2tpbmxhYiAtIFNwYSBDaMSDbSBTw7NjIERhIEzDoWkgVGhpw6p1!5e0!3m2!1svi!2s!4v1776057284562!5m2!1svi!2s',
        'ai_quest_location_2_maps_url'        => 'https://www.google.com/maps/place/Henie+Skinlab+-+Spa+Ch%C4%83m+S%C3%B3c+Da+L%C3%A1i+Thi%C3%AAu/@10.9148367,106.7018396,17z/data=!3m1!4b1!4m6!3m5!1s0x3174d9b18a1694d7:0x9981a3fbd49ef74!8m2!3d10.9148367!4d106.7018396!16s%2Fg%2F11mt2x70fp?hl=vi&entry=ttu&g_ep=EgoyMDI2MDQxNC4wIKXMDSoASAFQAw%3D%3D',
    );

    foreach ($defaults as $key => $value) {
        if (get_option($key, null) !== null) {
            continue;
        }
        update_option($key, $value);
    }
}
add_action('init', 'ai_quest_seed_default_options', 4);

function ai_quest_maybe_update_primary_color_default() {
    if (get_option('aiq_updated_primary_color_default', '0') === '1') {
        return;
    }

    $current = get_option('ai_quest_primary_color', null);
    if ($current === null || $current === '' || strtolower((string) $current) === '#2da08b' || strtolower((string) $current) === '#d4af37' || strtolower((string) $current) === '#c9a227') {
        update_option('ai_quest_primary_color', '#6B7D3A');
    }

    update_option('aiq_updated_primary_color_default', '1');
}
add_action('init', 'ai_quest_maybe_update_primary_color_default', 6);

function ai_quest_fix_opening_hours() {
    if (get_option('aiq_fixed_opening_hours_v1', '0') === '1') {
        return;
    }
    $current = get_option('ai_quest_locations_time_text', null);
    // Nếu đang chứa 21:00 thì update về 20:00
    if ($current !== null && strpos((string) $current, '21:00') !== false) {
        update_option('ai_quest_locations_time_text', str_replace('21:00', '20:00', (string) $current));
    }
    update_option('aiq_fixed_opening_hours_v1', '1');
}
add_action('init', 'ai_quest_fix_opening_hours', 7);

function ai_quest_fix_banner_button_url() {
    // Disabled - let users manage banner content themselves
    if (get_option('aiq_fixed_banner_button_url_v1', '0') === '1') {
        return;
    }
    update_option('aiq_fixed_banner_button_url_v1', '1');
}
add_action('init', 'ai_quest_fix_banner_button_url', 8);

/**
 * Lấy danh sách sub-categories từ service detail pages
 */
function ai_quest_get_all_services_from_categories() {
    $svc_pages = array(
        'cham_soc_da' => 'Chăm Sóc Da',
        'triet_long'  => 'Triệt Lông',
        'goi_dau'     => 'Gội Đầu',
    );
    $all_services = array();
    foreach ($svc_pages as $slug => $cat_label) {
        $s = 'ai_quest_svcpage_' . $slug;
        for ($ci = 1; $ci <= 5; $ci++) {
            $cp = $s . '_sub' . $ci;
            $sub_name = trim((string) ai_quest_get_setting($cp . '_name', ''));
            if ($sub_name === '') continue;
            $all_services[] = $sub_name;
        }
    }
    return $all_services;
}

function ai_quest_seed_cham_soc_da() {
    if (get_option('aiq_seeded_cham_soc_da_v1', '0') === '1') return;

    $s = 'ai_quest_svcpage_cham_soc_da';

    // Hero
    update_option($s . '_hero_title',    'Chăm Sóc Da Chuyên Nghiệp');
    update_option($s . '_hero_subtitle', 'Chăm Sóc Da');

    // Mục con 1: Chăm Sóc Da Mụn (cơ bản)
    update_option($s . '_sub1_name',        'Chăm Sóc Da Mụn');
    update_option($s . '_sub1_description', 'Liệu trình chăm sóc da mụn chuyên sâu, phù hợp với từng mức độ mụn khác nhau.');
    $sub1_svcs = array(
        1 => array('Mụn cơ bản',                              '350.000đ', ''),
        2 => array('Aqua peeling',                            '550.000đ', ''),
        3 => array('Mụn với tinh chất kháng viêm',            '550.000đ', ''),
        4 => array('Mụn với ánh sáng giảm viêm',              '650.000đ', ''),
        5 => array('Mụn với aqua peel và tinh chất kháng viêm','750.000đ', ''),
        6 => array('Mụn với aqua peel và ánh sáng giảm viêm', '750.000đ', ''),
    );
    foreach ($sub1_svcs as $i => $svc) {
        update_option($s . '_sub1_svc' . $i . '_name',  $svc[0]);
        update_option($s . '_sub1_svc' . $i . '_price', $svc[1]);
        update_option($s . '_sub1_svc' . $i . '_badge', $svc[2]);
    }

    // Mục con 2: Chăm Sóc Da Mụn (chuyên sâu)
    update_option($s . '_sub2_name',        'Chăm Sóc Da Mụn Chuyên Sâu');
    update_option($s . '_sub2_description', 'Liệu trình chuyên sâu với hoạt chất đặc trị, phù hợp với da mụn nặng và mụn thâm.');
    $sub2_svcs = array(
        1 => array('Detox CO2',                                                    '800.000đ',   ''),
        2 => array('Mụn với hoạt chất giảm viêm, giảm dày sừng, mờ thâm cấp 1',  '1.000.000đ', ''),
        3 => array('Mụn với hoạt chất giảm viêm, giảm dày sừng, mờ thâm cấp 2',  '1.200.000đ', ''),
        4 => array('Mụn với hoạt chất gom cồi mụn cấp 1',                         '1.200.000đ', ''),
        5 => array('Mụn với hoạt chất gom cồi mụn cấp 2',                         '2.000.000đ', ''),
        6 => array('Combo sạch mụn, mờ thâm',                                     '2.500.000đ', ''),
        7 => array('Combo sạch mụn, mờ thâm VIP',                                 '3.000.000đ', 'VIP'),
    );
    foreach ($sub2_svcs as $i => $svc) {
        update_option($s . '_sub2_svc' . $i . '_name',  $svc[0]);
        update_option($s . '_sub2_svc' . $i . '_price', $svc[1]);
        update_option($s . '_sub2_svc' . $i . '_badge', $svc[2]);
    }

    // Mục con 3: Chăm Sóc Da Rối Loạn Sắc Tố
    update_option($s . '_sub3_name',        'Chăm Sóc Da Rối Loạn Sắc Tố');
    update_option($s . '_sub3_description', 'Liệu trình chuyên biệt giúp cải thiện tình trạng nám, tàn nhang và rối loạn sắc tố da.');
    $sub3_svcs = array(
        1 => array('Nano tinh chất trắng sáng',                                    '650.000đ',   ''),
        2 => array('Glow skin O+ (Aqua peel, RF, sóng siêu âm, đẩy tinh chất sáng da)', '750.000đ', ''),
        3 => array('Tái tạo da với hoạt chất sáng da cấp 1',                       '1.200.000đ', ''),
        4 => array('Tái tạo da với hoạt chất sáng da cấp 2',                       '1.500.000đ', ''),
        5 => array('Toning mờ nám',                                                '2.000.000đ', ''),
        6 => array('Phục hồi da nám chuyên sâu',                                   '3.000.000đ', ''),
        7 => array('Nám với hoạt chất mờ nám, ức chế sắc tố',                      '4.000.000đ', ''),
    );
    foreach ($sub3_svcs as $i => $svc) {
        update_option($s . '_sub3_svc' . $i . '_name',  $svc[0]);
        update_option($s . '_sub3_svc' . $i . '_price', $svc[1]);
        update_option($s . '_sub3_svc' . $i . '_badge', $svc[2]);
    }

    // Mục con 4: Trẻ Hóa Da Đa Tầng
    update_option($s . '_sub4_name',        'Trẻ Hóa Da Đa Tầng');
    update_option($s . '_sub4_description', 'Liệu trình trẻ hóa da toàn diện, kích thích tái tạo collagen và phục hồi làn da tươi trẻ.');
    $sub4_svcs = array(
        1 => array('Nano cấp ẩm, tăng sinh collagen',                              '650.000đ',   ''),
        2 => array('Toning trẻ hóa',                                               '1.000.000đ', ''),
        3 => array('Cấp cẩm chuyên sâu, tăng sinh collagen',                       '2.000.000đ', ''),
        4 => array('Cấp ẩm chuyên sâu, căng bóng, trẻ hóa, tăng sinh collagen',   '4.000.000đ', ''),
        5 => array('Giảm nhăn, trẻ hóa da',                                        '5.000.000đ', ''),
    );
    foreach ($sub4_svcs as $i => $svc) {
        update_option($s . '_sub4_svc' . $i . '_name',  $svc[0]);
        update_option($s . '_sub4_svc' . $i . '_price', $svc[1]);
        update_option($s . '_sub4_svc' . $i . '_badge', $svc[2]);
    }

    update_option('aiq_seeded_cham_soc_da_v1', '1');
}
add_action('init', 'ai_quest_seed_cham_soc_da', 9);

function ai_quest_seed_triet_long() {
    if (get_option('aiq_seeded_triet_long_v2', '0') === '1') return;

    $s = 'ai_quest_svcpage_triet_long';

    update_option($s . '_hero_title',    'Triệt Lông Công Nghệ IDM Z200');
    update_option($s . '_hero_subtitle', 'Công nghệ triệt lạnh SHR-OPT an toàn – hiệu quả – giá hợp lý');

    // Mục con 1: Gói 10 Buổi (gộp tất cả vùng)
    update_option($s . '_sub1_name',        'Gói 10 Buổi (Liệu Trình Chuẩn)');
    update_option($s . '_sub1_description', 'Liệu trình triệt lông chuẩn 10 buổi với công nghệ SHR-OPT hiện đại, an toàn cho mọi loại da.');
    $sub1 = array(
        1  => array('Nách (15 phút)',                       '800.000đ',   ''),
        2  => array('Mặt (20 phút)',                        '1.200.000đ', ''),
        3  => array('Mép / Râu (10 phút)',                  '530.000đ',   ''),
        4  => array('1/2 Cẳng tay (20 phút)',               '1.300.000đ', ''),
        5  => array('1/2 Cẳng chân (25 phút)',              '1.500.000đ', ''),
        6  => array('Bụng (25 phút)',                       '1.500.000đ', ''),
        7  => array('Lưng (30 phút)',                       '1.700.000đ', ''),
        8  => array('Bikini đường viền (20 phút)',          '1.450.000đ', ''),
        9  => array('Bikini Full (30 phút)',                '2.400.000đ', ''),
        10 => array('Full Tay (30 phút)',                   '2.200.000đ', ''),
        11 => array('Full Chân (40 phút)',                  '2.900.000đ', ''),
        12 => array('Combo Toàn Thân Full Body (90 phút)', '8.500.000đ', 'HOT'),
    );
    foreach ($sub1 as $i => $svc) {
        update_option($s . '_sub1_svc' . $i . '_name',  $svc[0]);
        update_option($s . '_sub1_svc' . $i . '_price', $svc[1]);
        update_option($s . '_sub1_svc' . $i . '_badge', $svc[2]);
    }
    // Xóa các dịch vụ cũ từ mục con 2 (nếu có)
    for ($i = 1; $i <= 8; $i++) {
        delete_option($s . '_sub2_svc' . $i . '_name');
        delete_option($s . '_sub2_svc' . $i . '_price');
        delete_option($s . '_sub2_svc' . $i . '_badge');
    }

    // Mục con 2: Gói Triệt 2 Năm (gộp tất cả vùng)
    update_option($s . '_sub2_name',        'Gói Triệt 2 Năm (Bảo Hành 2 Năm Vùng Triệt)');
    update_option($s . '_sub2_description', 'Gói triệt lông linh hoạt 24-28 buổi trong 2 năm, bảo hành vùng triệt trọn đời.');
    $sub2 = array(
        1  => array('Nách (24-28 buổi)',                               '2.000.000đ',  ''),
        2  => array('Mặt (24-28 buổi)',                                '3.000.000đ',  ''),
        3  => array('Mép / Râu (24-28 buổi)',                          '1.350.000đ',  ''),
        4  => array('1/2 Cẳng tay (24-28 buổi)',                       '5.000.000đ',  ''),
        5  => array('1/2 Cẳng chân (24-28 buổi)',                      '5.500.000đ',  ''),
        6  => array('Bụng (24-28 buổi)',                               '5.500.000đ',  ''),
        7  => array('Lưng (24-28 buổi)',                               '6.200.000đ',  ''),
        8  => array('Bikini đường viền (24-28 buổi)',                  '5.200.000đ',  ''),
        9  => array('Bikini Full (24-28 buổi)',                        '8.500.000đ',  ''),
        10 => array('Full Tay (24-28 buổi)',                           '7.800.000đ',  ''),
        11 => array('Full Chân (24-28 buổi)',                          '10.200.000đ', ''),
        12 => array('Combo Toàn Thân Full Body 2 năm (không giới hạn)', '28.000.000đ', 'VIP'),
    );
    foreach ($sub2 as $i => $svc) {
        update_option($s . '_sub2_svc' . $i . '_name',  $svc[0]);
        update_option($s . '_sub2_svc' . $i . '_price', $svc[1]);
        update_option($s . '_sub2_svc' . $i . '_badge', $svc[2]);
    }

    // Xóa mục con 3 và 4 cũ
    foreach (array(3, 4) as $ci) {
        update_option($s . '_sub' . $ci . '_name', '');
        for ($i = 1; $i <= 8; $i++) {
            delete_option($s . '_sub' . $ci . '_svc' . $i . '_name');
        }
    }

    update_option('aiq_seeded_triet_long_v2', '1');
}
add_action('init', 'ai_quest_seed_triet_long', 10);

function ai_quest_seed_goi_dau() {
    if (get_option('aiq_seeded_goi_dau_v1', '0') === '1') return;

    $s = 'ai_quest_svcpage_goi_dau';

    update_option($s . '_hero_title',    'Gội Đầu Dưỡng Sinh');
    update_option($s . '_hero_subtitle', 'Gội Đầu');

    update_option($s . '_sub1_name',        'Gội Đầu');
    update_option($s . '_sub1_description', 'Dịch vụ gội đầu kết hợp massage bấm huyệt giúp lưu thông khí huyết và thư giãn vùng đầu.');

    $svcs = array(
        1 => array('Gội sạch (30 phút)',    '69.000đ',  ''),
        2 => array('Gội thư giãn (40 phút)','99.000đ',  ''),
        3 => array('Gội cao cấp (60 phút)', '159.000đ', ''),
    );
    foreach ($svcs as $i => $svc) {
        update_option($s . '_sub1_svc' . $i . '_name',  $svc[0]);
        update_option($s . '_sub1_svc' . $i . '_price', $svc[1]);
        update_option($s . '_sub1_svc' . $i . '_badge', $svc[2]);
    }

    update_option('aiq_seeded_goi_dau_v1', '1');
}
add_action('init', 'ai_quest_seed_goi_dau', 11);

function ai_quest_font_choices() {
    return array(
        'sora' => array('label' => 'Sora', 'family' => 'Sora', 'weights' => '400;600;700;800', 'fallback' => 'sans-serif'),
        'montserrat' => array('label' => 'Montserrat', 'family' => 'Montserrat', 'weights' => '300;400;500;600;700;800;900', 'fallback' => 'sans-serif'),
        'be-vietnam-pro' => array('label' => 'Be Vietnam Pro', 'family' => 'Be Vietnam Pro', 'weights' => '300;400;500;600;700;800', 'fallback' => 'sans-serif'),
        'inter' => array('label' => 'Inter', 'family' => 'Inter', 'weights' => '300;400;500;600;700;800', 'fallback' => 'sans-serif'),
        'noto-sans' => array('label' => 'Noto Sans', 'family' => 'Noto Sans', 'weights' => '300;400;500;600;700;800', 'fallback' => 'sans-serif'),
        'noto-serif' => array('label' => 'Noto Serif', 'family' => 'Noto Serif', 'weights' => '400;500;600;700;800', 'fallback' => 'serif'),
        'roboto' => array('label' => 'Roboto', 'family' => 'Roboto', 'weights' => '300;400;500;700;900', 'fallback' => 'sans-serif'),
        'open-sans' => array('label' => 'Open Sans', 'family' => 'Open Sans', 'weights' => '300;400;500;600;700;800', 'fallback' => 'sans-serif'),
        'nunito-sans' => array('label' => 'Nunito Sans', 'family' => 'Nunito Sans', 'weights' => '300;400;600;700;800;900', 'fallback' => 'sans-serif'),
        'source-sans-3' => array('label' => 'Source Sans 3', 'family' => 'Source Sans 3', 'weights' => '300;400;600;700;800;900', 'fallback' => 'sans-serif'),
        'lexend' => array('label' => 'Lexend', 'family' => 'Lexend', 'weights' => '300;400;500;600;700;800', 'fallback' => 'sans-serif'),
    );
}

function ai_quest_sanitize_font_choice($value) {
    $value = (string) $value;
    $choices = ai_quest_font_choices();
    return isset($choices[$value]) ? $value : 'montserrat';
}

function ai_quest_google_fonts_url_for_selected() {
    $choices = ai_quest_font_choices();

    $title_key = ai_quest_sanitize_font_choice(ai_quest_get_setting('ai_quest_title_font', 'sora'));
    $body_key = ai_quest_sanitize_font_choice(ai_quest_get_setting('ai_quest_body_font', 'montserrat'));

    $keys = array_values(array_unique(array($title_key, $body_key)));
    $families = array();

    foreach ($keys as $key) {
        if (!isset($choices[$key])) {
            continue;
        }
        $family = $choices[$key]['family'];
        $weights = $choices[$key]['weights'];
        $families[] = 'family=' . str_replace(' ', '+', $family) . ':wght@' . $weights;
    }

    if (count($families) === 0) {
        return '';
    }

    return 'https://fonts.googleapis.com/css2?' . implode('&', $families) . '&display=swap&subset=vietnamese';
}

function ai_quest_scripts() {
    // Enqueue Google Fonts
    $fonts_url = ai_quest_google_fonts_url_for_selected();
    if ($fonts_url) {
        wp_enqueue_style('ai-quest-fonts', $fonts_url, array(), null);
    }
    
    // Enqueue Main Custom Styles
    $css_path = get_template_directory() . '/assets/css/custom.css';
    $css_ver = file_exists($css_path) ? (string) filemtime($css_path) : null;
    wp_enqueue_style('ai-quest-custom-style', get_template_directory_uri() . '/assets/css/custom.css', array(), $css_ver);
    
    // Enqueue Main JS
    $js_path = get_template_directory() . '/assets/js/main.js';
    $js_ver = file_exists($js_path) ? (string) filemtime($js_path) : null;
    wp_enqueue_script('ai-quest-main-js', get_template_directory_uri() . '/assets/js/main.js', array(), $js_ver, true);

    // Facebook JS SDK (cho Facebook Reels embed)
    $fb_reels_enabled = (int) ai_quest_get_setting('ai_quest_fb_reels_enabled', 1);
    if ($fb_reels_enabled && is_front_page()) {
        wp_enqueue_script('facebook-jssdk', 'https://connect.facebook.net/vi_VN/sdk.js#xfbml=1&version=v19.0', array(), null, true);
    }
}
add_action('wp_enqueue_scripts', 'ai_quest_scripts');

function ai_quest_site_icon_url() {
    $icon_url = trim((string) ai_quest_get_setting('ai_quest_site_icon_url', ''));
    if ($icon_url === '') return;
    // Xóa favicon mặc định của WordPress
    remove_action('wp_head', 'wp_site_icon', 99);
    echo '<link rel="icon" type="image/png" href="' . esc_url($icon_url) . '">' . "\n";
    echo '<link rel="shortcut icon" href="' . esc_url($icon_url) . '">' . "\n";
    echo '<link rel="apple-touch-icon" href="' . esc_url($icon_url) . '">' . "\n";
}
add_action('wp_head', 'ai_quest_site_icon_url', 1);

function ai_quest_custom_colors_css() {
    $body_text_color = ai_quest_get_setting('ai_quest_body_text_color', '#666666');
    $title_text_color = ai_quest_get_setting('ai_quest_title_text_color', '#111111');
    $upper_header_bg = ai_quest_get_setting('ai_quest_upper_header_bg_color', '#ffffff');
    $upper_header_text = ai_quest_get_setting('ai_quest_upper_header_text_color', '#111111');
    $homepage_title_color = ai_quest_get_setting('ai_quest_homepage_title_color', '#D4AF37');
    $banner_title_color = ai_quest_get_setting('ai_quest_banner_title_color', '#111111');
    $banner_text_color = ai_quest_get_setting('ai_quest_banner_text_color', '#666666');
    
    echo '<style type="text/css">';
    
    // Body text (exclude buttons)
    if ($body_text_color) {
        echo ':root { --text-muted: ' . esc_html($body_text_color) . ' !important; }';
        echo 'body, p, span:not(.btn span):not(.feedback-btn-text):not(.feedback-btn-loading), li, ul, ol, div:not(.btn):not(.feedback-submit-btn), section, article, aside, blockquote, pre, code, table, td, th, label, input, textarea, select, .text-muted, .text-body, .text-content, .entry-content, .post-content, .page-content, .about-content, .service-content, .testimonial-content, .location-content { color: ' . esc_html($body_text_color) . ' !important; }';
    }
    
    // Title text
    if ($title_text_color) {
        echo ':root { --text-dark: ' . esc_html($title_text_color) . ' !important; }';
        echo 'body:not(.home) h1, body:not(.home) h2, body:not(.home) h3, body:not(.home) h4, body:not(.home) h5, body:not(.home) h6, body:not(.home) .text-dark, body:not(.home) .text-title, body:not(.home) .entry-title, body:not(.home) .post-title, body:not(.home) .page-title, body:not(.home) .section-title, body:not(.home) .feature-title, body:not(.home) .testimonial-name, body:not(.home) .about-hero-title, body:not(.home) .about-content-title { color: ' . esc_html($title_text_color) . ' !important; }';
    }
    
    // Homepage title text (only on front page)
    if ($homepage_title_color) {
        echo '.home h1, .home h2, .home h3, .home h4, .home h5, .home h6, .home .text-dark, .home .text-title, .home .section-title, .home .feature-title, .home .testimonial-name { color: ' . esc_html($homepage_title_color) . ' !important; }';
    }
    
    // Upper header background
    if ($upper_header_bg) {
        echo '.header-topbar { background-color: ' . esc_html($upper_header_bg) . ' !important; }';
    }
    
    // Upper header text & icon (EXCLUDE ENTIRE LOCATION MENU)
    if ($upper_header_text) {
        echo '.header-topbar, .header-topbar a:not(.topbar-location-item), .header-topbar span:not(.topbar-location-name):not(.topbar-location-address), .topbar-link:not(.topbar-location-item), .topbar-item:not(.topbar-location-trigger), .topbar-sep, .topbar-social a svg { color: ' . esc_html($upper_header_text) . ' !important; fill: ' . esc_html($upper_header_text) . ' !important; }';
        // Exclude everything inside .topbar-location-menu
        echo '.topbar-location-menu, .topbar-location-menu *, .topbar-location-menu a, .topbar-location-menu span { color: inherit !important; }';
    }
    
    // Banner (Khuyến Mãi) title color
    if ($banner_title_color) {
        echo '.banner-panel h1, .banner-panel h2, .banner-panel h3, .banner-panel .banner-title, .banner-panel .section-title, .banner-panel h2, .banner-panel h3 { color: ' . esc_html($banner_title_color) . ' !important; }';
    }
    
    // Banner (Khuyến Mãi) text color
    if ($banner_text_color) {
        echo '.banner-panel p, .banner-panel span, .banner-panel .banner-description, .banner-panel .text-body, .banner-panel .text-muted, .banner-panel p { color: ' . esc_html($banner_text_color) . ' !important; }';
    }
    
    // FORCE BUTTONS TO USE THEME COLORS, NOT CUSTOMIZED COLORS
    echo '.btn, .btn-primary, .consult-tab, .feedback-submit-btn, .about-btn, .svc-cat-btn { color: #ffffff !important; }';
    echo '.btn-primary, .consult-tab, .feedback-submit-btn, .about-btn { background-color: var(--primary-spa) !important; }';
    echo '.btn span, .consult-tab span, .feedback-submit-btn span, .about-btn span, .svc-cat-btn span { color: inherit !important; }';
    echo '</style>';
}
add_action('wp_head', 'ai_quest_custom_colors_css', 100);

function ai_quest_add_customizer_field($wp_customize, $id, $label, $section, $default, $type, $sanitize_callback) {
    $wp_customize->add_setting($id, array(
        'default'           => $default,
        'sanitize_callback' => $sanitize_callback,
        'type'              => 'option',
    ));

    $wp_customize->add_control($id, array(
        'label'   => $label,
        'section' => $section,
        'type'    => $type,
    ));
}

function ai_quest_sanitize_maps_embed_url($input) {
    $input = trim((string) $input);

    if ($input === '') {
        return '';
    }

    if (stripos($input, '<iframe') !== false) {
        if (preg_match('/src\\s*=\\s*([\\\"\\\'])(.*?)\\1/i', $input, $matches)) {
            return esc_url_raw($matches[2]);
        }
        return '';
    }

    return esc_url_raw($input);
}

function ai_quest_sanitize_image_url($input) {
    $input = trim((string) $input);

    if ($input === '') {
        return '';
    }

    if (stripos($input, '<img') !== false) {
        if (preg_match('/src\\s*=\\s*([\\\"\\\'])(.*?)\\1/i', $input, $matches)) {
            $input = trim((string) $matches[2]);
        } else {
            return '';
        }
    }

    if (strpos($input, '//') === 0) {
        $input = 'https:' . $input;
    } elseif (preg_match('~^www\\.~i', $input)) {
        $input = 'https://' . $input;
    }

    return esc_url_raw($input);
}

function ai_quest_sanitize_youtube_embed_url($input) {
    $input = trim((string) $input);

    if ($input === '') {
        return '';
    }

    $id = '';

    if (stripos($input, '<iframe') !== false) {
        if (preg_match('/src\\s*=\\s*([\\\"\\\'])(.*?)\\1/i', $input, $matches)) {
            $input = trim((string) $matches[2]);
        } else {
            return '';
        }
    }

    if (preg_match('/^[a-zA-Z0-9_-]{11}$/', $input)) {
        $id = $input;
    } else {
        if (preg_match('~youtu\.be/([a-zA-Z0-9_-]{11})~', $input, $m)) {
            $id = $m[1];
        } elseif (preg_match('~youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})~', $input, $m)) {
            $id = $m[1];
        } elseif (preg_match('~youtube\.com/shorts/([a-zA-Z0-9_-]{11})~', $input, $m)) {
            $id = $m[1];
        } elseif (preg_match('~youtube\.com/live/([a-zA-Z0-9_-]{11})~', $input, $m)) {
            $id = $m[1];
        } elseif (preg_match('~youtube\.com/embed/([a-zA-Z0-9_-]{11})~', $input, $m)) {
            $id = $m[1];
        }
    }

    if ($id === '') {
        return '';
    }

    return esc_url_raw('https://www.youtube.com/embed/' . $id);
}

function ai_quest_sanitize_checkbox($checked) {
    return $checked ? 1 : 0;
}

/**
 * Get metadata for all customizer settings
 * Returns array with setting_id => type mapping
 * Types: 'image_url', 'video_url', 'text', 'color', 'checkbox', 'number'
 */
function ai_quest_get_customizer_settings_metadata() {
    static $metadata = null;
    
    if ($metadata !== null) {
        return $metadata;
    }
    
    $metadata = array();
    
    // Site Icon
    $metadata['ai_quest_site_icon_url'] = 'image_url';
    
    // Colors
    $metadata['ai_quest_primary_color'] = 'color';
    $metadata['ai_quest_header_bg_color'] = 'color';
    $metadata['ai_quest_header_text_color'] = 'color';
    $metadata['ai_quest_body_text_color'] = 'color';
    $metadata['ai_quest_title_text_color'] = 'color';
    $metadata['ai_quest_upper_header_bg_color'] = 'color';
    $metadata['ai_quest_upper_header_text_color'] = 'color';
    $metadata['ai_quest_homepage_title_color'] = 'color';
    $metadata['ai_quest_banner_title_color'] = 'color';
    $metadata['ai_quest_banner_text_color'] = 'color';
    
    // Home Slider Images
    for ($i = 1; $i <= 10; $i++) {
        $metadata['ai_quest_home_slider_image_' . $i] = 'image_url';
        $metadata['ai_quest_home_slider_image_' . $i . '_mobile'] = 'image_url';
    }
    
    // Banner
    $metadata['ai_quest_banner_bg_url'] = 'image_url';
    
    // Locations
    $metadata['ai_quest_locations_logo_url'] = 'image_url';
    
    // Products Section
    for ($i = 1; $i <= 8; $i++) {
        $metadata['ai_quest_product_' . $i . '_image'] = 'image_url';
    }
    
    // Before/After Images
    for ($i = 1; $i <= 20; $i++) {
        $metadata['ai_quest_before_after_image_' . $i . '_url'] = 'image_url';
    }
    
    // Video Section
    $metadata['ai_quest_video_youtube_url'] = 'video_url';
    for ($i = 1; $i <= 4; $i++) {
        $metadata['ai_quest_video_thumbnail_' . $i] = 'image_url';
        $metadata['ai_quest_video_' . $i . '_url'] = 'video_url';
    }
    
    // Facebook Reels
    for ($i = 1; $i <= 50; $i++) {
        $metadata['ai_quest_fb_reel_' . $i . '_url'] = 'video_url';
        $metadata['ai_quest_fb_reel_' . $i . '_thumb'] = 'image_url'; // Thumbnail
    }
    
    // Marketing Section
    for ($i = 1; $i <= 4; $i++) {
        $metadata['ai_quest_marketing_' . $i . '_image'] = 'image_url';
    }
    
    // Features Section
    for ($i = 1; $i <= 6; $i++) {
        $metadata['ai_quest_feature_' . $i . '_icon'] = 'image_url';
    }
    
    // Testimonials
    for ($i = 1; $i <= 6; $i++) {
        $metadata['ai_quest_testimonial_' . $i . '_avatar'] = 'image_url';
    }
    
    // About Page
    $metadata['ai_quest_about_hero_image'] = 'image_url';
    $metadata['ai_quest_about_hero_image_url'] = 'image_url'; // Alternative URL field
    $metadata['ai_quest_about_section_1_image'] = 'image_url';
    $metadata['ai_quest_about_section_2_image'] = 'image_url';
    $metadata['ai_quest_about_section_3_image'] = 'image_url';
    
    // Service Detail Pages
    $service_pages = array('cham_soc_da', 'triet_long', 'goi_dau');
    foreach ($service_pages as $page) {
        $metadata['ai_quest_svcpage_' . $page . '_hero_image'] = 'image_url';
    }
    
    return apply_filters('ai_quest_customizer_settings_metadata', $metadata);
}

/**
 * Check if a setting ID is an image URL field
 */
function ai_quest_is_image_url_setting($setting_id) {
    $metadata = ai_quest_get_customizer_settings_metadata();
    return isset($metadata[$setting_id]) && $metadata[$setting_id] === 'image_url';
}

/**
 * Check if a setting ID is a video URL field
 */
function ai_quest_is_video_url_setting($setting_id) {
    $metadata = ai_quest_get_customizer_settings_metadata();
    return isset($metadata[$setting_id]) && $metadata[$setting_id] === 'video_url';
}

/**
 * Get all image URL setting IDs
 */
function ai_quest_get_all_image_url_settings() {
    $metadata = ai_quest_get_customizer_settings_metadata();
    $image_settings = array();
    
    foreach ($metadata as $setting_id => $type) {
        if ($type === 'image_url') {
            $image_settings[] = $setting_id;
        }
    }
    
    return $image_settings;
}

/**
 * Get all video URL setting IDs
 */
function ai_quest_get_all_video_url_settings() {
    $metadata = ai_quest_get_customizer_settings_metadata();
    $video_settings = array();
    
    foreach ($metadata as $setting_id => $type) {
        if ($type === 'video_url') {
            $video_settings[] = $setting_id;
        }
    }
    
    return $video_settings;
}

function ai_quest_customize_register($wp_customize) {
    $wp_customize->add_section('ai_quest_theme_options', array(
        'title'    => __('Tùy Chỉnh Giao Diện', 'ai-quest'),
        'priority' => 30,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_logo_text', __('Logo Text', 'ai-quest'), 'ai_quest_theme_options', 'Henie Skinlab', 'text', 'sanitize_text_field');

    $wp_customize->add_setting('ai_quest_site_icon_url', array(
        'default'           => '',
        'sanitize_callback' => 'esc_url_raw',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_site_icon_url', array(
        'label'       => __('Site Icon URL - Favicon (Tỉ lệ: 1:1)', 'ai-quest'),
        'description' => __('Dán URL ảnh favicon (PNG/ICO, tối thiểu 512x512px). Sẽ được dùng thay thế nếu chưa upload Site Icon.', 'ai-quest'),
        'section'     => 'title_tagline',
        'type'        => 'url',
    ));

    $font_choices = array();
    foreach (ai_quest_font_choices() as $key => $font) {
        $font_choices[$key] = $font['label'];
    }

    $wp_customize->add_setting('ai_quest_title_font', array(
        'default'           => 'sora',
        'sanitize_callback' => 'ai_quest_sanitize_font_choice',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_title_font', array(
        'label'   => __('Title Font', 'ai-quest'),
        'section' => 'title_tagline',
        'type'    => 'select',
        'choices' => $font_choices,
    ));

    $wp_customize->add_setting('ai_quest_body_font', array(
        'default'           => 'montserrat',
        'sanitize_callback' => 'ai_quest_sanitize_font_choice',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_body_font', array(
        'label'   => __('Body Font', 'ai-quest'),
        'section' => 'title_tagline',
        'type'    => 'select',
        'choices' => $font_choices,
    ));

    $wp_customize->add_setting('ai_quest_primary_color', array(
        'default'           => '#6B7D3A',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
    ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_primary_color', array(
        'label'   => __('Primary Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
    )));

    $wp_customize->add_setting('ai_quest_header_bg_color', array(
        'default'           => '#ffffff',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
    ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_header_bg_color', array(
        'label'   => __('Header Background Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
    )));

    $wp_customize->add_setting('ai_quest_header_text_color', array(
        'default'           => '#111111',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_header_text_color', array(
        'label'   => __('Header Text/Tab Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
        )));

    $wp_customize->add_setting('ai_quest_body_text_color', array(
        'default'           => '#666666',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_body_text_color', array(
        'label'   => __('Body/Regular Text Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
        )));

    $wp_customize->add_setting('ai_quest_title_text_color', array(
        'default'           => '#111111',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_title_text_color', array(
        'label'   => __('Title Text Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
        )));

    $wp_customize->add_setting('ai_quest_upper_header_bg_color', array(
        'default'           => '#ffffff',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_upper_header_bg_color', array(
        'label'   => __('Upper Header Background Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
        )));

    $wp_customize->add_setting('ai_quest_upper_header_text_color', array(
        'default'           => '#111111',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_upper_header_text_color', array(
        'label'   => __('Upper Header Text & Icon Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
        )));

    $wp_customize->add_setting('ai_quest_homepage_title_color', array(
        'default'           => '#D4AF37',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));

    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_homepage_title_color', array(
        'label'   => __('Homepage Title Text Color', 'ai-quest'),
        'section' => 'ai_quest_theme_options',
        )));

    $wp_customize->add_section('ai_quest_home_slider_options', array(
        'title'    => __('Slider Trang Chủ', 'ai-quest'),
        'priority' => 31,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_home_slider_enabled', __('Enable Section', 'ai-quest'), 'ai_quest_home_slider_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');

    $home_slider_defaults = array(
        1 => 'https://images.unsplash.com/photo-1540555700478-4be289fbecee?auto=format&fit=crop&q=80&w=2000',
        2 => 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?auto=format&fit=crop&q=80&w=2000',
        3 => 'https://images.unsplash.com/photo-1519823551278-64ac92734fb1?auto=format&fit=crop&q=80&w=2000',
        4 => '',
        5 => '',
        6 => '',
        7 => '',
        8 => '',
        9 => '',
        10 => '',
    );

    for ($i = 1; $i <= 10; $i++) {
        $setting_id = 'ai_quest_home_slider_image_' . $i;
        $wp_customize->add_setting($setting_id, array(
            'default'           => $home_slider_defaults[$i],
            'sanitize_callback' => 'ai_quest_sanitize_image_url',
            'type'              => 'option',
        ));

        $wp_customize->add_control($setting_id, array(
            'label'       => sprintf(__('Slide Image %d URL - Desktop (Tỉ lệ: 5:2)', 'ai-quest'), $i),
            'description' => __('Paste a direct image URL (https://...)', 'ai-quest'),
            'section'     => 'ai_quest_home_slider_options',
            'type'        => 'text',
        ));

        // Mobile URL (optional)
        $setting_id_mobile = 'ai_quest_home_slider_image_' . $i . '_mobile';
        $wp_customize->add_setting($setting_id_mobile, array(
            'default'           => '',
            'sanitize_callback' => 'ai_quest_sanitize_image_url',
            'type'              => 'option',
        ));

        $wp_customize->add_control($setting_id_mobile, array(
            'label'       => sprintf(__('Slide Image %d URL - Mobile (Tỉ lệ: 4:3, tùy chọn)', 'ai-quest'), $i),
            'description' => __('Nếu để trống sẽ dùng ảnh Desktop', 'ai-quest'),
            'section'     => 'ai_quest_home_slider_options',
            'type'        => 'text',
        ));
    }

    $wp_customize->add_setting('ai_quest_home_slider_initial', array(
        'default'           => 1,
        'sanitize_callback' => function ($value) {
            $value = (int) $value;
            if ($value < 1) return 1;
            if ($value > 10) return 10;
            return $value;
        },
        'type'              => 'option',
    ));

    $wp_customize->add_control('ai_quest_home_slider_initial', array(
        'label'   => __('Initial Slide', 'ai-quest'),
        'section' => 'ai_quest_home_slider_options',
        'type'    => 'select',
        'choices' => array(
            1 => '1',
            2 => '2',
            3 => '3',
            4 => '4',
            5 => '5',
            6 => '6',
            7 => '7',
            8 => '8',
            9 => '9',
            10 => '10',
        ),
    ));

    $wp_customize->add_setting('ai_quest_home_slider_interval', array(
        'default'           => 5,
        'sanitize_callback' => function ($value) {
            $value = (int) $value;
            if ($value < 1) return 1;
            if ($value > 60) return 60;
            return $value;
        },
        'type'              => 'option',
    ));

    $wp_customize->add_control('ai_quest_home_slider_interval', array(
        'label'       => __('Auto Next Interval (seconds)', 'ai-quest'),
        'section'     => 'ai_quest_home_slider_options',
        'type'        => 'number',
        'input_attrs' => array(
            'min'  => 1,
            'max'  => 60,
            'step' => 1,
        ),
    ));

    $wp_customize->add_section('ai_quest_about_options', array(
        'title'    => __('Trang Giới Thiệu', 'ai-quest'),
        'priority' => 31,
    ));

    // Background image for entire page - Image uploader
    $wp_customize->add_setting('ai_quest_about_hero_image', array(
        'default'           => '',
        'sanitize_callback' => 'esc_url_raw',
        'type'              => 'option',
    ));
    $wp_customize->add_control(new WP_Customize_Image_Control($wp_customize, 'ai_quest_about_hero_image', array(
        'label'       => __('Background Image (Upload)', 'ai-quest'),
        'description' => __('Upload background image for entire About page (recommended size: 1920x1080px)', 'ai-quest'),
        'section'     => 'ai_quest_about_options',
        'settings'    => 'ai_quest_about_hero_image',
    )));

    // Background image URL - Alternative option
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_hero_image_url', __('Background Image URL - Alternative (Tỉ lệ: Background)', 'ai-quest'), 'ai_quest_about_options', '', 'url', 'esc_url_raw');

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_1_title', __('Section 1 - Title', 'ai-quest'), 'ai_quest_about_options', 'Nghệ Thuật Chăm Sóc Từ Tâm', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_1_content', __('Section 1 - Content', 'ai-quest'), 'ai_quest_about_options', '', 'textarea', 'sanitize_textarea_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_1_image', __('Section 1 - Image URL (Tỉ lệ: 4:3)', 'ai-quest'), 'ai_quest_about_options', '', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_1_button_text', __('Section 1 - Button Text', 'ai-quest'), 'ai_quest_about_options', 'Liên Hệ Tư Vấn', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_1_button_url', __('Section 1 - Button URL', 'ai-quest'), 'ai_quest_about_options', '', 'url', 'esc_url_raw');
    
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_2_title', __('Section 2 - Title', 'ai-quest'), 'ai_quest_about_options', 'Vẻ Đẹp Cân Bằng Hoàn Hảo', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_2_content', __('Section 2 - Content', 'ai-quest'), 'ai_quest_about_options', '', 'textarea', 'sanitize_textarea_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_2_image', __('Section 2 - Image URL (Tỉ lệ: 4:3)', 'ai-quest'), 'ai_quest_about_options', '', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_2_button_text', __('Section 2 - Button Text', 'ai-quest'), 'ai_quest_about_options', 'Xem Dịch Vụ', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_2_button_url', __('Section 2 - Button URL', 'ai-quest'), 'ai_quest_about_options', '', 'url', 'esc_url_raw');
    
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_3_title', __('Section 3 - Title', 'ai-quest'), 'ai_quest_about_options', 'Triết Lý Của Chúng Tôi', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_3_content', __('Section 3 - Content', 'ai-quest'), 'ai_quest_about_options', '', 'textarea', 'sanitize_textarea_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_3_image', __('Section 3 - Image URL (Tỉ lệ: 4:3)', 'ai-quest'), 'ai_quest_about_options', '', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_3_button_text', __('Section 3 - Button Text', 'ai-quest'), 'ai_quest_about_options', 'Đặt Lịch Ngay', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_about_section_3_button_url', __('Section 3 - Button URL', 'ai-quest'), 'ai_quest_about_options', '', 'url', 'esc_url_raw');

    // ===================================
    // Panel: Dịch Vụ
    // ===================================
    $wp_customize->add_panel('ai_quest_services_panel', array(
        'title'    => __('Dịch Vụ', 'ai-quest'),
        'priority' => 32,
    ));

    // Section: Danh Mục Dịch Vụ
    $wp_customize->add_section('ai_quest_service_cats_options', array(
        'title'    => __('Danh Mục Dịch Vụ', 'ai-quest'),
        'panel'    => 'ai_quest_services_panel',
        'priority' => 10,
    ));

    $svc_cat_defaults = array(
        1 => array('Chăm Sóc Da', 'Liệu trình chăm sóc da chuyên sâu, phù hợp với từng loại da.', '', '#'),
        2 => array('Triệt Lông',  'Công nghệ triệt lông hiện đại, an toàn và hiệu quả lâu dài.',  '', '#'),
        3 => array('Gội Đầu',     'Gội đầu dưỡng sinh kết hợp massage bấm huyệt thư giãn.',       '', '#'),
    );

    for ($i = 1; $i <= 3; $i++) {
        $d = $svc_cat_defaults[$i];
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_svc_cat_' . $i . '_name',        sprintf(__('Danh mục %d - Tên', 'ai-quest'), $i),        'ai_quest_service_cats_options', $d[0], 'text',     'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_svc_cat_' . $i . '_description', sprintf(__('Danh mục %d - Mô tả', 'ai-quest'), $i),       'ai_quest_service_cats_options', $d[1], 'textarea', 'sanitize_textarea_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_svc_cat_' . $i . '_image_url',   sprintf(__('Danh mục %d - Ảnh URL (Tỉ lệ: 4:3)', 'ai-quest'), $i),     'ai_quest_service_cats_options', $d[2], 'url',      'esc_url_raw');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_svc_cat_' . $i . '_button_url',  sprintf(__('Danh mục %d - Nút URL', 'ai-quest'), $i),     'ai_quest_service_cats_options', $d[3], 'url',      'esc_url_raw');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_svc_cat_' . $i . '_button_text', sprintf(__('Danh mục %d - Nút Text', 'ai-quest'), $i),    'ai_quest_service_cats_options', 'Xem Dịch Vụ', 'text', 'sanitize_text_field');
    }

    // ---- Service Detail Pages ----
    $svc_pages = array(
        'cham-soc-da' => array('slug' => 'cham_soc_da', 'label' => 'Chăm Sóc Da',  'hero_default' => 'Chăm Sóc Da Chuyên Nghiệp'),
        'triet-long'  => array('slug' => 'triet_long',  'label' => 'Triệt Lông',    'hero_default' => 'Triệt Lông Công Nghệ Cao'),
        'goi-dau'     => array('slug' => 'goi_dau',     'label' => 'Gội Đầu',       'hero_default' => 'Gội Đầu Dưỡng Sinh'),
    );

    foreach ($svc_pages as $page_key => $page) {
        $s = 'ai_quest_svcpage_' . $page['slug'];
        $section_id = 'ai_quest_svcpage_' . $page['slug'] . '_options';

        $wp_customize->add_section($section_id, array(
            'title'    => sprintf(__('Trang DV: %s', 'ai-quest'), $page['label']),
            'panel'    => 'ai_quest_services_panel',
            'priority' => 20 + array_search($page_key, array_keys($svc_pages)),
        ));

        // Hero
        ai_quest_add_customizer_field($wp_customize, $s . '_hero_title',    __('Hero - Tiêu đề', 'ai-quest'),    $section_id, $page['hero_default'], 'text',     'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, $s . '_hero_subtitle', __('Hero - Phụ đề', 'ai-quest'),     $section_id, $page['label'],        'text',     'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, $s . '_hero_image',    __('Hero - Ảnh URL (Tỉ lệ: Background)', 'ai-quest'),    $section_id, '',                    'url',      'esc_url_raw');

        // Video section
        ai_quest_add_customizer_field($wp_customize, $s . '_video_title', __('Video - Tiêu đề', 'ai-quest'), $section_id, 'Video Thực Tế', 'text', 'sanitize_text_field');
        for ($vi = 1; $vi <= 3; $vi++) {
            ai_quest_add_customizer_field($wp_customize, $s . '_video_' . $vi, sprintf(__('Video %d - YouTube URL/ID', 'ai-quest'), $vi), $section_id, '', 'text', 'ai_quest_sanitize_youtube_embed_url');
        }

        // Sub-categories (max 5)
        for ($ci = 1; $ci <= 5; $ci++) {
            $cp = $s . '_sub' . $ci;
            ai_quest_add_customizer_field($wp_customize, $cp . '_name',        sprintf(__('Mục con %d - Tên', 'ai-quest'), $ci),        $section_id, '', 'text',     'sanitize_text_field');
            ai_quest_add_customizer_field($wp_customize, $cp . '_description', sprintf(__('Mục con %d - Mô tả', 'ai-quest'), $ci),      $section_id, '', 'textarea', 'sanitize_textarea_field');
            ai_quest_add_customizer_field($wp_customize, $cp . '_image',       sprintf(__('Mục con %d - Ảnh URL (Tỉ lệ: 4:3)', 'ai-quest'), $ci),    $section_id, '', 'url',      'esc_url_raw');

            // Services in sub-category (max 12)
            for ($si = 1; $si <= 12; $si++) {
                $sp = $cp . '_svc' . $si;
                ai_quest_add_customizer_field($wp_customize, $sp . '_name',  sprintf(__('Mục con %d - DV %d - Tên', 'ai-quest'), $ci, $si),  $section_id, '', 'text', 'sanitize_text_field');
                ai_quest_add_customizer_field($wp_customize, $sp . '_price', sprintf(__('Mục con %d - DV %d - Giá', 'ai-quest'), $ci, $si),  $section_id, '', 'text', 'sanitize_text_field');
                ai_quest_add_customizer_field($wp_customize, $sp . '_badge', sprintf(__('Mục con %d - DV %d - Badge', 'ai-quest'), $ci, $si), $section_id, '', 'text', 'sanitize_text_field');
            }
        }
    }

    // ===================================
    // Panel: Media
    // ===================================
    $wp_customize->add_panel('ai_quest_media_panel', array(
        'title'    => __('Media', 'ai-quest'),
        'priority' => 33,
    ));

    // Section: Before/After Images
    $wp_customize->add_section('ai_quest_before_after_options', array(
        'title'    => __('Hình Ảnh Trước/Sau', 'ai-quest'),
        'panel'    => 'ai_quest_media_panel',
        'priority' => 10,
    ));

    for ($i = 1; $i <= 20; $i++) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_before_after_image_' . $i . '_url', sprintf(__('Before/After Image %d URL (Tỉ lệ: 1:1)', 'ai-quest'), $i), 'ai_quest_before_after_options', '', 'text', 'ai_quest_sanitize_image_url');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_before_after_image_' . $i . '_alt', sprintf(__('Before/After Image %d Alt', 'ai-quest'), $i), 'ai_quest_before_after_options', '', 'text', 'sanitize_text_field');
    }

    for ($i = 1; $i <= 3; $i++) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_before_after_link_' . $i . '_text', sprintf(__('Before/After Link %d Text', 'ai-quest'), $i), 'ai_quest_before_after_options', '', 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_before_after_link_' . $i . '_url', sprintf(__('Before/After Link %d URL', 'ai-quest'), $i), 'ai_quest_before_after_options', '', 'url', 'esc_url_raw');
    }

    $wp_customize->add_section('ai_quest_video_options', array(
        'title'    => __('Video', 'ai-quest'),
        'panel'    => 'ai_quest_media_panel',
        'priority' => 20,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_video_enabled', __('Enable Section', 'ai-quest'), 'ai_quest_video_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_video_title', __('Video Title', 'ai-quest'), 'ai_quest_video_options', 'Video của Henie Skinlab', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_video_subtitle', __('Video Subtitle', 'ai-quest'), 'ai_quest_video_options', '', 'text', 'sanitize_text_field');

    for ($i = 1; $i <= 5; $i++) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_video_' . $i . '_youtube', sprintf(__('Video %d YouTube URL/ID', 'ai-quest'), $i), 'ai_quest_video_options', '', 'text', 'ai_quest_sanitize_youtube_embed_url');
    }

    for ($i = 1; $i <= 5; $i++) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_video_link_' . $i . '_text', sprintf(__('Video Link %d Text', 'ai-quest'), $i), 'ai_quest_video_options', '', 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_video_link_' . $i . '_url', sprintf(__('Video Link %d URL', 'ai-quest'), $i), 'ai_quest_video_options', '', 'url', 'esc_url_raw');
    }

    $wp_customize->add_section('ai_quest_features_options', array(
        'title'    => __('Tính Năng Nổi Bật', 'ai-quest'),
        'priority' => 33,
    ));

    // ---- Facebook Reels ----
    $wp_customize->add_section('ai_quest_fb_reels_options', array(
        'title'    => __('Facebook Reels', 'ai-quest'),
        'panel'    => 'ai_quest_media_panel',
        'priority' => 30,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_fb_reels_enabled', __('Hiện Section', 'ai-quest'), 'ai_quest_fb_reels_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_fb_reels_title', __('Tiêu đề', 'ai-quest'), 'ai_quest_fb_reels_options', 'Facebook Reels', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_fb_reels_subtitle', __('Mô tả', 'ai-quest'), 'ai_quest_fb_reels_options', '', 'text', 'sanitize_text_field');

    for ($i = 1; $i <= 50; $i++) {
        $wp_customize->add_setting('ai_quest_fb_reel_' . $i . '_url', array(
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'type'              => 'option',
        ));
        $wp_customize->add_control('ai_quest_fb_reel_' . $i . '_url', array(
            'label'       => sprintf(__('Reel %d - Facebook URL', 'ai-quest'), $i),
            'description' => __('Dán link Facebook Reel (https://www.facebook.com/reel/...)', 'ai-quest'),
            'section'     => 'ai_quest_fb_reels_options',
            'type'        => 'url',
        ));

        $wp_customize->add_setting('ai_quest_fb_reel_' . $i . '_thumb', array(
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'type'              => 'option',
        ));
        $wp_customize->add_control('ai_quest_fb_reel_' . $i . '_thumb', array(
            'label'       => sprintf(__('Reel %d - Thumbnail URL (Tỉ lệ: 9:16)', 'ai-quest'), $i),
            'description' => __('URL ảnh thumbnail (tỉ lệ 9:16 tốt nhất)', 'ai-quest'),
            'section'     => 'ai_quest_fb_reels_options',
            'type'        => 'url',
        ));

        $wp_customize->add_setting('ai_quest_fb_reel_' . $i . '_pinned', array(
            'default'           => 0,
            'sanitize_callback' => 'ai_quest_sanitize_checkbox',
            'type'              => 'option',
        ));
        $wp_customize->add_control('ai_quest_fb_reel_' . $i . '_pinned', array(
            'label'   => sprintf(__('Reel %d - Ghim lên đầu', 'ai-quest'), $i),
            'section' => 'ai_quest_fb_reels_options',
            'type'    => 'checkbox',
        ));
    }

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_features_enabled', __('Enable Section', 'ai-quest'), 'ai_quest_features_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');

    $wp_customize->add_section('ai_quest_partners_options', array(
        'title'    => __('Đối Tác', 'ai-quest'),
        'priority' => 34,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_partners_enabled', __('Hiện Section', 'ai-quest'), 'ai_quest_partners_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_partners_title', __('Tiêu đề', 'ai-quest'), 'ai_quest_partners_options', 'Đối Tác', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_partners_subtitle', __('Mô tả', 'ai-quest'), 'ai_quest_partners_options', '', 'text', 'sanitize_text_field');

    for ($i = 1; $i <= 10; $i++) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_partner_' . $i . '_logo_url', sprintf(__('Đối tác %d - Logo URL (Tỉ lệ: Tự do)', 'ai-quest'), $i), 'ai_quest_partners_options', '', 'url', 'esc_url_raw');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_partner_' . $i . '_name', sprintf(__('Đối tác %d - Tên', 'ai-quest'), $i), 'ai_quest_partners_options', '', 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_partner_' . $i . '_link_url', sprintf(__('Đối tác %d - Link URL', 'ai-quest'), $i), 'ai_quest_partners_options', '', 'url', 'esc_url_raw');
    }

    $feature_defaults = array(
        1 => array('✨', 'Công Nghệ Hiện Đại', 'Luôn cập nhật và ứng dụng các công nghệ làm đẹp tiên tiến nhất thế giới để mang lại hiệu quả tối ưu.'),
        2 => array('👩‍⚕️', 'Kỹ Thuật Viên Chuyên Nghiệp', 'Đội ngũ được đào tạo bài bản, có tâm và có tầm, mang đến sự an tâm tuyệt đối cho khách hàng.'),
        3 => array('🌿', 'Sản Phẩm Cao Cấp', 'Sử dụng các dòng dược mỹ phẩm uy tín, chiết xuất từ thiên nhiên, an toàn và lành tính cho mọi loại da.'),
    );

    foreach ($feature_defaults as $index => $defaults) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_feature_' . $index . '_icon', sprintf(__('Feature %d Icon', 'ai-quest'), $index), 'ai_quest_features_options', $defaults[0], 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_feature_' . $index . '_title', sprintf(__('Feature %d Title', 'ai-quest'), $index), 'ai_quest_features_options', $defaults[1], 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_feature_' . $index . '_description', sprintf(__('Feature %d Description', 'ai-quest'), $index), 'ai_quest_features_options', $defaults[2], 'textarea', 'sanitize_textarea_field');
    }

    $wp_customize->add_section('ai_quest_testimonials_options', array(
        'title'    => __('Đánh Giá Khách Hàng', 'ai-quest'),
        'priority' => 34,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonials_enabled', __('Enable Section', 'ai-quest'), 'ai_quest_testimonials_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonials_title', __('Testimonials Title', 'ai-quest'), 'ai_quest_testimonials_options', 'Cảm Nhận Khách Hàng', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonials_subtitle', __('Testimonials Subtitle', 'ai-quest'), 'ai_quest_testimonials_options', 'Họ nói gì sau khi trải nghiệm dịch vụ tại Henie Skinlab?', 'text', 'sanitize_text_field');

    $testimonial_defaults = array(
        1 => array('★★★★★', '"Tôi rất hài lòng với trải nghiệm tại Henie Skinlab. Combo này không chỉ tiết kiệm thời gian mà còn mang lại hiệu quả tốt nhất cho làn da."', 'Vũ Thái Thanh', 'Khách hàng thân thiết'),
        2 => array('★★★★★', '"Combo dịch vụ tại đây thực sự là sự lựa chọn hoàn hảo cho một ngày thư giãn. Tôi ấn tượng với sự kết hợp của các liệu pháp chăm sóc da."', 'Hồ Thiên Hà', 'Diễn viên'),
        3 => array('★★★★★', '"Không gian sang trọng, nhân viên chuyên nghiệp. Đây là nơi tuyệt vời nhất để tôi giải tỏa căng thẳng sau một tuần làm việc mệt mỏi."', 'Lý Duyên Mỹ', 'Vlogger'),
    );

    foreach ($testimonial_defaults as $index => $defaults) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonial_' . $index . '_stars', sprintf(__('Testimonial %d Stars', 'ai-quest'), $index), 'ai_quest_testimonials_options', $defaults[0], 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonial_' . $index . '_text', sprintf(__('Testimonial %d Text', 'ai-quest'), $index), 'ai_quest_testimonials_options', $defaults[1], 'textarea', 'sanitize_textarea_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonial_' . $index . '_name', sprintf(__('Testimonial %d Name', 'ai-quest'), $index), 'ai_quest_testimonials_options', $defaults[2], 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonial_' . $index . '_role', sprintf(__('Testimonial %d Role', 'ai-quest'), $index), 'ai_quest_testimonials_options', $defaults[3], 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonial_' . $index . '_image_url', sprintf(__('Testimonial %d Image URL (Tỉ lệ: 4:5)', 'ai-quest'), $index), 'ai_quest_testimonials_options', '', 'text', 'ai_quest_sanitize_image_url');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_testimonial_' . $index . '_image_alt', sprintf(__('Testimonial %d Image Alt', 'ai-quest'), $index), 'ai_quest_testimonials_options', '', 'text', 'sanitize_text_field');
    }

    $wp_customize->add_section('ai_quest_pricing_images_options', array(
        'title'    => __('Bảng Giá - Hình Ảnh', 'ai-quest'),
        'priority' => 34,
    ));

    for ($i = 1; $i <= 4; $i++) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_pricing_image_' . $i . '_url', sprintf(__('Ảnh Bảng Giá %d URL (Tỉ lệ: 2:3)', 'ai-quest'), $i), 'ai_quest_pricing_images_options', '', 'url', 'esc_url_raw');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_pricing_image_' . $i . '_alt', sprintf(__('Ảnh Bảng Giá %d Alt', 'ai-quest'), $i), 'ai_quest_pricing_images_options', 'Bảng giá dịch vụ ' . $i, 'text', 'sanitize_text_field');
    }

    $wp_customize->add_section('ai_quest_banner_options', array(
        'title'    => __('Khuyến Mãi', 'ai-quest'),
        'priority' => 35,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_banner_enabled', __('Hiện section trên trang chủ', 'ai-quest'), 'ai_quest_banner_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_banner_badge', __('Badge', 'ai-quest'), 'ai_quest_banner_options', '', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_banner_title', __('Tiêu đề', 'ai-quest'), 'ai_quest_banner_options', '', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_banner_description', __('Mô tả', 'ai-quest'), 'ai_quest_banner_options', '', 'textarea', 'sanitize_textarea_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_banner_button_text', __('Nút CTA - Text', 'ai-quest'), 'ai_quest_banner_options', '', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_banner_button_url', __('Nút CTA - URL', 'ai-quest'), 'ai_quest_banner_options', '', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_banner_bg_url', __('Ảnh nền URL (Tỉ lệ: Background)', 'ai-quest'), 'ai_quest_banner_options', '', 'url', 'esc_url_raw');
    
    $wp_customize->add_setting('ai_quest_banner_title_color', array(
        'default'           => '#111111',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));
    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_banner_title_color', array(
        'label'   => __('Màu Tiêu Đề Khuyến Mãi', 'ai-quest'),
        'section' => 'ai_quest_banner_options',
        )));
    
    $wp_customize->add_setting('ai_quest_banner_text_color', array(
        'default'           => '#666666',
        'sanitize_callback' => 'sanitize_hex_color',
        'type'              => 'option',
        ));
    $wp_customize->add_control(new WP_Customize_Color_Control($wp_customize, 'ai_quest_banner_text_color', array(
        'label'   => __('Màu Text Khuyến Mãi', 'ai-quest'),
        'section' => 'ai_quest_banner_options',
        )));

    $wp_customize->add_section('ai_quest_marketing_options', array(
        'title'    => __('Chương Trình Hội Viên', 'ai-quest'),
        'priority' => 36,
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_marketing_enabled', __('Enable Section', 'ai-quest'), 'ai_quest_marketing_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_marketing_title', __('Marketing Title', 'ai-quest'), 'ai_quest_marketing_options', 'Chương Trình Hội Viên', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_marketing_subtitle', __('Marketing Subtitle', 'ai-quest'), 'ai_quest_marketing_options', 'Ưu đãi đặc quyền dành riêng cho thành viên của Henie Skinlab.', 'text', 'sanitize_text_field');

    $marketing_defaults = array(
        1 => array('Gói Hội Viên Silver', 'Giảm 10% tất cả dịch vụ, tích điểm đổi quà và ưu tiên đặt lịch trước.', 'Xem Chi Tiết', '#'),
        2 => array('Gói Hội Viên Gold', 'Giảm 20% tất cả dịch vụ, tặng liệu trình chăm sóc da mặt miễn phí hàng tháng.', 'Xem Chi Tiết', '#'),
        3 => array('Gói Hội Viên Diamond', 'Đặc quyền chăm sóc tại phòng VIP, quà tặng sinh nhật cao cấp và giảm 30%.', 'Xem Chi Tiết', '#'),
    );

    foreach ($marketing_defaults as $index => $defaults) {
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_marketing_' . $index . '_title', sprintf(__('Marketing %d Title', 'ai-quest'), $index), 'ai_quest_marketing_options', $defaults[0], 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_marketing_' . $index . '_description', sprintf(__('Marketing %d Description', 'ai-quest'), $index), 'ai_quest_marketing_options', $defaults[1], 'textarea', 'sanitize_textarea_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_marketing_' . $index . '_button_text', sprintf(__('Marketing %d Button Text', 'ai-quest'), $index), 'ai_quest_marketing_options', $defaults[2], 'text', 'sanitize_text_field');
        ai_quest_add_customizer_field($wp_customize, 'ai_quest_marketing_' . $index . '_button_url', sprintf(__('Marketing %d Button URL', 'ai-quest'), $index), 'ai_quest_marketing_options', $defaults[3], 'url', 'esc_url_raw');
    }

    $wp_customize->add_section('ai_quest_locations_options', array(
        'title'    => __('Cài Đặt Footer', 'ai-quest'),
        'priority' => 36,
        'description' => __('Số điện thoại Hotline được lấy từ Header → Số Điện Thoại (tối đa 5 cơ sở). Nếu có từ 2 số trở lên, sẽ hiển thị danh sách theo hàng dọc.', 'ai-quest'),
    ));

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_enabled', __('Enable Section', 'ai-quest'), 'ai_quest_locations_options', 1, 'checkbox', 'ai_quest_sanitize_checkbox');

    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_heading', __('Locations Heading', 'ai-quest'), 'ai_quest_locations_options', 'Hệ Thống Henie Skinlab', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_logo_url', __('Locations Logo URL (Tỉ lệ: Tự do)', 'ai-quest'), 'ai_quest_locations_options', '', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_social_facebook_url', __('Locations Facebook URL', 'ai-quest'), 'ai_quest_locations_options', '#', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_social_instagram_url', __('Locations Instagram URL', 'ai-quest'), 'ai_quest_locations_options', '#', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_social_tiktok_url', __('Locations TikTok URL', 'ai-quest'), 'ai_quest_locations_options', '#', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_social_youtube_url', __('Locations YouTube URL', 'ai-quest'), 'ai_quest_locations_options', '#', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_time_text', __('Locations Time Text', 'ai-quest'), 'ai_quest_locations_options', 'Thứ Hai đến Chủ Nhật: 9:00 Sáng - 20:00 Tối', 'textarea', 'sanitize_textarea_field');
    
    // Hotline is now managed in Header → Phone Numbers section (up to 5 locations)
    // No need for separate hotline field here
    
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_website_label', __('Locations Website Label', 'ai-quest'), 'ai_quest_locations_options', 'henieskinlab.com', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_locations_website_url', __('Locations Website URL', 'ai-quest'), 'ai_quest_locations_options', 'https://henieskinlab.com/', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_1_title', __('Location 1 Description', 'ai-quest'), 'ai_quest_locations_options', 'Bình Thạnh, TP.HCM', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_1_address', __('Location 1 Address', 'ai-quest'), 'ai_quest_locations_options', '21/5D, Bình Lợi, Bình Lợi Trung, Hồ Chí Minh 700000, Việt Nam', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_1_map_embed_url', __('Location 1 Map Embed URL', 'ai-quest'), 'ai_quest_locations_options', 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3918.8028344097156!2d106.70298361125364!3d10.82639548928088!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x31752900161e84f1%3A0xf3284fbaaba2ba2e!2zSGVuaWUgU2tpbmxhYiAtIFNwYSBDaMSDbSBTw7NjIERhIELDrG5oIFRo4bqhbmg!5e0!3m2!1svi!2s!4v1776057224603!5m2!1svi!2s', 'textarea', 'ai_quest_sanitize_maps_embed_url');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_1_maps_url', __('Location 1 Google Maps URL', 'ai-quest'), 'ai_quest_locations_options', 'https://www.google.com/maps?cid=17521342013446994478&g_mp=CiVnb29nbGUubWFwcy5wbGFjZXMudjEuUGxhY2VzLkdldFBsYWNlEAIYASAA&hl=vi&source=embed', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_2_title', __('Location 2 Description', 'ai-quest'), 'ai_quest_locations_options', 'Lái Thiêu, TP.HCM', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_2_address', __('Location 2 Address', 'ai-quest'), 'ai_quest_locations_options', '188 3 Tháng 2, KP Đông Tư, Lái Thiêu, Hồ Chí Minh, Việt Nam', 'text', 'sanitize_text_field');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_2_map_embed_url', __('Location 2 Map Embed URL', 'ai-quest'), 'ai_quest_locations_options', 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3917.6413645801354!2d106.69925931125468!3d10.914836689197623!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3174d9b18a1694d7%3A0x9981a3fbd49ef74!2zSGVuaWUgU2tpbmxhYiAtIFNwYSBDaMSDbSBTw7NjIERhIEzDoWkgVGhpw6p1!5e0!3m2!1svi!2s!4v1776057284562!5m2!1svi!2s', 'textarea', 'ai_quest_sanitize_maps_embed_url');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_location_2_maps_url', __('Location 2 Google Maps URL', 'ai-quest'), 'ai_quest_locations_options', 'https://www.google.com/maps/place/Henie+Skinlab+-+Spa+Ch%C4%83m+S%C3%B3c+Da+L%C3%A1i+Thi%C3%AAu/@10.9148367,106.7018396,17z/data=!3m1!4b1!4m6!3m5!1s0x3174d9b18a1694d7:0x9981a3fbd49ef74!8m2!3d10.9148367!4d106.7018396!16s%2Fg%2F11mt2x70fp?hl=vi&entry=ttu&g_ep=EgoyMDI2MDQxNC4wIKXMDSoASAFQAw%3D%3D', 'url', 'esc_url_raw');

    $wp_customize->add_section('ai_quest_sticky_contact', array(
        'title'    => __('Liên Hệ Nhanh', 'ai-quest'),
        'priority' => 38,
        'description' => __('Số điện thoại được lấy từ Header → Số Điện Thoại (tối đa 5 cơ sở). Nếu có từ 2 số trở lên, sẽ hiển thị popup để chọn cơ sở.', 'ai-quest'),
    ));

    // Phone numbers are now managed in Header → Phone Numbers section (up to 5 locations)
    // No need for separate phone field here
    
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_sticky_zalo', __('Zalo URL', 'ai-quest'), 'ai_quest_sticky_contact', 'https://zalo.me/0962359465', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_sticky_messenger', __('Messenger URL', 'ai-quest'), 'ai_quest_sticky_contact', 'https://m.me/henieskinlab', 'url', 'esc_url_raw');
    ai_quest_add_customizer_field($wp_customize, 'ai_quest_sticky_facebook', __('Facebook URL', 'ai-quest'), 'ai_quest_sticky_contact', 'https://facebook.com/henieskinlab', 'url', 'esc_url_raw');

    // Toggle sections visibility
    $wp_customize->add_setting('ai_quest_home_services_enabled', array(
        'default'           => 1,
        'sanitize_callback' => 'absint',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_home_services_enabled', array(
        'label'       => __('Hiện Section Dịch Vụ ở Trang Chủ', 'ai-quest'),
        'description' => __('Bật/tắt hiển thị phần Dịch Vụ trên trang chủ.', 'ai-quest'),
        'section'     => 'ai_quest_theme_options',
        'type'        => 'checkbox',
    ));

    $wp_customize->add_setting('ai_quest_booking_button_enabled', array(
        'default'           => 1,
        'sanitize_callback' => 'absint',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_booking_button_enabled', array(
        'label'       => __('Hiện Nút Đặt Lịch', 'ai-quest'),
        'description' => __('Bật/tắt hiển thị nút Đặt Lịch trên Header và Menu.', 'ai-quest'),
        'section'     => 'ai_quest_theme_options',
        'type'        => 'checkbox',
    ));

    $wp_customize->add_setting('ai_quest_footer_google_maps_enabled', array(
        'default'           => 1,
        'sanitize_callback' => 'absint',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_footer_google_maps_enabled', array(
        'label'       => __('Hiện Google Maps ở Footer', 'ai-quest'),
        'description' => __('Bật/tắt hiển thị 2 bản đồ Google Maps ở phần Chi Nhánh cuối trang.', 'ai-quest'),
        'section'     => 'ai_quest_theme_options',
        'type'        => 'checkbox',
    ));

    $wp_customize->add_setting('ai_quest_topbar_location_enabled', array(
        'default'           => 1,
        'sanitize_callback' => 'absint',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_topbar_location_enabled', array(
        'label'       => __('Hiện Dropdown Location ở Header', 'ai-quest'),
        'description' => __('Bật/tắt hiển thị dropdown LOCATION ở góc trên đầu trang.', 'ai-quest'),
        'section'     => 'ai_quest_theme_options',
        'type'        => 'checkbox',
    ));

    $wp_customize->add_setting('ai_quest_consult_popup_enabled', array(
        'default'           => 1,
        'sanitize_callback' => 'absint',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_consult_popup_enabled', array(
        'label'       => __('Hiện Popup Tư Vấn', 'ai-quest'),
        'description' => __('Bật/tắt popup tư vấn tự động hiện khi mới vào trang.', 'ai-quest'),
        'section'     => 'ai_quest_theme_options',
        'type'        => 'checkbox',
    ));
}
add_action('customize_register', 'ai_quest_customize_register');

function ai_quest_maybe_restore_product_visibility_defaults() {
    if (get_option('aiq_restored_product_visibility_defaults', '0') === '1') {
        return;
    }

    $untouched_keys = array('badge', 'weight', 'name', 'description', 'price', 'url', 'image_url', 'image_alt');
    $suspect_count = 0;

    for ($i = 1; $i <= 5; $i++) {
        $all_untouched = true;
        foreach ($untouched_keys as $key) {
            if (get_option('ai_quest_product_' . $i . '_' . $key, null) !== null) {
                $all_untouched = false;
                break;
            }
        }

        $featured_opt = get_option('ai_quest_product_' . $i . '_show_featured', null);
        $all_opt = get_option('ai_quest_product_' . $i . '_show_all', null);

        if ($all_untouched && $featured_opt !== null && $all_opt !== null && (int) $featured_opt === 0 && (int) $all_opt === 0) {
            $suspect_count++;
        }
    }

    if ($suspect_count >= 3) {
        for ($i = 1; $i <= 5; $i++) {
            $all_untouched = true;
            foreach ($untouched_keys as $key) {
                if (get_option('ai_quest_product_' . $i . '_' . $key, null) !== null) {
                    $all_untouched = false;
                    break;
                }
            }

            if ($all_untouched) {
                update_option('ai_quest_product_' . $i . '_show_featured', 1);
                update_option('ai_quest_product_' . $i . '_show_all', 1);
            }
        }
    }

    update_option('aiq_restored_product_visibility_defaults', '1');
}
add_action('init', 'ai_quest_maybe_restore_product_visibility_defaults', 6);

function ai_quest_customizer_sync_product_visibility($wp_customize) {
    for ($i = 1; $i <= 20; $i++) {
        $name_option = get_option('ai_quest_product_' . $i . '_name', null);
        if ($name_option !== null && trim((string) $name_option) === '') {
            update_option('ai_quest_product_' . $i . '_show_featured', 0);
            update_option('ai_quest_product_' . $i . '_show_all', 0);
            continue;
        }

        $featured = (int) ai_quest_get_setting('ai_quest_product_' . $i . '_show_featured', $i <= 5 ? 1 : 0);
        $all = (int) ai_quest_get_setting('ai_quest_product_' . $i . '_show_all', $i <= 5 ? 1 : 0);

        if ($featured && !$all) {
            update_option('ai_quest_product_' . $i . '_show_all', 1);
        }
    }
}
add_action('customize_save_after', 'ai_quest_customizer_sync_product_visibility');

function ai_quest_customizer_css() {
    $primary_color      = ai_quest_get_setting('ai_quest_primary_color', '#6B7D3A');
    $header_bg_color    = ai_quest_get_setting('ai_quest_header_bg_color', '#ffffff');
    $header_text_color  = ai_quest_get_setting('ai_quest_header_text_color', '#111111');
    $choices = ai_quest_font_choices();
    $title_key = ai_quest_sanitize_font_choice(ai_quest_get_setting('ai_quest_title_font', 'sora'));
    $body_key = ai_quest_sanitize_font_choice(ai_quest_get_setting('ai_quest_body_font', 'montserrat'));

    $title_family = isset($choices[$title_key]) ? $choices[$title_key]['family'] : 'Sora';
    $title_fallback = isset($choices[$title_key]) ? $choices[$title_key]['fallback'] : 'sans-serif';
    $body_family = isset($choices[$body_key]) ? $choices[$body_key]['family'] : 'Montserrat';
    $body_fallback = isset($choices[$body_key]) ? $choices[$body_key]['fallback'] : 'sans-serif';

    $custom_css = ':root{';
    $custom_css .= '--primary-spa:' . esc_attr($primary_color) . ';';
    $custom_css .= '--header-bg:' . esc_attr($header_bg_color) . ';';
    $custom_css .= '--header-text:' . esc_attr($header_text_color) . ';';
    $custom_css .= "--font-title:'" . esc_attr($title_family) . "'," . esc_attr($title_fallback) . ';';
    $custom_css .= "--font-sans:'" . esc_attr($body_family) . "'," . esc_attr($body_fallback) . ';';
    $custom_css .= '}';
    $custom_css .= '.glass-header,.mini-header{background:var(--header-bg);}';
    $custom_css .= '.header-nav-row .nav-links a,.mini-header .nav-links a{color:var(--header-text);}';
    $custom_css .= '.logo a{color:var(--header-text);}';
    $custom_css .= '.mini-header .logo a{color:var(--header-text);}';
    $custom_css .= '.mini-header{border-bottom-color:var(--header-bg);}';
    wp_add_inline_style('ai-quest-custom-style', $custom_css);
}
add_action('wp_enqueue_scripts', 'ai_quest_customizer_css', 20);

function ai_quest_add_virtual_page_query_var($vars) {
    $vars[] = 'aiq_page';
    return $vars;
}
add_filter('query_vars', 'ai_quest_add_virtual_page_query_var');

function ai_quest_register_virtual_pages_rewrite_rules() {
    add_rewrite_rule('^dich-vu/?$', 'index.php?aiq_page=dich-vu', 'top');
    add_rewrite_rule('^bang-gia/?$', 'index.php?aiq_page=bang-gia', 'top');
    add_rewrite_rule('^gioi-thieu/?$', 'index.php?aiq_page=gioi-thieu', 'top');
    add_rewrite_rule('^dat-lich/?$', 'index.php?aiq_page=dat-lich', 'top');
    add_rewrite_rule('^dang-ky/?$', 'index.php?aiq_page=dang-ky', 'top');
    add_rewrite_rule('^tat-ca-dich-vu/?$', 'index.php?aiq_page=tat-ca-dich-vu', 'top');
    add_rewrite_rule('^khuyen-mai/?$', 'index.php?aiq_page=khuyen-mai', 'top');
    add_rewrite_rule('^doi-tac/?$', 'index.php?aiq_page=doi-tac', 'top');
    add_rewrite_rule('^cham-soc-da/?$', 'index.php?aiq_page=cham-soc-da', 'top');
    add_rewrite_rule('^triet-long/?$', 'index.php?aiq_page=triet-long', 'top');
    add_rewrite_rule('^goi-dau/?$', 'index.php?aiq_page=goi-dau', 'top');
}
add_action('init', 'ai_quest_register_virtual_pages_rewrite_rules');

function ai_quest_maybe_flush_virtual_pages_rewrite_rules() {
    if (get_option('aiq_virtual_pages_rewrite_flushed_v6') === '1') {
        return;
    }

    flush_rewrite_rules(false);
    update_option('aiq_virtual_pages_rewrite_flushed_v6', '1');
}
add_action('admin_init', 'ai_quest_maybe_flush_virtual_pages_rewrite_rules');

function ai_quest_virtual_page_document_title($parts) {
    $page = get_query_var('aiq_page');
    if (!$page) {
        return $parts;
    }

    $map = array(
        'dich-vu' => 'Dịch vụ',
        'bang-gia' => 'Bảng giá',
        'gioi-thieu' => 'Giới thiệu',
        'dat-lich' => 'Đặt lịch',
        'tat-ca-dich-vu' => 'Tất cả dịch vụ',
        'khuyen-mai' => 'Khuyến mãi',
        'doi-tac'    => 'Đối Tác',
        'chia-se'       => 'Chia Sẻ',
        'tu-chuyen-gia' => 'Từ Chuyên Gia',
        'tu-khach-hang' => 'Từ Khách Hàng',
        'cham-soc-da' => 'Chăm Sóc Da',
        'triet-long'  => 'Triệt Lông',
        'goi-dau'     => 'Gội Đầu',
    );

    if (isset($map[$page])) {
        $parts['title'] = $map[$page];
    }

    return $parts;
}
add_filter('document_title_parts', 'ai_quest_virtual_page_document_title', 20);

function ai_quest_template_for_virtual_pages($template) {
    global $wp_query;

    $page = get_query_var('aiq_page');
    if (!$page) {
        return $template;
    }

    $map = array(
        'dich-vu' => 'page-dich-vu.php',
        'bang-gia' => 'page-bang-gia.php',
        'gioi-thieu' => 'page-gioi-thieu.php',
        'dat-lich' => 'page-dat-lich.php',
        'dang-ky' => 'page-dang-ky.php',
        'tat-ca-dich-vu' => 'page-tat-ca-dich-vu.php',
        'khuyen-mai' => 'page-khuyen-mai.php',
        'doi-tac'    => 'page-doi-tac.php',
        'chia-se'       => 'page-chia-se.php',
        'tu-chuyen-gia' => 'page-tu-chuyen-gia.php',
        'tu-khach-hang' => 'page-tu-khach-hang.php',
        'cham-soc-da' => 'page-svc-detail.php',
        'triet-long'  => 'page-svc-detail.php',
        'goi-dau'     => 'page-svc-detail.php',
    );

    if (!isset($map[$page])) {
        return $template;
    }

    if (isset($wp_query)) {
        $wp_query->is_404 = false;
    }

    status_header(200);
    nocache_headers();

    $located = locate_template(array($map[$page]));
    return $located ? $located : $template;
}
add_filter('template_include', 'ai_quest_template_for_virtual_pages', 99);

// Add rewrite rules for pretty URLs with parent-child structure
function ai_quest_add_rewrite_rules() {
    // Parent pages (top level)
    $parent_pages = array(
        'dich-vu',
        'bang-gia',
        'gioi-thieu',
        'dat-lich',
        'dang-ky',
        'khuyen-mai',
        'doi-tac',
        'chia-se',
    );
    
    foreach ($parent_pages as $page) {
        add_rewrite_rule(
            '^' . $page . '/?$',
            'index.php?aiq_page=' . $page,
            'top'
        );
    }
    
    // Child pages under /dich-vu/
    $service_pages = array(
        'cham-soc-da',
        'triet-long',
        'goi-dau',
        'tat-ca-dich-vu',
    );
    
    foreach ($service_pages as $page) {
        add_rewrite_rule(
            '^dich-vu/' . $page . '/?$',
            'index.php?aiq_page=' . $page,
            'top'
        );
    }
    
    // Child pages under /chia-se/ (sharing section)
    add_rewrite_rule(
        '^chia-se/tu-chuyen-gia/page/([0-9]+)/?$',
        'index.php?aiq_page=tu-chuyen-gia&paged=$matches[1]',
        'top'
    );
    
    add_rewrite_rule(
        '^chia-se/tu-chuyen-gia/?$',
        'index.php?aiq_page=tu-chuyen-gia',
        'top'
    );
    
    add_rewrite_rule(
        '^chia-se/tu-khach-hang/page/([0-9]+)/?$',
        'index.php?aiq_page=tu-khach-hang&paged=$matches[1]',
        'top'
    );
    
    add_rewrite_rule(
        '^chia-se/tu-khach-hang/?$',
        'index.php?aiq_page=tu-khach-hang',
        'top'
    );
    
    // Consultation page
    add_rewrite_rule(
        '^tu-van/?$',
        'index.php?aiq_page=tu-van',
        'top'
    );
}
add_action('init', 'ai_quest_add_rewrite_rules');

// Flush rewrite rules on theme activation (run once)
function ai_quest_flush_rewrite_rules_on_activation() {
    if (get_option('ai_quest_rewrite_flushed_v2') !== 'yes') {
        ai_quest_add_rewrite_rules();
        flush_rewrite_rules();
        update_option('ai_quest_rewrite_flushed_v2', 'yes');
    }
}
add_action('after_switch_theme', 'ai_quest_flush_rewrite_rules_on_activation');

// Force flush rewrite rules (temporary - for debugging)
// Remove this after URLs work correctly
function ai_quest_force_flush_rewrite_rules() {
    // Delete the option to force re-flush
    delete_option('ai_quest_rewrite_flushed_v2');
    
    // Add rules and flush
    ai_quest_add_rewrite_rules();
    flush_rewrite_rules();
    
    // Set option again
    update_option('ai_quest_rewrite_flushed_v2', 'yes');
}
// Uncomment the line below to force flush on next page load, then comment it again
add_action('init', 'ai_quest_force_flush_rewrite_rules', 999);

// Register query var
function ai_quest_register_query_vars($vars) {
    $vars[] = 'aiq_page';
    $vars[] = 'paged';
    return $vars;
}
add_filter('query_vars', 'ai_quest_register_query_vars');

// Register Custom Post Type for Expert Articles (Từ Chuyên Gia)
function ai_quest_register_expert_article_post_type() {
    $labels = array(
        'name'                  => 'Từ Chuyên Gia',
        'singular_name'         => 'Bài Viết',
        'menu_name'             => 'Từ Chuyên Gia',
        'add_new'               => 'Thêm Bài Viết',
        'add_new_item'          => 'Thêm Bài Viết Mới',
        'edit_item'             => 'Sửa Bài Viết',
        'new_item'              => 'Bài Viết Mới',
        'view_item'             => 'Xem Bài Viết',
        'search_items'          => 'Tìm Bài Viết',
        'not_found'             => 'Không tìm thấy bài viết',
        'not_found_in_trash'    => 'Không có bài viết trong thùng rác',
        'all_items'             => 'Tất Cả Bài Viết',
    );

    $args = array(
        'labels'                => $labels,
        'public'                => true,
        'publicly_queryable'    => true,
        'show_ui'               => true,
        'show_in_menu'          => true,
        'query_var'             => true,
        'rewrite'               => array(
            'slug'              => 'chia-se/tu-chuyen-gia',
            'with_front'        => false,
        ),
        'capability_type'       => 'post',
        'has_archive'           => false,
        'hierarchical'          => false,
        'menu_position'         => 5,
        'menu_icon'             => 'dashicons-welcome-learn-more',
        'supports'              => array('title', 'editor', 'thumbnail', 'excerpt', 'author'),
        'show_in_rest'          => true,
    );

    register_post_type('expert_article', $args);
}
add_action('init', 'ai_quest_register_expert_article_post_type');

// Register Custom Post Type for Customer Articles (Từ Khách Hàng)
function ai_quest_register_customer_article_post_type() {
    $labels = array(
        'name'                  => 'Từ Khách Hàng',
        'singular_name'         => 'Bài Viết',
        'menu_name'             => 'Từ Khách Hàng',
        'add_new'               => 'Thêm Bài Viết',
        'add_new_item'          => 'Thêm Bài Viết Mới',
        'edit_item'             => 'Sửa Bài Viết',
        'new_item'              => 'Bài Viết Mới',
        'view_item'             => 'Xem Bài Viết',
        'search_items'          => 'Tìm Bài Viết',
        'not_found'             => 'Không tìm thấy bài viết',
        'not_found_in_trash'    => 'Không có bài viết trong thùng rác',
        'all_items'             => 'Tất Cả Bài Viết',
    );

    $args = array(
        'labels'                => $labels,
        'public'                => true,
        'publicly_queryable'    => true,
        'show_ui'               => true,
        'show_in_menu'          => true,
        'query_var'             => true,
        'rewrite'               => array(
            'slug'              => 'chia-se/tu-khach-hang',
            'with_front'        => false,
        ),
        'capability_type'       => 'post',
        'has_archive'           => false,
        'hierarchical'          => false,
        'menu_position'         => 6,
        'menu_icon'             => 'dashicons-groups',
        'supports'              => array('title', 'editor', 'thumbnail', 'excerpt', 'author'),
        'show_in_rest'          => true,
    );

    register_post_type('customer_article', $args);
}
add_action('init', 'ai_quest_register_customer_article_post_type');

// Register Custom Post Type for Service Articles (Bài Viết Dịch Vụ)
function ai_quest_register_service_article_post_type() {
    $labels = array(
        'name'                  => 'Bài Viết Dịch Vụ',
        'singular_name'         => 'Bài Viết Dịch Vụ',
        'menu_name'             => 'Bài Viết Dịch Vụ',
        'name_admin_bar'        => 'Bài Viết Dịch Vụ',
        'add_new'               => 'Thêm Mới',
        'add_new_item'          => 'Thêm Bài Viết Dịch Vụ Mới',
        'new_item'              => 'Bài Viết Mới',
        'edit_item'             => 'Sửa Bài Viết',
        'view_item'             => 'Xem Bài Viết',
        'all_items'             => 'Tất Cả Bài Viết',
        'search_items'          => 'Tìm Bài Viết',
        'not_found'             => 'Không tìm thấy bài viết nào',
        'not_found_in_trash'    => 'Không có bài viết nào trong thùng rác',
    );

    $args = array(
        'labels'             => $labels,
        'public'             => true,
        'publicly_queryable' => true,
        'show_ui'            => true,
        'show_in_menu'       => true,
        'query_var'          => true,
        'rewrite'            => false, // Disable default rewrite, we'll add custom rules
        'capability_type'    => 'post',
        'has_archive'        => false,
        'hierarchical'       => false,
        'menu_position'      => 21,
        'menu_icon'          => 'dashicons-media-document',
        'supports'           => array('title', 'editor', 'thumbnail', 'excerpt'),
        'show_in_rest'       => true, // Enable Gutenberg
    );

    register_post_type('service_article', $args);
}
add_action('init', 'ai_quest_register_service_article_post_type');

// Add custom rewrite rules for service articles
function ai_quest_service_article_rewrite_rules() {
    // Add rewrite rules for each service page
    add_rewrite_rule(
        '^cham-soc-da/([^/]+)/?$',
        'index.php?service_article=$matches[1]',
        'top'
    );
    
    add_rewrite_rule(
        '^triet-long/([^/]+)/?$',
        'index.php?service_article=$matches[1]',
        'top'
    );
    
    add_rewrite_rule(
        '^goi-dau/([^/]+)/?$',
        'index.php?service_article=$matches[1]',
        'top'
    );
}
add_action('init', 'ai_quest_service_article_rewrite_rules');

// Modify service article permalink structure
function ai_quest_service_article_permalink($post_link, $post) {
    if ($post->post_type === 'service_article') {
        $page_key = get_post_meta($post->ID, '_service_page', true);
        
        if ($page_key) {
            $post_link = home_url('/dich-vu/' . $page_key . '/' . $post->post_name . '/');
        }
    }
    
    return $post_link;
}
add_filter('post_type_link', 'ai_quest_service_article_permalink', 10, 2);

// Flush rewrite rules on theme activation (one time)
function ai_quest_flush_service_article_rewrite_rules() {
    if (get_option('ai_quest_service_article_rewrite_flushed', '0') === '0') {
        ai_quest_service_article_rewrite_rules();
        flush_rewrite_rules();
        update_option('ai_quest_service_article_rewrite_flushed', '1');
    }
}
add_action('init', 'ai_quest_flush_service_article_rewrite_rules', 999);

// Register Custom Post Type for Service Detail Articles (Bài Viết Chi Tiết DV)
function ai_quest_register_service_detail_article_post_type() {
    error_log('=== REGISTERING service_detail_article ===');
    
    $labels = array(
        'name'                  => 'Bài Viết Chi Tiết DV',
        'singular_name'         => 'Bài Viết Chi Tiết DV',
        'menu_name'             => 'Bài Viết Chi Tiết DV',
        'name_admin_bar'        => 'Bài Viết Chi Tiết DV',
        'add_new'               => 'Thêm Mới',
        'add_new_item'          => 'Thêm Bài Viết Chi Tiết Mới',
        'new_item'              => 'Bài Viết Mới',
        'edit_item'             => 'Sửa Bài Viết',
        'view_item'             => 'Xem Bài Viết',
        'all_items'             => 'Tất Cả Bài Viết',
        'search_items'          => 'Tìm Bài Viết',
        'not_found'             => 'Không tìm thấy bài viết nào',
        'not_found_in_trash'    => 'Không có bài viết nào trong thùng rác',
    );

    $args = array(
        'labels'             => $labels,
        'public'             => true,
        'publicly_queryable' => true,
        'show_ui'            => true,
        'show_in_menu'       => true,
        'query_var'          => true,
        'rewrite'            => array(
            'slug'       => 'dich-vu',
            'with_front' => false,
        ),
        'capability_type'    => 'post',
        'has_archive'        => false,
        'hierarchical'       => false,
        'menu_position'      => 22,
        'menu_icon'          => 'dashicons-list-view',
        'supports'           => array('title', 'editor', 'thumbnail', 'excerpt'),
        'show_in_rest'       => true,
    );

    $result = register_post_type('svc_detail_article', $args); // Changed name
    
    if (is_wp_error($result)) {
        error_log('FAILED to register: ' . $result->get_error_message());
    } else {
        error_log('SUCCESS registered svc_detail_article');
    }
}
add_action('init', 'ai_quest_register_service_detail_article_post_type');

// Custom permalink structure for service detail articles
function ai_quest_svc_detail_article_permalink($post_link, $post) {
    if ($post->post_type !== 'svc_detail_article') {
        return $post_link;
    }
    
    $parent_service = get_post_meta($post->ID, '_parent_service', true);
    $page_key = get_post_meta($post->ID, '_service_page', true);
    
    if (!$parent_service || !$page_key) {
        return $post_link;
    }
    
    // Get parent service article URL
    $parent_article_url = ai_quest_get_service_article_url($parent_service, $page_key);
    
    if ($parent_article_url) {
        // Remove trailing slash and add post slug
        $parent_article_url = untrailingslashit($parent_article_url);
        return $parent_article_url . '/' . $post->post_name . '/';
    }
    
    return $post_link;
}
add_filter('post_type_link', 'ai_quest_svc_detail_article_permalink', 10, 2);

// Add rewrite rules for hierarchical URLs
function ai_quest_service_articles_rewrite_rules() {
    // Pattern for service_article: /dich-vu/page-key/service-slug/
    add_rewrite_rule(
        '^dich-vu/([^/]+)/([^/]+)/?$',
        'index.php?service_article=$matches[2]',
        'top'
    );
    
    // Pattern for svc_detail_article: /dich-vu/page-key/parent-service-slug/detail-service-slug/
    add_rewrite_rule(
        '^dich-vu/([^/]+)/([^/]+)/([^/]+)/?$',
        'index.php?svc_detail_article=$matches[3]',
        'top'
    );
}
add_action('init', 'ai_quest_service_articles_rewrite_rules');

// Flush rewrite rules once after adding custom rules
function ai_quest_flush_svc_detail_rewrite_rules() {
    if (get_option('ai_quest_svc_detail_rewrite_flushed', '0') === '0') {
        flush_rewrite_rules();
        update_option('ai_quest_svc_detail_rewrite_flushed', '1');
    }
}
add_action('init', 'ai_quest_flush_svc_detail_rewrite_rules', 999);

// Force enable post thumbnail support for article post types
function ai_quest_force_thumbnail_support() {
    // Ensure theme supports post thumbnails
    if (!current_theme_supports('post-thumbnails')) {
        add_theme_support('post-thumbnails');
    }
    
    // Explicitly add support for our custom post types
    add_post_type_support('expert_article', 'thumbnail');
    add_post_type_support('customer_article', 'thumbnail');
    add_post_type_support('expert_article', 'excerpt');
    add_post_type_support('customer_article', 'excerpt');
}
add_action('init', 'ai_quest_force_thumbnail_support', 20);

// Ensure Featured Image and Excerpt are visible for article post types
function ai_quest_add_article_editor_support() {
    // Make sure excerpt is visible
    add_post_type_support('expert_article', 'excerpt');
    add_post_type_support('customer_article', 'excerpt');
    
    // Make sure featured image is visible
    add_post_type_support('expert_article', 'thumbnail');
    add_post_type_support('customer_article', 'thumbnail');
}
add_action('init', 'ai_quest_add_article_editor_support');

// Sync service articles with service sub-categories
function ai_quest_sync_service_articles() {
    // Get all services from customizer
    $svc_pages = array(
        'cham-soc-da' => array('slug' => 'cham_soc_da', 'label' => 'Chăm Sóc Da'),
        'triet-long'  => array('slug' => 'triet_long',  'label' => 'Triệt Lông'),
        'goi-dau'     => array('slug' => 'goi_dau',     'label' => 'Gội Đầu'),
    );
    
    $current_services = array(); // Track all current services
    
    foreach ($svc_pages as $page_key => $page_data) {
        $s = 'ai_quest_svcpage_' . $page_data['slug'];
        
        for ($ci = 1; $ci <= 5; $ci++) {
            $cp = $s . '_sub' . $ci;
            $sub_name = trim((string) ai_quest_get_setting($cp . '_name', ''));
            
            if ($sub_name !== '') {
                $service_key = $page_key . '||' . $sub_name; // Unique key
                $current_services[$service_key] = array(
                    'name' => $sub_name,
                    'page_key' => $page_key,
                    'page_label' => $page_data['label']
                );
                
                // Check if article exists for this service
                $existing = get_posts(array(
                    'post_type' => 'service_article',
                    'post_status' => 'any',
                    'posts_per_page' => 1,
                    'meta_query' => array(
                        array(
                            'key' => '_service_key',
                            'value' => $service_key,
                            'compare' => '='
                        )
                    )
                ));
                
                if (empty($existing)) {
                    // Create new article for this service
                    $post_id = wp_insert_post(array(
                        'post_type' => 'service_article',
                        'post_title' => $sub_name,
                        'post_status' => 'draft', // Start as draft
                        'post_content' => '<p>Nội dung chi tiết về dịch vụ <strong>' . esc_html($sub_name) . '</strong>.</p><p>Vui lòng chỉnh sửa và thêm thông tin chi tiết về dịch vụ này.</p>',
                    ));
                    
                    if ($post_id) {
                        update_post_meta($post_id, '_service_key', $service_key);
                        update_post_meta($post_id, '_service_name', $sub_name);
                        update_post_meta($post_id, '_service_page', $page_key);
                        update_post_meta($post_id, '_auto_created', '1');
                    }
                }
            }
        }
    }
    
    // Delete articles for services that no longer exist
    $all_articles = get_posts(array(
        'post_type' => 'service_article',
        'post_status' => 'any',
        'posts_per_page' => -1,
        'meta_key' => '_service_key'
    ));
    
    foreach ($all_articles as $article) {
        $service_key = get_post_meta($article->ID, '_service_key', true);
        
        if ($service_key && !isset($current_services[$service_key])) {
            // Service no longer exists, delete the article
            wp_delete_post($article->ID, true); // Force delete
        }
    }
}

// Run sync when customizer is saved
add_action('customize_save_after', 'ai_quest_sync_service_articles');

// Run sync on init (for initial setup)
function ai_quest_maybe_sync_service_articles() {
    if (get_option('ai_quest_service_articles_synced', '0') === '0') {
        ai_quest_sync_service_articles();
        update_option('ai_quest_service_articles_synced', '1');
    }
}
add_action('init', 'ai_quest_maybe_sync_service_articles', 99);

// Sync service detail articles (for individual services)
function ai_quest_sync_service_detail_articles() {
    $svc_pages = array(
        'cham-soc-da' => array('slug' => 'cham_soc_da', 'label' => 'Chăm Sóc Da'),
        'triet-long'  => array('slug' => 'triet_long',  'label' => 'Triệt Lông'),
        'goi-dau'     => array('slug' => 'goi_dau',     'label' => 'Gội Đầu'),
    );
    
    $current_services = array();
    
    foreach ($svc_pages as $page_key => $page_data) {
        $s = 'ai_quest_svcpage_' . $page_data['slug'];
        
        for ($ci = 1; $ci <= 5; $ci++) {
            $cp = $s . '_sub' . $ci;
            $parent_name = trim((string) ai_quest_get_setting($cp . '_name', ''));
            
            if ($parent_name !== '') {
                // Loop through individual services
                for ($si = 1; $si <= 12; $si++) {
                    $sp = $cp . '_svc' . $si;
                    $svc_name = trim((string) ai_quest_get_setting($sp . '_name', ''));
                    
                    if ($svc_name !== '') {
                        $service_key = $page_key . '||' . $parent_name . '||' . $svc_name;
                        $current_services[$service_key] = array(
                            'name' => $svc_name,
                            'parent' => $parent_name,
                            'page_key' => $page_key,
                            'page_label' => $page_data['label'],
                            'price' => ai_quest_get_setting($sp . '_price', ''),
                            'badge' => ai_quest_get_setting($sp . '_badge', '')
                        );
                        
                        // Check if article exists
                        $existing = get_posts(array(
                            'post_type' => 'svc_detail_article',
                            'post_status' => 'any',
                            'posts_per_page' => 1,
                            'meta_query' => array(
                                array(
                                    'key' => '_service_key',
                                    'value' => $service_key,
                                    'compare' => '='
                                )
                            )
                        ));
                        
                        if (empty($existing)) {
                            // Create new article
                            $post_id = wp_insert_post(array(
                                'post_type' => 'svc_detail_article',
                                'post_title' => $svc_name,
                                'post_status' => 'draft',
                                'post_content' => '<p>Nội dung chi tiết về dịch vụ <strong>' . esc_html($svc_name) . '</strong>.</p>',
                            ));
                            
                            if ($post_id) {
                                update_post_meta($post_id, '_service_key', $service_key);
                                update_post_meta($post_id, '_service_name', $svc_name);
                                update_post_meta($post_id, '_parent_service', $parent_name);
                                update_post_meta($post_id, '_service_page', $page_key);
                                update_post_meta($post_id, '_auto_created', '1');
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Delete articles for services that no longer exist
    $all_articles = get_posts(array(
        'post_type' => 'svc_detail_article',
        'post_status' => 'any',
        'posts_per_page' => -1,
        'meta_key' => '_service_key'
    ));
    
    foreach ($all_articles as $article) {
        $service_key = get_post_meta($article->ID, '_service_key', true);
        
        if ($service_key && !isset($current_services[$service_key])) {
            wp_delete_post($article->ID, true);
        }
    }
}

// Run sync when customizer is saved
add_action('customize_save_after', 'ai_quest_sync_service_detail_articles');

// Run sync on init (for initial setup) - SAME AS service_article
function ai_quest_maybe_sync_service_detail_articles() {
    if (get_option('ai_quest_svc_detail_articles_synced', '0') === '0') {
        ai_quest_sync_service_detail_articles();
        update_option('ai_quest_svc_detail_articles_synced', '1');
    }
}
add_action('init', 'ai_quest_maybe_sync_service_detail_articles', 99);

// Prevent manual deletion of auto-created service articles
function ai_quest_prevent_service_article_deletion($post_id) {
    $post = get_post($post_id);
    
    if ($post && $post->post_type === 'service_article') {
        $auto_created = get_post_meta($post_id, '_auto_created', true);
        
        if ($auto_created === '1') {
            wp_die(
                '<h1>Không thể xóa bài viết này</h1>' .
                '<p>Bài viết này được tạo tự động từ dịch vụ con trong Customizer.</p>' .
                '<p>Để xóa bài viết này, bạn cần xóa dịch vụ con tương ứng trong <strong>Customizer → Dịch Vụ</strong>.</p>' .
                '<p><a href="' . admin_url('edit.php?post_type=service_article') . '">← Quay lại danh sách</a></p>',
                'Không thể xóa',
                array('back_link' => true)
            );
        }
    }
}
add_action('before_delete_post', 'ai_quest_prevent_service_article_deletion');

// Add admin notice for auto-created articles
function ai_quest_service_article_admin_notice() {
    $screen = get_current_screen();
    
    if ($screen && $screen->post_type === 'service_article') {
        global $post;
        
        if ($post && get_post_meta($post->ID, '_auto_created', true) === '1') {
            $service_name = get_post_meta($post->ID, '_service_name', true);
            $page_key = get_post_meta($post->ID, '_service_page', true);
            
            echo '<div class="notice notice-info"><p>';
            echo '<strong>📝 Bài viết tự động:</strong> Bài viết này được tạo tự động từ dịch vụ "<strong>' . esc_html($service_name) . '</strong>". ';
            echo 'Bạn có thể chỉnh sửa nội dung nhưng không thể xóa thủ công. ';
            echo 'Để xóa, hãy xóa dịch vụ tương ứng trong Customizer.';
            echo '</p></div>';
        }
    }
}
add_action('admin_notices', 'ai_quest_service_article_admin_notice');

// Hide "Move to Trash" link for auto-created articles
function ai_quest_hide_delete_link_for_service_articles($actions, $post) {
    if ($post->post_type === 'service_article') {
        $auto_created = get_post_meta($post->ID, '_auto_created', true);
        
        if ($auto_created === '1') {
            unset($actions['trash']);
            unset($actions['delete']);
        }
    }
    
    return $actions;
}
add_filter('post_row_actions', 'ai_quest_hide_delete_link_for_service_articles', 10, 2);

// Add meta box to show service info (read-only)
function ai_quest_add_service_info_meta_box() {
    add_meta_box(
        'service_article_info',
        '📋 Thông Tin Dịch Vụ',
        'ai_quest_service_info_meta_box_callback',
        'service_article',
        'side',
        'high'
    );
}
add_action('add_meta_boxes', 'ai_quest_add_service_info_meta_box');

// Meta box callback - display service info
function ai_quest_service_info_meta_box_callback($post) {
    $service_name = get_post_meta($post->ID, '_service_name', true);
    $page_key = get_post_meta($post->ID, '_service_page', true);
    $auto_created = get_post_meta($post->ID, '_auto_created', true);
    
    $page_labels = array(
        'cham-soc-da' => 'Chăm Sóc Da',
        'triet-long' => 'Triệt Lông',
        'goi-dau' => 'Gội Đầu'
    );
    
    $page_label = isset($page_labels[$page_key]) ? $page_labels[$page_key] : $page_key;
    
    ?>
    <div style="padding: 5px 0;">
        <p style="margin: 0 0 10px 0;">
            <strong>Trang dịch vụ:</strong><br>
            <span style="color: #2271b1; font-weight: 600;"><?php echo esc_html($page_label); ?></span>
        </p>
        
        <p style="margin: 0 0 10px 0;">
            <strong>Tên dịch vụ con:</strong><br>
            <span style="color: #2271b1; font-weight: 600;"><?php echo esc_html($service_name); ?></span>
        </p>
        
        <?php if ($auto_created === '1') : ?>
            <p style="margin: 0; padding: 10px; background: #f0f6fc; border-left: 3px solid #2271b1; font-size: 12px;">
                <strong>ℹ️ Lưu ý:</strong> Bài viết này được tạo tự động và đồng bộ với dịch vụ trong Customizer. Không thể xóa thủ công.
            </p>
        <?php endif; ?>
        
        <p style="margin: 15px 0 0 0;">
            <a href="<?php echo admin_url('customize.php?autofocus[section]=ai_quest_svcpage_' . str_replace('-', '_', $page_key)); ?>" 
               class="button button-secondary" 
               style="width: 100%; text-align: center;">
                ⚙️ Chỉnh sửa trong Customizer
            </a>
        </p>
    </div>
    <?php
}

// Get service article URL by service name
function ai_quest_get_service_article_url($service_name, $page_key = '') {
    $service_key = $page_key . '||' . $service_name;
    
    $args = array(
        'post_type' => 'service_article',
        'post_status' => 'publish',
        'posts_per_page' => 1,
        'meta_query' => array(
            array(
                'key' => '_service_key',
                'value' => $service_key,
                'compare' => '='
            )
        )
    );
    
    $query = new WP_Query($args);
    
    if ($query->have_posts()) {
        $query->the_post();
        $url = get_permalink();
        wp_reset_postdata();
        return $url;
    }
    
    return false;
}

// Get service detail article URL by service name
function ai_quest_get_service_detail_article_url($service_name, $parent_service, $page_key) {
    $service_key = $page_key . '||' . $parent_service . '||' . $service_name;
    
    $args = array(
        'post_type' => 'svc_detail_article',
        'post_status' => 'publish',
        'posts_per_page' => 1,
        'meta_query' => array(
            array(
                'key' => '_service_key',
                'value' => $service_key,
                'compare' => '='
            )
        )
    );
    
    $query = new WP_Query($args);
    
    if ($query->have_posts()) {
        $query->the_post();
        $url = get_permalink();
        wp_reset_postdata();
        return $url;
    }
    
    return false;
}

// Get all service detail articles for a parent service
function ai_quest_get_service_detail_articles($parent_service, $page_key) {
    $args = array(
        'post_type' => 'svc_detail_article',
        'post_status' => 'publish',
        'posts_per_page' => -1,
        'orderby' => 'title',
        'order' => 'ASC',
        'meta_query' => array(
            'relation' => 'AND',
            array(
                'key' => '_parent_service',
                'value' => $parent_service,
                'compare' => '='
            ),
            array(
                'key' => '_service_page',
                'value' => $page_key,
                'compare' => '='
            )
        )
    );
    
    $query = new WP_Query($args);
    $articles = array();
    
    if ($query->have_posts()) {
        while ($query->have_posts()) {
            $query->the_post();
            $articles[] = array(
                'id' => get_the_ID(),
                'title' => get_the_title(),
                'url' => get_permalink(),
                'service_name' => get_post_meta(get_the_ID(), '_service_name', true)
            );
        }
        wp_reset_postdata();
    }
    
    return $articles;
}

// Prevent manual deletion of auto-created service detail articles
function ai_quest_prevent_service_detail_article_deletion($post_id) {
    $post = get_post($post_id);
    
    if ($post && $post->post_type === 'svc_detail_article') {
        $auto_created = get_post_meta($post_id, '_auto_created', true);
        
        if ($auto_created === '1') {
            wp_die(
                '<h1>Không thể xóa bài viết này</h1>' .
                '<p>Bài viết này được tạo tự động từ dịch vụ chi tiết trong Customizer.</p>' .
                '<p>Để xóa bài viết này, bạn cần xóa dịch vụ chi tiết tương ứng trong <strong>Customizer → Dịch Vụ</strong>.</p>' .
                '<p><a href="' . admin_url('edit.php?post_type=svc_detail_article') . '">← Quay lại danh sách</a></p>',
                'Không thể xóa',
                array('back_link' => true)
            );
        }
    }
}
add_action('before_delete_post', 'ai_quest_prevent_service_detail_article_deletion');

// Add admin notice for auto-created detail articles
function ai_quest_service_detail_article_admin_notice() {
    $screen = get_current_screen();
    
    if ($screen && $screen->post_type === 'svc_detail_article') {
        global $post;
        
        if ($post && get_post_meta($post->ID, '_auto_created', true) === '1') {
            $service_name = get_post_meta($post->ID, '_service_name', true);
            $parent_service = get_post_meta($post->ID, '_parent_service', true);
            
            echo '<div class="notice notice-info"><p>';
            echo '<strong>📝 Bài viết tự động:</strong> Bài viết này được tạo tự động từ dịch vụ "<strong>' . esc_html($service_name) . '</strong>" ';
            echo 'trong mục "<strong>' . esc_html($parent_service) . '</strong>". ';
            echo 'Bạn có thể chỉnh sửa nội dung nhưng không thể xóa thủ công.';
            echo '</p></div>';
        }
    }
}
add_action('admin_notices', 'ai_quest_service_detail_article_admin_notice');

// Hide "Move to Trash" link for auto-created detail articles
function ai_quest_hide_delete_link_for_service_detail_articles($actions, $post) {
    if ($post->post_type === 'svc_detail_article') {
        $auto_created = get_post_meta($post->ID, '_auto_created', true);
        
        if ($auto_created === '1') {
            unset($actions['trash']);
            unset($actions['delete']);
        }
    }
    
    return $actions;
}
add_filter('post_row_actions', 'ai_quest_hide_delete_link_for_service_detail_articles', 10, 2);

// Add meta box to show service detail info (read-only)
function ai_quest_add_service_detail_info_meta_box() {
    add_meta_box(
        'svc_detail_article_info',
        '📋 Thông Tin Dịch Vụ Chi Tiết',
        'ai_quest_service_detail_info_meta_box_callback',
        'svc_detail_article',
        'side',
        'high'
    );
}
add_action('add_meta_boxes', 'ai_quest_add_service_detail_info_meta_box');

// Meta box callback - display service detail info
function ai_quest_service_detail_info_meta_box_callback($post) {
    $service_name = get_post_meta($post->ID, '_service_name', true);
    $parent_service = get_post_meta($post->ID, '_parent_service', true);
    $page_key = get_post_meta($post->ID, '_service_page', true);
    $auto_created = get_post_meta($post->ID, '_auto_created', true);
    
    $page_labels = array(
        'cham-soc-da' => 'Chăm Sóc Da',
        'triet-long' => 'Triệt Lông',
        'goi-dau' => 'Gội Đầu'
    );
    
    $page_label = isset($page_labels[$page_key]) ? $page_labels[$page_key] : $page_key;
    
    ?>
    <div style="padding: 5px 0;">
        <p style="margin: 0 0 10px 0;">
            <strong>Trang dịch vụ:</strong><br>
            <span style="color: #2271b1; font-weight: 600;"><?php echo esc_html($page_label); ?></span>
        </p>
        
        <p style="margin: 0 0 10px 0;">
            <strong>Mục dịch vụ con:</strong><br>
            <span style="color: #2271b1; font-weight: 600;"><?php echo esc_html($parent_service); ?></span>
        </p>
        
        <p style="margin: 0 0 10px 0;">
            <strong>Tên dịch vụ chi tiết:</strong><br>
            <span style="color: #2271b1; font-weight: 600;"><?php echo esc_html($service_name); ?></span>
        </p>
        
        <?php if ($auto_created === '1') : ?>
            <p style="margin: 0; padding: 10px; background: #f0f6fc; border-left: 3px solid #2271b1; font-size: 12px;">
                <strong>ℹ️ Lưu ý:</strong> Bài viết này được tạo tự động và đồng bộ với dịch vụ trong Customizer. Không thể xóa thủ công.
            </p>
        <?php endif; ?>
        
        <p style="margin: 15px 0 0 0;">
            <a href="<?php echo admin_url('customize.php?autofocus[section]=ai_quest_svcpage_' . str_replace('-', '_', $page_key)); ?>" 
               class="button button-secondary" 
               style="width: 100%; text-align: center;">
                ⚙️ Chỉnh sửa trong Customizer
            </a>
        </p>
    </div>
    <?php
}

// Customize admin columns for article post types
function ai_quest_article_columns($columns) {
    $new_columns = array();
    
    // Reorder columns to show thumbnail and excerpt
    foreach ($columns as $key => $value) {
        if ($key === 'title') {
            $new_columns['thumbnail'] = 'Ảnh Preview';
        }
        $new_columns[$key] = $value;
        if ($key === 'title') {
            $new_columns['excerpt'] = 'Tóm Tắt';
        }
    }
    
    return $new_columns;
}
add_filter('manage_expert_article_posts_columns', 'ai_quest_article_columns');
add_filter('manage_customer_article_posts_columns', 'ai_quest_article_columns');

// Display thumbnail in admin columns
function ai_quest_article_column_content($column, $post_id) {
    if ($column === 'thumbnail') {
        $thumbnail = get_the_post_thumbnail($post_id, array(80, 80));
        if ($thumbnail) {
            echo $thumbnail;
        } else {
            echo '<span style="color:#999;">Chưa có ảnh</span>';
        }
    }
    
    if ($column === 'excerpt') {
        $excerpt = get_the_excerpt($post_id);
        if ($excerpt) {
            echo '<div style="max-width:300px;">' . wp_trim_words($excerpt, 15) . '</div>';
        } else {
            echo '<span style="color:#999;">Chưa có tóm tắt</span>';
        }
    }
}
add_action('manage_expert_article_posts_custom_column', 'ai_quest_article_column_content', 10, 2);
add_action('manage_customer_article_posts_custom_column', 'ai_quest_article_column_content', 10, 2);

// Add helpful text to Featured Image meta box
function ai_quest_featured_image_instruction($content) {
    global $post_type;
    
    if (in_array($post_type, array('expert_article', 'customer_article'))) {
        $content .= '<p style="padding:10px;background:#f0f0f1;margin-top:10px;border-left:4px solid #2271b1;">';
        $content .= '<strong>💡 Hướng dẫn:</strong><br>';
        $content .= 'Ảnh này sẽ hiển thị làm ảnh preview của bài viết trong danh sách.<br>';
        $content .= 'Kích thước đề xuất: <strong>800x600px</strong> hoặc tỷ lệ 4:3';
        $content .= '</p>';
    }
    
    return $content;
}
add_filter('admin_post_thumbnail_html', 'ai_quest_featured_image_instruction');

// Add helpful text to Excerpt meta box
function ai_quest_excerpt_instruction() {
    global $post_type;
    
    if (in_array($post_type, array('expert_article', 'customer_article'))) {
        echo '<p style="padding:10px;background:#f0f0f1;margin-top:10px;border-left:4px solid #2271b1;">';
        echo '<strong>💡 Hướng dẫn:</strong><br>';
        echo 'Đoạn tóm tắt này sẽ hiển thị dưới tiêu đề bài viết trong danh sách.<br>';
        echo 'Độ dài đề xuất: <strong>100-150 ký tự</strong> (khoảng 2-3 câu)';
        echo '</p>';
    }
}
add_action('edit_form_after_title', 'ai_quest_excerpt_instruction');

// Make excerpt box more prominent
function ai_quest_move_excerpt_meta_box() {
    global $post_type;
    
    if (in_array($post_type, array('expert_article', 'customer_article'))) {
        remove_meta_box('postexcerpt', $post_type, 'normal');
        add_meta_box(
            'postexcerpt',
            'Tóm Tắt Bài Viết (Excerpt)',
            'post_excerpt_meta_box',
            $post_type,
            'normal',
            'high'
        );
    }
}
add_action('add_meta_boxes', 'ai_quest_move_excerpt_meta_box');

// Enable Featured Image panel in Gutenberg editor
function ai_quest_enable_featured_image_in_gutenberg() {
    ?>
    <script>
    // Ensure Featured Image panel is visible in Gutenberg
    wp.domReady(function() {
        // Check if we're editing article post types
        const postType = wp.data.select('core/editor').getCurrentPostType();
        
        if (postType === 'expert_article' || postType === 'customer_article') {
            // Open the Featured Image panel by default
            const isEditorSidebarOpened = wp.data.select('core/edit-post').isEditorSidebarOpened();
            
            if (!isEditorSidebarOpened) {
                wp.data.dispatch('core/edit-post').openGeneralSidebar('edit-post/document');
            }
            
            // Enable Featured Image support
            wp.data.dispatch('core/edit-post').enablePublishSidebar();
            
            console.log('✅ Featured Image panel enabled for ' + postType);
        }
    });
    </script>
    <?php
}
add_action('enqueue_block_editor_assets', 'ai_quest_enable_featured_image_in_gutenberg');

// Add custom CSS to make Featured Image more prominent in Gutenberg
function ai_quest_gutenberg_featured_image_styles() {
    global $post_type;
    
    if (in_array($post_type, array('expert_article', 'customer_article'))) {
        ?>
        <style>
            /* Make Featured Image panel more prominent */
            .editor-post-featured-image {
                border: 3px solid #2271b1 !important;
                padding: 16px !important;
                background: #f0f6fc !important;
                border-radius: 8px !important;
                margin-bottom: 20px !important;
            }
            
            .editor-post-featured-image__container {
                margin-bottom: 12px !important;
            }
            
            .editor-post-featured-image__toggle,
            .editor-post-featured-image button {
                width: 100% !important;
                justify-content: center !important;
                height: 40px !important;
                font-size: 14px !important;
                font-weight: 600 !important;
            }
            
            /* Add instruction text */
            .editor-post-featured-image::before {
                content: "💡 Ảnh này sẽ hiển thị làm ảnh preview trong danh sách bài viết. Kích thước đề xuất: 800x600px";
                display: block;
                padding: 12px;
                background: white;
                border-left: 4px solid #2271b1;
                margin-bottom: 16px;
                font-size: 13px;
                line-height: 1.5;
                border-radius: 4px;
            }
            
            /* Make Excerpt panel more prominent */
            .editor-post-excerpt {
                border: 3px solid #2271b1 !important;
                padding: 16px !important;
                background: #f0f6fc !important;
                border-radius: 8px !important;
                margin-bottom: 20px !important;
            }
            
            .editor-post-excerpt::before {
                content: "💡 Đoạn tóm tắt này sẽ hiển thị dưới tiêu đề trong danh sách. Độ dài đề xuất: 100-150 ký tự";
                display: block;
                padding: 12px;
                background: white;
                border-left: 4px solid #2271b1;
                margin-bottom: 16px;
                font-size: 13px;
                line-height: 1.5;
                border-radius: 4px;
            }
            
            .editor-post-excerpt textarea {
                min-height: 100px !important;
                font-size: 14px !important;
            }
            
            /* Highlight the settings button */
            .edit-post-header__settings button[aria-label*="Settings"],
            .edit-post-header__settings button[aria-label*="Cài đặt"] {
                animation: pulse-settings 2s infinite;
            }
            
            @keyframes pulse-settings {
                0%, 100% {
                    box-shadow: 0 0 0 0 rgba(34, 113, 177, 0.4);
                }
                50% {
                    box-shadow: 0 0 0 8px rgba(34, 113, 177, 0);
                }
            }
        </style>
        <?php
    }
}
add_action('admin_head', 'ai_quest_gutenberg_featured_image_styles');

// Add prominent notice to guide users to Featured Image
function ai_quest_featured_image_notice() {
    global $post_type, $pagenow;
    
    if (in_array($post_type, array('expert_article', 'customer_article')) && 
        in_array($pagenow, array('post-new.php', 'post.php'))) {
        ?>
        <div class="notice notice-info is-dismissible" style="margin: 20px 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border: none; color: white; border-radius: 8px;">
            <h2 style="color: white; margin-top: 0; font-size: 18px;">📸 Hướng Dẫn Thêm Ảnh Preview & Tóm Tắt</h2>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 15px;">
                <div style="background: rgba(255,255,255,0.1); padding: 15px; border-radius: 6px; backdrop-filter: blur(10px);">
                    <h3 style="color: white; margin-top: 0; font-size: 16px;">🖼️ Ảnh Preview</h3>
                    <ol style="margin: 10px 0; padding-left: 20px; line-height: 1.8;">
                        <li>Nhìn góc <strong>trên bên phải</strong></li>
                        <li>Click icon <strong>⚙️ Settings</strong> (bánh răng)</li>
                        <li>Sidebar sẽ mở ra bên phải</li>
                        <li>Scroll xuống tìm <strong>"Featured image"</strong></li>
                        <li>Click <strong>"Set featured image"</strong></li>
                    </ol>
                </div>
                <div style="background: rgba(255,255,255,0.1); padding: 15px; border-radius: 6px; backdrop-filter: blur(10px);">
                    <h3 style="color: white; margin-top: 0; font-size: 16px;">📝 Tóm Tắt</h3>
                    <ol style="margin: 10px 0; padding-left: 20px; line-height: 1.8;">
                        <li>Mở sidebar bên phải (icon ⚙️)</li>
                        <li>Tìm tab <strong>"Post"</strong> hoặc <strong>"Bài viết"</strong></li>
                        <li>Scroll xuống tìm <strong>"Excerpt"</strong></li>
                        <li>Nhập đoạn tóm tắt (100-150 ký tự)</li>
                    </ol>
                </div>
            </div>
            <p style="margin: 15px 0 0; font-size: 14px; opacity: 0.9;">
                💡 <strong>Lưu ý:</strong> Nếu không thấy sidebar, click vào icon <strong>⚙️</strong> ở góc trên bên phải màn hình.
            </p>
        </div>
        
        <script>
        jQuery(document).ready(function($) {
            // Auto-open settings sidebar after 2 seconds if not opened
            setTimeout(function() {
                // Check if sidebar is closed
                if (!$('.edit-post-sidebar').is(':visible')) {
                    // Find and click the settings button
                    $('.edit-post-header__settings button[aria-label*="Settings"], .edit-post-header__settings button[aria-label*="Cài đặt"]').first().click();
                    
                    console.log('✅ Auto-opened settings sidebar');
                }
            }, 2000);
        });
        </script>
        <?php
    }
}
add_action('admin_notices', 'ai_quest_featured_image_notice');

// Add custom admin styles for article post types
function ai_quest_article_admin_styles() {
    global $post_type;
    
    if (in_array($post_type, array('expert_article', 'customer_article'))) {
        ?>
        <style>
            /* Make Featured Image box more prominent */
            #postimagediv {
                border: 2px solid #2271b1;
                background: #f6f7f7;
            }
            
            #postimagediv .inside {
                padding: 15px;
            }
            
            #postimagediv .hndle {
                background: #2271b1;
                color: white;
                padding: 12px 15px;
                font-size: 14px;
                font-weight: 600;
            }
            
            /* Make Excerpt box more prominent */
            #postexcerpt {
                border: 2px solid #2271b1;
                background: #f6f7f7;
            }
            
            #postexcerpt .inside {
                padding: 15px;
            }
            
            #postexcerpt .hndle {
                background: #2271b1;
                color: white;
                padding: 12px 15px;
                font-size: 14px;
                font-weight: 600;
            }
            
            #excerpt {
                width: 100%;
                min-height: 100px;
                font-size: 14px;
                padding: 10px;
                border: 1px solid #8c8f94;
                border-radius: 4px;
            }
            
            /* Highlight required fields */
            .editor-post-title__input,
            #title {
                border: 2px solid #2271b1 !important;
            }
            
            /* Admin columns styling */
            .column-thumbnail img {
                border-radius: 4px;
                border: 1px solid #ddd;
            }
            
            .column-excerpt {
                color: #50575e;
                line-height: 1.5;
            }
            
            /* Help text styling */
            .article-help-text {
                background: #e7f5fe;
                border-left: 4px solid #2271b1;
                padding: 12px 15px;
                margin: 15px 0;
                border-radius: 0 4px 4px 0;
            }
            
            .article-help-text strong {
                color: #2271b1;
                display: block;
                margin-bottom: 5px;
            }
        </style>
        <?php
    }
}
add_action('admin_head', 'ai_quest_article_admin_styles');

// Helper function to generate pretty URLs with parent-child structure
function ai_quest_page_url($page_slug, $args = array()) {
    // Define parent-child relationships
    $hierarchy = array(
        // Service pages (children of dich-vu)
        'cham-soc-da' => 'dich-vu',
        'triet-long' => 'dich-vu',
        'goi-dau' => 'dich-vu',
        'tat-ca-dich-vu' => 'dich-vu',
        
        // Sharing pages (children of chia-se)
        'tu-chuyen-gia' => 'chia-se',
        'tu-khach-hang' => 'chia-se',
    );
    
    // Build URL with parent if exists
    if (isset($hierarchy[$page_slug])) {
        $url = home_url('/' . $hierarchy[$page_slug] . '/' . $page_slug . '/');
    } else {
        $url = home_url('/' . $page_slug . '/');
    }
    
    // Add query parameters if provided
    if (!empty($args)) {
        $url = add_query_arg($args, $url);
    }
    
    return $url;
}


function ai_quest_customizer_preview_js() {
    $promo_url    = add_query_arg('aiq_page', 'khuyen-mai', home_url('/'));
    $home_url     = home_url('/');
    ?>
    <script>
    (function() {
        var promoUrl = <?php echo wp_json_encode($promo_url); ?>;
        var homeUrl  = <?php echo wp_json_encode($home_url); ?>;
        var _activeSection = null;

        wp.customize.bind('ready', function() {
            // Theo dõi section nào đang active
            wp.customize.section.each(function(section) {
                section.expanded.bind(function(isExpanded) {
                    if (isExpanded) {
                        _activeSection = section.id;
                    }
                });
            });

            // Khi section Promotions mở, navigate preview đến trang khuyến mãi
            wp.customize.section('ai_quest_promotions_options', function(section) {
                section.expanded.bind(function(isExpanded) {
                    if (isExpanded) {
                        wp.customize.previewer.previewUrl.set(promoUrl);
                    }
                });
            });

            // Sau mỗi lần previewer refresh, nếu đang ở section Promotions thì giữ URL
            wp.customize.previewer.bind('refresh', function() {
                if (_activeSection === 'ai_quest_promotions_options') {
                    wp.customize.previewer.previewUrl.set(promoUrl);
                }
            });
        });
    }());
    </script>
    <?php
}
add_action('customize_controls_print_footer_scripts', 'ai_quest_customizer_preview_js');


// ============================================================
// Supabase Integration Settings
// ============================================================

function ai_quest_seed_supabase_defaults() {
    if (get_option('aiq_seeded_supabase_v1', '0') === '1') return;
    // These are set to the app's Supabase project - update store_id after running SQL migration
    update_option('ai_quest_supabase_url', 'https://cgqxrsoaxgyvcskbixuu.supabase.co');
    update_option('ai_quest_supabase_anon_key', 'sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh');
    update_option('ai_quest_store_id', ''); // Set this to your store UUID from the stores table
    update_option('aiq_seeded_supabase_v1', '1');
}
add_action('init', 'ai_quest_seed_supabase_defaults', 12);

function ai_quest_register_supabase_customizer($wp_customize) {
    $wp_customize->add_section('ai_quest_supabase_options', array(
        'title'    => __('Tích Hợp Supabase', 'ai-quest'),
        'priority' => 99,
    ));

    $wp_customize->add_setting('ai_quest_supabase_url', array(
        'default'           => 'https://cgqxrsoaxgyvcskbixuu.supabase.co',
        'sanitize_callback' => 'esc_url_raw',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_supabase_url', array(
        'label'       => __('Supabase Project URL', 'ai-quest'),
        'description' => __('e.g. https://xxxx.supabase.co', 'ai-quest'),
        'section'     => 'ai_quest_supabase_options',
        'type'        => 'text',
    ));

    $wp_customize->add_setting('ai_quest_supabase_anon_key', array(
        'default'           => '',
        'sanitize_callback' => 'sanitize_text_field',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_supabase_anon_key', array(
        'label'       => __('Supabase Anon Key', 'ai-quest'),
        'description' => __('Public anon key (safe for frontend)', 'ai-quest'),
        'section'     => 'ai_quest_supabase_options',
        'type'        => 'text',
    ));

    $wp_customize->add_setting('ai_quest_store_id', array(
        'default'           => '',
        'sanitize_callback' => 'sanitize_text_field',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_store_id', array(
        'label'       => __('Store UUID', 'ai-quest'),
        'description' => __('UUID of the store from the stores table in Supabase', 'ai-quest'),
        'section'     => 'ai_quest_supabase_options',
        'type'        => 'text',
    ));

    // Partner CTA text
    $wp_customize->add_setting('ai_quest_partner_cta_text', array(
        'default'           => 'Trở thành đối tác của Henie Skinlab',
        'sanitize_callback' => 'sanitize_text_field',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_partner_cta_text', array(
        'label'       => __('Partner CTA Button Text', 'ai-quest'),
        'description' => __('Text hiển thị trên button đăng ký đối tác', 'ai-quest'),
        'section'     => 'ai_quest_supabase_options',
        'type'        => 'text',
    ));
}
add_action('customize_register', 'ai_quest_register_supabase_customizer');

// ============================================
// Sharing Pages Hero Images
// ============================================

function ai_quest_register_sharing_hero_customizer($wp_customize) {
    // Add section
    $wp_customize->add_section('ai_quest_sharing_hero_options', array(
        'title'    => __('Ảnh Hero - Trang Chia Sẻ', 'ai-quest'),
        'priority' => 45,
    ));

    // Expert Articles Hero Image URL
    $wp_customize->add_setting('ai_quest_expert_hero_image', array(
        'default'           => '',
        'sanitize_callback' => 'esc_url_raw',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_expert_hero_image', array(
        'label'       => __('URL Ảnh Hero - Từ Chuyên Gia', 'ai-quest'),
        'description' => __('Dán URL ảnh hero. Kích thước đề xuất: 1920x400px', 'ai-quest'),
        'section'     => 'ai_quest_sharing_hero_options',
        'type'        => 'url',
        'settings'    => 'ai_quest_expert_hero_image',
    ));

    // Customer Articles Hero Image URL
    $wp_customize->add_setting('ai_quest_customer_hero_image', array(
        'default'           => '',
        'sanitize_callback' => 'esc_url_raw',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_customer_hero_image', array(
        'label'       => __('URL Ảnh Hero - Từ Khách Hàng', 'ai-quest'),
        'description' => __('Dán URL ảnh hero. Kích thước đề xuất: 1920x400px', 'ai-quest'),
        'section'     => 'ai_quest_sharing_hero_options',
        'type'        => 'url',
        'settings'    => 'ai_quest_customer_hero_image',
    ));

    // Expert Hero Title
    $wp_customize->add_setting('ai_quest_expert_hero_title', array(
        'default'           => 'Từ Chuyên Gia',
        'sanitize_callback' => 'sanitize_text_field',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_expert_hero_title', array(
        'label'       => __('Tiêu Đề Hero - Từ Chuyên Gia', 'ai-quest'),
        'section'     => 'ai_quest_sharing_hero_options',
        'type'        => 'text',
    ));

    // Expert Hero Subtitle
    $wp_customize->add_setting('ai_quest_expert_hero_subtitle', array(
        'default'           => 'Kiến thức và kinh nghiệm từ các chuyên gia làm đẹp hàng đầu',
        'sanitize_callback' => 'sanitize_text_field',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_expert_hero_subtitle', array(
        'label'       => __('Mô Tả Hero - Từ Chuyên Gia', 'ai-quest'),
        'section'     => 'ai_quest_sharing_hero_options',
        'type'        => 'text',
    ));

    // Customer Hero Title
    $wp_customize->add_setting('ai_quest_customer_hero_title', array(
        'default'           => 'Từ Khách Hàng',
        'sanitize_callback' => 'sanitize_text_field',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_customer_hero_title', array(
        'label'       => __('Tiêu Đề Hero - Từ Khách Hàng', 'ai-quest'),
        'section'     => 'ai_quest_sharing_hero_options',
        'type'        => 'text',
    ));

    // Customer Hero Subtitle
    $wp_customize->add_setting('ai_quest_customer_hero_subtitle', array(
        'default'           => 'Trải nghiệm và chia sẻ thực tế từ khách hàng của Henie Skinlab',
        'sanitize_callback' => 'sanitize_text_field',
        'type'              => 'option',
    ));
    $wp_customize->add_control('ai_quest_customer_hero_subtitle', array(
        'label'       => __('Mô Tả Hero - Từ Khách Hàng', 'ai-quest'),
        'section'     => 'ai_quest_sharing_hero_options',
        'type'        => 'text',
    ));
}
add_action('customize_register', 'ai_quest_register_sharing_hero_customizer');


// ============================================
// Force HTTPS for Image URLs Only (Safe Version)
// ============================================

// Force HTTPS for attachment URLs (images, media) - only when displaying
add_filter('wp_get_attachment_url', 'ai_quest_force_https_images', 999);
add_filter('wp_get_attachment_image_src', 'ai_quest_force_https_image_src', 999);

function ai_quest_force_https_images($url) {
    if (!empty($url) && is_string($url)) {
        // Only convert URLs from this domain
        if (strpos($url, 'henieskinlab.com') !== false) {
            $url = str_replace('http://', 'https://', $url);
        }
    }
    return $url;
}

function ai_quest_force_https_image_src($image) {
    if (is_array($image) && isset($image[0])) {
        if (strpos($image[0], 'henieskinlab.com') !== false) {
            $image[0] = str_replace('http://', 'https://', $image[0]);
        }
    }
    return $image;
}

// Force HTTPS for upload directory URLs
add_filter('upload_dir', 'ai_quest_force_https_upload_dir', 999);

function ai_quest_force_https_upload_dir($uploads) {
    if (isset($uploads['url']) && strpos($uploads['url'], 'henieskinlab.com') !== false) {
        $uploads['url'] = str_replace('http://', 'https://', $uploads['url']);
    }
    if (isset($uploads['baseurl']) && strpos($uploads['baseurl'], 'henieskinlab.com') !== false) {
        $uploads['baseurl'] = str_replace('http://', 'https://', $uploads['baseurl']);
    }
    return $uploads;
}

// Force HTTPS for srcset attributes
add_filter('wp_calculate_image_srcset', 'ai_quest_force_https_srcset', 999);

function ai_quest_force_https_srcset($sources) {
    if (is_array($sources)) {
        foreach ($sources as &$source) {
            if (isset($source['url']) && strpos($source['url'], 'henieskinlab.com') !== false) {
                $source['url'] = str_replace('http://', 'https://', $source['url']);
            }
        }
    }
    return $sources;
}

// Force HTTPS for content images only
add_filter('the_content', 'ai_quest_force_https_content_images', 999);

function ai_quest_force_https_content_images($content) {
    if (is_string($content)) {
        // Only replace image URLs in content
        $content = preg_replace(
            '#(src|href)=["\']http://henieskinlab\.com/wp-content/uploads/([^"\']+)["\']#i',
            '$1="https://henieskinlab.com/wp-content/uploads/$2"',
            $content
        );
    }
    return $content;
}


// ===================================
// Feedback System
// ===================================

// Create feedback table on theme activation
function ai_quest_create_feedback_table() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'feedback';
    $charset_collate = $wpdb->get_charset_collate();
    
    $sql = "CREATE TABLE IF NOT EXISTS $table_name (
        id bigint(20) NOT NULL AUTO_INCREMENT,
        message text NOT NULL,
        ip_address varchar(100) DEFAULT '',
        user_agent text DEFAULT '',
        created_at datetime DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY  (id),
        KEY created_at (created_at)
    ) $charset_collate;";
    
    require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
    dbDelta($sql);
}
add_action('after_switch_theme', 'ai_quest_create_feedback_table');

// AJAX handler for feedback submission
function ai_quest_submit_feedback() {
    // Verify nonce
    if (!isset($_POST['nonce']) || !wp_verify_nonce($_POST['nonce'], 'ai-quest-nonce')) {
        wp_send_json_error('Invalid security token');
        return;
    }
    
    // Get and sanitize message
    $message = isset($_POST['message']) ? sanitize_textarea_field($_POST['message']) : '';
    
    if (empty($message)) {
        wp_send_json_error('Vui lòng nhập nội dung góp ý');
        return;
    }
    
    if (strlen($message) > 500) {
        wp_send_json_error('Nội dung góp ý không được vượt quá 500 ký tự');
        return;
    }
    
    // Get user info
    $ip_address = $_SERVER['REMOTE_ADDR'] ?? '';
    $user_agent = $_SERVER['HTTP_USER_AGENT'] ?? '';
    
    // Insert into database
    global $wpdb;
    $table_name = $wpdb->prefix . 'feedback';
    
    $result = $wpdb->insert(
        $table_name,
        array(
            'message' => $message,
            'ip_address' => $ip_address,
            'user_agent' => $user_agent,
            'created_at' => current_time('mysql')
        ),
        array('%s', '%s', '%s', '%s')
    );
    
    if ($result === false) {
        wp_send_json_error('Có lỗi xảy ra khi lưu góp ý. Vui lòng thử lại sau.');
        return;
    }
    
    wp_send_json_success('Góp ý đã được gửi thành công');
}
add_action('wp_ajax_submit_feedback', 'ai_quest_submit_feedback');
add_action('wp_ajax_nopriv_submit_feedback', 'ai_quest_submit_feedback');

// Admin menu to view feedback
function ai_quest_feedback_admin_menu() {
    add_menu_page(
        'Góp Ý',
        'Góp Ý',
        'manage_options',
        'ai-quest-feedback',
        'ai_quest_feedback_admin_page',
        'dashicons-feedback',
        30
    );
}
add_action('admin_menu', 'ai_quest_feedback_admin_menu');

// Admin page to display feedback
function ai_quest_feedback_admin_page() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'feedback';
    
    // Handle delete action
    if (isset($_GET['action']) && $_GET['action'] === 'delete' && isset($_GET['id'])) {
        $id = intval($_GET['id']);
        $wpdb->delete($table_name, array('id' => $id), array('%d'));
        echo '<div class="notice notice-success"><p>Đã xóa góp ý thành công.</p></div>';
    }
    
    // Get all feedback
    $feedbacks = $wpdb->get_results("SELECT * FROM $table_name ORDER BY created_at DESC");
    
    ?>
    <div class="wrap">
        <h1>Góp Ý Từ Khách Hàng</h1>
        
        <?php if (empty($feedbacks)) : ?>
            <p>Chưa có góp ý nào.</p>
        <?php else : ?>
            <table class="wp-list-table widefat fixed striped">
                <thead>
                    <tr>
                        <th style="width: 60px;">ID</th>
                        <th>Nội Dung</th>
                        <th style="width: 150px;">IP Address</th>
                        <th style="width: 180px;">Thời Gian</th>
                        <th style="width: 100px;">Hành Động</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($feedbacks as $feedback) : ?>
                        <tr>
                            <td><?php echo esc_html($feedback->id); ?></td>
                            <td><?php echo esc_html($feedback->message); ?></td>
                            <td><?php echo esc_html($feedback->ip_address); ?></td>
                            <td><?php echo esc_html($feedback->created_at); ?></td>
                            <td>
                                <a href="?page=ai-quest-feedback&action=delete&id=<?php echo esc_attr($feedback->id); ?>" 
                                   class="button button-small" 
                                   onclick="return confirm('Bạn có chắc muốn xóa góp ý này?')">
                                    Xóa
                                </a>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
    <?php
}


// ===================================
// Auto Featured Image from Content
// ===================================

// Automatically set featured image from first image in content if not set
function ai_quest_auto_set_featured_image($post_id) {
    // Prevent infinite loops
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
        return;
    }
    
    // Check user permissions
    if (!current_user_can('edit_post', $post_id)) {
        return;
    }
    
    // Only for our custom post types
    $post_type = get_post_type($post_id);
    if (!in_array($post_type, array('expert_article', 'customer_article'))) {
        return;
    }
    
    // Check if post already has a featured image
    if (has_post_thumbnail($post_id)) {
        return;
    }
    
    // Get post content
    $post = get_post($post_id);
    if (!$post) {
        return;
    }
    
    $content = $post->post_content;
    
    // Find first image in content
    preg_match_all('/<img[^>]+src=[\'"]([^\'"]+)[\'"][^>]*>/i', $content, $matches);
    
    if (!empty($matches[1][0])) {
        $image_url = $matches[1][0];
        
        // Check if it's a WordPress attachment (already in Media Library)
        $attachment_id = attachment_url_to_postid($image_url);
        
        if ($attachment_id) {
            // It's a WordPress attachment, set it as featured image
            set_post_thumbnail($post_id, $attachment_id);
        }
        // DO NOT download external images - this causes "Update failed" errors
        // Users should upload images to Media Library first or use ImgBB plugin
    }
}
add_action('save_post', 'ai_quest_auto_set_featured_image', 20);

// Remove featured image from content to avoid duplication
function ai_quest_remove_featured_image_from_content($content) {
    // Only on single post pages for our custom post types
    if (!is_singular(array('expert_article', 'customer_article'))) {
        return $content;
    }
    
    // Get the featured image ID
    $thumbnail_id = get_post_thumbnail_id();
    
    if (!$thumbnail_id) {
        return $content;
    }
    
    // Get the featured image URL
    $thumbnail_url = wp_get_attachment_url($thumbnail_id);
    
    if (!$thumbnail_url) {
        return $content;
    }
    
    // Get different sizes of the featured image
    $thumbnail_sizes = array('thumbnail', 'medium', 'medium_large', 'large', 'full');
    $urls_to_remove = array($thumbnail_url);
    
    foreach ($thumbnail_sizes as $size) {
        $image_data = wp_get_attachment_image_src($thumbnail_id, $size);
        if ($image_data) {
            $urls_to_remove[] = $image_data[0];
        }
    }
    
    // Remove all instances of the featured image from content
    foreach ($urls_to_remove as $url) {
        // Escape special characters in URL for regex
        $escaped_url = preg_quote($url, '/');
        
        // Remove img tags containing this URL
        $content = preg_replace(
            '/<p[^>]*>\s*<img[^>]+src=[\'"]' . $escaped_url . '[\'"][^>]*>\s*<\/p>/i',
            '',
            $content
        );
        
        $content = preg_replace(
            '/<img[^>]+src=[\'"]' . $escaped_url . '[\'"][^>]*>/i',
            '',
            $content
        );
        
        // Remove figure tags (Gutenberg image blocks)
        $content = preg_replace(
            '/<figure[^>]*>.*?<img[^>]+src=[\'"]' . $escaped_url . '[\'"][^>]*>.*?<\/figure>/is',
            '',
            $content
        );
    }
    
    // Clean up empty paragraphs
    $content = preg_replace('/<p>\s*<\/p>/i', '', $content);
    
    return $content;
}
add_filter('the_content', 'ai_quest_remove_featured_image_from_content', 20);


// ===================================
// Bulk Update Featured Images for Existing Posts
// ===================================

// Add admin notice with button to update all posts
function ai_quest_featured_image_admin_notice() {
    $screen = get_current_screen();
    if ($screen && in_array($screen->post_type, array('expert_article', 'customer_article'))) {
        ?>
        <div class="notice notice-info">
            <p>
                <strong>Cập nhật ảnh preview tự động:</strong> 
                Nhấn nút bên dưới để tự động set ảnh preview cho tất cả bài viết chưa có ảnh preview.
            </p>
            <p>
                <button type="button" class="button button-primary" id="ai-quest-update-featured-images">
                    Cập nhật ảnh preview cho tất cả bài viết
                </button>
                <span id="ai-quest-update-status" style="margin-left: 10px;"></span>
            </p>
        </div>
        <script>
        jQuery(document).ready(function($) {
            $('#ai-quest-update-featured-images').on('click', function() {
                var btn = $(this);
                var status = $('#ai-quest-update-status');
                
                btn.prop('disabled', true);
                status.html('<span style="color: #0073aa;">Đang xử lý...</span>');
                
                $.ajax({
                    url: ajaxurl,
                    type: 'POST',
                    data: {
                        action: 'ai_quest_bulk_update_featured_images',
                        nonce: '<?php echo wp_create_nonce('ai_quest_bulk_update'); ?>'
                    },
                    success: function(response) {
                        if (response.success) {
                            status.html('<span style="color: #46b450;">✓ ' + response.data + '</span>');
                            setTimeout(function() {
                                location.reload();
                            }, 2000);
                        } else {
                            status.html('<span style="color: #dc3232;">✗ ' + response.data + '</span>');
                            btn.prop('disabled', false);
                        }
                    },
                    error: function() {
                        status.html('<span style="color: #dc3232;">✗ Có lỗi xảy ra</span>');
                        btn.prop('disabled', false);
                    }
                });
            });
        });
        </script>
        <?php
    }
}
add_action('admin_notices', 'ai_quest_featured_image_admin_notice');

// AJAX handler to bulk update featured images
function ai_quest_bulk_update_featured_images_ajax() {
    // Verify nonce
    if (!isset($_POST['nonce']) || !wp_verify_nonce($_POST['nonce'], 'ai_quest_bulk_update')) {
        wp_send_json_error('Invalid security token');
        return;
    }
    
    // Check permissions
    if (!current_user_can('edit_posts')) {
        wp_send_json_error('Bạn không có quyền thực hiện thao tác này');
        return;
    }
    
    // Get all posts without featured image
    $args = array(
        'post_type' => array('expert_article', 'customer_article'),
        'posts_per_page' => -1,
        'post_status' => 'any',
        'meta_query' => array(
            'relation' => 'OR',
            array(
                'key' => '_thumbnail_id',
                'compare' => 'NOT EXISTS'
            ),
            array(
                'key' => '_thumbnail_id',
                'value' => '',
                'compare' => '='
            )
        )
    );
    
    $posts = get_posts($args);
    $updated_count = 0;
    
    foreach ($posts as $post) {
        // Get post content
        $content = $post->post_content;
        
        // Find first image in content
        preg_match_all('/<img[^>]+src=[\'"]([^\'"]+)[\'"][^>]*>/i', $content, $matches);
        
        if (!empty($matches[1][0])) {
            $image_url = $matches[1][0];
            
            // Check if it's an attachment
            $attachment_id = attachment_url_to_postid($image_url);
            
            if ($attachment_id) {
                set_post_thumbnail($post->ID, $attachment_id);
                $updated_count++;
            } else {
                // Try to download external image
                require_once(ABSPATH . 'wp-admin/includes/media.php');
                require_once(ABSPATH . 'wp-admin/includes/file.php');
                require_once(ABSPATH . 'wp-admin/includes/image.php');
                
                $upload = media_sideload_image($image_url, $post->ID, null, 'id');
                if (!is_wp_error($upload)) {
                    set_post_thumbnail($post->ID, $upload);
                    $updated_count++;
                }
            }
        }
    }
    
    if ($updated_count > 0) {
        wp_send_json_success("Đã cập nhật ảnh preview cho {$updated_count} bài viết");
    } else {
        wp_send_json_success("Không có bài viết nào cần cập nhật");
    }
}
add_action('wp_ajax_ai_quest_bulk_update_featured_images', 'ai_quest_bulk_update_featured_images_ajax');

// ===================================
// Header Menu Customizer
// ===================================
function ai_quest_register_header_customizer($wp_customize) {
    // Add Header panel
    $wp_customize->add_panel('ai_quest_header_panel', array(
        'title'    => __('Header', 'ai-quest'),
        'priority' => 20, // Đặt ở trên cùng
    ));
    
    // ===================================
    // Section: Logo
    // ===================================
    $wp_customize->add_section('ai_quest_header_logo', array(
        'title'    => __('Logo', 'ai-quest'),
        'panel'    => 'ai_quest_header_panel',
        'priority' => 5,
    ));
    
    // Move logo from Site Identity to Header
    $wp_customize->get_control('custom_logo')->section = 'ai_quest_header_logo';
    $wp_customize->get_control('custom_logo')->priority = 1;
    
    // Add logo URL field
    $wp_customize->add_setting('ai_quest_logo_url', array(
        'default'           => '',
        'sanitize_callback' => 'esc_url_raw',
        'transport'         => 'refresh',
    ));
    
    $wp_customize->add_control('ai_quest_logo_url', array(
        'label'       => __('Logo URL', 'ai-quest'),
        'description' => __('Nhập URL cho logo (để trống sẽ dùng URL mặc định từ upload). Hỗ trợ ImgBB và các URL khác.', 'ai-quest'),
        'section'     => 'ai_quest_header_logo',
        'type'        => 'url',
        'priority'    => 2,
    ));
    
    // ===================================
    // Section: Menu Items
    // ===================================
    $wp_customize->add_section('ai_quest_header_menu', array(
        'title'    => __('Mục Menu', 'ai-quest'),
        'panel'    => 'ai_quest_header_panel',
        'priority' => 10,
    ));
    
    // ===================================
    // Section: Phone Numbers
    // ===================================
    $wp_customize->add_section('ai_quest_header_phones', array(
        'title'    => __('Số Điện Thoại', 'ai-quest'),
        'panel'    => 'ai_quest_header_panel',
        'priority' => 15,
        'description' => __('Quản lý số điện thoại hiển thị trên header. Nếu có từ 2 cơ sở trở lên, sẽ hiển thị "CƠ SỞ X:" ở trước mỗi số.', 'ai-quest'),
    ));
    
    // Add phone number fields for up to 5 locations
    for ($i = 1; $i <= 5; $i++) {
        $wp_customize->add_setting('ai_quest_header_phone_' . $i, array(
            'default'           => ($i === 1) ? '096 235 94 65' : '',
            'sanitize_callback' => 'sanitize_text_field',
            'transport'         => 'refresh',
        ));
        
        $wp_customize->add_control('ai_quest_header_phone_' . $i, array(
            'label'       => sprintf(__('Số Điện Thoại Cơ Sở %d', 'ai-quest'), $i),
            'description' => ($i === 1) ? __('Số điện thoại chính (bắt buộc)', 'ai-quest') : __('Để trống nếu không có cơ sở này', 'ai-quest'),
            'section'     => 'ai_quest_header_phones',
            'type'        => 'text',
            'priority'    => $i,
        ));
    }
    
    // Define menu items
    $menu_items = array(
        'trang_chu' => array(
            'label' => 'Trang Chủ',
            'default_text' => 'Henie Skinlab',
            'order' => 0
        ),
        'gioi_thieu' => array(
            'label' => 'Giới Thiệu',
            'default_text' => 'Giới Thiệu',
            'order' => 1
        ),
        'dich_vu' => array(
            'label' => 'Dịch Vụ',
            'default_text' => 'Dịch Vụ',
            'order' => 2
        ),
        'bang_gia' => array(
            'label' => 'Bảng Giá',
            'default_text' => 'Bảng Giá',
            'order' => 3
        ),
        'khuyen_mai' => array(
            'label' => 'Khuyến Mãi',
            'default_text' => 'Khuyến Mãi',
            'order' => 4
        ),
        'doi_tac' => array(
            'label' => 'Đối Tác',
            'default_text' => 'Đối Tác',
            'order' => 5
        ),
        'chia_se' => array(
            'label' => 'Chia Sẻ',
            'default_text' => 'Chia Sẻ',
            'order' => 6
        ),
        'tu_van' => array(
            'label' => 'Tư Vấn',
            'default_text' => 'Tư Vấn',
            'order' => 7
        ),
        'dat_lich' => array(
            'label' => 'Đặt Lịch',
            'default_text' => 'ĐẶT LỊCH',
            'order' => 8
        ),
    );
    
    foreach ($menu_items as $key => $item) {
        // Note for fixed items
        $description = '';
        if ($key === 'trang_chu') {
            $description = 'Tab này luôn hiển thị ở vị trí đầu tiên (bên trái logo)';
        } elseif ($key === 'dat_lich') {
            $description = 'Tab này luôn hiển thị ở vị trí cuối cùng (bên phải)';
        }
        
        // Checkbox to show/hide (except for trang_chu and dat_lich - always visible)
        if (!in_array($key, array('trang_chu', 'dat_lich'))) {
            $wp_customize->add_setting('ai_quest_header_' . $key . '_visible', array(
                'default'           => true,
                'sanitize_callback' => 'ai_quest_sanitize_checkbox',
                'transport'         => 'refresh',
            ));
            
            $wp_customize->add_control('ai_quest_header_' . $key . '_visible', array(
                'label'       => sprintf(__('Hiển thị "%s"', 'ai-quest'), $item['label']),
                'section'     => 'ai_quest_header_menu',
                'type'        => 'checkbox',
                'priority'    => $item['order'] * 10,
                'description' => $description,
            ));
        }
        
        // Text input to change label
        $wp_customize->add_setting('ai_quest_header_' . $key . '_text', array(
            'default'           => $item['default_text'],
            'sanitize_callback' => 'sanitize_text_field',
            'transport'         => 'refresh',
        ));
        
        $wp_customize->add_control('ai_quest_header_' . $key . '_text', array(
            'label'       => sprintf(__('Tên hiển thị "%s"', 'ai-quest'), $item['label']),
            'section'     => 'ai_quest_header_menu',
            'type'        => 'text',
            'priority'    => $item['order'] * 10 + 1,
            'description' => $description,
        ));
    }
}
add_action('customize_register', 'ai_quest_register_header_customizer');

// Helper function to get menu item visibility
function ai_quest_is_menu_visible($item_key) {
    // Trang chủ và Đặt lịch luôn hiển thị
    if (in_array($item_key, array('trang_chu', 'dat_lich'))) {
        return true;
    }
    $visible = get_theme_mod('ai_quest_header_' . $item_key . '_visible', true);
    // Convert to boolean - handle both string and int values
    return !empty($visible) && $visible !== '0' && $visible !== 0;
}

// Helper function to get menu item text
function ai_quest_get_menu_text($item_key, $default = '') {
    $text = get_theme_mod('ai_quest_header_' . $item_key . '_text', $default);
    return !empty($text) ? $text : $default;
}

// Helper function to get logo URL
function ai_quest_get_logo_url() {
    // Check if custom URL is set
    $custom_url = get_theme_mod('ai_quest_logo_url', '');
    if (!empty($custom_url)) {
        return esc_url($custom_url);
    }
    
    // Fallback to uploaded logo
    $custom_logo_id = get_theme_mod('custom_logo');
    if ($custom_logo_id) {
        $logo_url = wp_get_attachment_image_url($custom_logo_id, 'full');
        if ($logo_url) {
            return esc_url($logo_url);
        }
    }
    
    // No logo set
    return '';
}

// Helper function to get phone numbers
function ai_quest_get_header_phones() {
    $phones = array();
    
    for ($i = 1; $i <= 5; $i++) {
        $phone = trim(get_theme_mod('ai_quest_header_phone_' . $i, ''));
        if (!empty($phone)) {
            $phones[] = $phone;
        }
    }
    
    return $phones;
}

// Helper function to format phone display
function ai_quest_format_phone_display($phones) {
    if (empty($phones)) {
        return '';
    }
    
    // If only 1 phone, display without prefix
    if (count($phones) === 1) {
        return esc_html($phones[0]);
    }
    
    // If 2 or more phones, add "CƠ SỞ X:" prefix and separate with bullet
    $formatted = array();
    foreach ($phones as $index => $phone) {
        $formatted[] = 'CƠ SỞ ' . ($index + 1) . ': ' . esc_html($phone);
    }
    
    return implode(' <span class="topbar-sep">•</span> ', $formatted);
}
