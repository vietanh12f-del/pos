<?php
get_header();

$page_key = get_query_var('aiq_page', '');
$booking_page_url = ai_quest_page_url('dat-lich');

$svc_pages = array(
    'cham-soc-da' => array('slug' => 'cham_soc_da', 'label' => 'Chăm Sóc Da',  'hero_default' => 'Chăm Sóc Da Chuyên Nghiệp'),
    'triet-long'  => array('slug' => 'triet_long',  'label' => 'Triệt Lông',    'hero_default' => 'Triệt Lông Công Nghệ Cao'),
    'goi-dau'     => array('slug' => 'goi_dau',     'label' => 'Gội Đầu',       'hero_default' => 'Gội Đầu Dưỡng Sinh'),
);

if (!isset($svc_pages[$page_key])) {
    wp_redirect(home_url('/'));
    exit;
}

$page    = $svc_pages[$page_key];
$s       = 'ai_quest_svcpage_' . $page['slug'];

$hero_title    = ai_quest_get_setting($s . '_hero_title',    $page['hero_default']);
$hero_subtitle = ai_quest_get_setting($s . '_hero_subtitle', $page['label']);
$hero_image    = ai_quest_get_setting($s . '_hero_image',    '');

// Load videos
$svc_video_title = ai_quest_get_setting($s . '_video_title', 'Video Thực Tế');
$svc_videos = array();
for ($vi = 1; $vi <= 3; $vi++) {
    $embed = trim((string) ai_quest_get_setting($s . '_video_' . $vi, ''));
    if ($embed === '') continue;
    $svc_videos[] = $embed;
}

// Load sub-categories
$sub_cats = array();
for ($ci = 1; $ci <= 5; $ci++) {
    $cp   = $s . '_sub' . $ci;
    $name = trim((string) ai_quest_get_setting($cp . '_name', ''));
    if ($name === '') continue;

    $services = array();
    for ($si = 1; $si <= 12; $si++) {
        $sp       = $cp . '_svc' . $si;
        $svc_name = trim((string) ai_quest_get_setting($sp . '_name', ''));
        if ($svc_name === '') continue;
        $services[] = array(
            'name'  => $svc_name,
            'price' => ai_quest_get_setting($sp . '_price', ''),
            'badge' => ai_quest_get_setting($sp . '_badge', ''),
        );
    }

    $sub_cats[] = array(
        'name'        => $name,
        'description' => ai_quest_get_setting($cp . '_description', ''),
        'image'       => ai_quest_get_setting($cp . '_image', ''),
        'services'    => $services,
        'index'       => $ci,
    );
}
?>

<main id="main">

    <!-- Hero -->
    <div class="svc-detail-hero" <?php if ($hero_image) : ?>style="background-image:linear-gradient(rgba(255,255,255,0.55),rgba(255,255,255,0.55)),url('<?php echo esc_url($hero_image); ?>')"<?php endif; ?>>
        <div class="container svc-detail-hero-inner">
            <h1><?php echo esc_html($hero_title); ?></h1>
            <p><?php echo esc_html($hero_subtitle); ?></p>
        </div>
    </div>

    <!-- Sub-categories -->
    <?php if (count($sub_cats) > 0) : ?>
        <?php foreach ($sub_cats as $cat) : ?>
            <?php $is_even = ($cat['index'] % 2 === 0); ?>
            <section class="svc-detail-section section container<?php echo $is_even ? ' svc-section-alt' : ''; ?>">
                <div class="svc-detail-row<?php echo $is_even ? ' svc-detail-row--reverse' : ''; ?>">

                    <!-- Text side -->
                    <div class="svc-detail-text">
                        <h2><?php echo esc_html($cat['name']); ?></h2>
                        <?php if ($cat['description']) : ?>
                            <p class="svc-detail-desc"><?php echo esc_html($cat['description']); ?></p>
                        <?php endif; ?>

                        <?php if (count($cat['services']) > 0) : ?>
                            <div class="svc-detail-list">
                                <?php foreach ($cat['services'] as $svc) : ?>
                                    <?php 
                                    // Check if detail article exists
                                    $detail_url = ai_quest_get_service_detail_article_url($svc['name'], $cat['name'], $page_key);
                                    $is_clickable = !empty($detail_url);
                                    ?>
                                    <div class="svc-detail-item<?php echo $is_clickable ? ' clickable' : ''; ?>" 
                                         <?php if ($is_clickable) : ?>
                                         onclick="window.location.href='<?php echo esc_url($detail_url); ?>'"
                                         <?php endif; ?>>
                                        <span class="svc-detail-item-name">
                                            <?php echo esc_html($svc['name']); ?>
                                            <?php if ($is_clickable) : ?>
                                                <svg class="svc-detail-item-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                                    <polyline points="9 18 15 12 9 6"></polyline>
                                                </svg>
                                            <?php endif; ?>
                                        </span>
                                        <span class="svc-detail-item-right">
                                            <?php if ($svc['badge']) : ?>
                                                <span class="svc-detail-item-badge"><?php echo esc_html($svc['badge']); ?></span>
                                            <?php endif; ?>
                                            <?php if ($svc['price']) : ?>
                                                <span class="svc-detail-item-price"><?php echo esc_html($svc['price']); ?></span>
                                            <?php endif; ?>
                                        </span>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>

                        <div class="svc-detail-buttons">
                            <?php 
                            // Check if service article exists for this service
                            $article_url = ai_quest_get_service_article_url($cat['name'], $page_key);
                            ?>
                            
                            <a href="<?php echo $article_url ? esc_url($article_url) : '#'; ?>" 
                               class="svc-detail-view-btn<?php echo !$article_url ? ' disabled' : ''; ?>"
                               <?php echo !$article_url ? 'onclick="alert(\'Nội dung chi tiết đang được cập nhật.\'); return false;"' : ''; ?>>
                                Xem chi tiết
                            </a>
                            
                            <a href="<?php echo esc_url(add_query_arg('service_name', $cat['name'], $booking_page_url)); ?>" class="svc-detail-book-btn">Đặt lịch hẹn</a>
                        </div>
                    </div>

                    <!-- Image side -->
                    <?php if ($cat['image']) : ?>
                        <div class="svc-detail-img">
                            <img src="<?php echo esc_url($cat['image']); ?>" 
                                 alt="<?php echo esc_attr($cat['name']); ?>"
                                 loading="lazy"
                                 decoding="async">
                        </div>
                    <?php endif; ?>

                </div>
            </section>
        <?php endforeach; ?>
    <?php else : ?>
        <section class="section container">
            <div class="section-empty">Đang cập nhật nội dung dịch vụ.</div>
        </section>
    <?php endif; ?>

    <?php if (count($svc_videos) > 0) : ?>
        <section class="section container">
            <div class="section-title-center">
                <h2><?php echo esc_html($svc_video_title); ?></h2>
            </div>
            <div class="media-grid">
                <div class="media-card">
                    <div class="media-carousel media-carousel--video" data-carousel>
                        <button class="media-nav-btn prev" type="button" aria-label="Trước" data-carousel-prev>
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
                        </button>
                        <div class="media-viewport">
                            <div class="media-track" data-carousel-track>
                                <?php foreach ($svc_videos as $embed) : ?>
                                    <div class="media-slide">
                                        <div class="video-embed">
                                            <iframe src="<?php echo esc_url($embed); ?>" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        </div>
                        <button class="media-nav-btn next" type="button" aria-label="Sau" data-carousel-next>
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
                        </button>
                    </div>
                    <?php if (count($svc_videos) > 1) : ?>
                        <div class="media-dots" data-carousel-dots>
                            <?php for ($i = 0; $i < count($svc_videos); $i++) : ?>
                                <button class="media-dot" type="button" aria-label="Video <?php echo esc_attr($i + 1); ?>" data-carousel-dot="<?php echo esc_attr($i); ?>"></button>
                            <?php endfor; ?>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>
    <?php endif; ?>

</main>

<?php get_footer(); ?>
