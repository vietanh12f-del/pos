<?php
/**
 * Single Service Detail Article Template
 * Template for individual service detail articles (Bài Viết Chi Tiết DV)
 */

get_header();

while (have_posts()) : the_post();
    
    $service_name = get_post_meta(get_the_ID(), '_service_name', true);
    $parent_service = get_post_meta(get_the_ID(), '_parent_service', true);
    $page_key = get_post_meta(get_the_ID(), '_service_page', true);
    $booking_page_url = ai_quest_page_url('dat-lich');
    
    $page_labels = array(
        'cham-soc-da' => 'Chăm Sóc Da',
        'triet-long' => 'Triệt Lông',
        'goi-dau' => 'Gội Đầu'
    );
    
    $page_label = isset($page_labels[$page_key]) ? $page_labels[$page_key] : '';
    $service_page_url = ai_quest_page_url($page_key);
    
    // Get parent service article URL
    $parent_article_url = ai_quest_get_service_article_url($parent_service, $page_key);
    
    ?>
    
    <main id="main">
        <article class="service-article-single svc-detail-article-single">
            
            <!-- Breadcrumb -->
            <div class="container" style="padding: 20px 0 10px;">
                <div class="breadcrumb">
                    <a href="<?php echo esc_url(home_url('/')); ?>">Trang chủ</a>
                    <span class="sep">›</span>
                    <a href="<?php echo esc_url($service_page_url); ?>"><?php echo esc_html($page_label); ?></a>
                    <span class="sep">›</span>
                    <?php if ($parent_article_url) : ?>
                        <a href="<?php echo esc_url($parent_article_url); ?>"><?php echo esc_html($parent_service); ?></a>
                    <?php else : ?>
                        <span><?php echo esc_html($parent_service); ?></span>
                    <?php endif; ?>
                    <span class="sep">›</span>
                    <span class="current"><?php echo esc_html($service_name); ?></span>
                </div>
            </div>
            
            <!-- Hero Section -->
            <?php if (has_post_thumbnail()) : ?>
                <div class="service-article-hero">
                    <?php the_post_thumbnail('full'); ?>
                    <div class="service-article-hero-overlay">
                        <div class="container">
                            <h1><?php the_title(); ?></h1>
                            <p class="service-article-category">
                                <?php echo esc_html($page_label); ?> › <?php echo esc_html($parent_service); ?>
                            </p>
                        </div>
                    </div>
                </div>
            <?php else : ?>
                <div class="service-article-header container">
                    <p class="service-article-category">
                        <?php echo esc_html($page_label); ?> › <?php echo esc_html($parent_service); ?>
                    </p>
                    <h1><?php the_title(); ?></h1>
                </div>
            <?php endif; ?>
            
            <!-- Content -->
            <div class="container">
                <div class="service-article-content">
                    
                    <!-- Excerpt -->
                    <?php if (has_excerpt()) : ?>
                        <div class="service-article-excerpt">
                            <?php the_excerpt(); ?>
                        </div>
                    <?php endif; ?>
                    
                    <!-- Main Content -->
                    <div class="service-article-body">
                        <?php the_content(); ?>
                    </div>
                    
                    <!-- CTA Section -->
                    <div class="service-article-cta">
                        <h3>Đặt lịch hẹn ngay hôm nay</h3>
                        <p>Liên hệ với chúng tôi để được tư vấn và đặt lịch hẹn cho dịch vụ <strong><?php echo esc_html($service_name); ?></strong>.</p>
                        <div class="service-article-cta-buttons">
                            <?php if ($parent_article_url) : ?>
                                <a href="<?php echo esc_url($parent_article_url); ?>" class="btn-secondary">
                                    ← Quay lại <?php echo esc_html($parent_service); ?>
                                </a>
                            <?php else : ?>
                                <a href="<?php echo esc_url($service_page_url); ?>" class="btn-secondary">
                                    ← Xem tất cả dịch vụ
                                </a>
                            <?php endif; ?>
                            <a href="<?php echo esc_url(add_query_arg('service_name', $service_name, $booking_page_url)); ?>" class="btn-primary">
                                Đặt lịch hẹn →
                            </a>
                        </div>
                    </div>
                    
                    <!-- Related Services (Optional) -->
                    <?php if ($parent_service) : ?>
                        <div class="service-article-related">
                            <h3>Các dịch vụ khác trong <?php echo esc_html($parent_service); ?></h3>
                            <p style="text-align: center; margin-top: 20px;">
                                <?php if ($parent_article_url) : ?>
                                    <a href="<?php echo esc_url($parent_article_url); ?>" class="btn-secondary">
                                        Xem tất cả dịch vụ trong mục này
                                    </a>
                                <?php else : ?>
                                    <a href="<?php echo esc_url($service_page_url); ?>" class="btn-secondary">
                                        Xem tất cả dịch vụ
                                    </a>
                                <?php endif; ?>
                            </p>
                        </div>
                    <?php endif; ?>
                    
                </div>
            </div>
            
        </article>
    </main>
    
    <?php
    
endwhile;

get_footer();
?>
