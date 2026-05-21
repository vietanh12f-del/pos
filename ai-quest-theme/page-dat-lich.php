<?php
get_header();

$booking_bg = 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?auto=format&fit=crop&q=80&w=2200';
$time_text = ai_quest_get_setting('ai_quest_locations_time_text', 'Thứ Hai đến Chủ Nhật: 9:00 Sáng - 20:00 Tối');

$selected_service_id = isset($_GET['service_id']) ? (int) $_GET['service_id'] : 0;
$selected_service_name = isset($_GET['service_name']) ? trim(sanitize_text_field(wp_unslash($_GET['service_name']))) : '';

$service_options = array();
foreach (ai_quest_get_all_services_from_categories() as $svc_name) {
    $service_options[] = array('id' => 0, 'name' => $svc_name);
}

$location_1_title   = ai_quest_get_setting('ai_quest_location_1_title', 'Bình Thạnh, TP.HCM');
$location_1_address = ai_quest_get_setting('ai_quest_location_1_address', '21/5D, Bình Lợi, Bình Lợi Trung, Hồ Chí Minh');
$location_2_title   = ai_quest_get_setting('ai_quest_location_2_title', 'Lái Thiêu, TP.HCM');
$location_2_address = ai_quest_get_setting('ai_quest_location_2_address', '188 3 Tháng 2, KP Đông Tư, Lái Thiêu, Hồ Chí Minh');

$supabase_url = ai_quest_get_setting('ai_quest_supabase_url', 'https://cgqxrsoaxgyvcskbixuu.supabase.co');
$supabase_key = ai_quest_get_setting('ai_quest_supabase_anon_key', 'sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh');
$store_id     = ai_quest_get_setting('ai_quest_store_id', '');
?>

<main id="main">
    <section class="booking-page" style="background-image: linear-gradient(rgba(255,255,255,0.65), rgba(255,255,255,0.65)), url('<?php echo esc_url($booking_bg); ?>');">
        <div class="container">
            <div class="booking-card">
                <h1 class="booking-title">Đặt lịch hẹn</h1>
                <p class="booking-subtitle">Xin vui lòng liên hệ với chúng tôi nếu quý khách có bất kỳ thắc mắc nào liên quan đến các gói dịch vụ của Henie Skinlab.</p>

                <div id="booking-success" style="display:none; background:#e8f5e9; border:1px solid #4caf50; border-radius:8px; padding:16px; margin-bottom:16px; color:#2e7d32; text-align:center;">
                    ✅ <strong>Đặt lịch thành công!</strong> Chúng tôi sẽ liên hệ xác nhận sớm nhất.
                </div>
                <div id="booking-error" style="display:none; background:#ffebee; border:1px solid #f44336; border-radius:8px; padding:16px; margin-bottom:16px; color:#c62828; text-align:center;">
                    ❌ Có lỗi xảy ra. Vui lòng thử lại hoặc liên hệ hotline.
                </div>

                <form class="booking-form" id="booking-form">
                    <div class="booking-grid">
                        <input type="text" name="full_name" placeholder="Họ tên*" required>
                        <select name="time_slot" required>
                            <option value="">Chọn thời gian</option>
                            <?php for ($hour = 9; $hour <= 18; $hour++) : ?>
                                <?php $label = sprintf('%02d:00', $hour); ?>
                                <option value="<?php echo esc_attr($label); ?>"><?php echo esc_html($label); ?></option>
                            <?php endfor; ?>
                        </select>
                        <input type="date" name="booking_date" class="date-input-field" placeholder="Chọn ngày" required>

                        <input type="email" name="email" placeholder="Email">
                        <select name="service" required>
                            <option value="">Chọn dịch vụ</option>
                            <?php foreach ($service_options as $service) : ?>
                                <?php
                                $is_selected = false;
                                if ($selected_service_name !== '' && trim($service['name']) === $selected_service_name) {
                                    $is_selected = true;
                                }
                                ?>
                                <option value="<?php echo esc_attr($service['name']); ?>" <?php selected($is_selected, true); ?>><?php echo esc_html($service['name']); ?></option>
                            <?php endforeach; ?>
                        </select>
                        <input type="tel" name="phone" placeholder="Số điện thoại*" required>
                    </div>

                    <div class="booking-row">
                        <select name="branch" required>
                            <option value="">Chọn chi nhánh</option>
                            <option value="co-so-1">Cơ sở 1 — <?php echo esc_html($location_1_title); ?> — <?php echo esc_html($location_1_address); ?></option>
                            <option value="co-so-2">Cơ sở 2 — <?php echo esc_html($location_2_title); ?> — <?php echo esc_html($location_2_address); ?></option>
                        </select>
                    </div>

                    <div class="booking-row">
                        <textarea name="note" placeholder="Ghi chú (tùy chọn)" rows="3" style="width:100%; padding:12px; border:1px solid #ddd; border-radius:8px; font-size:14px; resize:vertical;"></textarea>
                    </div>

                    <button class="booking-submit" type="submit" id="booking-btn">Đặt lịch</button>
                </form>

                <p class="booking-time"><strong>Giờ mở cửa:</strong> <?php echo esc_html($time_text); ?></p>
            </div>
        </div>
    </section>
</main>

<script>
(function() {
    // iOS-specific fixes for date input
    var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
    var dateInput = document.querySelector('.date-input-field');
    var placeholderText = 'Chọn ngày';
    
    if (dateInput) {
        // Prevent iOS zoom by ensuring font-size >= 16px
        dateInput.style.fontSize = '16px';
        
        // Add CSS class for empty state
        function updateDateInputState() {
            if (!dateInput.value) {
                dateInput.classList.add('date-input-empty');
            } else {
                dateInput.classList.remove('date-input-empty');
            }
        }
        
        // Initial state
        updateDateInputState();
        
        // Update on change
        dateInput.addEventListener('change', updateDateInputState);
        
        if (isIOS) {
            // On iOS, make sure the input is interactive
            dateInput.addEventListener('touchstart', function(e) {
                // Allow the native date picker to open normally
            }, { passive: true });
        }
    }

    // Handle booking form submission
    var SUPABASE_URL = <?php echo wp_json_encode($supabase_url); ?>;
    var SUPABASE_KEY = <?php echo wp_json_encode($supabase_key); ?>;
    var STORE_ID     = <?php echo wp_json_encode($store_id); ?>;

    document.getElementById('booking-form').addEventListener('submit', function(e) {
        e.preventDefault();
        var form = e.target;
        var btn  = document.getElementById('booking-btn');
        var successEl = document.getElementById('booking-success');
        var errorEl   = document.getElementById('booking-error');

        successEl.style.display = 'none';
        errorEl.style.display   = 'none';
        btn.disabled = true;
        btn.textContent = 'Đang gửi...';

        // Use date as-is since native input returns yyyy-mm-dd
        var bookingDate = form.booking_date.value;

        var payload = {
            lead_type:    'appointment',
            full_name:    form.full_name.value.trim(),
            phone:        form.phone.value.trim(),
            email:        form.email.value.trim() || null,
            service_type: form.service.value,
            booking_date: bookingDate,
            time_slot:    form.time_slot.value,
            branch:       form.branch.value,
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
            console.error('Booking error:', err);
            errorEl.style.display = 'block';
        })
        .finally(function() {
            btn.disabled = false;
            btn.textContent = 'Đặt lịch';
        });
    });
})();
</script>

<?php
get_footer();
?>
