<?php
get_header();

$partner_cta_text = ai_quest_get_setting('ai_quest_partner_cta_text', 'Trở thành đối tác của Henie Skinlab');
$supabase_url = ai_quest_get_setting('ai_quest_supabase_url', 'https://cgqxrsoaxgyvcskbixuu.supabase.co');
$supabase_key = ai_quest_get_setting('ai_quest_supabase_anon_key', 'sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh');
$store_id     = ai_quest_get_setting('ai_quest_store_id', '');

$partners = array();
for ($i = 1; $i <= 10; $i++) {
    $logo_url = trim((string) ai_quest_get_setting('ai_quest_partner_' . $i . '_logo_url', ''));
    $name     = trim((string) ai_quest_get_setting('ai_quest_partner_' . $i . '_name', ''));
    $link_url = trim((string) ai_quest_get_setting('ai_quest_partner_' . $i . '_link_url', ''));
    if ($logo_url === '' && $name === '') continue;
    $partners[] = array('logo_url' => $logo_url, 'name' => $name, 'link_url' => $link_url);
}
?>

<main id="main">
    <section class="section container">
        <div class="section-title-center">
            <h2>Đối Tác</h2>
            <p>Những đối tác đồng hành cùng Henie Skinlab.</p>
        </div>

        <?php if (!empty($partners)) : ?>
            <div class="partners-grid-wrapper" style="max-width: 1200px; margin: 0 auto 48px;">
                <div class="partners-grid" style="display:flex; flex-wrap:wrap; gap:32px; justify-content:center; align-items:stretch;">
                    <?php foreach ($partners as $partner) : ?>
                        <?php 
                        $has_link = !empty($partner['link_url']) && $partner['link_url'] !== '' && $partner['link_url'] !== '#';
                        ?>
                        
                        <?php if ($has_link) : ?>
                            <!-- Partner with link - entire card is clickable -->
                            <a href="<?php echo esc_url($partner['link_url']); ?>" 
                               target="_blank" 
                               rel="noopener noreferrer" 
                               class="partner-card partner-card-link"
                               style="display:flex; flex-direction:column; align-items:center; justify-content:center; gap:16px; padding:32px 24px; background:#fff; border-radius:16px; box-shadow:0 2px 12px rgba(0,0,0,.08); transition: transform 0.3s, box-shadow 0.3s; width: 220px; min-height: 200px; text-decoration:none; cursor:pointer; pointer-events:auto;">
                                <?php if ($partner['logo_url']) : ?>
                                    <div style="display:flex; align-items:center; justify-content:center; width:100%; height:120px;">
                                        <img src="<?php echo esc_url($partner['logo_url']); ?>" 
                                             alt="<?php echo esc_attr($partner['name'] ?: 'Partner logo'); ?>" 
                                             style="max-height:120px; max-width:100%; width:auto; height:auto; object-fit:contain; pointer-events:none;">
                                    </div>
                                <?php endif; ?>
                                <?php if (!empty($partner['name'])) : ?>
                                    <span style="font-size:15px; font-weight:600; color:#333; text-align:center; line-height:1.4; pointer-events:none;"><?php echo esc_html($partner['name']); ?></span>
                                <?php endif; ?>
                            </a>
                        <?php else : ?>
                            <!-- Partner without link - not clickable -->
                            <div class="partner-card" 
                                 style="display:flex; flex-direction:column; align-items:center; justify-content:center; gap:16px; padding:32px 24px; background:#fff; border-radius:16px; box-shadow:0 2px 12px rgba(0,0,0,.08); transition: transform 0.3s, box-shadow 0.3s; width: 220px; min-height: 200px;">
                                <?php if ($partner['logo_url']) : ?>
                                    <div style="display:flex; align-items:center; justify-content:center; width:100%; height:120px;">
                                        <img src="<?php echo esc_url($partner['logo_url']); ?>" 
                                             alt="<?php echo esc_attr($partner['name'] ?: 'Partner logo'); ?>" 
                                             style="max-height:120px; max-width:100%; width:auto; height:auto; object-fit:contain;">
                                    </div>
                                <?php endif; ?>
                                <?php if (!empty($partner['name'])) : ?>
                                    <span style="font-size:15px; font-weight:600; color:#333; text-align:center; line-height:1.4;"><?php echo esc_html($partner['name']); ?></span>
                                <?php endif; ?>
                            </div>
                        <?php endif; ?>
                    <?php endforeach; ?>
                </div>
            </div>
        <?php else : ?>
            <div class="section-empty" style="margin-bottom:48px;">Đang cập nhật thông tin đối tác.</div>
        <?php endif; ?>

        <!-- CTA Button -->
        <div style="text-align:center; margin-top:16px;">
            <button
                id="open-partner-form"
                class="btn btn-primary"
                style="font-size:16px; padding:14px 36px; border-radius:50px; cursor:pointer; border:none;"
            >
                <?php echo esc_html($partner_cta_text); ?>
            </button>
        </div>
    </section>
</main>

<!-- Partner Registration Popup -->
<div id="partner-popup" class="modal-overlay" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,.55); z-index:9999; align-items:center; justify-content:center;">
    <div style="background:#fff; border-radius:20px; padding:32px; max-width:480px; width:90%; position:relative; max-height:90vh; overflow-y:auto;">
        <button id="close-partner-popup" style="position:absolute; top:14px; right:18px; background:none; border:none; font-size:24px; cursor:pointer; color:#888;">&times;</button>
        <h2 style="margin:0 0 8px; font-size:22px;"><?php echo esc_html($partner_cta_text); ?></h2>
        <p style="color:#888; margin:0 0 24px; font-size:14px;">Điền thông tin bên dưới, chúng tôi sẽ liên hệ trong 24 giờ.</p>

        <div id="partner-success" style="display:none; background:#e8f5e9; border:1px solid #4caf50; border-radius:8px; padding:14px; margin-bottom:16px; color:#2e7d32; text-align:center;">
            ✅ <strong>Đăng ký thành công!</strong> Chúng tôi sẽ liên hệ sớm nhất.
        </div>
        <div id="partner-error" style="display:none; background:#ffebee; border:1px solid #f44336; border-radius:8px; padding:14px; margin-bottom:16px; color:#c62828; text-align:center;">
            ❌ Có lỗi xảy ra. Vui lòng thử lại.
        </div>

        <form id="partner-form" style="display:flex; flex-direction:column; gap:14px;">
            <input
                type="text" name="full_name" placeholder="Tên / Thương hiệu*" required
                style="padding:12px 16px; border:1px solid #ddd; border-radius:10px; font-size:15px; outline:none;"
            >
            <input
                type="tel" name="phone" placeholder="Số điện thoại*" required
                style="padding:12px 16px; border:1px solid #ddd; border-radius:10px; font-size:15px; outline:none;"
            >
            <input
                type="email" name="email" placeholder="Gmail / Email*" required
                style="padding:12px 16px; border:1px solid #ddd; border-radius:10px; font-size:15px; outline:none;"
            >
            <textarea
                name="note" placeholder="Ghi chú (tùy chọn)" rows="3"
                style="padding:12px 16px; border:1px solid #ddd; border-radius:10px; font-size:15px; outline:none; resize:vertical;"
            ></textarea>
            <button
                type="submit" id="partner-submit-btn"
                class="btn btn-primary"
                style="padding:14px; border-radius:10px; font-size:15px; font-weight:700; cursor:pointer; border:none;"
            >
                Gửi đăng ký
            </button>
        </form>
    </div>
</div>

<script>
(function() {
    var SUPABASE_URL = <?php echo wp_json_encode($supabase_url); ?>;
    var SUPABASE_KEY = <?php echo wp_json_encode($supabase_key); ?>;
    var STORE_ID     = <?php echo wp_json_encode($store_id); ?>;

    // Debug partner links
    console.log('=== PARTNERS PAGE DEBUG ===');
    
    // Find all partner card links
    var partnerLinks = document.querySelectorAll('.partner-card-link');
    console.log('Found partner card links:', partnerLinks.length);
    
    partnerLinks.forEach(function(link, index) {
        console.log('Partner ' + (index + 1) + ':');
        console.log('  - URL:', link.href);
        console.log('  - Computed cursor:', window.getComputedStyle(link).cursor);
        console.log('  - Computed pointer-events:', window.getComputedStyle(link).pointerEvents);
        
        // Force clickable
        link.style.cursor = 'pointer';
        link.style.pointerEvents = 'auto';
        
        // Add click listener with capture phase to run before other handlers
        link.addEventListener('click', function(e) {
            console.log('✓ Partner link clicked!');
            console.log('  - Opening:', link.href);
            console.log('  - Default prevented?', e.defaultPrevented);
            
            // Force navigation even if something tries to prevent it
            if (e.defaultPrevented) {
                console.warn('Default was prevented, forcing navigation...');
            }
            
            // Open in new tab
            window.open(link.href, '_blank', 'noopener,noreferrer');
            
            // Prevent any other handlers from interfering
            e.stopPropagation();
        }, true); // Use capture phase
        
        // Add mouseenter for debugging
        link.addEventListener('mouseenter', function() {
            console.log('Mouse entered partner card:', link.href);
        });
    });
    
    console.log('=== END DEBUG ===');

    var popup    = document.getElementById('partner-popup');
    var openBtn  = document.getElementById('open-partner-form');
    var closeBtn = document.getElementById('close-partner-popup');

    openBtn.addEventListener('click', function() {
        popup.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    });

    closeBtn.addEventListener('click', function() {
        popup.style.display = 'none';
        document.body.style.overflow = '';
    });

    popup.addEventListener('click', function(e) {
        if (e.target === popup) {
            popup.style.display = 'none';
            document.body.style.overflow = '';
        }
    });

    document.getElementById('partner-form').addEventListener('submit', function(e) {
        e.preventDefault();
        var form      = e.target;
        var btn       = document.getElementById('partner-submit-btn');
        var successEl = document.getElementById('partner-success');
        var errorEl   = document.getElementById('partner-error');

        successEl.style.display = 'none';
        errorEl.style.display   = 'none';
        btn.disabled = true;
        btn.textContent = 'Đang gửi...';

        var payload = {
            lead_type:    'partner',
            full_name:    form.full_name.value.trim(),
            phone:        form.phone.value.trim(),
            email:        form.email.value.trim(),
            note:         form.note.value.trim(),
            source:       'website',
            status:       'new'
        };
        if (STORE_ID) payload.store_id = STORE_ID;

        fetch(SUPABASE_URL + '/rest/v1/website_leads', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': SUPABASE_KEY,
                'Authorization': 'Bearer ' + SUPABASE_KEY,
                'Prefer': 'return=minimal'
            },
            body: JSON.stringify(payload)
        })
        .then(function(res) {
            if (res.ok || res.status === 201) {
                successEl.style.display = 'block';
                form.reset();
                setTimeout(function() {
                    popup.style.display = 'none';
                    document.body.style.overflow = '';
                }, 2500);
            } else {
                return res.text().then(function(t) { throw new Error(t); });
            }
        })
        .catch(function(err) {
            console.error('Partner form error:', err);
            errorEl.style.display = 'block';
        })
        .finally(function() {
            btn.disabled = false;
            btn.textContent = 'Gửi đăng ký';
        });
    });
})();
</script>

<?php get_footer(); ?>
