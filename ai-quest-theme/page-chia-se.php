<?php
/**
 * Template for Chia Sẻ page
 */
get_header();

// Get latest articles from each category
$expert_articles = new WP_Query(array(
    'post_type' => 'expert_article',
    'posts_per_page' => 3,
    'orderby' => 'date',
    'order' => 'DESC',
));

$customer_articles = new WP_Query(array(
    'post_type' => 'customer_article',
    'posts_per_page' => 3,
    'orderby' => 'date',
    'order' => 'DESC',
));

$expert_count = wp_count_posts('expert_article')->publish;
$customer_count = wp_count_posts('customer_article')->publish;

// Get hero images
$expert_hero_image = ai_quest_get_setting('ai_quest_expert_hero_image', '');
$customer_hero_image = ai_quest_get_setting('ai_quest_customer_hero_image', '');

$categories = array(
    array(
        'name' => 'Chia Sẻ Từ Chuyên Gia',
        'description' => 'Kiến thức và kinh nghiệm từ các chuyên gia làm đẹp hàng đầu',
        'icon' => '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>',
        'button_url' => ai_quest_page_url('tu-chuyen-gia'),
        'button_text' => 'Xem Tất Cả',
        'count' => $expert_count,
        'articles' => $expert_articles,
        'hero_image' => $expert_hero_image,
    ),
    array(
        'name' => 'Chia Sẻ Từ Khách Hàng',
        'description' => 'Trải nghiệm và chia sẻ thực tế từ khách hàng của Henie Skinlab',
        'icon' => '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>',
        'button_url' => ai_quest_page_url('tu-khach-hang'),
        'button_text' => 'Xem Tất Cả',
        'count' => $customer_count,
        'articles' => $customer_articles,
        'hero_image' => $customer_hero_image,
    ),
);
?>

<main id="main">
    <section class="section container">
        <div class="section-title-center">
            <h1>Chia Sẻ</h1>
            <p>Khám phá kiến thức từ chuyên gia và trải nghiệm từ khách hàng</p>
        </div>

        <div class="sharing-categories">
            <?php foreach ($categories as $category) : ?>
                <div class="sharing-category-section">
                    <!-- Category Header -->
                    <div class="sharing-category-header" <?php if (!empty($category['hero_image'])) : ?>style="background-image: url('<?php echo esc_url($category['hero_image']); ?>'); background-size: cover; background-position: center;"<?php endif; ?>>
                        <?php if (!empty($category['hero_image'])) : ?>
                            <div class="sharing-category-header-overlay"></div>
                        <?php endif; ?>
                        <div class="sharing-category-icon">
                            <?php echo $category['icon']; ?>
                        </div>
                        <div class="sharing-category-info">
                            <h2><?php echo esc_html($category['name']); ?></h2>
                            <p><?php echo esc_html($category['description']); ?></p>
                            <div class="sharing-category-meta">
                                <span class="sharing-count"><?php echo esc_html($category['count']); ?> bài viết</span>
                            </div>
                        </div>
                        <div class="sharing-category-action">
                            <a href="<?php echo esc_url($category['button_url']); ?>" class="btn btn-primary">
                                <?php echo esc_html($category['button_text']); ?> →
                            </a>
                        </div>
                    </div>

                    <!-- Latest Articles Preview -->
                    <?php if ($category['articles']->have_posts()) : ?>
                        <div class="sharing-hanging-bar"></div>
                        <div class="sharing-preview-grid">
                            <?php while ($category['articles']->have_posts()) : $category['articles']->the_post(); ?>
                                <article class="sharing-preview-card">
                                    <?php if (has_post_thumbnail()) : ?>
                                        <a href="<?php the_permalink(); ?>" class="sharing-preview-image">
                                            <?php the_post_thumbnail('medium'); ?>
                                        </a>
                                    <?php endif; ?>
                                    
                                    <div class="sharing-preview-content">
                                        <h3 class="sharing-preview-title">
                                            <a href="<?php the_permalink(); ?>"><?php the_title(); ?></a>
                                        </h3>
                                        
                                        <?php if (has_excerpt()) : ?>
                                            <p class="sharing-preview-excerpt"><?php echo wp_trim_words(get_the_excerpt(), 15); ?></p>
                                        <?php endif; ?>
                                        
                                        <div class="sharing-preview-meta">
                                            <span class="sharing-preview-date"><?php echo get_the_date('d/m/Y'); ?></span>
                                            <a href="<?php the_permalink(); ?>" class="sharing-preview-link">Đọc thêm →</a>
                                        </div>
                                    </div>
                                </article>
                            <?php endwhile; ?>
                            <?php wp_reset_postdata(); ?>
                        </div>
                    <?php else : ?>
                        <div class="sharing-empty">
                            <p>Chưa có bài viết nào trong mục này.</p>
                        </div>
                    <?php endif; ?>
                </div>
            <?php endforeach; ?>
        </div>
    </section>
</main>

<style>
.sharing-categories {
    margin-top: 48px;
}

.sharing-category-section {
    margin-bottom: 100px;
    padding-bottom: 0;
    border-bottom: none;
}

.sharing-category-section:last-child {
    margin-bottom: 0;
}

.sharing-category-header {
    position: relative;
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 24px;
    margin-bottom: 0;
    padding: 80px 40px;
    min-height: 400px;
    background: linear-gradient(135deg, #f8f9fa 0%, #ffffff 100%);
    border-radius: 20px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.08);
    overflow: visible;
}

.sharing-category-header-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.3);
    z-index: 1;
    border-radius: 20px;
}

.sharing-category-icon {
    display: none;
}

.sharing-category-info {
    position: relative;
    z-index: 2;
    flex: 1;
}

.sharing-category-info h2 {
    margin: 0 0 12px;
    font-size: 32px;
    font-weight: 700;
    color: var(--text-primary);
}

/* When header has background image */
.sharing-category-header[style*="background-image"] .sharing-category-info h2,
.sharing-category-header[style*="background-image"] .sharing-category-info p {
    color: white;
    text-shadow: 0 2px 10px rgba(0,0,0,0.5);
}

.sharing-category-header[style*="background-image"] .sharing-count {
    background: rgba(255, 255, 255, 0.9);
    color: var(--primary-spa);
}

.sharing-category-info p {
    margin: 0 0 16px;
    font-size: 17px;
    color: var(--text-secondary);
    line-height: 1.6;
}

.sharing-category-meta {
    position: relative;
    z-index: 2;
    display: flex;
    align-items: center;
    gap: 16px;
}

.sharing-count {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background: white;
    border-radius: 20px;
    font-size: 14px;
    font-weight: 600;
    color: var(--primary-spa);
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.sharing-category-action {
    position: absolute;
    bottom: 40px;
    right: 40px;
    z-index: 2;
}

/* Category Label - Hidden */
.sharing-category-label {
    display: none;
}

/* Thanh treo chữ U đơn giản - độ dày đều nhau */
.sharing-hanging-bar {
    position: relative;
    height: 60px;
    margin: -10px 10% 0;
    border-left: 5px solid var(--primary-spa);
    border-right: 5px solid var(--primary-spa);
    border-bottom: 5px solid var(--primary-spa);
    border-top: none;
    border-radius: 0 0 15px 15px;
}

/* Móc tròn trái gắn vào header */
.sharing-hanging-bar::before {
    content: '';
    position: absolute;
    top: -15px;
    left: -10.5px;
    width: 16px;
    height: 16px;
    background: var(--primary-spa);
    border-radius: 50%;
    box-shadow: 0 2px 6px rgba(107, 125, 58, 0.4);
}

/* Móc tròn phải gắn vào header */
.sharing-hanging-bar::after {
    content: '';
    position: absolute;
    top: -15px;
    right: -10.5px;
    width: 16px;
    height: 16px;
    background: var(--primary-spa);
    border-radius: 50%;
    box-shadow: 0 2px 6px rgba(107, 125, 58, 0.4);
}

/* Preview Grid - Hanging design */
.sharing-preview-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 24px;
    position: relative;
    padding: 40px 32px 32px;
    margin: 0 10%;
}

/* Wrapper cho card */
.sharing-preview-card {
    background: white;
    border-radius: 12px;
    overflow: visible;
    box-shadow: 0 4px 16px rgba(0,0,0,0.12);
    transition: all 0.3s ease;
    border: 1px solid #e5e5e5;
    position: relative;
}

/* Dây treo từ thanh U xuống card */
.sharing-preview-card::before {
    content: '';
    position: absolute;
    top: -35px;
    left: 50%;
    transform: translateX(-50%);
    width: 3px;
    height: 30px;
    background: var(--primary-spa);
    z-index: 2;
}

/* Móc treo gắn vào thanh U */
.sharing-preview-card::after {
    content: '';
    position: absolute;
    top: -45px;
    left: 50%;
    transform: translateX(-50%);
    width: 12px;
    height: 12px;
    background: var(--primary-spa);
    border-radius: 50%;
    border: 2px solid white;
    box-shadow: 0 2px 6px rgba(107, 125, 58, 0.5);
    z-index: 3;
}

.sharing-preview-card:hover {
    transform: translateY(-8px);
    box-shadow: 0 8px 24px rgba(107, 125, 58, 0.25);
    border-color: var(--primary-spa);
}

/* Hiệu ứng swing khi hover */
.sharing-preview-card:hover::before {
    animation: swing 0.6s ease-in-out;
}

@keyframes swing {
    0%, 100% { transform: translateX(-50%) rotate(0deg); transform-origin: top center; }
    25% { transform: translateX(-50%) rotate(3deg); transform-origin: top center; }
    75% { transform: translateX(-50%) rotate(-3deg); transform-origin: top center; }
}

.sharing-preview-image {
    display: block;
    aspect-ratio: 16 / 9;
    overflow: hidden;
    border-radius: 12px 12px 0 0;
}

.sharing-preview-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 0.3s;
}

.sharing-preview-card:hover .sharing-preview-image img {
    transform: scale(1.05);
}

.sharing-preview-content {
    padding: 20px;
}

.sharing-preview-title {
    margin: 0 0 12px;
    font-size: 16px;
    font-weight: 600;
    line-height: 1.4;
}

.sharing-preview-title a {
    color: var(--text-primary);
    text-decoration: none;
    transition: color 0.2s;
}

.sharing-preview-title a:hover {
    color: var(--primary-spa);
}

.sharing-preview-excerpt {
    margin: 0 0 16px;
    font-size: 14px;
    line-height: 1.6;
    color: var(--text-secondary);
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

.sharing-preview-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 13px;
}

.sharing-preview-date {
    color: var(--text-secondary);
}

.sharing-preview-link {
    color: var(--primary-spa);
    text-decoration: none;
    font-weight: 500;
    transition: color 0.2s;
}

.sharing-preview-link:hover {
    color: var(--primary-spa-dark);
}

.sharing-empty {
    padding: 40px;
    text-align: center;
    background: var(--bg-light);
    border-radius: 12px;
    color: var(--text-secondary);
}

/* Mobile Responsive */
@media (max-width: 991px) {
    .sharing-category-header {
        flex-wrap: wrap;
        min-height: 200px;
        padding: 48px 32px;
    }
    
    .sharing-category-icon {
        width: 80px;
        height: 80px;
    }
    
    .sharing-category-action {
        position: relative;
        bottom: auto;
        right: auto;
        width: 100%;
        margin-top: 16px;
    }
    
    .sharing-category-action .btn {
        width: 100%;
        text-align: center;
    }
    
    /* Ẩn thanh treo trên mobile */
    .sharing-hanging-bar {
        display: none;
    }
    
    /* Grid dọc - các bài viết */
    .sharing-preview-grid {
        grid-template-columns: 1fr;
        gap: 24px;
        padding: 32px;
        margin: 0;
    }
    
    /* Bỏ thanh treo và móc trên mobile */
    .sharing-preview-grid::before,
    .sharing-preview-grid::after {
        display: none;
    }
    
    /* Bỏ dây treo và móc của card */
    .sharing-preview-card::before,
    .sharing-preview-card::after {
        display: none;
    }
}

@media (max-width: 768px) {
    .sharing-category-header {
        padding: 40px 24px;
        min-height: 180px;
    }
    
    .sharing-category-icon {
        width: 70px;
        height: 70px;
    }
    
    .sharing-category-icon svg {
        width: 36px;
        height: 36px;
    }
    
    .sharing-category-info h2 {
        font-size: 26px;
    }
    
    .sharing-category-info p {
        font-size: 15px;
    }
    
    .sharing-preview-grid {
        padding: 24px;
        gap: 20px;
    }
    
    .sharing-category-section {
        margin-bottom: 80px;
    }
}
</style>

<?php get_footer(); ?>
