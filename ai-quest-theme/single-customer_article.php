<?php
/**
 * Template for single customer article post
 */
get_header();

if (have_posts()) :
    while (have_posts()) : the_post();
        $post_type = get_post_type();
        $category_name = ($post_type === 'expert_article') ? 'Chia Sẻ Từ Chuyên Gia' : 'Chia Sẻ Từ Khách Hàng';
        $category_slug = ($post_type === 'expert_article') ? 'tu-chuyen-gia' : 'tu-khach-hang';
        $category_url = ai_quest_page_url($category_slug);
        $author_name = get_the_author();
        $post_date = get_the_date('d/m/Y');
        ?>
        
        <main id="main">
            <article class="article-single">
                <!-- Breadcrumb -->
                <div class="container">
                    <nav class="breadcrumb">
                        <a href="<?php echo home_url('/'); ?>">Trang chủ</a>
                        <span class="separator">/</span>
                        <a href="<?php echo ai_quest_page_url('chia-se'); ?>">Chia sẻ</a>
                        <span class="separator">/</span>
                        <a href="<?php echo esc_url($category_url); ?>"><?php echo esc_html($category_name); ?></a>
                        <span class="separator">/</span>
                        <span class="current"><?php the_title(); ?></span>
                    </nav>
                </div>

                <!-- Article Header -->
                <header class="article-header section container">
                    <div class="article-category">
                        <a href="<?php echo esc_url($category_url); ?>">
                            <?php echo esc_html($category_name); ?>
                        </a>
                    </div>
                    
                    <h1 class="article-title"><?php the_title(); ?></h1>
                    
                    <div class="article-meta">
                        <span class="article-author">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                                <circle cx="12" cy="7" r="4"></circle>
                            </svg>
                            <?php echo esc_html($author_name); ?>
                        </span>
                        <span class="article-date">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                                <line x1="16" y1="2" x2="16" y2="6"></line>
                                <line x1="8" y1="2" x2="8" y2="6"></line>
                                <line x1="3" y1="10" x2="21" y2="10"></line>
                            </svg>
                            <?php echo esc_html($post_date); ?>
                        </span>
                    </div>
                </header>

                <!-- Article Content -->
                <div class="article-content section container">
                    <div class="article-body">
                        <?php the_content(); ?>
                    </div>
                </div>

                <!-- Article Footer -->
                <footer class="article-footer section container">
                    <div class="article-navigation">
                        <?php
                        $prev_post = get_previous_post();
                        $next_post = get_next_post();
                        ?>
                        
                        <?php if ($prev_post) : ?>
                            <a href="<?php echo get_permalink($prev_post); ?>" class="article-nav-link prev">
                                <span class="nav-label">← Bài trước</span>
                                <span class="nav-title"><?php echo esc_html($prev_post->post_title); ?></span>
                            </a>
                        <?php endif; ?>
                        
                        <?php if ($next_post) : ?>
                            <a href="<?php echo get_permalink($next_post); ?>" class="article-nav-link next">
                                <span class="nav-label">Bài sau →</span>
                                <span class="nav-title"><?php echo esc_html($next_post->post_title); ?></span>
                            </a>
                        <?php endif; ?>
                    </div>
                    
                    <div class="article-back-link">
                        <a href="<?php echo esc_url($category_url); ?>" class="btn btn-outline">
                            ← Quay lại <?php echo esc_html($category_name); ?>
                        </a>
                    </div>
                </footer>
            </article>
        </main>
        
        <?php
    endwhile;
endif;

get_footer();
?>
