<?php
if (is_front_page()) {
    locate_template('front-page.php', true);
    return;
}

get_header();
?>

<main id="main">
    <div class="container section">
        <?php if (have_posts()) : while (have_posts()) : the_post(); ?>
            <article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
                <h1><?php the_title(); ?></h1>
                <div class="entry-content">
                    <?php the_content(); ?>
                </div>
            </article>
        <?php endwhile; endif; ?>
    </div>
</main>

<?php get_footer(); ?>
