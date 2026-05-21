<?php
/**
 * Template Name: Tư Vấn Dịch Vụ
 */
get_header();

// Use default values since Consultation Page section has been removed from Customizer
$hero_image = '';
$hero_title = 'Tư Vấn Dịch Vụ';
$hero_subtitle = 'Chuyên Viên Tư Vấn';
$bg = 'https://images.unsplash.com/photo-1540555700478-4be289fbecee?auto=format&fit=crop&q=80&w=2200';
$time_text = ai_quest_get_setting('ai_quest_locations_time_text', 'Thứ Hai đến Chủ Nhật: 9:00 Sáng - 20:00 Tối');

$service_options = array();
foreach (ai_quest_get_all_services_from_categories() as $svc_name) {
    $service_options[] = $svc_name;
}

$supabase_url = ai_quest_get_setting('ai_quest_supabase_url', 'https://cgqxrsoaxgyvcskbixuu.supabase.co');
$supabase_key = ai_quest_get_setting('ai_quest_supabase_anon_key', 'sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh');
$store_id     = ai_quest_get_setting('ai_quest_store_id', '');
?>

<main id="main">

    <!-- Hero -->
    <div class="svc-detail-hero" <?php if ($hero_image) : ?>style="background-image:linear-gradient(rgba(255,255,255,0.55),rgba(255,255,255,0.55)),url('<?php echo esc_url($hero_image); ?>')"<?php endif; ?>>
        <div class="container svc-detail-hero-inner">
            <h1><?php echo esc_html($hero_title); ?></h1>
            <p><?php echo esc_html($hero_subtitle); ?></p>
        </div>
    </div>

    <section class="booking-page" style="background-image: linear-gradient(rgba(255,255,255,0.65), rgba(255,255,255,0.65)), url('<?php echo esc_url($bg); ?>');">
        <div class="container">
            <div class="booking-card">
                <h2 class="booking-title">Để Lại Thông Tin</h2>
                <p class="booking-subtitle">Chuyên viên của chúng tôi sẽ liên hệ tư vấn miễn phí cho bạn.</p>

                <div id="consult-success" style="display:none; background:#e8f5e9; border:1px solid #4caf50; border-radius:8px; padding:16px; margin-bottom:16px; color:#2e7d32; text-align:center;">
                    ✅ <strong>Gửi yêu cầu thành công!</strong> Chúng tôi sẽ liên hệ tư vấn sớm nhất.
                </div>
                <div id="consult-error" style="display:none; background:#ffebee; border:1px solid #f44336; border-radius:8px; padding:16px; margin-bottom:16px; color:#c62828; text-align:center;">
                    ❌ Có lỗi xảy ra. Vui lòng thử lại hoặc liên hệ hotline.
                </div>

                <form class="booking-form" id="consult-form">
                    <div class="booking-grid">
                        <input type="text" name="full_name" placeholder="Họ tên*" required>
                        <input type="tel" name="phone" placeholder="Số điện thoại*" required>
                        <select name="service" required style="grid-column: 1 / -1;">
                            <option value="">Chọn dịch vụ cần tư vấn*</option>
                            <?php foreach ($service_options as $svc) : ?>
                                <option value="<?php echo esc_attr($svc); ?>"><?php echo esc_html($svc); ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="booking-row" style="margin-top:12px;">
                        <textarea name="note" placeholder="Ghi chú / câu hỏi của bạn (tùy chọn)" rows="4" style="width:100%; padding:12px; border:1px solid #ddd; border-radius:8px; font-size:14px; resize:vertical;"></textarea>
                    </div>

                    <button class="booking-submit" type="submit" id="consult-btn">Gửi yêu cầu tư vấn</button>
                </form>

                <p class="booking-time"><strong>Giờ làm việc:</strong> <?php echo esc_html($time_text); ?></p>
            </div>
        </div>
    </section>
</main>

<script>
(function() {
    var SUPABASE_URL = <?php echo wp_json_encode($supabase_url); ?>;
    var SUPABASE_KEY = <?php echo wp_json_encode($supabase_key); ?>;
    var STORE_ID     = <?php echo wp_json_encode($store_id); ?>;

    document.getElementById('consult-form').addEventListener('submit', function(e) {
        e.preventDefault();
        var form = e.target;
        var btn  = document.getElementById('consult-btn');
        var successEl = document.getElementById('consult-success');
        var errorEl   = document.getElementById('consult-error');

        successEl.style.display = 'none';
        errorEl.style.display   = 'none';
        btn.disabled = true;
        btn.textContent = 'Đang gửi...';

        var payload = {
            lead_type:    'consultation',
            full_name:    form.full_name.value.trim(),
            phone:        form.phone.value.trim(),
            service_type: form.service.value,
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
            } else {
                return res.text().then(function(t) { throw new Error(t); });
            }
        })
        .catch(function(err) {
            console.error('Consult error:', err);
            errorEl.style.display = 'block';
        })
        .finally(function() {
            btn.disabled = false;
            btn.textContent = 'Gửi yêu cầu tư vấn';
        });
    });
})();
</script>

<?php get_footer(); ?>
