<?php
/**
 * Template for Từ Chuyên Gia page
 */
get_header();

// Get hero image and text
$hero_image = ai_quest_get_setting('ai_quest_expert_hero_image', '');
$hero_title = ai_quest_get_setting('ai_quest_expert_hero_title', 'Chia Sẻ Từ Chuyên Gia');
$hero_subtitle = ai_quest_get_setting('ai_quest_expert_hero_subtitle', 'Kiến thức và kinh nghiệm từ các chuyên gia làm đẹp hàng đầu');

// Get pagination
$paged = (get_query_var('paged')) ? get_query_var('paged') : 1;

// Query expert articles
$args = array(
    'post_type' => 'expert_article',
    'posts_per_page' => 9,
    'paged' => $paged,
    'orderby' => 'date',
    'order' => 'DESC',
);

$expert_query = new WP_Query($args);
?>

<main id="main">
    <?php if ($hero_image) : ?>
        <!-- Hero Section -->
        <section class="sharing-hero" style="background-image: url('<?php echo esc_url($hero_image); ?>');">
            <div class="sharing-hero-overlay"></div>
            <div class="container">
                <div class="sharing-hero-content">
                    <h1><?php echo esc_html($hero_title); ?></h1>
                    <p><?php echo esc_html($hero_subtitle); ?></p>
                </div>
            </div>
        </section>
    <?php endif; ?>

    <section class="section container">
        <?php if (!$hero_image) : ?>
            <!-- Page Header (if no hero image) -->
            <div class="section-title-center">
                <h1><?php echo esc_html($hero_title); ?></h1>
                <p><?php echo esc_html($hero_subtitle); ?></p>
            </div>
        <?php endif; ?>

        <!-- Articles Grid -->
        <?php if ($expert_query->have_posts()) : ?>
            <div class="articles-grid">
                <?php while ($expert_query->have_posts()) : $expert_query->the_post(); ?>
                    <article class="article-card">
                        <?php if (has_post_thumbnail()) : ?>
                            <a href="<?php the_permalink(); ?>" class="article-card-image">
                                <?php the_post_thumbnail('medium'); ?>
                            </a>
                        <?php endif; ?>
                        
                        <div class="article-card-content">
                            <h3 class="article-card-title">
                                <a href="<?php the_permalink(); ?>"><?php the_title(); ?></a>
                            </h3>
                            
                            <?php if (has_excerpt()) : ?>
                                <p class="article-card-excerpt"><?php echo wp_trim_words(get_the_excerpt(), 20); ?></p>
                            <?php endif; ?>
                            
                            <div class="article-card-meta">
                                <span class="article-card-date"><?php echo get_the_date('d/m/Y'); ?></span>
                                <a href="<?php the_permalink(); ?>" class="article-card-link">Đọc thêm →</a>
                            </div>
                        </div>
                    </article>
                <?php endwhile; ?>
            </div>

            <!-- Pagination -->
            <?php
            $total_pages = $expert_query->max_num_pages;
            if ($total_pages > 1) :
                ?>
                <div class="pagination">
                    <?php
                    echo paginate_links(array(
                        'total' => $total_pages,
                        'current' => $paged,
                        'prev_text' => '← Trước',
                        'next_text' => 'Sau →',
                        'base' => ai_quest_page_url('tu-chuyen-gia') . '%_%',
                        'format' => 'page/%#%/',
                    ));
                    ?>
                </div>
            <?php endif; ?>
            
            <?php wp_reset_postdata(); ?>
        <?php else : ?>
            <div class="section-empty">
                <p>Chưa có bài viết nào.</p>
                <a href="<?php echo admin_url('post-new.php?post_type=expert_article'); ?>" class="btn btn-primary">Thêm Bài Viết Đầu Tiên</a>
            </div>
        <?php endif; ?>
    </section>
</main>

<style>
/* Hero Section */
.sharing-hero {
    position: relative;
    height: 400px;
    background-size: cover;
    background-position: center;
    background-repeat: no-repeat;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 60px;
}

.sharing-hero-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.3);
}

.sharing-hero-content {
    position: relative;
    z-index: 2;
    text-align: center;
    color: white;
    max-width: 800px;
    padding: 0 20px;
}

.sharing-hero-content h1 {
    font-size: 48px;
    font-weight: 700;
    margin: 0 0 20px;
    text-shadow: 0 2px 10px rgba(0,0,0,0.5);
}

.sharing-hero-content p {
    font-size: 20px;
    line-height: 1.6;
    margin: 0;
    text-shadow: 0 1px 5px rgba(0,0,0,0.5);
}

@media (max-width: 768px) {
    .sharing-hero {
        height: 300px;
        margin-bottom: 40px;
    }
    
    .sharing-hero-content h1 {
        font-size: 32px;
        margin-bottom: 15px;
    }
    
    .sharing-hero-content p {
        font-size: 16px;
    }
}
</style>

<?php get_footer(); ?>
