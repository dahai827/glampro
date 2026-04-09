## 🎨 获取指定分类下功能配置列表

### 接口信息

- **URL**：`GET /get-item-configs`
- **认证**：❌ 公开接口（无需 Token，仅需 apikey）
- **Headers**:
  ```
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  Authorization: Bearer {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 | 默认值 |
|------|------|------|------|--------|
| app_id | string | 应用标识（用于区分不同APP的配置） | ✅  | "default" |
| section_id | string | 分类id | ✅  | "" |
| limit | number | 每页返回的分类数量（1-100） | ✅  | 3 |
| cursor | string | 游标，用于获取下一页（第一页无需提供,后端按照sort_order生序排序，从上一页响应的 `next_cursor` 获取） | ❌ | null |

**请求示例**:
```bash

# 获取特定应用的广告页面配置
GET /get-item-configs?app_id=ios_v2&section_id=xxx

# 获取图片菜单的功能配置（首页，每页3条）
GET /get-item-configs?app_id=ios_v2&section_id=xxx&limit=3

# 获取下一页（使用上一页返回的 next_cursor）
GET /get-item-configs?app_id=ios_v2&section_id=xxx&limit=3&cursor=item_id_2
```

### 响应结构

**响应 HTTP Status**: `200 OK`

**响应 Body**:
```json
{
  "sections": [
    {
      "id": 22,
      "type": "section",
      "title": "home",
      "subtitle": "",
      "layout": "grid",
      "menu": "image",
      "sort_order": 0,
      "items": [
        {
          "id": "temp-y4myt0cx6",
          "title": "qianwen",
          "subtitle": "",
          "icon_url": "",
          "cover_image_url": "https://dl.fuliapp.site/apps/annyrsai/apk/1766985164058_image.jpeg",
          "placeholder_gradient": [
            "#2E3A41",
            "#F48F21"
          ],
          "badge": null,
          "card_type": null,
          "text_mode": null,
          "text_image_url": null,
          "sort_order": 0,
          "requires_preview": false,
          "estimated_credits": 30,
          "scene": "",
          "template": "",
          "prompt_template": "你是一只宠物角色，当前心情为开心，请结合这张图片的画面信息，以开心的语气，随意发挥用40-80个字以内的中文内容表达情绪，要求一定要用英文，用第一人称口吻生成一句自然、富有情感的表达，注意识别图片中宠物的年龄，用对应年龄的男人的声音表达",
          "enable_image_merge": false,
          "face_swap_video_template": "",
          "model_type": "image_to_video",
          "model_id": "wan2.6-i2v",
          "preview_style": "image_comparison",
          "is_ad": false,
          "material_requirements": []
        },
        {
          "id": "temp-p9np7gxlp",
          "title": "c4",
          "subtitle": "",
          "icon_url": "",
          "cover_image_url": "https://dl.fuliapp.site/apps/annyrsai/apk/1766985170752_image.jpeg",
          "badge": null,
          "card_type": null,
          "text_mode": null,
          "text_image_url": null,
          "sort_order": 0,
          "requires_preview": true,
          "estimated_credits": 30,
          "scene": "",
          "template": "",
          "prompt_template": "",
          "enable_image_merge": false,
          "face_swap_video_template": "https://lrenlgqppvqfbibxppbi.supabase.co/storage/v1/object/public/cms/items/temp-zlisdoe1z/face-swap-template/1766675831797_470d89bd-388b-4df9-a19e-56b5750928f6.mp4",
          "model_type": "video_face_swap",
          "model_id": "50a0a0018673852629578e627576326036b407e0dbd8cf8a0b5028296726dc5c",
          "cover_video": "https://lrenlgqppvqfbibxppbi.supabase.co/storage/v1/object/public/cms/items/temp-zlisdoe1z/cover-video/1766675949035_3bcb2a98-0da4-40ab-ae78-ae1beca7fbee.mp4",
          "cover_video_thumbnail": "https://dl.fuliapp.site/apps/annyrsai/images/1767067861125_thumbnail_1767067858802.jpg",
          "preview_style": "video_effect",
          "face_swap_video_hls_url": "https://customer-w27izj1fjq2mcg2q.cloudflarestream.com/c3d4fc800da1cc792492cc94bc060f1b/manifest/video.m3u8",
          "is_ad": false,
          "material_requirements": []
        },
        {
          "id": "temp-v88ngcds6",
          "title": "one",
          "subtitle": "",
          "icon_url": "",
          "cover_image_url": "https://dl.fuliapp.site/apps/annyrsai/apk/1766985202302_image.jpeg",
          "badge": null,
          "card_type": null,
          "text_mode": null,
          "text_image_url": null,
          "sort_order": 1,
          "requires_preview": true,
          "estimated_credits": 10,
          "scene": "",
          "template": "",
          "prompt_template": "",
          "enable_image_merge": false,
          "face_swap_video_template": "https://lrenlgqppvqfbibxppbi.supabase.co/storage/v1/object/public/cms/items/temp-vg5f51gc9/face-swap-template/1766220586830_addog.mp4",
          "model_type": "video_face_swap",
          "model_id": "50a0a0018673852629578e627576326036b407e0dbd8cf8a0b5028296726dc5c",
          "preview_style": "video_effect",
          "is_ad": false,
          "material_requirements": []
        }
      ]
    }
  ],
  "version": "1.0.0",
  "pagination": {
    "limit": 3,
    "has_next": true,
    "next_cursor": "temp-v88ngcds6"
  }
}
```