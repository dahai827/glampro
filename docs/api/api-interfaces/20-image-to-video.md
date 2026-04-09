## 图生视频接口

### 接口信息

- **URL**：`POST /image-to-video`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| item_id | string | 功能配置项ID | ✅ |
| image_url | string \| string[] | 输入图片URL（单张字符串或数组） | ✅ |
| prompt | string | 提示词（可选，如果item配置了prompt_template则使用模板） | ❌ |

### 图片合成功能

当功能配置项（item）启用了图片合成功能（`enable_image_merge = true`）时，接口会自动执行两步流程：

1. **第一步 - 图片合成**：使用图生图模型将两张输入图片合成一张
2. **第二步 - 图生视频**：使用图生视频模型将合成后的图片生成视频

**触发条件**：
- item 配置了 `enable_image_merge = true`
- `image_url` 是包含 **2个元素** 的数组

**注意事项**：
- 如果启用了图片合成，必须提供 **2张图片**
- 返回的 `task_id` 是最后视频任务的ID
- 图片合成失败时会自动回滚积分

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| task_id | string | **任务ID（用于查询任务状态）** |
| credits_used | number | 本次任务扣除的积分 |
| credits_balance | number | 当前积分余额 |
| model_used | string | 使用的模型ID |
| input_images_count | number | 输入图片数量 |
| message | string | 提示信息 |

### 任务状态查询

创建任务后，使用返回的 `task_id` 调用 `/get-task` 接口查询任务状态：

```
创建任务 → task_id
  ↓
每3秒轮询一次 /get-task?task_id={task_id}
  ↓
status = processing → 继续轮询
status = completed → 展示视频（output_url）
status = failed → 显示错误
```

### 请求示例

**单张图片（普通模式）**：
```bash
curl -X POST "${BASE_URL}/image-to-video" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "item_id": "face-to-video",
    "image_url": "https://example.com/image.jpg",
    "prompt": "a beautiful woman"
  }'
```

**两张图片（图片合成模式）**：
```bash
curl -X POST "${BASE_URL}/image-to-video" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "item_id": "merge-and-video",
    "image_url": [
      "https://example.com/image1.jpg",
      "https://example.com/image2.jpg"
    ],
    "prompt": "merge two images"
  }'
```

### 响应示例

**成功响应**：
```json
{
  "success": true,
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "credits_used": 50,
  "credits_balance": 1950,
  "model_used": "volcano-image-to-video-v1",
  "input_images_count": 2,
  "message": "视频生成任务已提交，请通过 task_id 轮询获取结果"
}
```

**失败响应（图片数量错误）**：
```json
{
  "success": false,
  "error": "图片合成功能需要提供2张图片，当前提供了 1 张"
}
```

**失败响应（图片合成失败）**：
```json
{
  "success": false,
  "error": "图片合成失败: 图生图模型调用失败"
}
```

### 任务数据说明

任务记录中的 `input_data` 字段包含以下信息：

**普通模式**：
```json
{
  "image_urls": ["https://example.com/image.jpg"],
  "images_count": 1,
  "prompt": "a beautiful woman",
  "model": "volcano-image-to-video-v1",
  "item_id": "face-to-video"
}
```

**图片合成模式**：
```json
{
  "image_urls": [
    "https://example.com/image1.jpg",
    "https://example.com/image2.jpg"
  ],
  "images_count": 2,
  "prompt": "merged image to video",
  "model": "volcano-image-to-video-v1",
  "item_id": "merge-and-video",
  "enable_image_merge": true,
  "merged_image_url": "https://example.com/merged-image.jpg",
  "original_images": [
    "https://example.com/image1.jpg",
    "https://example.com/image2.jpg"
  ],
  "merge_model_id": "volcano-image-to-image-v1",
  "video_model_id": "volcano-image-to-video-v1"
}
```

### 重要提示

⚠️ **图片数量**：图片合成模式必须提供 **2张图片**
⚠️ **积分扣除**：任务创建时一次性扣除积分，失败时自动回滚
⚠️ **异步处理**：视频生成是异步的，需要通过 `task_id` 轮询获取结果
⚠️ **提示词模板**：如果item配置了 `prompt_template`，且用户未提供 `prompt`，则使用模板
⚠️ **图片合成提示词**：图片合成模式使用 `merge_prompt_template`（第一步），视频生成使用 `video_prompt_template`（第二步）

### 错误处理

- **图片合成失败**：自动回滚积分，返回错误信息
- **视频生成失败**：自动回滚积分，返回错误信息
- **任务保存失败**：自动回滚积分，返回错误信息

### 使用场景

- 单张图片生成视频（普通模式）
- 两张图片合成后生成视频（图片合成模式）
- 支持多种图生视频模型（火山引擎、N1n、Bailian、KIE等）

---