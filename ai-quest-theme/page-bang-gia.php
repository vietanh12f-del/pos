<?php
get_header();

$pricing_images = array();
for ($i = 1; $i <= 4; $i++) {
    $url = trim((string) ai_quest_get_setting('ai_quest_pricing_image_' . $i . '_url', ''));
    $alt = trim((string) ai_quest_get_setting('ai_quest_pricing_image_' . $i . '_alt', 'Bảng giá dịch vụ ' . $i));
    $pricing_images[] = array('url' => $url, 'alt' => $alt);
}

$has_images = array_filter($pricing_images, fn($img) => $img['url'] !== '');
?>

<main id="main">
    <section class="section container">
        <div class="section-title-center">
            <h2>Bảng Giá</h2>
        </div>

        <?php if (count($has_images) > 0) : ?>
            <div class="pricing-images-grid">
                <?php foreach ($pricing_images as $img) : ?>
                    <?php if ($img['url'] === '') continue; ?>
                    <div class="pricing-image-cell">
                        <img src="<?php echo esc_url($img['url']); ?>" alt="<?php echo esc_attr($img['alt']); ?>">
                    </div>
                <?php endforeach; ?>
            </div>
        <?php else : ?>
            <div class="pricing-empty">Chưa có hình ảnh bảng giá. Vui lòng thêm ảnh trong Customize → Bảng Giá - Hình Ảnh.</div>
        <?php endif; ?>
    </section>
</main>

<?php get_footer(); ?>
