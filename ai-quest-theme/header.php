<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
    <?php wp_body_open(); ?>
    
    <?php
    $locations_time_text = ai_quest_get_setting('ai_quest_locations_time_text', 'Thứ Hai đến Chủ Nhật: 9:00 Sáng - 20:00 Tối');
    $locations_hotline = ai_quest_get_setting('ai_quest_locations_hotline', '096 235 94 65');
    $locations_facebook_url = ai_quest_get_setting('ai_quest_locations_social_facebook_url', '#');
    $locations_instagram_url = ai_quest_get_setting('ai_quest_locations_social_instagram_url', '#');
    $locations_tiktok_url = ai_quest_get_setting('ai_quest_locations_social_tiktok_url', '#');
    $locations_youtube_url = ai_quest_get_setting('ai_quest_locations_social_youtube_url', '#');
    $location_1_title = ai_quest_get_setting('ai_quest_location_1_title', 'Bình Thạnh, TP.HCM');
    $location_1_address = ai_quest_get_setting('ai_quest_location_1_address', '21/5D, Bình Lợi, Bình Lợi Trung, Hồ Chí Minh 700000, Việt Nam');
    $location_1_map_embed_url = ai_quest_get_setting('ai_quest_location_1_map_embed_url', 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3918.8028344097156!2d106.70298361125364!3d10.82639548928088!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x31752900161e84f1%3A0xf3284fbaaba2ba2e!2zSGVuaWUgU2tpbmxhYiAtIFNwYSBDaMSDbSBTw7NjIERhIELDrG5oIFRo4bqhbmg!5e0!3m2!1svi!2s!4v1776057224603!5m2!1svi!2s');
    $location_1_maps_url = ai_quest_get_setting('ai_quest_location_1_maps_url', 'https://www.google.com/maps?cid=17521342013446994478&g_mp=CiVnb29nbGUubWFwcy5wbGFjZXMudjEuUGxhY2VzLkdldFBsYWNlEAIYASAA&hl=vi&source=embed');
    $location_2_title = ai_quest_get_setting('ai_quest_location_2_title', 'Lái Thiêu, TP.HCM');
    $location_2_address = ai_quest_get_setting('ai_quest_location_2_address', '188 3 Tháng 2, KP Đông Tư, Lái Thiêu, Hồ Chí Minh, Việt Nam');
    $location_2_map_embed_url = ai_quest_get_setting('ai_quest_location_2_map_embed_url', 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3917.6413645801354!2d106.69925931125468!3d10.914836689197623!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3174d9b18a1694d7%3A0x9981a3fbd49ef74!2zSGVuaWUgU2tpbmxhYiAtIFNwYSBDaMSDbSBTw7NjIERhIEzDoWkgVGhpw6p1!5e0!3m2!1svi!2s!4v1776057284562!5m2!1svi!2s');
    $location_2_maps_url = ai_quest_get_setting('ai_quest_location_2_maps_url', 'https://www.google.com/maps/place/Henie+Skinlab+-+Spa+Ch%C4%83m+S%C3%B3c+Da+L%C3%A1i+Thi%C3%AAu/@10.9148367,106.7018396,17z/data=!3m1!4b1!4m6!3m5!1s0x3174d9b18a1694d7:0x9981a3fbd49ef74!8m2!3d10.9148367!4d106.7018396!16s%2Fg%2F11mt2x70fp?hl=vi&entry=ttu&g_ep=EgoyMDI2MDQxNC4wIKXMDSoASAFQAw%3D%3D');

    if (!$location_1_maps_url && $location_1_map_embed_url) {
        $location_1_maps_url = preg_replace('~^https?://www\\.google\\.com/maps/embed\\?~', 'https://www.google.com/maps?', $location_1_map_embed_url);
        $location_1_maps_url = remove_query_arg('output', $location_1_maps_url);
    }
    if (!$location_2_maps_url && $location_2_map_embed_url) {
        $location_2_maps_url = preg_replace('~^https?://www\\.google\\.com/maps/embed\\?~', 'https://www.google.com/maps?', $location_2_map_embed_url);
        $location_2_maps_url = remove_query_arg('output', $location_2_maps_url);
    }

    $services_page_url = ai_quest_page_url('dich-vu');
    $all_services_page_url = ai_quest_page_url('tat-ca-dich-vu');
    $promotions_page_url = ai_quest_page_url('khuyen-mai');
    $pricing_page_url = ai_quest_page_url('bang-gia');
    $about_page_url = ai_quest_page_url('gioi-thieu');
    $booking_page_url = ai_quest_page_url('dat-lich');
    $partners_page_url = ai_quest_page_url('doi-tac');

    // Get logo URL (from custom URL or uploaded logo)
    $logo_image_url = ai_quest_get_logo_url();
    
    // Fallback to old setting if exists
    if (empty($logo_image_url)) {
        $logo_image_url = trim((string) ai_quest_get_setting('ai_quest_logo_image_url', ''));
    }
    
    // Get phone numbers from Header settings
    $header_phones = ai_quest_get_header_phones();
    // Fallback to old hotline setting if no phones configured
    if (empty($header_phones)) {
        $header_phones = array($locations_hotline);
    }

    // Detect trang hiện tại để highlight tab
    $current_page = get_query_var('aiq_page', '');
    $is_home     = is_front_page() && $current_page === '';
    $svc_pages_keys = array('dich-vu', 'cham-soc-da', 'triet-long', 'goi-dau', 'tat-ca-dich-vu');

    function aiq_nav_class($condition) {
        return $condition ? ' class="nav-active"' : '';
    }
    ?>

    <header id="header" class="glass-header">
        <div class="header-topbar">
            <div class="container header-topbar-inner">
                <div class="topbar-left">
                    <?php if ($location_1_maps_url || $location_2_maps_url) : ?>
                        <div class="topbar-location">
                            <span class="topbar-link topbar-location-trigger" aria-haspopup="true" aria-expanded="false">LOCATION</span>
                            <div class="topbar-location-menu" role="menu">
                                <?php if ($location_1_maps_url) : ?>
                                    <a class="topbar-location-item" role="menuitem" href="<?php echo esc_url($location_1_maps_url); ?>" target="_blank" rel="noopener">
                                        <span class="topbar-location-name">Cơ sở 1: <?php echo esc_html($location_1_title); ?></span>
                                        <span class="topbar-location-address"><?php echo esc_html($location_1_address); ?></span>
                                    </a>
                                <?php endif; ?>
                                <?php if ($location_2_maps_url) : ?>
                                    <a class="topbar-location-item" role="menuitem" href="<?php echo esc_url($location_2_maps_url); ?>" target="_blank" rel="noopener">
                                        <span class="topbar-location-name">Cơ sở 2: <?php echo esc_html($location_2_title); ?></span>
                                        <span class="topbar-location-address"><?php echo esc_html($location_2_address); ?></span>
                                    </a>
                                <?php endif; ?>
                            </div>
                        </div>
                    <?php else : ?>
                        <span class="topbar-item">LOCATION</span>
                    <?php endif; ?>
                    <span class="topbar-sep">•</span>
                    <span class="topbar-phones">
                        <?php 
                        if (count($header_phones) === 1) {
                            // Single phone - clickable link
                            echo '<a class="topbar-link" href="tel:' . esc_attr(str_replace(' ', '', $header_phones[0])) . '">' . esc_html($header_phones[0]) . '</a>';
                        } else {
                            // Multiple phones - display with prefix, not clickable
                            echo '<span class="topbar-item">' . ai_quest_format_phone_display($header_phones) . '</span>';
                        }
                        ?>
                    </span>
                </div>
                <div class="topbar-right">
                    <span class="topbar-item"><?php echo esc_html($locations_time_text); ?></span>
                    <div class="topbar-social">
                        <?php if ($locations_facebook_url && $locations_facebook_url !== '#') : ?>
                            <a class="topbar-link" href="<?php echo esc_url($locations_facebook_url); ?>" target="_blank" rel="noopener" aria-label="Facebook">
                                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                                    <path d="M22 12a10 10 0 1 0-11.56 9.88v-7H7.9V12h2.54V9.8c0-2.5 1.49-3.89 3.77-3.89 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.62.77-1.62 1.56V12h2.76l-.44 2.88h-2.32v7A10 10 0 0 0 22 12z"></path>
                                </svg>
                            </a>
                        <?php endif; ?>
                        <?php if ($locations_instagram_url && $locations_instagram_url !== '#') : ?>
                            <a class="topbar-link" href="<?php echo esc_url($locations_instagram_url); ?>" target="_blank" rel="noopener" aria-label="Instagram">
                                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                                    <path d="M7.75 2h8.5A5.75 5.75 0 0 1 22 7.75v8.5A5.75 5.75 0 0 1 16.25 22h-8.5A5.75 5.75 0 0 1 2 16.25v-8.5A5.75 5.75 0 0 1 7.75 2zm0 1.5A4.25 4.25 0 0 0 3.5 7.75v8.5A4.25 4.25 0 0 0 7.75 20.5h8.5a4.25 4.25 0 0 0 4.25-4.25v-8.5A4.25 4.25 0 0 0 16.25 3.5h-8.5z"></path>
                                    <path d="M12 7a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm0 1.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z"></path>
                                    <path d="M17.5 6.25a1 1 0 1 1-2 0 1 1 0 0 1 2 0z"></path>
                                </svg>
                            </a>
                        <?php endif; ?>
                        <?php if ($locations_tiktok_url && $locations_tiktok_url !== '#') : ?>
                            <a class="topbar-link" href="<?php echo esc_url($locations_tiktok_url); ?>" target="_blank" rel="noopener" aria-label="TikTok">
                                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                                    <path d="M15 3c.6 3.4 3 5.4 6 5.6v3.1c-2.2-.1-4.2-.9-6-2.3v6.6c0 3.9-3.2 7-7.1 7A7.1 7.1 0 0 1 1 16.5c0-3.9 3.2-7.1 7.1-7.1.4 0 .8 0 1.2.1v3.4c-.4-.2-.8-.3-1.2-.3-2.1 0-3.8 1.7-3.8 3.9 0 2.1 1.7 3.9 3.8 3.9 2.2 0 3.9-1.8 3.9-4V3h3z"></path>
                                </svg>
                            </a>
                        <?php endif; ?>
                        <?php 
                        $locations_youtube_url = ai_quest_get_setting('ai_quest_locations_social_youtube_url', '#');
                        if ($locations_youtube_url && $locations_youtube_url !== '#') : ?>
                            <a class="topbar-link" href="<?php echo esc_url($locations_youtube_url); ?>" target="_blank" rel="noopener" aria-label="YouTube">
                                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                                    <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"></path>
                                </svg>
                            </a>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>

        <div class="header-main">
            <div class="container">
                <div class="header-nav-row">
                    <!-- Hamburger (mobile only) -->
                    <button class="mobile-menu-btn" id="mobile-menu-btn" aria-label="Mở menu" aria-expanded="false">
                        <span></span><span></span><span></span>
                    </button>

                    <!-- Logo trái -->
                    <div class="logo">
                        <?php if ($logo_image_url) : ?>
                            <a href="<?php echo esc_url(home_url('/')); ?>" class="custom-logo-link" rel="home">
                                <img src="<?php echo esc_url($logo_image_url); ?>" class="custom-logo" alt="<?php echo esc_attr(get_bloginfo('name')); ?>">
                            </a>
                        <?php elseif (has_custom_logo()) : ?>
                            <?php echo wp_kses_post(get_custom_logo()); ?>
                        <?php else : ?>
                            <a href="<?php echo esc_url(home_url('/')); ?>"><?php echo esc_html(ai_quest_get_setting('ai_quest_logo_text', 'Henie Skinlab')); ?></a>
                        <?php endif; ?>
                    </div>

                    <!-- Nav giữa -->
                    <div class="header-nav-center">
                        <nav class="main-nav hide-for-medium">
                            <ul class="nav-links">
                                <li<?php echo aiq_nav_class($is_home); ?>><a href="<?php echo esc_url(home_url('/')); ?>"><?php echo esc_html(ai_quest_get_menu_text('trang_chu', 'Henie Skinlab')); ?></a></li>
                                
                                <?php if (ai_quest_is_menu_visible('bang_gia')) : ?>
                                <li<?php echo aiq_nav_class($current_page === 'bang-gia'); ?>><a href="<?php echo esc_url($pricing_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('bang_gia', 'Bảng Giá')); ?></a></li>
                                <?php endif; ?>
                                
                                <?php if (ai_quest_is_menu_visible('gioi_thieu')) : ?>
                                <li<?php echo aiq_nav_class($current_page === 'gioi-thieu'); ?>><a href="<?php echo esc_url($about_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('gioi_thieu', 'Giới Thiệu')); ?></a></li>
                                <?php endif; ?>
                                
                                <?php if (ai_quest_is_menu_visible('dich_vu')) : ?>
                                <li class="nav-has-dropdown<?php echo in_array($current_page, $svc_pages_keys) ? ' nav-active' : ''; ?>">
                                    <a href="<?php echo esc_url($services_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('dich_vu', 'Dịch Vụ')); ?></a>
                                    <ul class="nav-dropdown">
                                        <li><a href="<?php echo esc_url(ai_quest_page_url('cham-soc-da')); ?>">Chăm Sóc Da</a></li>
                                        <li><a href="<?php echo esc_url(ai_quest_page_url('triet-long')); ?>">Triệt Lông</a></li>
                                        <li><a href="<?php echo esc_url(ai_quest_page_url('goi-dau')); ?>">Gội Đầu</a></li>
                                    </ul>
                                </li>
                                <?php endif; ?>
                                
                                <?php if (ai_quest_is_menu_visible('khuyen_mai')) : ?>
                                <li<?php echo aiq_nav_class($current_page === 'khuyen-mai'); ?>><a href="<?php echo esc_url($promotions_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('khuyen_mai', 'Khuyến Mãi')); ?></a></li>
                                <?php endif; ?>
                                
                                <?php if (ai_quest_is_menu_visible('doi_tac')) : ?>
                                <li<?php echo aiq_nav_class($current_page === 'doi-tac'); ?>><a href="<?php echo esc_url($partners_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('doi_tac', 'Đối Tác')); ?></a></li>
                                <?php endif; ?>
                                
                                <?php if (ai_quest_is_menu_visible('chia_se')) : ?>
                                <li class="nav-has-dropdown<?php echo in_array($current_page, array('chia-se', 'tu-chuyen-gia', 'tu-khach-hang')) ? ' nav-active' : ''; ?>">
                                    <a href="<?php echo esc_url(ai_quest_page_url('chia-se')); ?>"><?php echo esc_html(ai_quest_get_menu_text('chia_se', 'Chia Sẻ')); ?></a>
                                    <ul class="nav-dropdown">
                                        <li><a href="<?php echo esc_url(ai_quest_page_url('tu-chuyen-gia')); ?>">Chia Sẻ Từ Chuyên Gia</a></li>
                                        <li><a href="<?php echo esc_url(ai_quest_page_url('tu-khach-hang')); ?>">Chia Sẻ Từ Khách Hàng</a></li>
                                    </ul>
                                </li>
                                <?php endif; ?>
                                
                                <?php if (ai_quest_is_menu_visible('tu_van')) : ?>
                                <li><a href="#" data-open-consult-popup><?php echo esc_html(ai_quest_get_menu_text('tu_van', 'Tư Vấn')); ?></a></li>
                                <?php endif; ?>
                            </ul>
                        </nav>
                    </div>

                    <!-- Button phải -->
                    <div class="header-actions">
                        <a href="<?php echo esc_url($booking_page_url); ?>" class="consult-tab hide-for-small"><?php echo esc_html(ai_quest_get_menu_text('dat_lich', 'ĐẶT LỊCH')); ?></a>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <!-- Mobile Nav Drawer -->
    <div class="mobile-nav-overlay" id="mobile-nav-overlay"></div>
    <nav class="mobile-nav-drawer" id="mobile-nav-drawer" aria-label="Mobile navigation">
        <button class="mobile-nav-close" id="mobile-nav-close" aria-label="Đóng menu">×</button>
        <ul class="nav-links">
            <li><a href="<?php echo esc_url(home_url('/')); ?>" style="color: var(--primary-spa);"><?php echo esc_html(ai_quest_get_menu_text('trang_chu', 'Henie Skinlab')); ?></a></li>
            
            <?php if (ai_quest_is_menu_visible('bang_gia')) : ?>
            <li><a href="<?php echo esc_url($pricing_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('bang_gia', 'Bảng Giá')); ?></a></li>
            <?php endif; ?>
            
            <?php if (ai_quest_is_menu_visible('gioi_thieu')) : ?>
            <li><a href="<?php echo esc_url($about_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('gioi_thieu', 'Giới Thiệu')); ?></a></li>
            <?php endif; ?>
            
            <?php if (ai_quest_is_menu_visible('dich_vu')) : ?>
            <li><a href="<?php echo esc_url($services_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('dich_vu', 'Dịch Vụ')); ?></a></li>
            <li style="padding-left:16px;border-bottom:none;"><a href="<?php echo esc_url(add_query_arg('aiq_page', 'cham-soc-da', home_url('/'))); ?>" style="font-size:0.9rem;color:var(--text-muted);">— Chăm Sóc Da</a></li>
            <li style="padding-left:16px;border-bottom:none;"><a href="<?php echo esc_url(add_query_arg('aiq_page', 'triet-long', home_url('/'))); ?>" style="font-size:0.9rem;color:var(--text-muted);">— Triệt Lông</a></li>
            <li style="padding-left:16px;"><a href="<?php echo esc_url(add_query_arg('aiq_page', 'goi-dau', home_url('/'))); ?>" style="font-size:0.9rem;color:var(--text-muted);">— Gội Đầu</a></li>
            <?php endif; ?>
            
            <?php if (ai_quest_is_menu_visible('khuyen_mai')) : ?>
            <li><a href="<?php echo esc_url($promotions_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('khuyen_mai', 'Khuyến Mãi')); ?></a></li>
            <?php endif; ?>
            
            <?php if (ai_quest_is_menu_visible('doi_tac')) : ?>
            <li><a href="<?php echo esc_url($partners_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('doi_tac', 'Đối Tác')); ?></a></li>
            <?php endif; ?>
            
            <?php if (ai_quest_is_menu_visible('chia_se')) : ?>
            <li><a href="<?php echo esc_url(ai_quest_page_url('chia-se')); ?>"><?php echo esc_html(ai_quest_get_menu_text('chia_se', 'Chia Sẻ')); ?></a></li>
            <li style="padding-left:16px;border-bottom:none;"><a href="<?php echo esc_url(ai_quest_page_url('tu-chuyen-gia')); ?>" style="font-size:0.9rem;color:var(--text-muted);">— Chia Sẻ Từ Chuyên Gia</a></li>
            <li style="padding-left:16px;"><a href="<?php echo esc_url(ai_quest_page_url('tu-khach-hang')); ?>" style="font-size:0.9rem;color:var(--text-muted);">— Chia Sẻ Từ Khách Hàng</a></li>
            <?php endif; ?>
            
            <?php if (ai_quest_is_menu_visible('tu_van')) : ?>
            <li><a href="#" data-open-consult-popup><?php echo esc_html(ai_quest_get_menu_text('tu_van', 'Tư Vấn')); ?></a></li>
            <?php endif; ?>
            
            <li><a href="<?php echo esc_url($booking_page_url); ?>" style="color:var(--primary-spa);font-weight:800;"><?php echo esc_html(ai_quest_get_menu_text('dat_lich', 'ĐẶT LỊCH')); ?></a></li>
        </ul>
    </nav>

    <div class="mini-header" id="mini-header" aria-hidden="true">
        <div class="container mini-header-inner">
            <!-- Hamburger (mobile only) -->
            <button class="mini-menu-btn" aria-label="Mở menu" onclick="document.getElementById('mobile-menu-btn').click()">
                <span></span><span></span><span></span>
            </button>

            <!-- Logo trái -->
            <div class="logo">
                <?php if ($logo_image_url) : ?>
                    <a href="<?php echo esc_url(home_url('/')); ?>" class="custom-logo-link" rel="home">
                        <img src="<?php echo esc_url($logo_image_url); ?>" class="custom-logo" alt="<?php echo esc_attr(get_bloginfo('name')); ?>">
                    </a>
                <?php elseif (has_custom_logo()) : ?>
                    <?php echo wp_kses_post(get_custom_logo()); ?>
                <?php else : ?>
                    <a href="<?php echo esc_url(home_url('/')); ?>"><?php echo esc_html(ai_quest_get_setting('ai_quest_logo_text', 'Henie Skinlab')); ?></a>
                <?php endif; ?>
            </div>

            <!-- Nav giữa -->
            <nav class="main-nav mini-nav" aria-label="Primary">
                <ul class="nav-links">
                    <li<?php echo aiq_nav_class($is_home); ?>><a href="<?php echo esc_url(home_url('/')); ?>"><?php echo esc_html(ai_quest_get_menu_text('trang_chu', 'Henie Skinlab')); ?></a></li>
                    
                    <?php if (ai_quest_is_menu_visible('bang_gia')) : ?>
                    <li<?php echo aiq_nav_class($current_page === 'bang-gia'); ?>><a href="<?php echo esc_url($pricing_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('bang_gia', 'Bảng Giá')); ?></a></li>
                    <?php endif; ?>
                    
                    <?php if (ai_quest_is_menu_visible('gioi_thieu')) : ?>
                    <li<?php echo aiq_nav_class($current_page === 'gioi-thieu'); ?>><a href="<?php echo esc_url($about_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('gioi_thieu', 'Giới Thiệu')); ?></a></li>
                    <?php endif; ?>
                    
                    <?php if (ai_quest_is_menu_visible('dich_vu')) : ?>
                    <li class="nav-has-dropdown<?php echo in_array($current_page, $svc_pages_keys) ? ' nav-active' : ''; ?>">
                        <a href="<?php echo esc_url($services_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('dich_vu', 'Dịch Vụ')); ?></a>
                        <ul class="nav-dropdown">
                            <li><a href="<?php echo esc_url(add_query_arg('aiq_page', 'cham-soc-da', home_url('/'))); ?>">Chăm Sóc Da</a></li>
                            <li><a href="<?php echo esc_url(add_query_arg('aiq_page', 'triet-long', home_url('/'))); ?>">Triệt Lông</a></li>
                            <li><a href="<?php echo esc_url(add_query_arg('aiq_page', 'goi-dau', home_url('/'))); ?>">Gội Đầu</a></li>
                        </ul>
                    </li>
                    <?php endif; ?>
                    
                    <?php if (ai_quest_is_menu_visible('khuyen_mai')) : ?>
                    <li<?php echo aiq_nav_class($current_page === 'khuyen-mai'); ?>><a href="<?php echo esc_url($promotions_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('khuyen_mai', 'Khuyến Mãi')); ?></a></li>
                    <?php endif; ?>
                    
                    <?php if (ai_quest_is_menu_visible('doi_tac')) : ?>
                    <li<?php echo aiq_nav_class($current_page === 'doi-tac'); ?>><a href="<?php echo esc_url($partners_page_url); ?>"><?php echo esc_html(ai_quest_get_menu_text('doi_tac', 'Đối Tác')); ?></a></li>
                    <?php endif; ?>
                    
                    <?php if (ai_quest_is_menu_visible('chia_se')) : ?>
                    <li class="nav-has-dropdown<?php echo in_array($current_page, array('chia-se', 'tu-chuyen-gia', 'tu-khach-hang')) ? ' nav-active' : ''; ?>">
                        <a href="<?php echo esc_url(ai_quest_page_url('chia-se')); ?>"><?php echo esc_html(ai_quest_get_menu_text('chia_se', 'Chia Sẻ')); ?></a>
                        <ul class="nav-dropdown">
                            <li><a href="<?php echo esc_url(ai_quest_page_url('tu-chuyen-gia')); ?>">Chia Sẻ Từ Chuyên Gia</a></li>
                            <li><a href="<?php echo esc_url(ai_quest_page_url('tu-khach-hang')); ?>">Chia Sẻ Từ Khách Hàng</a></li>
                        </ul>
                    </li>
                    <?php endif; ?>
                    
                    <?php if (ai_quest_is_menu_visible('tu_van')) : ?>
                    <li><a href="#" data-open-consult-popup><?php echo esc_html(ai_quest_get_menu_text('tu_van', 'Tư Vấn')); ?></a></li>
                    <?php endif; ?>
                </ul>
            </nav>

            <!-- Button phải -->
            <div class="mini-header-actions">
                <a href="<?php echo esc_url($booking_page_url); ?>" class="consult-tab mini-booking"><?php echo esc_html(ai_quest_get_menu_text('dat_lich', 'ĐẶT LỊCH')); ?></a>
            </div>
        </div>
    </div>
