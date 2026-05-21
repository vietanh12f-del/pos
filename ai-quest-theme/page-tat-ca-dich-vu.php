<?php
get_header();

$fallback_image_url = 'https://images.unsplash.com/photo-1540555700478-4be289fbecee?auto=format&fit=crop&q=80&w=1200';
$booking_page_url = ai_quest_page_url('dat-lich');
$services = array();

$default_badges = array(1 => 'HOT', 2 => 'POPULAR', 3 => '', 4 => '', 5 => '');
$default_weights = array(1 => '60 PHÚT', 2 => '90 PHÚT', 3 => '45 PHÚT', 4 => '120 PHÚT', 5 => '60 PHÚT');
$default_names = array(1 => 'Massage Body Tinh Dầu', 2 => 'Chăm Sóc Da Chuyên Sâu', 3 => 'Gội Đầu Dưỡng Sinh', 4 => 'Combo Beauty & Spa', 5 => 'Detox Da Mặt Thải Độc');
$default_descriptions = array(1 => 'Liệu pháp thư giãn sâu giúp giảm căng thẳng mệt mỏi và tái tạo năng lượng.', 2 => 'Quy trình detox và cấp ẩm tầng sâu giúp làn da sáng khỏe rạng rỡ.', 3 => '', 4 => '', 5 => '');
$default_prices = array(1 => '350.000đ', 2 => '550.000đ', 3 => '150.000đ', 4 => '850.000đ', 5 => '250.000đ');
$default_images = array(
    1 => 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?auto=format&fit=crop&q=80&w=1200',
    2 => 'https://images.unsplash.com/photo-1512290923902-8a9f81dc236c?auto=format&fit=crop&q=80&w=1200',
    3 => 'https://images.unsplash.com/photo-1560750588-73207b1ef5b8?auto=format&fit=crop&q=80&w=1200',
    4 => 'https://images.unsplash.com/photo-1519823551278-64ac92734fb1?auto=format&fit=crop&q=80&w=1200',
    5 => 'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?auto=format&fit=crop&q=80&w=1200',
);
$default_image_alts = array(1 => 'Massage Body Tinh Dầu', 2 => 'Chăm Sóc Da Chuyên Sâu', 3 => 'Gội Đầu Dưỡng Sinh', 4 => 'Combo Beauty & Spa', 5 => 'Detox Da Mặt Thải Độc');

for ($i = 1; $i <= 20; $i++) {
    $default_badge = isset($default_badges[$i]) ? $default_badges[$i] : '';
    $default_weight = isset($default_weights[$i]) ? $default_weights[$i] : '';
    $default_name = isset($default_names[$i]) ? $default_names[$i] : '';
    $default_description = isset($default_descriptions[$i]) ? $default_descriptions[$i] : '';
    $default_price = isset($default_prices[$i]) ? $default_prices[$i] : '';
    $default_image = isset($default_images[$i]) ? $default_images[$i] : '';
    $default_image_alt = isset($default_image_alts[$i]) ? $default_image_alts[$i] : '';

    $has_default_name = trim((string) $default_name) !== '';
    $show_all_default = $has_default_name ? 1 : 0;
    $show_all = (int) ai_quest_get_setting('ai_quest_product_' . $i . '_show_all', $show_all_default);
    if (!$show_all) {
        continue;
    }

    $name = (string) ai_quest_get_setting('ai_quest_product_' . $i . '_name', $default_name);
    if (trim($name) === '') {
        continue;
    }

    $image_url = (string) ai_quest_get_setting('ai_quest_product_' . $i . '_image_url', $default_image);

    $services[] = array(
        'id' => $i,
        'badge' => ai_quest_get_setting('ai_quest_product_' . $i . '_badge', $default_badge),
        'weight' => ai_quest_get_setting('ai_quest_product_' . $i . '_weight', $default_weight),
        'name' => $name,
        'description' => ai_quest_get_setting('ai_quest_product_' . $i . '_description', $default_description),
        'price' => ai_quest_get_setting('ai_quest_product_' . $i . '_price', $default_price),
        'url' => ai_quest_get_setting('ai_quest_product_' . $i . '_url', '#'),
        'booking_url' => add_query_arg(array(
            'service_id' => $i,
            'service_name' => $name,
        ), $booking_page_url),
        'image_url' => $image_url ? $image_url : $fallback_image_url,
        'image_alt' => ai_quest_get_setting('ai_quest_product_' . $i . '_image_alt', $default_image_alt),
    );
}
?>

<main id="main">
    <section class="section container">
        <div class="section-title-center">
            <h2>Tất cả dịch vụ</h2>
            <p>Khám phá toàn bộ dịch vụ hiện có.</p>
        </div>

        <?php if (count($services) > 0) : ?>
            <div class="service-grid service-grid--all">
                <?php foreach ($services as $service) : ?>
                    <article class="service-card" data-service-id="<?php echo esc_attr($service['id']); ?>">
                        <div class="service-img">
                            <img src="<?php echo esc_url($service['image_url']); ?>" alt="<?php echo esc_attr($service['image_alt']); ?>">
                        </div>
                        <div class="service-content">
                            <h3 class="service-name"><?php echo esc_html($service['name']); ?></h3>
                            <div class="service-meta-box">
                                <div class="meta-item">
                                    <span class="meta-label">GIÁ DỊCH VỤ</span>
                                    <span class="meta-value"><?php echo esc_html($service['price']); ?></span>
                                </div>
                                <div class="meta-divider"></div>
                                <div class="meta-item">
                                    <span class="meta-label">THỜI GIAN</span>
                                    <span class="meta-value"><?php echo esc_html($service['weight']); ?></span>
                                </div>
                            </div>
                            <p class="service-excerpt"><?php echo esc_html($service['description']); ?></p>

                            <div class="service-card-footer">
                                <span>HENIE SKINLAB</span>
                                <span>henieskinlab.com</span>
                                <span>096 235 94 65</span>
                            </div>
                        </div>
                        <button class="btn-service-detail"><?php echo esc_html($service['name']); ?></button>
                        <script type="application/json" class="service-full-data">
                            <?php echo wp_json_encode($service); ?>
                        </script>
                    </article>
                <?php endforeach; ?>
            </div>
        <?php else : ?>
            <div class="section-empty">Chưa có dịch vụ.</div>
        <?php endif; ?>
    </section>
</main>

<?php
get_footer();
?>
