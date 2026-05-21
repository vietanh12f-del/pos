# 📐 Tỉ Lệ Ảnh (Image Aspect Ratios)

## Tổng Quan
Tài liệu này liệt kê tỉ lệ khung hình (aspect ratio) cho tất cả các vị trí ảnh trong theme.

---

## 🏠 Trang Chủ (Homepage)

### Home Slider
- **Tỉ lệ Desktop:** Tự động (full width)
- **Tỉ lệ Mobile:** 4:3
- **Kích thước đề xuất:** 1920x1080px
- **Field:** `ai_quest_home_slider_image_1` đến `ai_quest_home_slider_image_10`

### Banner Khuyến Mãi
- **Tỉ lệ:** Background (không cố định)
- **Kích thước đề xuất:** 1600x900px
- **Field:** `ai_quest_banner_bg_url`

### Danh Mục Dịch Vụ
- **Tỉ lệ Desktop:** 4:3
- **Tỉ lệ Mobile:** 16:9
- **Kích thước đề xuất:** 800x600px
- **Field:** `ai_quest_svc_cat_1_image_url`, `ai_quest_svc_cat_2_image_url`, `ai_quest_svc_cat_3_image_url`

### Before/After Images
- **Tỉ lệ:** 1:1 (vuông)
- **Kích thước đề xuất:** 800x800px
- **Field:** `ai_quest_before_after_image_1_url` đến `ai_quest_before_after_image_20_url`

### Video Thumbnails
- **Tỉ lệ:** 16:9
- **Kích thước đề xuất:** 1280x720px
- **Field:** `ai_quest_video_thumbnail_1` đến `ai_quest_video_thumbnail_4`

### Facebook Reels Thumbnails
- **Tỉ lệ:** 9:16 (dọc)
- **Kích thước đề xuất:** 720x1280px
- **Field:** `ai_quest_fb_reel_1_thumb` đến `ai_quest_fb_reel_50_thumb`

### Chương Trình Hội Viên
- **Tỉ lệ:** 4:5 (dọc)
- **Kích thước đề xuất:** 640x800px
- **Field:** `ai_quest_marketing_1_image` đến `ai_quest_marketing_4_image`

### Testimonials (Đánh Giá)
- **Tỉ lệ:** 4:5 (dọc)
- **Kích thước đề xuất:** 400x500px
- **Field:** `ai_quest_testimonial_1_avatar` đến `ai_quest_testimonial_6_avatar`

---

## 📄 Trang Giới Thiệu (About Page)

### Hero Background
- **Tỉ lệ:** Background (không cố định)
- **Kích thước đề xuất:** 1920x1080px
- **Field:** `ai_quest_about_hero_image`, `ai_quest_about_hero_image_url`

### Section Images
- **Tỉ lệ:** 4:3
- **Kích thước đề xuất:** 800x600px
- **Field:** `ai_quest_about_section_1_image`, `ai_quest_about_section_2_image`, `ai_quest_about_section_3_image`

---

## 🛍️ Trang Dịch Vụ (Service Pages)

### Hero Background
- **Tỉ lệ:** Background (không cố định)
- **Kích thước đề xuất:** 1920x1080px
- **Field:** `ai_quest_svcpage_cham_soc_da_hero_image`, `ai_quest_svcpage_triet_long_hero_image`, `ai_quest_svcpage_goi_dau_hero_image`

### Service Detail Images
- **Tỉ lệ:** 4:3
- **Kích thước đề xuất:** 800x600px
- **Field:** Các field `_sub1_image` đến `_sub5_image` trong mỗi service page

---

## 💰 Trang Bảng Giá (Pricing Page)

### Pricing Images
- **Tỉ lệ:** 2:3 (dọc)
- **Kích thước đề xuất:** 600x900px
- **Field:** `ai_quest_pricing_image_1_url` đến `ai_quest_pricing_image_20_url`

---

## 🗺️ Hệ Thống Cửa Hàng

### Logo
- **Tỉ lệ:** Tự do (nên dùng PNG trong suốt)
- **Kích thước đề xuất:** 200x200px
- **Field:** `ai_quest_locations_logo_url`

### Map Embed
- **Tỉ lệ Desktop:** 4:3
- **Tỉ lệ Mobile:** 16:9
- **Field:** Không phải ảnh (iframe)

---

## 🎨 Branding

### Site Icon
- **Tỉ lệ:** 1:1 (vuông)
- **Kích thước đề xuất:** 512x512px
- **Field:** `ai_quest_site_icon_url`

### Logo
- **Tỉ lệ:** Tự do (nên dùng PNG trong suốt)
- **Kích thước đề xuất:** 200x60px
- **Field:** `ai_quest_logo_image_url`

---

## 📝 Bài Viết (Articles)

### Article Card Thumbnail
- **Tỉ lệ:** 16:9
- **Kích thước đề xuất:** 1280x720px
- **Field:** Featured Image

---

## 📊 Tổng Hợp Tỉ Lệ

| Tỉ Lệ | Mô Tả | Sử Dụng Cho |
|-------|-------|-------------|
| **1:1** | Vuông | Before/After, Site Icon |
| **4:5** | Dọc nhẹ | Marketing, Testimonials |
| **2:3** | Dọc | Pricing Images |
| **9:16** | Dọc (mobile) | Facebook Reels |
| **4:3** | Ngang chuẩn | Service images, About sections, Slider mobile |
| **16:9** | Ngang rộng | Videos, Article thumbnails, Map mobile |
| **Background** | Không cố định | Hero sections, Banners |

---

## 💡 Lưu Ý

1. **Kích thước đề xuất** là kích thước tối ưu, có thể dùng ảnh lớn hơn nhưng giữ đúng tỉ lệ
2. **Mobile** có thể có tỉ lệ khác desktop để tối ưu hiển thị
3. **Background images** không bị crop, nên dùng ảnh có subject ở giữa
4. **Dùng ImgBB** để upload ảnh và lấy URL
5. **Format đề xuất:** JPG cho ảnh, PNG cho logo/icon có nền trong suốt

---

## 🔧 Cách Kiểm Tra Tỉ Lệ Ảnh

1. Mở ảnh trong trình chỉnh sửa
2. Kiểm tra kích thước (width x height)
3. Tính tỉ lệ: width ÷ height
4. So sánh với tỉ lệ yêu cầu

**Ví dụ:**
- Ảnh 800x600 → 800÷600 = 1.33 → Tỉ lệ 4:3 ✅
- Ảnh 1920x1080 → 1920÷1080 = 1.78 → Tỉ lệ 16:9 ✅
- Ảnh 800x800 → 800÷800 = 1 → Tỉ lệ 1:1 ✅
