<?php
get_header();

$svc_cat_page_urls = array(
    1 => ai_quest_page_url('cham-soc-da'),
    2 => ai_quest_page_url('triet-long'),
    3 => ai_quest_page_url('goi-dau'),
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

<main id="main">
    <section class="section container">
        <div class="section-title-center">
            <h2>Dịch Vụ Của Henie Skinlab</h2>
            <p>Khám phá các dịch vụ chăm sóc sắc đẹp chuyên nghiệp tại Henie Skinlab.</p>
        </div>

        <div class="svc-cat-grid svc-cat-count-<?php echo count($svc_cats); ?>">
            <?php foreach ($svc_cats as $cat) : ?>
                <div class="svc-cat-card">
                    <div class="svc-cat-img">
                        <?php if ($cat['image_url']) : ?>
                            <img src="<?php echo esc_url($cat['image_url']); ?>" 
                                 alt="<?php echo esc_attr($cat['name']); ?>"
                                 loading="lazy"
                                 decoding="async">
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
</main>

<?php get_footer(); ?>
