<?php
get_header();

$brand_name = ai_quest_get_setting('ai_quest_footer_brand_name', 'Henie Skinlab');

// Background image for entire page - prioritize upload over URL
$about_hero_image = ai_quest_get_setting('ai_quest_about_hero_image', '');
if (empty($about_hero_image)) {
    $about_hero_image = ai_quest_get_setting('ai_quest_about_hero_image_url', '');
}

// Get content for 3 sections
$about_section_1_title = trim((string) ai_quest_get_setting('ai_quest_about_section_1_title', 'Nghệ Thuật Chăm Sóc Từ Tâm'));
$about_section_1_content = trim((string) ai_quest_get_setting('ai_quest_about_section_1_content', ''));
$about_section_1_image = ai_quest_get_setting('ai_quest_about_section_1_image', '');
$about_section_1_button_text = trim((string) ai_quest_get_setting('ai_quest_about_section_1_button_text', 'Liên Hệ Tư Vấn'));
$about_section_1_button_url = ai_quest_get_setting('ai_quest_about_section_1_button_url', '#');
if (empty($about_section_1_button_url)) {
    $about_section_1_button_url = '#'; // Will trigger consult popup
}

$about_section_2_title = trim((string) ai_quest_get_setting('ai_quest_about_section_2_title', 'Vẻ Đẹp Cân Bằng Hoàn Hảo'));
$about_section_2_content = trim((string) ai_quest_get_setting('ai_quest_about_section_2_content', ''));
$about_section_2_image = ai_quest_get_setting('ai_quest_about_section_2_image', '');
$about_section_2_button_text = trim((string) ai_quest_get_setting('ai_quest_about_section_2_button_text', 'Xem Dịch Vụ'));
$about_section_2_button_url = ai_quest_get_setting('ai_quest_about_section_2_button_url', ai_quest_page_url('dich-vu'));
if (empty($about_section_2_button_url)) {
    $about_section_2_button_url = ai_quest_page_url('dich-vu');
}

$about_section_3_title = trim((string) ai_quest_get_setting('ai_quest_about_section_3_title', 'Triết Lý Của Chúng Tôi'));
$about_section_3_content = trim((string) ai_quest_get_setting('ai_quest_about_section_3_content', ''));
$about_section_3_image = ai_quest_get_setting('ai_quest_about_section_3_image', '');
$about_section_3_button_text = trim((string) ai_quest_get_setting('ai_quest_about_section_3_button_text', 'Đặt Lịch Ngay'));
$about_section_3_button_url = ai_quest_get_setting('ai_quest_about_section_3_button_url', ai_quest_page_url('dat-lich'));
if (empty($about_section_3_button_url)) {
    $about_section_3_button_url = ai_quest_page_url('dat-lich');
}
?>

<main id="main" class="about-page-new" <?php if ($about_hero_image) : ?>style="background-image: url('<?php echo esc_url($about_hero_image); ?>'); background-size: cover; background-position: center; background-attachment: fixed;"<?php endif; ?>>
    
    <!-- Section 1: Hero with Content Left, Image Right -->
    <section class="about-hero-section">
        <div class="about-hero-wrapper">
            <div class="about-hero-content">
                <h1 class="about-hero-title" style="color: #000000 !important;"><?php echo esc_html($about_section_1_title); ?></h1>
                <?php if ($about_section_1_content) : ?>
                    <div class="about-hero-text"><?php echo nl2br(esc_html($about_section_1_content)); ?></div>
                <?php endif; ?>
                <?php if ($about_section_1_button_text) : ?>
                    <?php if ($about_section_1_button_url === '#') : ?>
                        <a href="#" data-open-consult-popup class="btn btn-primary about-btn">
                            <?php echo esc_html($about_section_1_button_text); ?>
                        </a>
                    <?php else : ?>
                        <a href="<?php echo esc_url($about_section_1_button_url); ?>" class="btn btn-primary about-btn">
                            <?php echo esc_html($about_section_1_button_text); ?>
                        </a>
                    <?php endif; ?>
                <?php endif; ?>
            </div>
            <?php if ($about_section_1_image) : ?>
                <div class="about-hero-image">
                    <img src="<?php echo esc_url($about_section_1_image); ?>" alt="<?php echo esc_attr($about_section_1_title); ?>">
                </div>
            <?php endif; ?>
        </div>
    </section>

    <!-- Section 2: Image Left, Content Right -->
    <section class="about-content-section about-section-light">
        <div class="about-content-wrapper">
            <?php if ($about_section_2_image) : ?>
                <div class="about-content-image">
                    <img src="<?php echo esc_url($about_section_2_image); ?>" alt="<?php echo esc_attr($about_section_2_title); ?>">
                </div>
            <?php endif; ?>
            <div class="about-content-text">
                <h2 class="about-content-title" style="color: #000000 !important;"><?php echo esc_html($about_section_2_title); ?></h2>
                <?php if ($about_section_2_content) : ?>
                    <div class="about-content-description"><?php echo nl2br(esc_html($about_section_2_content)); ?></div>
                <?php endif; ?>
                <?php if ($about_section_2_button_text) : ?>
                    <a href="<?php echo esc_url($about_section_2_button_url); ?>" class="btn btn-primary about-btn">
                        <?php echo esc_html($about_section_2_button_text); ?>
                    </a>
                <?php endif; ?>
            </div>
        </div>
    </section>

    <!-- Section 3: Content Left, Image Right -->
    <section class="about-content-section">
        <div class="about-content-wrapper about-content-reverse">
            <div class="about-content-text">
                <h2 class="about-content-title" style="color: #000000 !important;"><?php echo esc_html($about_section_3_title); ?></h2>
                <?php if ($about_section_3_content) : ?>
                    <div class="about-content-description"><?php echo nl2br(esc_html($about_section_3_content)); ?></div>
                <?php endif; ?>
                <?php if ($about_section_3_button_text) : ?>
                    <a href="<?php echo esc_url($about_section_3_button_url); ?>" class="btn btn-primary about-btn">
                        <?php echo esc_html($about_section_3_button_text); ?>
                    </a>
                <?php endif; ?>
            </div>
            <?php if ($about_section_3_image) : ?>
                <div class="about-content-image">
                    <img src="<?php echo esc_url($about_section_3_image); ?>" alt="<?php echo esc_attr($about_section_3_title); ?>">
                </div>
            <?php endif; ?>
        </div>
    </section>

</main>

<style>
/* About Page New Styles */
.about-page-new {
    background: transparent;
    position: relative;
}

/* Light overlay for readability */
.about-page-new::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.1);
    pointer-events: none;
    z-index: 0;
}

.about-page-new > * {
    position: relative;
    z-index: 1;
}

/* Make sections semi-transparent to show background */
.about-page-new .about-hero-section {
    background: rgba(255, 255, 255, 0.75) !important;
    backdrop-filter: blur(2px);
}

.about-page-new .about-content-section {
    background: rgba(255, 255, 255, 0.7) !important;
    backdrop-filter: blur(1px);
}

.about-page-new .about-section-light {
    background: rgba(245, 245, 245, 0.6) !important;
    backdrop-filter: blur(1px);
}

/* Hero Section - Full Width */
.about-hero-section {
    background: linear-gradient(135deg, #fafafa 0%, #ffffff 100%);
    padding: 100px 0;
    min-height: 600px;
    display: flex;
    align-items: center;
}

.about-hero-wrapper {
    max-width: 1100px;
    margin: 0 auto;
    padding: 0 60px;
    display: grid;
    grid-template-columns: 1fr 0.8fr;
    gap: 80px;
    align-items: center;
}

.about-hero-content {
    max-width: 550px;
}

.about-hero-title {
    font-size: 42px;
    font-weight: 300;
    line-height: 1.2;
    margin: 0 0 32px;
    color: #000000 !important;
    font-family: var(--font-title);
    letter-spacing: -0.5px;
}

.about-hero-text {
    font-size: 17px;
    line-height: 1.8;
    color: #666;
    margin: 0 0 40px;
    font-weight: 300;
}

.about-btn {
    display: inline-block;
    padding: 14px 32px;
    background: var(--primary-spa);
    color: #fff;
    text-decoration: none;
    border-radius: 8px;
    font-size: 15px;
    font-weight: 600;
    transition: all 0.3s ease;
    border: none;
}

.about-btn:hover {
    background: #5a6a32;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(107, 125, 58, 0.3);
}

.about-hero-image {
    position: relative;
    width: 100%;
    aspect-ratio: 3 / 4;
}

.about-hero-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 8px;
}

/* Content Sections */
.about-content-section {
    padding: 120px 0;
    background: #fff;
}

.about-section-light {
    background: #f5f5f5;
}

.about-content-wrapper {
    max-width: 1100px;
    margin: 0 auto;
    padding: 0 60px;
    display: grid;
    grid-template-columns: 0.8fr 1fr;
    gap: 80px;
    align-items: center;
}

.about-content-reverse {
    grid-template-columns: 1fr 0.8fr;
}

.about-content-image {
    position: relative;
    width: 100%;
    aspect-ratio: 3 / 4;
}

.about-content-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 8px;
}

.about-content-text {
    max-width: 550px;
}

.about-content-reverse .about-content-text {
    margin-left: auto;
}

.about-content-title {
    font-size: 42px;
    font-weight: 300;
    line-height: 1.3;
    margin: 0 0 28px;
    color: #000000 !important;
    font-family: var(--font-title);
    letter-spacing: -0.5px;
}

.about-content-description {
    font-size: 16px;
    line-height: 1.8;
    color: #666;
    margin: 0 0 36px;
    font-weight: 300;
}

/* Responsive Design */
@media (max-width: 1200px) {
    .about-hero-wrapper,
    .about-content-wrapper {
        max-width: 960px;
        padding: 0 40px;
        gap: 60px;
    }
    
    .about-hero-title,
    .about-content-title {
        font-size: 36px;
    }
    
    .about-hero-image,
    .about-content-image {
        aspect-ratio: 3 / 4;
    }
}

@media (max-width: 991px) {
    .about-hero-wrapper,
    .about-content-wrapper {
        grid-template-columns: 1fr !important;
        gap: 40px;
        padding: 0 30px;
    }
    
    .about-hero-section {
        padding: 80px 0;
        min-height: auto;
    }
    
    .about-content-section {
        padding: 80px 0;
    }
    
    .about-hero-image,
    .about-content-image {
        aspect-ratio: 3 / 4;
    }
    
    .about-hero-title,
    .about-content-title {
        font-size: 32px;
    }
    
    .about-hero-content,
    .about-content-text {
        max-width: 100%;
    }
    
    .about-content-reverse .about-content-text {
        margin-left: 0;
    }
    
    /* Reorder for mobile */
    .about-content-wrapper {
        display: flex;
        flex-direction: column;
    }
    
    .about-content-reverse {
        flex-direction: column;
    }
    
    .about-content-reverse .about-content-text {
        order: 1;
    }
    
    .about-content-reverse .about-content-image {
        order: 2;
    }
}

@media (max-width: 768px) {
    .about-hero-wrapper,
    .about-content-wrapper {
        padding: 0 20px;
    }
    
    .about-hero-section {
        padding: 60px 0;
    }
    
    .about-content-section {
        padding: 60px 0;
    }
    
    .about-hero-title,
    .about-content-title {
        font-size: 28px;
        margin-bottom: 24px;
    }
    
    .about-hero-text,
    .about-content-description {
        font-size: 15px;
        margin-bottom: 32px;
    }
    
    .about-hero-image,
    .about-content-image {
        aspect-ratio: 3 / 4;
    }
    
    .about-btn {
        font-size: 14px;
        padding: 12px 28px;
    }
}

/* Remove About Page Hero styles - no longer needed */
</style>

<?php
get_footer();
?>
