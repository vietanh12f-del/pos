<?php
get_header();

$supabase_url = ai_quest_get_setting('ai_quest_supabase_url', 'https://cgqxrsoaxgyvcskbixuu.supabase.co');
$supabase_key = ai_quest_get_setting('ai_quest_supabase_anon_key', 'sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh');
?>

<main id="main">
    <section class="section container smartkiot-register-page">
        <div class="section-title-center">
            <h2>Đăng ký</h2>
            <p>Khởi tạo dịch vụ phần mềm quản lý trên web, sau đó sử dụng tài khoản Gmail/Google để đăng nhập ứng dụng SmartKiot.</p>
        </div>

        <div class="smartkiot-service-grid">
            <button type="button" class="smartkiot-service-card" id="smartkiot-open-registration">
                <span class="smartkiot-service-icon">▦</span>
                <span class="smartkiot-service-title">Phần mềm quản lý</span>
                <span class="smartkiot-service-desc">Tạo cửa hàng, mời nhân viên bằng email/Gmail và quản lý quyền truy cập.</span>
            </button>
        </div>

        <div id="smartkiot-registration-panel" class="smartkiot-registration-panel" hidden>
            <div class="smartkiot-panel-header">
                <div>
                    <h3>Tạo cửa hàng trên web</h3>
                    <p>Đăng nhập Google để tạo cửa hàng. Nhân viên được mời sẽ thấy lời mời trong app khi đăng nhập đúng email.</p>
                </div>
                <button type="button" id="smartkiot-google-login" class="btn btn-primary">Đăng nhập Google</button>
            </div>

            <div id="smartkiot-auth-state" class="smartkiot-auth-state">Bạn chưa đăng nhập.</div>
            <div id="smartkiot-register-success" class="smartkiot-alert smartkiot-alert-success" hidden></div>
            <div id="smartkiot-register-error" class="smartkiot-alert smartkiot-alert-error" hidden></div>

            <form id="smartkiot-store-form" class="smartkiot-store-form">
                <div class="smartkiot-form-grid">
                    <label>
                        <span>Tên cửa hàng*</span>
                        <input type="text" name="store_name" placeholder="Ví dụ: SmartKiot Demo Store" required>
                    </label>
                    <label>
                        <span>Địa chỉ</span>
                        <input type="text" name="store_address" placeholder="Địa chỉ cửa hàng">
                    </label>
                    <label>
                        <span>Tên chủ cửa hàng*</span>
                        <input type="text" name="owner_name" placeholder="Họ và tên" required>
                    </label>
                    <label>
                        <span>Email chủ cửa hàng</span>
                        <input type="email" name="owner_email" placeholder="Tự lấy từ Google" readonly>
                    </label>
                </div>

                <div class="smartkiot-employees-block">
                    <div class="smartkiot-employees-header">
                        <div>
                            <h4>Mời nhân viên bằng email/Gmail</h4>
                            <p>Có thể nhập email dù nhân viên chưa có tài khoản. Khi nhân viên login Google lần đầu, app sẽ gắn lời mời theo email.</p>
                        </div>
                        <button type="button" id="smartkiot-add-employee" class="smartkiot-secondary-btn">Thêm nhân viên</button>
                    </div>
                    <div id="smartkiot-employee-list" class="smartkiot-employee-list"></div>
                </div>

                <button type="submit" id="smartkiot-submit-store" class="btn btn-primary smartkiot-submit-btn">Tạo cửa hàng</button>
            </form>
        </div>
    </section>
</main>

<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script>
(function() {
    const supabaseUrl = <?php echo wp_json_encode($supabase_url); ?>;
    const supabaseKey = <?php echo wp_json_encode($supabase_key); ?>;
    const client = window.supabase.createClient(supabaseUrl, supabaseKey, {
        auth: {
            persistSession: true,
            detectSessionInUrl: true
        }
    });

    const defaultPermissions = [
        'view_home',
        'view_orders',
        'view_inventory'
    ];
    const allPermissions = [
        ['view_home', 'Xem Trang chủ'],
        ['view_orders', 'Xem Đơn hàng'],
        ['view_inventory', 'Xem Kho hàng'],
        ['view_expenses', 'Xem Chi phí'],
        ['view_reports', 'Xem Báo cáo'],
        ['view_customization', 'Xem Tuỳ chỉnh'],
        ['manage_employees', 'Quản lý Nhân viên'],
        ['delete_employee', 'Xóa Nhân viên'],
        ['view_statistics', 'Xem Thống kê'],
        ['view_inventory_reports', 'Xem Báo cáo kho'],
        ['manage_production', 'Quản lý sản xuất'],
        ['manage_customers', 'Quản lý khách hàng']
    ];

    const openBtn = document.getElementById('smartkiot-open-registration');
    const panel = document.getElementById('smartkiot-registration-panel');
    const googleBtn = document.getElementById('smartkiot-google-login');
    const authState = document.getElementById('smartkiot-auth-state');
    const form = document.getElementById('smartkiot-store-form');
    const employeeList = document.getElementById('smartkiot-employee-list');
    const addEmployeeBtn = document.getElementById('smartkiot-add-employee');
    const successBox = document.getElementById('smartkiot-register-success');
    const errorBox = document.getElementById('smartkiot-register-error');
    const submitBtn = document.getElementById('smartkiot-submit-store');

    if (!openBtn || !panel || !form) return;

    function showMessage(type, message) {
        successBox.hidden = true;
        errorBox.hidden = true;
        const box = type === 'success' ? successBox : errorBox;
        box.textContent = message;
        box.hidden = false;
    }

    function clearMessages() {
        successBox.hidden = true;
        errorBox.hidden = true;
    }

    function createEmployeeRow() {
        const row = document.createElement('div');
        row.className = 'smartkiot-employee-row';
        const permissionInputs = allPermissions.map(([value, label]) => {
            const checked = defaultPermissions.includes(value) ? ' checked' : '';
            return '<label><input type="checkbox" value="' + value + '"' + checked + '> ' + label + '</label>';
        }).join('');
        row.innerHTML = '<div class="smartkiot-employee-main"><input type="email" class="smartkiot-employee-email" placeholder="emailnhanvien@gmail.com"><button type="button" class="smartkiot-remove-employee">Xóa</button></div><div class="smartkiot-permissions">' + permissionInputs + '</div>';
        row.querySelector('.smartkiot-remove-employee').addEventListener('click', () => row.remove());
        employeeList.appendChild(row);
    }

    async function updateAuthState() {
        const { data } = await client.auth.getSession();
        const user = data.session && data.session.user ? data.session.user : null;
        const ownerEmailInput = form.querySelector('input[name="owner_email"]');
        const ownerNameInput = form.querySelector('input[name="owner_name"]');
        if (user) {
            const name = user.user_metadata && (user.user_metadata.full_name || user.user_metadata.name) ? (user.user_metadata.full_name || user.user_metadata.name) : '';
            authState.textContent = 'Đã đăng nhập: ' + (user.email || user.id);
            googleBtn.textContent = 'Đổi tài khoản Google';
            ownerEmailInput.value = user.email || '';
            if (!ownerNameInput.value && name) ownerNameInput.value = name;
        } else {
            authState.textContent = 'Bạn chưa đăng nhập.';
            googleBtn.textContent = 'Đăng nhập Google';
            ownerEmailInput.value = '';
        }
        return user;
    }

    async function findProfileByEmail(email) {
        const { data, error } = await client
            .from('profiles')
            .select('id')
            .ilike('email', email)
            .limit(1);
        if (error || !data || data.length === 0) return null;
        return data[0].id;
    }

    function getEmployeeInvites() {
        return Array.from(employeeList.querySelectorAll('.smartkiot-employee-row')).map((row) => {
            const emailInput = row.querySelector('.smartkiot-employee-email');
            const email = emailInput.value.trim().toLowerCase();
            const permissions = Array.from(row.querySelectorAll('.smartkiot-permissions input:checked')).map((input) => input.value);
            return { email, permissions };
        }).filter((item) => item.email);
    }

    async function ensureOwnerProfile(user, ownerName) {
        const payload = {
            id: user.id,
            full_name: ownerName,
            email: user.email || null,
            created_at: new Date().toISOString(),
            account_role: 'owner'
        };
        const { error } = await client.from('profiles').upsert(payload);
        if (error) throw error;
    }

    openBtn.addEventListener('click', () => {
        panel.hidden = false;
        panel.scrollIntoView({ behavior: 'smooth', block: 'start' });
        updateAuthState();
    });

    googleBtn.addEventListener('click', async () => {
        clearMessages();
        const { error } = await client.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: window.location.href.split('#')[0]
            }
        });
        if (error) showMessage('error', error.message);
    });

    addEmployeeBtn.addEventListener('click', createEmployeeRow);

    form.addEventListener('submit', async (event) => {
        event.preventDefault();
        clearMessages();
        submitBtn.disabled = true;
        submitBtn.textContent = 'Đang tạo...';

        try {
            const user = await updateAuthState();
            if (!user) throw new Error('Vui lòng đăng nhập Google trước khi tạo cửa hàng.');

            const storeName = form.store_name.value.trim();
            const storeAddress = form.store_address.value.trim();
            const ownerName = form.owner_name.value.trim();
            if (!storeName || !ownerName) throw new Error('Vui lòng nhập tên cửa hàng và tên chủ cửa hàng.');

            await ensureOwnerProfile(user, ownerName);

            const storeId = crypto.randomUUID();
            const { error: storeError } = await client.from('stores').insert({
                id: storeId,
                name: storeName,
                address: storeAddress || null,
                owner_id: user.id,
                created_at: new Date().toISOString()
            });
            if (storeError) throw storeError;

            const ownerMember = {
                id: crypto.randomUUID(),
                store_id: storeId,
                user_id: user.id,
                email: user.email || null,
                role: 'owner',
                permissions: allPermissions.map(([value]) => value),
                status: 'active',
                joined_at: new Date().toISOString()
            };
            const { error: ownerMemberError } = await client.from('store_members').insert(ownerMember);
            if (ownerMemberError) throw ownerMemberError;

            const invites = getEmployeeInvites();
            for (const invite of invites) {
                const userId = await findProfileByEmail(invite.email);
                const memberPayload = {
                    id: crypto.randomUUID(),
                    store_id: storeId,
                    email: invite.email,
                    role: 'employee',
                    permissions: invite.permissions.length ? invite.permissions : defaultPermissions,
                    status: 'invited',
                    joined_at: new Date().toISOString()
                };
                if (userId) {
                    memberPayload.user_id = userId;
                }
                const { error: inviteError } = await client.from('store_members').insert(memberPayload);
                if (inviteError) throw inviteError;
            }

            form.reset();
            employeeList.innerHTML = '';
            await updateAuthState();
            showMessage('success', 'Đã tạo cửa hàng và lời mời nhân viên. Nhân viên đăng nhập app bằng đúng email/Gmail để nhận lời mời.');
        } catch (error) {
            showMessage('error', error.message || 'Không thể tạo cửa hàng. Vui lòng thử lại.');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Tạo cửa hàng';
        }
    });

    client.auth.onAuthStateChange(() => updateAuthState());
    createEmployeeRow();
    updateAuthState();
}());
</script>

<?php get_footer(); ?>
