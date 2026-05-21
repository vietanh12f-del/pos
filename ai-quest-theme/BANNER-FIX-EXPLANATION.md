# Banner Default Values Issue - FIXED ✓

## Vấn Đề (The Problem)

Khi xóa hết nội dung banner trong Customizer, trang web vẫn hiển thị nội dung mặc định thay vì không hiển thị gì.

**Nguyên nhân:** Function `ai_quest_get_setting()` có fallback sang `get_theme_mod()`, nên ngay cả khi xóa giá trị trong OPTIONS table, nó vẫn lấy giá trị từ THEME_MODS table.

## Giải Pháp (The Solution)

### 1. Sửa Function `ai_quest_get_setting()` ✓

**File:** `functions.php` (line ~26-31)

**Trước đây:**
```php
function ai_quest_get_setting($id, $default = '') {
    $value = get_option($id, null);
    if ($value !== null) {
        return $value;
    }
    return get_theme_mod($id, $default);  // ← VẤN ĐỀ Ở ĐÂY
}
```

**Sau khi sửa:**
```php
function ai_quest_get_setting($id, $default = '') {
    $value = get_option($id, null);
    if ($value !== null) {
        return $value;
    }
    // Don't fallback to theme_mods - we've migrated everything to options
    // If not in options table, return the default
    return $default;  // ← FIXED: Không còn check theme_mods nữa
}
```

### 2. Xóa Dữ Liệu Cũ Trong Database

Có 3 script để xóa dữ liệu:

#### Script 1: `DEBUG-BANNER-VALUES.php` (Kiểm tra)
- **Mục đích:** Kiểm tra giá trị banner trong database
- **Khi nào dùng:** Khi muốn xem giá trị đang được lưu ở đâu
- **URL:** `https://yourdomain.com/wp-content/themes/ai-quest-theme/DEBUG-BANNER-VALUES.php`

#### Script 2: `CLEAR-THEME-MODS.php` (Xóa Theme Mods)
- **Mục đích:** Xóa banner values từ THEME_MODS table
- **Khi nào dùng:** Khi DEBUG script cho thấy có giá trị trong THEME_MODS
- **URL:** `https://yourdomain.com/wp-content/themes/ai-quest-theme/CLEAR-THEME-MODS.php`

#### Script 3: `CLEAR-ALL-BANNER-DATA.php` (Xóa Tất Cả) ⭐ RECOMMENDED
- **Mục đích:** Xóa banner values từ CẢ OPTIONS và THEME_MODS
- **Khi nào dùng:** Cách nhanh nhất để xóa sạch tất cả
- **URL:** `https://yourdomain.com/wp-content/themes/ai-quest-theme/CLEAR-ALL-BANNER-DATA.php`

## Hướng Dẫn Thực Hiện (Step-by-Step)

### Bước 1: Upload Theme Mới
1. Upload toàn bộ theme folder lên server
2. Theme đã được sửa function `ai_quest_get_setting()`

### Bước 2: Chạy Script Xóa Dữ Liệu
1. Truy cập: `https://henieskinlab.com/wp-content/themes/ai-quest-theme/CLEAR-ALL-BANNER-DATA.php`
2. Script sẽ tự động xóa tất cả banner content
3. Kiểm tra kết quả trên màn hình

### Bước 3: Clear Cache
1. **Browser Cache:** Ctrl+Shift+Delete (hoặc Cmd+Shift+Delete trên Mac)
2. **WordPress Cache:** Nếu có plugin cache (WP Super Cache, W3 Total Cache, etc.), clear nó
3. **Server Cache:** Nếu hosting có cache, clear từ control panel
4. **CDN Cache:** Nếu dùng Cloudflare, clear cache từ Cloudflare dashboard

### Bước 4: Kiểm Tra
1. Mở homepage trong incognito/private window
2. Banner section không nên hiển thị nếu Customizer trống
3. Nếu vẫn thấy, chạy `DEBUG-BANNER-VALUES.php` để kiểm tra

### Bước 5: Xóa Script (BẢO MẬT)
Sau khi xong, xóa các file này:
- `DEBUG-BANNER-VALUES.php`
- `CLEAR-THEME-MODS.php`
- `CLEAR-ALL-BANNER-DATA.php`
- `CLEAR-BANNER-DEFAULTS.php` (cũ)
- `BANNER-FIX-EXPLANATION.md` (file này)

## Cách Hoạt Động Sau Khi Fix

### Khi Customizer Có Nội Dung:
```
User nhập banner content → Lưu vào OPTIONS table → Frontend hiển thị
```

### Khi Customizer Trống:
```
User xóa banner content → OPTIONS table = NULL → Frontend KHÔNG hiển thị
```

### Logic Kiểm Tra:
```php
// front-page.php
$banner_title = ai_quest_get_setting('ai_quest_banner_title', '');
$banner_description = ai_quest_get_setting('ai_quest_banner_description', '');

// Check if banner has content
$banner_has_content = !empty($banner_title) || !empty($banner_description);

// Only show if has content
if ($banner_enabled && $banner_has_content) {
    // Display banner
}
```

## Tại Sao Vấn Đề Này Xảy Ra?

1. **Migration từ Theme Mods sang Options:**
   - Theme ban đầu dùng `theme_mods` để lưu settings
   - Sau đó migrate sang `options` table
   - Nhưng function `ai_quest_get_setting()` vẫn check cả 2 nơi

2. **Default Values trong Seed Function:**
   - Function `ai_quest_seed_default_options()` đã seed banner defaults
   - Những giá trị này được lưu vào database
   - Khi user xóa trong Customizer, giá trị vẫn còn trong database

3. **Customizer Behavior:**
   - Khi save empty value, WordPress có thể lưu empty string hoặc không lưu gì
   - Nếu không lưu gì, `get_option()` return NULL
   - Function `ai_quest_get_setting()` fallback sang `get_theme_mod()`
   - `get_theme_mod()` có thể vẫn có giá trị cũ

## Files Đã Sửa

1. **functions.php**
   - Line ~26-31: Sửa `ai_quest_get_setting()` function
   - Line ~50-120: Đã xóa banner defaults từ `ai_quest_seed_default_options()`

2. **front-page.php**
   - Line ~180-260: Đã có logic check `$banner_has_content`
   - Chỉ hiển thị banner khi có nội dung

## Troubleshooting

### Vẫn thấy banner content sau khi clear?

1. **Check cache:**
   - Browser cache
   - WordPress cache plugin
   - Server cache
   - CDN cache (Cloudflare, etc.)

2. **Run debug script:**
   ```
   https://yourdomain.com/wp-content/themes/ai-quest-theme/DEBUG-BANNER-VALUES.php
   ```

3. **Check database directly:**
   - phpMyAdmin → wp_options table
   - Search for `ai_quest_banner_`
   - Manually delete if needed

4. **Check theme_mods:**
   - phpMyAdmin → wp_options table
   - Find row with `option_name = 'theme_mods_ai-quest-theme'`
   - Check if banner values are in the serialized data

### Script không chạy?

1. **404 Error:**
   - Kiểm tra file đã upload đúng folder chưa
   - Path phải là: `wp-content/themes/ai-quest-theme/SCRIPT-NAME.php`

2. **Access Denied:**
   - Đảm bảo đã login WordPress với quyền Administrator

3. **White Screen:**
   - Check PHP error logs
   - Có thể path `../../../wp-load.php` không đúng

## Kết Luận

Sau khi fix:
- ✓ Xóa nội dung trong Customizer → Banner không hiển thị
- ✓ Thêm nội dung trong Customizer → Banner hiển thị
- ✓ Không còn giá trị mặc định tự động xuất hiện
- ✓ Function `ai_quest_get_setting()` chỉ check OPTIONS table

**Lưu ý:** Nhớ xóa tất cả debug/cleanup scripts sau khi hoàn thành để bảo mật!
