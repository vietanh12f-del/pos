<?php
get_header();

// Get banner settings without default values
$banner_badge       = ai_quest_get_setting('ai_quest_banner_badge', '');
$banner_title       = ai_quest_get_setting('ai_quest_banner_title', '');
$banner_description = ai_quest_get_setting('ai_quest_banner_description', '');
$banner_button_text = ai_quest_get_setting('ai_quest_banner_button_text', '');
$banner_button_url  = ai_quest_get_setting('ai_quest_banner_button_url', '');
$banner_bg_url      = ai_quest_get_setting('ai_quest_banner_bg_url', '');

// Check if banner has content
$banner_has_content = !empty($banner_title) || !empty($banner_description);
?>

<main id="main">
    <section class="section container">
        <div class="section-title-center">
            <h2>Khuyến Mãi</h2>
        </div>
        
        <?php if ($banner_has_content) : ?>
            <div class="banner-panel" style="background-image: linear-gradient(rgba(0,0,0,.45), rgba(0,0,0,.45)), url('<?php echo esc_url($banner_bg_url); ?>');">
                <?php if ($banner_badge) : ?>
                    <span class="banner-panel-badge"><?php echo esc_html($banner_badge); ?></span>
                <?php endif; ?>
                <?php if ($banner_title) : ?>
                    <h2><?php echo esc_html($banner_title); ?></h2>
                <?php endif; ?>
                <?php if ($banner_description) : ?>
                    <p><?php echo esc_html($banner_description); ?></p>
                <?php endif; ?>
                <?php if ($banner_button_text && $banner_button_url) : ?>
                    <a href="<?php echo esc_url($banner_button_url); ?>" class="btn btn-primary"><?php echo esc_html($banner_button_text); ?></a>
                <?php endif; ?>
            </div>
        <?php else : ?>
            <div class="no-promotions-message" style="text-align: center; padding: 60px 20px; background: #f9f9f9; border-radius: 8px; margin-top: 20px;">
                <p style="font-size: 18px; color: #666; margin: 0;">Hiện tại chưa có chương trình khuyến mãi nào.</p>
                <p style="font-size: 14px; color: #999; margin-top: 10px;">Vui lòng quay lại sau hoặc liên hệ với chúng tôi để biết thêm thông tin.</p>
            </div>
        <?php endif; ?>
    </section>
</main>

<?php get_footer(); ?>
