<?php
get_header();

$home_slider_enabled = (int) ai_quest_get_setting('ai_quest_home_slider_enabled', 1);
$home_slider_initial = (int) ai_quest_get_setting('ai_quest_home_slider_initial', 1);
$home_slider_interval = (int) ai_quest_get_setting('ai_quest_home_slider_interval', 5);
$home_slider_interval = max(1, min(60, $home_slider_interval));
$home_slider_images = array();
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
    $url_desktop = trim((string) ai_quest_get_setting('ai_quest_home_slider_image_' . $i, $home_slider_defaults[$i]));
    $url_mobile = trim((string) ai_quest_get_setting('ai_quest_home_slider_image_' . $i . '_mobile', ''));
    
    if ($url_desktop === '') {
        continue;
    }
    
    // If mobile URL is empty, use desktop URL as fallback
    if ($url_mobile === '') {
        $url_mobile = $url_desktop;
    }
    
    $home_slider_images[] = array(
        'desktop' => $url_desktop,
        'mobile' => $url_mobile,
    );
}
$home_slider_initial_index = 0;
if (count($home_slider_images) > 0) {
    $home_slider_initial_index = max(0, min(count($home_slider_images) - 1, $home_slider_initial - 1));
}

$services_page_url = add_query_arg('aiq_page', 'dich-vu', home_url('/'));
$all_services_page_url = add_query_arg('aiq_page', 'tat-ca-dich-vu', home_url('/'));
$booking_page_url = add_query_arg('aiq_page', 'dat-lich', home_url('/'));

$before_after_title = trim((string) ai_quest_get_setting('ai_quest_before_after_title', 'Hình Ảnh Trước & Sau Trị Liệu'));
if ($before_after_title === '') {
    $before_after_title = 'Hình Ảnh Trước & Sau Trị Liệu';
}
$before_after_subtitle = trim((string) ai_quest_get_setting('ai_quest_before_after_subtitle', ''));
$before_after_images = array();
for ($i = 1; $i <= 20; $i++) {
    $url = trim((string) ai_quest_get_setting('ai_quest_before_after_image_' . $i . '_url', ''));
    $alt = (string) ai_quest_get_setting('ai_quest_before_after_image_' . $i . '_alt', '');

    if ($url === '') {
        $url = trim((string) ai_quest_get_setting('ai_quest_before_after_case_' . $i . '_before_url', ''));
        $alt = (string) ai_quest_get_setting('ai_quest_before_after_case_' . $i . '_before_alt', '');
    }
    if ($url === '') {
        $url = trim((string) ai_quest_get_setting('ai_quest_before_after_case_' . $i . '_after_url', ''));
        $alt = (string) ai_quest_get_setting('ai_quest_before_after_case_' . $i . '_after_alt', '');
    }

    if ($url === '') {
        continue;
    }

    $before_after_images[] = array(
        'url' => $url,
        'alt' => $alt,
    );
}
$before_after_links = array();
for ($i = 1; $i <= 3; $i++) {
    $text = trim((string) ai_quest_get_setting('ai_quest_before_after_link_' . $i . '_text', ''));
    $url = ai_quest_get_setting('ai_quest_before_after_link_' . $i . '_url', '');
    if ($text === '' || !$url) {
        continue;
    }
    $before_after_links[] = array('text' => $text, 'url' => $url);
}

$video_title = trim((string) ai_quest_get_setting('ai_quest_video_title', 'Video của Henie Skinlab'));
if ($video_title === '') {
    $video_title = 'Video của Henie Skinlab';
}
$video_subtitle = trim((string) ai_quest_get_setting('ai_quest_video_subtitle', ''));
$videos = array();
for ($i = 1; $i <= 5; $i++) {
    $embed = trim((string) ai_quest_get_setting('ai_quest_video_' . $i . '_youtube', ''));
    if ($embed === '') {
        continue;
    }
    $videos[] = array('embed' => $embed);
}
$video_links = array();
for ($i = 1; $i <= 5; $i++) {
    $text = trim((string) ai_quest_get_setting('ai_quest_video_link_' . $i . '_text', ''));
    $url = ai_quest_get_setting('ai_quest_video_link_' . $i . '_url', '');
    if ($text === '' || !$url) {
        continue;
    }
    $video_links[] = array('text' => $text, 'url' => $url);
}

$features = array();
for ($i = 1; $i <= 3; $i++) {
    $default_icons = array(1 => '✨', 2 => '👩‍⚕️', 3 => '🌿');
    $default_titles = array(1 => 'Công Nghệ Hiện Đại', 2 => 'Kỹ Thuật Viên Chuyên Nghiệp', 3 => 'Sản Phẩm Cao Cấp');
    $default_descriptions = array(
        1 => 'Luôn cập nhật và ứng dụng các công nghệ làm đẹp tiên tiến nhất thế giới để mang lại hiệu quả tối ưu.',
        2 => 'Đội ngũ được đào tạo bài bản, có tâm và có tầm, mang đến sự an tâm tuyệt đối cho khách hàng.',
        3 => 'Sử dụng các dòng dược mỹ phẩm uy tín, chiết xuất từ thiên nhiên, an toàn và lành tính cho mọi loại da.',
    );

    $features[$i] = array(
        'icon' => ai_quest_get_setting('ai_quest_feature_' . $i . '_icon', $default_icons[$i]),
        'title' => ai_quest_get_setting('ai_quest_feature_' . $i . '_title', $default_titles[$i]),
        'description' => ai_quest_get_setting('ai_quest_feature_' . $i . '_description', $default_descriptions[$i]),
    );
}

$testimonials_title = ai_quest_get_setting('ai_quest_testimonials_title', 'Cảm Nhận Khách Hàng');
$testimonials_subtitle = ai_quest_get_setting('ai_quest_testimonials_subtitle', 'Họ nói gì sau khi trải nghiệm dịch vụ tại Henie Skinlab?');
$testimonials = array();
for ($i = 1; $i <= 3; $i++) {
    $default_stars = array(1 => '★★★★★', 2 => '★★★★★', 3 => '★★★★★');
    $default_texts = array(
        1 => '"Tôi rất hài lòng với trải nghiệm tại Henie Skinlab. Combo này không chỉ tiết kiệm thời gian mà còn mang lại hiệu quả tốt nhất cho làn da."',
        2 => '"Combo dịch vụ tại đây thực sự là sự lựa chọn hoàn hảo cho một ngày thư giãn. Tôi ấn tượng với sự kết hợp của các liệu pháp chăm sóc da."',
        3 => '"Không gian sang trọng, nhân viên chuyên nghiệp. Đây là nơi tuyệt vời nhất để tôi giải tỏa căng thẳng sau một tuần làm việc mệt mỏi."',
    );
    $default_names = array(1 => 'Vũ Thái Thanh', 2 => 'Hồ Thiên Hà', 3 => 'Lý Duyên Mỹ');
    $default_roles = array(1 => 'Khách hàng thân thiết', 2 => 'Diễn viên', 3 => 'Vlogger');
    $default_images = array(
        1 => 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=1200',
        2 => 'https://images.unsplash.com/photo-1542206395-9feb3edaa68d?auto=format&fit=crop&q=80&w=1200',
        3 => 'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?auto=format&fit=crop&q=80&w=1200',
    );

    $testimonials[$i] = array(
        'stars' => ai_quest_get_setting('ai_quest_testimonial_' . $i . '_stars', $default_stars[$i]),
        'text' => ai_quest_get_setting('ai_quest_testimonial_' . $i . '_text', $default_texts[$i]),
        'name' => ai_quest_get_setting('ai_quest_testimonial_' . $i . '_name', $default_names[$i]),
        'role' => ai_quest_get_setting('ai_quest_testimonial_' . $i . '_role', $default_roles[$i]),
        'image_url' => ai_quest_get_setting('ai_quest_testimonial_' . $i . '_image_url', $default_images[$i]),
        'image_alt' => ai_quest_get_setting('ai_quest_testimonial_' . $i . '_image_alt', $default_names[$i]),
    );
}

$marketing_title = ai_quest_get_setting('ai_quest_marketing_title', 'Chương Trình Hội Viên');
$marketing_subtitle = ai_quest_get_setting('ai_quest_marketing_subtitle', 'Ưu đãi đặc quyền dành riêng cho thành viên của Henie Skinlab.');
$marketing_plans = array();
for ($i = 1; $i <= 3; $i++) {
    $default_titles = array(1 => 'Gói Hội Viên Silver', 2 => 'Gói Hội Viên Gold', 3 => 'Gói Hội Viên Diamond');
    $default_descriptions = array(
        1 => 'Giảm 10% tất cả dịch vụ, tích điểm đổi quà và ưu tiên đặt lịch trước.',
        2 => 'Giảm 20% tất cả dịch vụ, tặng liệu trình chăm sóc da mặt miễn phí hàng tháng.',
        3 => 'Đặc quyền chăm sóc tại phòng VIP, quà tặng sinh nhật cao cấp và giảm 30%.',
    );
    $default_buttons = array(1 => 'Xem Chi Tiết', 2 => 'Xem Chi Tiết', 3 => 'Xem Chi Tiết');
    $marketing_plans[$i] = array(
        'title' => ai_quest_get_setting('ai_quest_marketing_' . $i . '_title', $default_titles[$i]),
        'description' => ai_quest_get_setting('ai_quest_marketing_' . $i . '_description', $default_descriptions[$i]),
        'button_text' => ai_quest_get_setting('ai_quest_marketing_' . $i . '_button_text', $default_buttons[$i]),
        'button_url' => ai_quest_get_setting('ai_quest_marketing_' . $i . '_button_url', '#'),
    );
}

$before_after_enabled = (int) ai_quest_get_setting('ai_quest_before_after_enabled', 1);
$video_enabled = (int) ai_quest_get_setting('ai_quest_video_enabled', 1);
$marketing_enabled = (int) ai_quest_get_setting('ai_quest_marketing_enabled', 1);
$features_enabled = (int) ai_quest_get_setting('ai_quest_features_enabled', 1);
$testimonials_enabled = (int) ai_quest_get_setting('ai_quest_testimonials_enabled', 1);
$banner_enabled       = (int) ai_quest_get_setting('ai_quest_banner_enabled', 1);
$partners_enabled     = (int) ai_quest_get_setting('ai_quest_partners_enabled', 1);
$partners_title       = ai_quest_get_setting('ai_quest_partners_title', 'Đối Tác');
$partners_subtitle    = ai_quest_get_setting('ai_quest_partners_subtitle', '');
$partners = array();
for ($i = 1; $i <= 10; $i++) {
    $logo_url = trim((string) ai_quest_get_setting('ai_quest_partner_' . $i . '_logo_url', ''));
    $name     = trim((string) ai_quest_get_setting('ai_quest_partner_' . $i . '_name', ''));
    $link_url = trim((string) ai_quest_get_setting('ai_quest_partner_' . $i . '_link_url', ''));
    if ($logo_url === '') continue;
    $partners[] = array('logo_url' => $logo_url, 'name' => $name, 'link_url' => $link_url);
}

$banner_badge       = ai_quest_get_setting('ai_quest_banner_badge', '');
$banner_title       = ai_quest_get_setting('ai_quest_banner_title', '');
$banner_description = ai_quest_get_setting('ai_quest_banner_description', '');
$banner_button_text = ai_quest_get_setting('ai_quest_banner_button_text', '');
$banner_button_url  = ai_quest_get_setting('ai_quest_banner_button_url', '');
$banner_bg_url      = ai_quest_get_setting('ai_quest_banner_bg_url', '');

// Check if banner has content
$banner_has_content = !empty($banner_title) || !empty($banner_description);

// Facebook Reels
$fb_reels_enabled  = (int) ai_quest_get_setting('ai_quest_fb_reels_enabled', 1);
$fb_reels_title    = trim((string) ai_quest_get_setting('ai_quest_fb_reels_title', 'Facebook Reels'));
if ($fb_reels_title === '') $fb_reels_title = 'Facebook Reels';
$fb_reels_subtitle = trim((string) ai_quest_get_setting('ai_quest_fb_reels_subtitle', ''));

$fb_reels_pinned = array();
$fb_reels_normal = array();
for ($i = 1; $i <= 50; $i++) {
    $url = trim((string) ai_quest_get_setting('ai_quest_fb_reel_' . $i . '_url', ''));
    if ($url === '') continue;
    $thumb = trim((string) ai_quest_get_setting('ai_quest_fb_reel_' . $i . '_thumb', ''));
    $pinned = (int) ai_quest_get_setting('ai_quest_fb_reel_' . $i . '_pinned', 0);
    $embed_url = 'https://www.facebook.com/plugins/video.php?href=' . rawurlencode($url) . '&show_text=false&width=400&height=711&mute=0';
    $item = array('url' => $url, 'embed_url' => $embed_url, 'thumb' => $thumb, 'pinned' => $pinned, 'slot' => $i);
    if ($pinned) {
        $fb_reels_pinned[] = $item;
    } else {
        $fb_reels_normal[] = $item;
    }
}
// Pinned lên đầu, normal reverse (mới nhất trước), ghép lại
$fb_reels_normal_rev = array_reverse($fb_reels_normal);
$fb_reels = array_merge($fb_reels_pinned, $fb_reels_normal_rev);
?>

<main id="main">

    <?php if ($home_slider_enabled && count($home_slider_images) > 0) : ?>
        <section class="home-slider" data-home-slider data-initial-index="<?php echo esc_attr($home_slider_initial_index); ?>" data-interval-seconds="<?php echo esc_attr($home_slider_interval); ?>">
            <div class="home-slider-viewport" data-home-slider-viewport>
                <div class="home-slider-track" data-home-slider-track>
                    <?php foreach ($home_slider_images as $img) : ?>
                        <div class="home-slider-slide">
                            <picture>
                                <source media="(max-width: 768px)" srcset="<?php echo esc_url($img['mobile']); ?>">
                                <img src="<?php echo esc_url($img['desktop']); ?>" alt="">
                            </picture>
                        </div>
                    <?php endforeach; ?>
                </div>
                <button class="home-slider-nav prev" type="button" aria-label="Ảnh trước" data-home-slider-prev>
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
                </button>
                <button class="home-slider-nav next" type="button" aria-label="Ảnh sau" data-home-slider-next>
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
                </button>
                <div class="home-slider-dots" data-home-slider-dots>
                    <?php for ($i = 0; $i < count($home_slider_images); $i++) : ?>
                        <button class="home-slider-dot<?php echo $i === $home_slider_initial_index ? ' is-active' : ''; ?>" type="button" aria-label="Ảnh <?php echo esc_attr($i + 1); ?>" data-home-slider-dot="<?php echo esc_attr($i); ?>"></button>
                    <?php endfor; ?>
                </div>
            </div>
        </section>
    <?php endif; ?>

    <?php if ($banner_enabled && $banner_has_content) : ?>
        <section class="section container" style="margin-top:60px;">
            <div class="banner-panel" style="background-image:linear-gradient(rgba(0,0,0,.45),rgba(0,0,0,.45)),url('<?php echo esc_url($banner_bg_url); ?>');">
                <?php if ($banner_badge) : ?>
                    <span class="banner-panel-badge"><?php echo esc_html($banner_badge); ?></span>
                <?php endif; ?>
                <?php if ($banner_title) : ?>
                    <h2><?php echo esc_html($banner_title); ?></h2>
                <?php endif; ?>
                <?php if ($banner_description) : ?>
                    <p><?php echo esc_html($banner_description); ?></p>
                <?php endif; ?>
                <?php if ($banner_button_text && $banner_button_url) : ?>
                    <a href="<?php echo esc_url($banner_button_url); ?>" class="btn btn-primary"><?php echo esc_html($banner_button_text); ?></a>
                <?php endif; ?>
            </div>
        </section>
    <?php endif; ?>

    <section class="section container" id="services">
        <div class="section-title-center">
            <h2>Dịch Vụ Của Henie Skinlab</h2>
            <p>Khám phá các dịch vụ chăm sóc sắc đẹp chuyên nghiệp tại Henie Skinlab.</p>
        </div>

        <?php
        $svc_cat_page_urls = array(
            1 => add_query_arg('aiq_page', 'cham-soc-da', home_url('/')),
            2 => add_query_arg('aiq_page', 'triet-long',  home_url('/')),
            3 => add_query_arg('aiq_page', 'goi-dau',     home_url('/')),
        );

        $svc_cat_defaults = array(
            1 => array('Chăm Sóc Da', 'Liệu trình chăm sóc da chuyên sâu, phù hợp với từng loại da.', ''),
            2 => array('Triệt Lông',  'Công nghệ triệt lông hiện đại, an toàn và hiệu quả lâu dài.',  ''),
            3 => array('Gội Đầu',     'Gội đầu dưỡng sinh kết hợp massage bấm huyệt thư giãn.',       ''),
        );

        $svc_cats = array();
        for ($i = 1; $i <= 3; $i++) {
            $d = $svc_cat_defaults[$i];
            $name = ai_quest_get_setting('ai_quest_svc_cat_' . $i . '_name', $d[0]);
            if (!$name) continue;
            $svc_cats[] = array(
                'name'        => $name,
                'description' => ai_quest_get_setting('ai_quest_svc_cat_' . $i . '_description', $d[1]),
                'image_url'   => ai_quest_get_setting('ai_quest_svc_cat_' . $i . '_image_url', $d[2]),
                'button_url'  => $svc_cat_page_urls[$i],
                'button_text' => ai_quest_get_setting('ai_quest_svc_cat_' . $i . '_button_text', 'Xem Dịch Vụ'),
            );
        }
        ?>

        <div class="svc-cat-grid svc-cat-count-<?php echo count($svc_cats); ?>">
            <?php foreach ($svc_cats as $cat) : ?>
                <div class="svc-cat-card">
                    <div class="svc-cat-img">
                        <?php if ($cat['image_url']) : ?>
                            <img src="<?php echo esc_url($cat['image_url']); ?>" alt="<?php echo esc_attr($cat['name']); ?>">
                        <?php endif; ?>
                    </div>
                    <div class="svc-cat-body">
                        <h3><?php echo esc_html($cat['name']); ?></h3>
                        <?php if ($cat['description']) : ?>
                            <p><?php echo esc_html($cat['description']); ?></p>
                        <?php endif; ?>
                        <a href="<?php echo esc_url($cat['button_url']); ?>" class="svc-cat-btn">
                            <?php echo esc_html($cat['button_text']); ?>
                        </a>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </section>

    <?php if ($before_after_enabled) : ?>
        <section class="section container">
            <div class="section-title-center">
                <h2><?php echo esc_html($before_after_title); ?></h2>
                <?php if ($before_after_subtitle) : ?>
                    <p><?php echo esc_html($before_after_subtitle); ?></p>
                <?php endif; ?>
            </div>

            <div class="media-grid">
                <div class="media-card">
                    <?php if (count($before_after_images) > 0) : ?>
                        <div class="before-after-carousel" data-before-after-carousel>
                            <button class="media-nav-btn prev" type="button" aria-label="Trước" data-before-after-prev>
                                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
                            </button>
                            <div class="before-after-viewport" data-before-after-viewport>
                                <div class="before-after-track" data-before-after-track>
                                    <?php foreach ($before_after_images as $img) : ?>
                                        <div class="before-after-slide">
                                            <div class="before-after-image">
                                                <img src="<?php echo esc_url($img['url']); ?>" alt="<?php echo esc_attr($img['alt']); ?>">
                                            </div>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            </div>
                            <button class="media-nav-btn next" type="button" aria-label="Sau" data-before-after-next>
                                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
                            </button>
                        </div>
                        <div class="before-after-dots" data-before-after-dots>
                            <?php for ($i = 0; $i < count($before_after_images); $i++) : ?>
                                <button class="before-after-dot" type="button" aria-label="Đi tới ảnh <?php echo esc_attr($i + 1); ?>" data-before-after-dot="<?php echo esc_attr($i); ?>"></button>
                            <?php endfor; ?>
                        </div>
                    <?php else : ?>
                        <div class="section-empty">Chưa có hình ảnh before/after.</div>
                    <?php endif; ?>

                    <?php if (count($before_after_links) > 0) : ?>
                        <div class="media-links">
                            <?php foreach ($before_after_links as $link) : ?>
                                <a class="btn btn-outline" href="<?php echo esc_url($link['url']); ?>" target="_blank" rel="noopener"><?php echo esc_html($link['text']); ?></a>
                            <?php endforeach; ?>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>
    <?php endif; ?>

    <?php if ($video_enabled) : ?>
        <section class="section container">
            <div class="section-title-center">
                <h2><?php echo esc_html($video_title); ?></h2>
                <?php if ($video_subtitle) : ?>
                    <p><?php echo esc_html($video_subtitle); ?></p>
                <?php endif; ?>
            </div>

            <div class="media-grid">
                <div class="media-card">
                    <?php if (count($videos) > 0) : ?>
                        <div class="media-carousel media-carousel--video" data-carousel>
                            <button class="media-nav-btn prev" type="button" aria-label="Trước" data-carousel-prev>
                                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
                            </button>
                            <div class="media-viewport">
                                <div class="media-track" data-carousel-track>
                                    <?php foreach ($videos as $idx => $video) : 
                                        // Extract YouTube video ID for thumbnail
                                        $video_id = '';
                                        if (preg_match('~/embed/([a-zA-Z0-9_-]{11})~', $video['embed'], $matches)) {
                                            $video_id = $matches[1];
                                        }
                                        $thumbnail_url = $video_id ? "https://img.youtube.com/vi/{$video_id}/maxresdefault.jpg" : '';
                                    ?>
                                        <div class="media-slide" data-video-index="<?php echo $idx; ?>">
                                            <div class="video-embed" data-video-container>
                                                <?php if ($thumbnail_url) : ?>
                                                    <img src="<?php echo esc_url($thumbnail_url); ?>" alt="Video thumbnail" class="video-thumbnail">
                                                    <button class="video-play-btn" data-video-src="<?php echo esc_attr($video['embed']); ?>" type="button" aria-label="Phát video">
                                                        <svg width="68" height="48" viewBox="0 0 68 48"><path d="M66.52,7.74c-0.78-2.93-2.49-5.41-5.42-6.19C55.79,.13,34,0,34,0S12.21,.13,6.9,1.55 C3.97,2.33,2.27,4.81,1.48,7.74C0.06,13.05,0,24,0,24s0.06,10.95,1.48,16.26c0.78,2.93,2.49,5.41,5.42,6.19 C12.21,47.87,34,48,34,48s21.79-0.13,27.1-1.55c2.93-0.78,4.64-3.26,5.42-6.19C67.94,34.95,68,24,68,24S67.94,13.05,66.52,7.74z" fill="#f00"></path><path d="M 45,24 27,14 27,34" fill="#fff"></path></svg>
                                                    </button>
                                                <?php else : ?>
                                                    <!-- Fallback: load iframe directly if no thumbnail -->
                                                    <iframe src="<?php echo esc_url($video['embed']); ?>" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen loading="lazy"></iframe>
                                                <?php endif; ?>
                                            </div>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            </div>
                            <button class="media-nav-btn next" type="button" aria-label="Sau" data-carousel-next>
                                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
                            </button>
                        </div>
                        <div class="media-dots" data-carousel-dots>
                            <?php for ($i = 0; $i < count($videos); $i++) : ?>
                                <button class="media-dot" type="button" aria-label="Đi tới video <?php echo esc_attr($i + 1); ?>" data-carousel-dot="<?php echo esc_attr($i); ?>"></button>
                            <?php endfor; ?>
                        </div>
                    <?php else : ?>
                        <div class="section-empty">Chưa có video.</div>
                    <?php endif; ?>

                    <?php if (count($video_links) > 0) : ?>
                        <div class="media-links">
                            <?php foreach ($video_links as $link) : ?>
                                <a class="btn btn-outline" href="<?php echo esc_url($link['url']); ?>" target="_blank" rel="noopener"><?php echo esc_html($link['text']); ?></a>
                            <?php endforeach; ?>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>
    <?php endif; ?>

    <?php if ($fb_reels_enabled && count($fb_reels) > 0) : ?>
    <div class="rls-wrap">
        <div class="rls-inner">
            <button class="rls-btn rls-btn--l" id="rls-l" aria-label="Trước">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
            </button>
            <div class="rls-vp" id="rls-vp" data-fb-reels-grid>
                <div class="rls-tr" id="rls-tr">
                    <?php foreach ($fb_reels as $k => $reel) : ?>
                    <div class="rls-c" data-i="<?php echo $k; ?>" data-u="<?php echo esc_attr($reel['embed_url']); ?>" data-reel-open="<?php echo $k; ?>">
                        <?php if ($reel['thumb']) : ?>
                            <img src="<?php echo esc_url($reel['thumb']); ?>" alt="Reel <?php echo $k+1; ?>">
                        <?php else : ?>
                            <div class="rls-ph"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.5"><polygon points="5 3 19 12 5 21"/></svg></div>
                        <?php endif; ?>
                        <div class="rls-pi"><svg width="22" height="22" viewBox="0 0 24 24" fill="white"><polygon points="5 3 19 12 5 21"/></svg></div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
            <button class="rls-btn rls-btn--r" id="rls-r" aria-label="Sau">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
            </button>
        </div>
    </div>

    <div class="rls-pop" id="fb-reels-popup" style="display:none" aria-hidden="true">
        <button class="rls-x" id="fb-reels-popup-close">&#215;</button>
        <div class="rls-pop-row">
            <button class="rls-pn" id="fb-reels-prev"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg></button>
            <div class="rls-fr">
                <div data-fb-popup-track>
                    <?php foreach ($fb_reels as $k => $reel) : ?>
                    <div class="fb-reels-popup-slide" data-reel-url="<?php echo esc_attr($reel['url']); ?>">
                        <iframe class="fb-reels-popup-iframe" data-src="<?php echo esc_attr($reel['embed_url']); ?>" frameborder="0" allowfullscreen allow="autoplay;clipboard-write;encrypted-media;picture-in-picture;web-share"></iframe>
                        <a href="<?php echo esc_url($reel['url']); ?>" target="_blank" class="fb-reels-mobile-link" style="display:none;">
                            <svg width="40" height="40" viewBox="0 0 24 24" fill="white"><polygon points="5 3 19 12 5 21"/></svg>
                            <span>Xem trên Facebook</span>
                        </a>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
            <button class="rls-pn" id="fb-reels-next"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg></button>
        </div>
        <div class="rls-ct" data-fb-popup-counter id="rls-ct"></div>
    </div>

    <script>
    // Facebook Reels functionality is now handled in main.js
    </script>
    <?php endif; ?>

    <?php if ($partners_enabled) : ?>
        <section class="section container">
            <div class="section-title-center">
                <h2><?php echo esc_html($partners_title); ?></h2>
                <?php if ($partners_subtitle) : ?>
                    <p><?php echo esc_html($partners_subtitle); ?></p>
                <?php endif; ?>
            </div>
            <?php if (count($partners) > 0) : ?>
                <div class="partners-grid">
                    <?php foreach ($partners as $partner) : ?>
                        <?php if ($partner['link_url']) : ?>
                            <a class="partner-item" href="<?php echo esc_url($partner['link_url']); ?>" target="_blank" rel="noopener" title="<?php echo esc_attr($partner['name']); ?>">
                                <img src="<?php echo esc_url($partner['logo_url']); ?>" alt="<?php echo esc_attr($partner['name']); ?>">
                            </a>
                        <?php else : ?>
                            <div class="partner-item" title="<?php echo esc_attr($partner['name']); ?>">
                                <img src="<?php echo esc_url($partner['logo_url']); ?>" alt="<?php echo esc_attr($partner['name']); ?>">
                            </div>
                        <?php endif; ?>
                    <?php endforeach; ?>
                </div>
            <?php else : ?>
                <div class="section-empty">Chưa có đối tác. Thêm logo đối tác trong Customize → Đối Tác.</div>
            <?php endif; ?>
        </section>
    <?php endif; ?>

    <?php if ($marketing_enabled) : ?>
        <section class="section container">
            <div class="section-title">
                <div>
                    <h2><?php echo esc_html($marketing_title); ?></h2>
                    <p><?php echo esc_html($marketing_subtitle); ?></p>
                </div>
            </div>
            <div class="marketing-grid">
                <?php foreach ($marketing_plans as $plan) : ?>
                    <article class="marketing-card">
                        <h3><?php echo esc_html($plan['title']); ?></h3>
                        <p><?php echo esc_html($plan['description']); ?></p>
                        <a href="<?php echo esc_url($plan['button_url']); ?>" class="view-all"><?php echo esc_html($plan['button_text']); ?></a>
                    </article>
                <?php endforeach; ?>
            </div>
        </section>
    <?php endif; ?>

    <?php if ($features_enabled) : ?>
        <section class="icons-section">
            <div class="container icons-grid">
                <?php foreach ($features as $feature) : ?>
                    <div class="icon-item">
                        <div class="icon-circle"><?php echo esc_html($feature['icon']); ?></div>
                        <h4><?php echo esc_html($feature['title']); ?></h4>
                        <p><?php echo esc_html($feature['description']); ?></p>
                    </div>
                <?php endforeach; ?>
            </div>
        </section>
    <?php endif; ?>

    <?php if ($testimonials_enabled) : ?>
        <section class="section container">
            <div class="section-title-center">
                <h2><?php echo esc_html($testimonials_title); ?></h2>
                <p><?php echo esc_html($testimonials_subtitle); ?></p>
            </div>
            <div class="testimonial-grid">
                <?php foreach ($testimonials as $testimonial) : ?>
                    <article class="testimonial-card">
                        <div class="testimonial-photo">
                            <img src="<?php echo esc_url($testimonial['image_url']); ?>" alt="<?php echo esc_attr($testimonial['image_alt']); ?>">
                        </div>
                        <div class="testimonial-quote">
                            <p class="testimonial-text"><?php echo esc_html($testimonial['text']); ?></p>
                            <p class="testimonial-author">— <?php echo esc_html($testimonial['name']); ?><?php if (!empty($testimonial['role'])) : ?> <span class="testimonial-role">(<?php echo esc_html($testimonial['role']); ?>)</span><?php endif; ?></p>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
        </section>
    <?php endif; ?>

    <!-- Feedback Section -->
    <?php
    $supabase_url = ai_quest_get_setting('ai_quest_supabase_url', 'https://cgqxrsoaxgyvcskbixuu.supabase.co');
    $supabase_key = ai_quest_get_setting('ai_quest_supabase_anon_key', 'sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh');
    $store_id     = ai_quest_get_setting('ai_quest_store_id', '');
    ?>
    <section class="section container feedback-section">
        <div class="section-title-center">
            <h2>Góp Ý Của Bạn</h2>
            <p>Chia sẻ ý kiến của bạn để giúp chúng tôi cải thiện dịch vụ</p>
        </div>
        
        <div class="feedback-form-wrapper">
            <div id="feedback-success" style="display:none; background:#e8f5e9; border:1px solid #4caf50; border-radius:8px; padding:16px; margin-bottom:16px; color:#2e7d32; text-align:center;">
                ✅ <strong>Cảm ơn bạn đã gửi góp ý!</strong> Chúng tôi sẽ xem xét và cải thiện dịch vụ.
            </div>
            <div id="feedback-error" style="display:none; background:#ffebee; border:1px solid #f44336; border-radius:8px; padding:16px; margin-bottom:16px; color:#c62828; text-align:center;">
                ❌ Có lỗi xảy ra. Vui lòng thử lại sau.
            </div>

            <form id="feedback-form" class="feedback-form">
                <div class="booking-grid" style="margin-bottom:12px;">
                    <input type="text" name="full_name" placeholder="Họ tên (tùy chọn)" style="padding:12px; border:1px solid #ddd; border-radius:8px; font-size:14px;">
                    <input type="tel" name="phone" placeholder="Số điện thoại (tùy chọn)" style="padding:12px; border:1px solid #ddd; border-radius:8px; font-size:14px;">
                </div>
                <div class="feedback-form-group">
                    <textarea 
                        id="feedback-message" 
                        name="feedback_message" 
                        placeholder="Nhập nội dung góp ý*" 
                        maxlength="500" 
                        required
                    ></textarea>
                    <div class="feedback-char-count">
                        <span id="feedback-char-current">0</span> / 500
                    </div>
                </div>
                
                <button type="submit" class="btn btn-primary feedback-submit-btn" style="background-color: var(--primary-spa) !important; color: #ffffff !important;">
                    <span class="feedback-btn-text" style="color: #ffffff !important;">Gửi Góp Ý</span>
                    <span class="feedback-btn-loading" style="display:none; color: #ffffff !important;">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color: #ffffff !important;">
                            <circle cx="12" cy="12" r="10" opacity="0.25"/>
                            <path d="M12 2 A10 10 0 0 1 22 12" stroke-linecap="round">
                                <animateTransform attributeName="transform" type="rotate" from="0 12 12" to="360 12 12" dur="1s" repeatCount="indefinite"/>
                            </path>
                        </svg>
                        Đang gửi...
                    </span>
                </button>
            </form>
        </div>
    </section>
</main>

<script>
(function() {
    var SUPABASE_URL = <?php echo wp_json_encode($supabase_url); ?>;
    var SUPABASE_KEY = <?php echo wp_json_encode($supabase_key); ?>;
    var STORE_ID     = <?php echo wp_json_encode($store_id); ?>;

    var form       = document.getElementById('feedback-form');
    var textarea   = document.getElementById('feedback-message');
    var charEl     = document.getElementById('feedback-char-current');
    var submitBtn  = form.querySelector('.feedback-submit-btn');
    var btnText    = submitBtn.querySelector('.feedback-btn-text');
    var btnLoading = submitBtn.querySelector('.feedback-btn-loading');
    var successEl  = document.getElementById('feedback-success');
    var errorEl    = document.getElementById('feedback-error');

    // Character counter
    textarea.addEventListener('input', function() {
        charEl.textContent = this.value.length;
    });

    form.addEventListener('submit', function(e) {
        e.preventDefault();

        var message = textarea.value.trim();
        if (!message) return;

        successEl.style.display = 'none';
        errorEl.style.display   = 'none';
        submitBtn.disabled = true;
        btnText.style.display   = 'none';
        btnLoading.style.display = 'flex';

        var payload = {
            lead_type: 'feedback',
            full_name: (form.full_name.value.trim() || 'Ẩn danh'),
            phone:     (form.phone.value.trim() || ''),
            note:      message,
            source:    'website',
            status:    'new'
        };
        if (STORE_ID) payload.store_id = STORE_ID;

        fetch(SUPABASE_URL + '/rest/v1/website_leads', {
            method: 'POST',
            headers: {
                'Content-Type':  'application/json',
                'apikey':        SUPABASE_KEY,
                'Authorization': 'Bearer ' + SUPABASE_KEY,
                'Prefer':        'return=minimal'
            },
            body: JSON.stringify(payload)
        })
        .then(function(res) {
            if (res.ok || res.status === 201) {
                successEl.style.display = 'block';
                form.reset();
                charEl.textContent = '0';
            } else {
                return res.text().then(function(t) { throw new Error(t); });
            }
        })
        .catch(function(err) {
            console.error('Feedback error:', err);
            errorEl.style.display = 'block';
        })
        .finally(function() {
            submitBtn.disabled = false;
            btnText.style.display   = 'inline';
            btnLoading.style.display = 'none';
        });
    });
})();
</script>

<?php get_footer(); ?>
