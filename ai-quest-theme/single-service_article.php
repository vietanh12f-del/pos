<?php
/**
 * Single Service Article Template
 */

get_header();

while (have_posts()) : the_post();
    
    $service_name = get_post_meta(get_the_ID(), '_service_name', true);
    $page_key = get_post_meta(get_the_ID(), '_service_page', true);
    $booking_page_url = ai_quest_page_url('dat-lich');
    
    $page_labels = array(
        'cham-soc-da' => 'Chăm Sóc Da',
        'triet-long' => 'Triệt Lông',
        'goi-dau' => 'Gội Đầu'
    );
    
    $page_label = isset($page_labels[$page_key]) ? $page_labels[$page_key] : '';
    $service_page_url = ai_quest_page_url($page_key);
    
    ?>
    
    <main id="main">
        <article class="service-article-single">
            
            <!-- Breadcrumb -->
            <div class="container" style="padding: 20px 0 10px;">
                <div class="breadcrumb">
                    <a href="<?php echo esc_url(home_url('/')); ?>">Trang chủ</a>
                    <span class="sep">›</span>
                    <a href="<?php echo esc_url($service_page_url); ?>"><?php echo esc_html($page_label); ?></a>
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
                            <?php if ($page_label) : ?>
                                <p class="service-article-category"><?php echo esc_html($page_label); ?></p>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            <?php else : ?>
                <!-- No featured image, show title inside content area -->
            <?php endif; ?>
            
            <!-- Content -->
            <div class="container">
                <?php 
                // Get related service detail articles
                $detail_articles = ai_quest_get_service_detail_articles($service_name, $page_key);
                $has_sidebar = !empty($detail_articles);
                ?>
                
                <div class="service-article-layout <?php echo $has_sidebar ? 'has-sidebar' : 'no-sidebar'; ?>">
                    
                    <?php if ($has_sidebar) : ?>
                        <!-- Sidebar: Service Detail List -->
                        <aside class="service-article-sidebar">
                            <div class="service-detail-menu">
                                <h3 class="service-detail-menu-title">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
                                    </svg>
                                    <?php echo esc_html($service_name); ?>
                                </h3>
                                <div class="service-detail-menu-list">
                                    <?php foreach ($detail_articles as $article) : ?>
                                        <a href="<?php echo esc_url($article['url']); ?>" 
                                           class="service-detail-menu-item <?php echo (get_the_ID() === $article['id']) ? 'active' : ''; ?>">
                                            <span class="service-detail-menu-item-icon">
                                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                                    <polyline points="9 18 15 12 9 6"></polyline>
                                                </svg>
                                            </span>
                                            <span class="service-detail-menu-item-text">
                                                <?php echo esc_html($article['title']); ?>
                                            </span>
                                        </a>
                                    <?php endforeach; ?>
                                </div>
                            </div>
                        </aside>
                    <?php endif; ?>
                    
                    <!-- Main Content -->
                    <div class="service-article-content <?php echo $has_sidebar ? 'has-sidebar' : ''; ?>">
                    
                    <?php if (!has_post_thumbnail()) : ?>
                        <!-- Title inside content when no featured image -->
                        <div class="service-article-header-inline">
                            <?php if ($page_label) : ?>
                                <p class="service-article-category"><?php echo esc_html($page_label); ?></p>
                            <?php endif; ?>
                            <h1><?php the_title(); ?></h1>
                        </div>
                    <?php endif; ?>
                    
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
                            <a href="<?php echo esc_url($service_page_url); ?>" class="btn-secondary">
                                ← Xem tất cả dịch vụ
                            </a>
                            <a href="<?php echo esc_url(add_query_arg('service_name', $service_name, $booking_page_url)); ?>" class="btn-primary">
                                Đặt lịch hẹn →
                            </a>
                        </div>
                    </div>
                    
                </div><!-- .service-article-content -->
                
            </div><!-- .service-article-layout -->
        </div><!-- .container -->
            
        </article>
    </main>
    
    <?php
    
endwhile;

get_footer();
?>
