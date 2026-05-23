    <?php
    $footer_brand_name = ai_quest_get_setting('ai_quest_footer_brand_name', 'Henie Skinlab');
    $footer_brand_description = ai_quest_get_setting('ai_quest_footer_brand_description', 'Nơi đánh thức vẻ đẹp tiềm ẩn với đội ngũ chuyên gia hàng đầu và công nghệ làm đẹp tiên tiến nhất.');
    $footer_fanpage_text = ai_quest_get_setting('ai_quest_footer_fanpage_text', 'Facebook Fanpage');
    $footer_fanpage_url = ai_quest_get_setting('ai_quest_footer_fanpage_url', '#');
    $footer_contact_address = ai_quest_get_setting('ai_quest_footer_contact_address', 'TP. Hồ Chí Minh, Việt Nam');
    $footer_contact_phone = ai_quest_get_setting('ai_quest_footer_contact_phone', '096 235 94 65');
    $footer_contact_email = ai_quest_get_setting('ai_quest_footer_contact_email', 'info@mybeautyspa.vn');

    if ($footer_contact_phone === '098 384 18 19' || $footer_contact_phone === '0983841819') {
        $footer_contact_phone = '096 235 94 65';
    }

    $footer_nav_title = ai_quest_get_setting('ai_quest_footer_nav_title', 'DỊCH VỤ');
    $footer_nav_items = array(
        array('text' => ai_quest_get_setting('ai_quest_footer_nav_1_text', 'Chăm Sóc Da'), 'url' => ai_quest_get_setting('ai_quest_footer_nav_1_url', '#')),
        array('text' => ai_quest_get_setting('ai_quest_footer_nav_2_text', 'Massage Thư Giãn'), 'url' => ai_quest_get_setting('ai_quest_footer_nav_2_url', '#')),
        array('text' => ai_quest_get_setting('ai_quest_footer_nav_3_text', 'Combo Làm Đẹp'), 'url' => ai_quest_get_setting('ai_quest_footer_nav_3_url', '#')),
    );

    $footer_support_title = ai_quest_get_setting('ai_quest_footer_support_title', 'HỖ TRỢ');
    $footer_support_items = array(
        array('text' => ai_quest_get_setting('ai_quest_footer_support_1_text', 'Đặt Lịch Trực Tuyến'), 'url' => ai_quest_get_setting('ai_quest_footer_support_1_url', '#')),
        array('text' => ai_quest_get_setting('ai_quest_footer_support_2_text', 'Bảng Giá Dịch Vụ'), 'url' => ai_quest_get_setting('ai_quest_footer_support_2_url', '#')),
        array('text' => ai_quest_get_setting('ai_quest_footer_support_3_text', 'Chính Sách Hội Viên'), 'url' => ai_quest_get_setting('ai_quest_footer_support_3_url', '#')),
    );

    $footer_newsletter_title = ai_quest_get_setting('ai_quest_footer_newsletter_title', 'BẢN TIN');
    $footer_newsletter_description = ai_quest_get_setting('ai_quest_footer_newsletter_description', 'Đăng ký để nhận thông tin về các gói ưu đãi mới và bí quyết chăm sóc sắc đẹp từ chuyên gia.');
    $footer_newsletter_placeholder = ai_quest_get_setting('ai_quest_footer_newsletter_placeholder', 'Địa chỉ Email của bạn');
    $footer_newsletter_button_text = ai_quest_get_setting('ai_quest_footer_newsletter_button_text', '→');

    $footer_social_items = array(
        array('text' => ai_quest_get_setting('ai_quest_footer_social_1_text', 'Facebook'), 'url' => ai_quest_get_setting('ai_quest_footer_social_1_url', '#')),
        array('text' => ai_quest_get_setting('ai_quest_footer_social_2_text', 'Instagram'), 'url' => ai_quest_get_setting('ai_quest_footer_social_2_url', '#')),
        array('text' => ai_quest_get_setting('ai_quest_footer_social_3_text', 'TikTok'), 'url' => ai_quest_get_setting('ai_quest_footer_social_3_url', '#')),
    );

    $footer_copyright = ai_quest_get_setting('ai_quest_footer_copyright', 'Henie Skinlab - Tôn vinh vẻ đẹp Việt.');
    $footer_policy_text = ai_quest_get_setting('ai_quest_footer_policy_text', 'Chính Sách Bảo Mật');
    $footer_policy_url = ai_quest_get_setting('ai_quest_footer_policy_url', '#');
    $footer_terms_text = ai_quest_get_setting('ai_quest_footer_terms_text', 'Điều Khoản Dịch Vụ');
    $footer_terms_url = ai_quest_get_setting('ai_quest_footer_terms_url', '#');
    ?>

    <?php
    $locations_enabled = (int) ai_quest_get_setting('ai_quest_locations_enabled', 1);
    $locations_heading = ai_quest_get_setting('ai_quest_locations_heading', 'Hệ Thống Cửa Hàng');
    $locations_logo_url = ai_quest_get_setting('ai_quest_locations_logo_url', '');
    $locations_facebook_url = ai_quest_get_setting('ai_quest_locations_social_facebook_url', '#');
    $locations_instagram_url = ai_quest_get_setting('ai_quest_locations_social_instagram_url', '#');
    $locations_tiktok_url = ai_quest_get_setting('ai_quest_locations_social_tiktok_url', '#');
    $locations_youtube_url = ai_quest_get_setting('ai_quest_locations_social_youtube_url', '#');
    $locations_time_text = ai_quest_get_setting('ai_quest_locations_time_text', 'Thứ Hai đến Chủ Nhật: 9:00 Sáng - 20:00 Tối');
    $locations_hotline = ai_quest_get_setting('ai_quest_locations_hotline', $footer_contact_phone);
    $locations_website_label = ai_quest_get_setting('ai_quest_locations_website_label', '');
    $locations_website_url = ai_quest_get_setting('ai_quest_locations_website_url', home_url('/'));

    if ($locations_hotline === '098 384 18 19' || $locations_hotline === '0983841819') {
        $locations_hotline = '096 235 94 65';
    }
    
    // Get phone numbers from Header settings for footer display
    $footer_phones = ai_quest_get_header_phones();
    // Fallback to old hotline setting if no phones configured
    if (empty($footer_phones)) {
        $footer_phones = array($locations_hotline);
    }

    if ($locations_website_label === 'mybeautyspa.vn') {
        $locations_website_label = 'henieskinlab.com';
    }
    if ($locations_website_url === 'https://mybeautyspa.vn/' || $locations_website_url === 'http://mybeautyspa.vn/' || $locations_website_url === 'mybeautyspa.vn') {
        $locations_website_url = 'https://henieskinlab.com/';
    }
    if (($locations_website_url === home_url('/') || $locations_website_url === '') && $locations_website_label === '') {
        $locations_website_url = 'https://henieskinlab.com/';
        $locations_website_label = 'henieskinlab.com';
    }
    $locations_website_host = parse_url($locations_website_url ? $locations_website_url : home_url('/'), PHP_URL_HOST);
    $locations_website_display = $locations_website_label ? $locations_website_label : ($locations_website_host ? $locations_website_host : $footer_brand_name);
    $footer_google_maps_enabled = (int) ai_quest_get_setting('ai_quest_footer_google_maps_enabled', 1);
    $consult_popup_enabled = (int) ai_quest_get_setting('ai_quest_consult_popup_enabled', 1);
    $location_1_title = ai_quest_get_setting('ai_quest_location_1_title', 'Chi nhánh 1');
    $location_1_address = ai_quest_get_setting('ai_quest_location_1_address', '18 Thống Nhất, Phường 10, Gò Vấp, Thành phố Hồ Chí Minh');
    $location_2_title = ai_quest_get_setting('ai_quest_location_2_title', 'Chi nhánh 2');
    $location_2_address = ai_quest_get_setting('ai_quest_location_2_address', '124B Trần Thái Tông, Phường 15, Tân Bình, Thành phố Hồ Chí Minh');
    $location_1_map_embed_url = ai_quest_get_setting('ai_quest_location_1_map_embed_url', '');
    $location_2_map_embed_url = ai_quest_get_setting('ai_quest_location_2_map_embed_url', '');
    ?>

    <?php if ($locations_enabled) : ?>
        <section class="store-locations-section">
            <div class="container">
                <div class="store-locations-card">
                    <div class="store-info">
                        <div class="store-logo">
                            <?php if ($locations_logo_url) : ?>
                                <img src="<?php echo esc_url($locations_logo_url); ?>" alt="<?php echo esc_attr($footer_brand_name); ?>">
                            <?php else : ?>
                                <div class="store-logo-placeholder serif-font"><?php echo esc_html(mb_substr($footer_brand_name, 0, 1)); ?></div>
                            <?php endif; ?>
                        </div>
                        <div class="store-time-title">THỜI GIAN</div>
                        <div class="store-time-text"><?php echo esc_html($locations_time_text); ?></div>
                        <div class="store-contact">
                            <?php if (count($footer_phones) === 1): ?>
                                <!-- Single phone - inline display -->
                                <div><b>Hotline:</b> <?php echo esc_html($footer_phones[0]); ?></div>
                            <?php else: ?>
                                <!-- Multiple phones - centered title then list -->
                                <div class="store-contact-hotline-title"><b>Hotline:</b></div>
                                <div class="store-contact-phones">
                                    <?php foreach ($footer_phones as $index => $phone): ?>
                                        <div class="store-contact-phone-item">
                                            <span class="phone-label">Cơ Sở <?php echo ($index + 1); ?>:</span>
                                            <span class="phone-number"><?php echo esc_html($phone); ?></span>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            <?php endif; ?>
                            <div><b>Website:</b> <a href="<?php echo esc_url($locations_website_url); ?>" target="_blank" rel="noopener" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;"><?php echo esc_html($locations_website_display); ?></a></div>
                        </div>
                        <div class="store-social-icons">
                            <?php if ($locations_facebook_url && $locations_facebook_url !== '#') : ?>
                                <a class="social-icon" href="<?php echo esc_url($locations_facebook_url); ?>" target="_blank" rel="noopener" aria-label="Facebook" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;">
                                    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
                                        <path d="M22 12a10 10 0 1 0-11.56 9.88v-7H7.9V12h2.54V9.8c0-2.5 1.49-3.89 3.77-3.89 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.62.77-1.62 1.56V12h2.76l-.44 2.88h-2.32v7A10 10 0 0 0 22 12z"></path>
                                    </svg>
                                </a>
                            <?php endif; ?>
                            <?php if ($locations_instagram_url && $locations_instagram_url !== '#') : ?>
                                <a class="social-icon" href="<?php echo esc_url($locations_instagram_url); ?>" target="_blank" rel="noopener" aria-label="Instagram" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;">
                                    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
                                        <path d="M7.75 2h8.5A5.75 5.75 0 0 1 22 7.75v8.5A5.75 5.75 0 0 1 16.25 22h-8.5A5.75 5.75 0 0 1 2 16.25v-8.5A5.75 5.75 0 0 1 7.75 2zm0 1.5A4.25 4.25 0 0 0 3.5 7.75v8.5A4.25 4.25 0 0 0 7.75 20.5h8.5a4.25 4.25 0 0 0 4.25-4.25v-8.5A4.25 4.25 0 0 0 16.25 3.5h-8.5z"></path>
                                        <path d="M12 7a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm0 1.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z"></path>
                                        <path d="M17.5 6.25a1 1 0 1 1-2 0 1 1 0 0 1 2 0z"></path>
                                    </svg>
                                </a>
                            <?php endif; ?>
                            <?php if ($locations_tiktok_url && $locations_tiktok_url !== '#') : ?>
                                <a class="social-icon" href="<?php echo esc_url($locations_tiktok_url); ?>" target="_blank" rel="noopener" aria-label="TikTok" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;">
                                    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
                                        <path d="M15 3c.6 3.4 3 5.4 6 5.6v3.1c-2.2-.1-4.2-.9-6-2.3v6.6c0 3.9-3.2 7-7.1 7A7.1 7.1 0 0 1 1 16.5c0-3.9 3.2-7.1 7.1-7.1.4 0 .8 0 1.2.1v3.4c-.4-.2-.8-.3-1.2-.3-2.1 0-3.8 1.7-3.8 3.9 0 2.1 1.7 3.9 3.8 3.9 2.2 0 3.9-1.8 3.9-4V3h3z"></path>
                                    </svg>
                                </a>
                            <?php endif; ?>
                            <?php if ($locations_youtube_url && $locations_youtube_url !== '#') : ?>
                                <a class="social-icon" href="<?php echo esc_url($locations_youtube_url); ?>" target="_blank" rel="noopener" aria-label="YouTube" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;">
                                    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
                                        <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"></path>
                                    </svg>
                                </a>
                            <?php endif; ?>
                        </div>
                    </div>
                    <?php if ($footer_google_maps_enabled) : ?>
                    <div class="store-branch">
                        <h4 style="margin-bottom: 6px;">Chi nhánh 1</h4>
                        <div class="branch-meta">
                            <div class="branch-desc"><?php echo esc_html($location_1_title); ?></div>
                            <div class="branch-address"><span class="branch-address-label">Địa chỉ:</span> <?php echo esc_html($location_1_address); ?></div>
                        </div>
                        <div class="map-embed">
                            <?php
                            $location_1_embed_src = $location_1_map_embed_url ? $location_1_map_embed_url : 'https://www.google.com/maps?q=' . rawurlencode($location_1_address) . '&output=embed';
                            ?>
                            <iframe class="maps-iframe" src="<?php echo esc_url($location_1_embed_src); ?>" width="600" height="450" style="border:0;" allowfullscreen="" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>
                        </div>
                    </div>
                    <div class="store-branch">
                        <h4 style="margin-bottom: 6px;">Chi nhánh 2</h4>
                        <div class="branch-meta">
                            <div class="branch-desc"><?php echo esc_html($location_2_title); ?></div>
                            <div class="branch-address"><span class="branch-address-label">Địa chỉ:</span> <?php echo esc_html($location_2_address); ?></div>
                        </div>
                        <div class="map-embed">
                            <?php
                            $location_2_embed_src = $location_2_map_embed_url ? $location_2_map_embed_url : 'https://www.google.com/maps?q=' . rawurlencode($location_2_address) . '&output=embed';
                            ?>
                            <iframe class="maps-iframe" src="<?php echo esc_url($location_2_embed_src); ?>" width="600" height="450" style="border:0;" allowfullscreen="" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>
                        </div>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>
    <?php endif; ?>

    <button type="button" class="back-to-top" id="back-to-top" aria-label="Lên đầu trang">
        <svg class="back-to-top-icon" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">
            <polyline points="18 15 12 9 6 15"></polyline>
        </svg>
        </svg>
    </button>

    <?php if ($consult_popup_enabled) : ?>
    <!-- Popup Tư Vấn -->
    <?php
    $consult_service_options = ai_quest_get_all_services_from_categories();
    ?>
    <div id="consult-popup" class="modal-overlay">
        <div class="modal-content animate-in booking-modal">
            <button class="modal-close" id="close-consult-popup">&times;</button>
            <div class="booking-modal-inner">
                <h2 class="booking-title">Tư vấn dịch vụ</h2>
                <p class="booking-subtitle">Xin vui lòng để lại thông tin, Henie Skinlab sẽ liên hệ tư vấn sớm nhất.</p>

                <form id="consult-form" class="booking-form" action="#" method="post">
                    <div class="booking-grid">
                        <input type="text" name="full_name" placeholder="Họ tên*" required>
                        <select name="service" required>
                            <option value="">Chọn dịch vụ</option>
                            <?php foreach ($consult_service_options as $svc_name) : ?>
                                <option value="<?php echo esc_attr($svc_name); ?>"><?php echo esc_html($svc_name); ?></option>
                            <?php endforeach; ?>
                        </select>
                        <input type="tel" name="phone" placeholder="Số điện thoại*" required>
                    </div>

                    <div class="booking-row">
                        <textarea name="note" placeholder="Ghi chú" rows="4"></textarea>
                    </div>

                    <button class="booking-submit" type="submit">Gửi yêu cầu</button>
                </form>
            </div>
        </div>
    </div>
    <?php endif; ?>

    <!-- Service Detail Modal -->
    <div id="service-modal" class="service-modal">
        <span class="service-modal-close" id="close-service-modal">&times;</span>
        <div class="service-modal-content">
            <div class="service-modal-header">
                <img id="service-modal-img" src="" alt="">
                <h2 id="service-modal-title" class="service-modal-title"></h2>
            </div>
            <div class="service-modal-body">
                <div class="service-modal-info">
                    <div class="modal-info-item">
                        <span class="modal-info-label">GIÁ DỊCH VỤ</span>
                        <span id="service-modal-price" class="modal-info-value"></span>
                    </div>
                    <div class="modal-info-item">
                        <span class="modal-info-label">THỜI GIAN</span>
                        <span id="service-modal-time" class="modal-info-value"></span>
                    </div>
                </div>
                <div class="service-modal-description">
                    <h4>Mô tả dịch vụ</h4>
                    <div id="service-modal-desc-content"></div>
                </div>
            </div>
            <div class="service-modal-footer">
                <a href="#" class="btn btn-primary" id="service-modal-booking">ĐẶT LỊCH NGAY</a>
            </div>
        </div>
    </div>

    <?php wp_footer(); ?>

    <script>
    window.aiqConfig = {
        supabaseUrl: <?php echo wp_json_encode(ai_quest_get_setting('ai_quest_supabase_url', 'https://cgqxrsoaxgyvcskbixuu.supabase.co')); ?>,
        supabaseKey: <?php echo wp_json_encode(ai_quest_get_setting('ai_quest_supabase_anon_key', 'sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh')); ?>,
        storeId:     <?php echo wp_json_encode(ai_quest_get_setting('ai_quest_store_id', '')); ?>
    };
    </script>
    
    <!-- Sticky Contact Bar -->
    <?php
    $sticky_phone = ai_quest_get_setting('ai_quest_sticky_phone', '0962359465');
    $sticky_zalo = ai_quest_get_setting('ai_quest_sticky_zalo', 'https://zalo.me/0962359465');
    $sticky_messenger = ai_quest_get_setting('ai_quest_sticky_messenger', 'https://m.me/henieskinlab');
    $sticky_facebook = ai_quest_get_setting('ai_quest_sticky_facebook', 'https://facebook.com/henieskinlab');

    if ($sticky_phone === '0983841819' || $sticky_phone === '098 384 18 19') {
        $sticky_phone = '0962359465';
    }
    if ($sticky_zalo === 'https://zalo.me/0983841819') {
        $sticky_zalo = 'https://zalo.me/0962359465';
    }
    
    // Get phone numbers from Header settings
    $sticky_phones = ai_quest_get_header_phones();
    // Fallback to old setting if no phones configured
    if (empty($sticky_phones)) {
        $sticky_phones = array($sticky_phone);
    }
    
    // Get location addresses (up to 5 locations to match phone numbers)
    $location_addresses = array();
    for ($i = 1; $i <= 5; $i++) {
        $title = ai_quest_get_setting('ai_quest_location_' . $i . '_title', '');
        $address = ai_quest_get_setting('ai_quest_location_' . $i . '_address', '');
        if (!empty($title) || !empty($address)) {
            $location_addresses[] = array(
                'title' => $title,
                'address' => $address
            );
        }
    }
    ?>
    <div class="sticky-contact-bar">
        <?php if (!empty($sticky_phones)): ?>
            <?php if (count($sticky_phones) === 1): ?>
                <!-- Single phone - direct link -->
                <a href="tel:<?php echo esc_attr(str_replace(' ', '', $sticky_phones[0])); ?>" class="contact-item phone" title="Gọi điện" style="cursor: pointer !important;">
                    <svg viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M6.62 10.79c1.44 2.83 3.76 5.21 6.59 6.65l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>
                </a>
            <?php else: ?>
                <!-- Multiple phones - show popup -->
                <button type="button" class="contact-item phone" id="sticky-phone-btn" title="Chọn cơ sở để gọi" style="cursor: pointer !important; background: none; border: none; padding: 0;">
                    <svg viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M6.62 10.79c1.44 2.83 3.76 5.21 6.59 6.65l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>
                </button>
                
                <!-- Phone popup -->
                <div id="sticky-phone-popup" class="sticky-phone-popup" style="display: none;">
                    <div class="sticky-phone-popup-content">
                        <div class="sticky-phone-popup-header">
                            <h3>Chọn Cơ Sở</h3>
                            <button type="button" class="sticky-phone-popup-close">&times;</button>
                        </div>
                        <div class="sticky-phone-popup-list">
                            <?php foreach ($sticky_phones as $index => $phone): ?>
                                <a href="tel:<?php echo esc_attr(str_replace(' ', '', $phone)); ?>" class="sticky-phone-item">
                                    <div class="sticky-phone-item-icon">
                                        <svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M6.62 10.79c1.44 2.83 3.76 5.21 6.59 6.65l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>
                                    </div>
                                    <div class="sticky-phone-item-info">
                                        <div class="sticky-phone-item-label">Cơ Sở <?php echo ($index + 1); ?></div>
                                        <div class="sticky-phone-item-number"><?php echo esc_html($phone); ?></div>
                                        <?php if (isset($location_addresses[$index])): ?>
                                            <?php if (!empty($location_addresses[$index]['title'])): ?>
                                                <div class="sticky-phone-item-title"><?php echo esc_html($location_addresses[$index]['title']); ?></div>
                                            <?php endif; ?>
                                            <?php if (!empty($location_addresses[$index]['address'])): ?>
                                                <div class="sticky-phone-item-address"><?php echo esc_html($location_addresses[$index]['address']); ?></div>
                                            <?php endif; ?>
                                        <?php endif; ?>
                                    </div>
                                </a>
                            <?php endforeach; ?>
                        </div>
                    </div>
                </div>
            <?php endif; ?>
        <?php endif; ?>
        <?php if ($sticky_zalo && $sticky_zalo !== '#'): ?>
            <a href="<?php echo esc_url($sticky_zalo); ?>" class="contact-item zalo" target="_blank" rel="noopener noreferrer" title="Zalo" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;">
                <span class="zalo-text">Zalo</span>
            </a>
        <?php endif; ?>
        <?php if ($sticky_messenger && $sticky_messenger !== '#'): ?>
            <a href="<?php echo esc_url($sticky_messenger); ?>" class="contact-item messenger" target="_blank" rel="noopener noreferrer" title="Messenger" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;">
                <svg viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.15 2 11.13c0 3.06 1.83 5.76 4.67 7.35.24.13.38.4.38.68l.01 2.1c0 .32.34.52.61.36l2.34-1.34c.2-.11.43-.16.66-.14 1.08.1 2.18.16 3.33.16 5.52 0 10-4.15 10-9.13S17.52 2 12 2zm1.13 12.3l-2.3-2.45-4.48 2.45 4.92-5.23 2.35 2.45 4.41-2.45-4.9 5.23z"/></svg>
            </a>
        <?php endif; ?>
        <?php if ($sticky_facebook && $sticky_facebook !== '#'): ?>
            <a href="<?php echo esc_url($sticky_facebook); ?>" class="contact-item facebook" target="_blank" rel="noopener noreferrer" title="Facebook" onclick="window.open(this.href, '_blank'); return false;" style="cursor: pointer !important;">
                <svg viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.477 2 2 6.477 2 12c0 4.991 3.657 9.128 8.438 9.878v-6.987h-2.54V12h2.54V9.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V12h2.773l-.443 2.89h-2.33v6.988C18.343 21.128 22 16.991 22 12c0-5.523-4.477-10-10-10z"/></svg>
            </a>
        <?php endif; ?>
    </div>
    
    <script>
    // Sticky phone popup handler
    (function() {
        var phoneBtn = document.getElementById('sticky-phone-btn');
        var phonePopup = document.getElementById('sticky-phone-popup');
        var closeBtn = phonePopup ? phonePopup.querySelector('.sticky-phone-popup-close') : null;
        
        if (phoneBtn && phonePopup) {
            // Open popup
            phoneBtn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                phonePopup.style.display = 'block';
                setTimeout(function() {
                    phonePopup.classList.add('active');
                }, 10);
            });
            
            // Close popup
            if (closeBtn) {
                closeBtn.addEventListener('click', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    phonePopup.classList.remove('active');
                    setTimeout(function() {
                        phonePopup.style.display = 'none';
                    }, 300);
                });
            }
            
            // Close on outside click
            phonePopup.addEventListener('click', function(e) {
                if (e.target === phonePopup) {
                    phonePopup.classList.remove('active');
                    setTimeout(function() {
                        phonePopup.style.display = 'none';
                    }, 300);
                }
            });
            
            // Close on ESC key
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape' && phonePopup.style.display === 'block') {
                    phonePopup.classList.remove('active');
                    setTimeout(function() {
                        phonePopup.style.display = 'none';
                    }, 300);
                }
            });
        }
    })();
    </script>
</body>
</html>
