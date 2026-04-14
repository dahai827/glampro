# 🎬 动作模仿图生视频接口

## 接口信息

- **URL**：`POST /image-to-dongzuo-video`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```
- **返回**：异步返回任务 ID（需要轮询 `/get-task` 获取结果）

> 📖 关于认证和 Token 获取，请参考 [认证说明文档](./00-authentication.md)

---

## 请求参数

| 参数                     | 类型               | 说明                                                | 必需  |
| ------------------------ | ------------------ | --------------------------------------------------- | ----- |
| `item_id`                | string             | 功能配置项 ID（来自 `/get-feature-configs`）        | ✅ 是 |
| `image_url`              | string 或 string[] | 人物主图 URL，**仅支持 1 张**（数组时长度必须为 1） | ✅ 是 |
| `video_url`              | string             | 动作驱动视频 URL（建议直接使用 `/upload-video` 返回值） | ✅ 是 |
| `video_duration_seconds` | number             | 驱动视频时长（秒，建议直接使用 `/upload-video` 返回值，服务端会校验 `<=30`） | ✅ 是 |

**注意**：

- `image_url` 和 `video_url` 必须是可公网访问的 `http/https` 链接。
- v1 仅支持单图动作模仿，不支持多图输入。
- 接口会立即返回任务信息；最终视频需通过 `/get-task` 轮询获取。

---

## 完整调用流程（推荐）

1. 上传人像图片 → [`/upload-image`](./03-upload-image.md)
2. 上传驱动视频 → [`/upload-video`](./12-upload-video.md)
   - 动作模仿场景建议传 `purpose=image_to_motionvideo`
   - 从响应中获取 `video_url` 和 `video_duration_seconds`
3. 调用 `/image-to-dongzuo-video` 创建任务
4. 调用 [`/get-task`](./04-get-task.md) 轮询任务结果

---

## 输入输出限制（官方）

### 输入限制

1. 驱动视频（`video_url`）

- 时长：不超过 `30s`
- 格式：`mp4` / `mov` / `webm`
- 分辨率：`>=200x200`，`<=2048x1440 (2K)`

2. 人像图片（`image_url`）

- 格式：`jpeg` / `jpg` / `png`
- 分辨率：`>=480x480`，`<=1920x1080`
- 大小：不超过 `4.7MB`

### 输出规格

- 输出格式：`mp4`
- 输出分辨率：`720P`
- 输出帧率：`25fps`

---

## App 侧上传建议（强烈建议）

1. 图片上传前处理

- 在 App 端先做等比例缩放，建议宽高都不超过 `1024`
- 同时做图片压缩，尽量控制在 `4.7MB` 内（建议留裕量，例如 `<=4MB`）

2. 视频上传前提示

- 在 App 端上传前先把视频压缩/转码成 `480p`
- 在 App 端明确提示用户：驱动视频时长不要超过 `30s`

> 服务端也会做前置校验：图片格式/大小/分辨率、视频格式、视频时长（`video_duration_seconds`）。

---

## 请求示例

### JavaScript

```javascript
const response = await fetch(
  "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-to-dongzuo-video",
  {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      item_id: "dongzuo-video-001",
      image_url: "https://example.com/portrait.jpg",
      video_url: "https://example.com/driver.mp4",
      video_duration_seconds: 12.5,
    }),
  },
);

const result = await response.json();
console.log(result);
```

### cURL

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-to-dongzuo-video" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "item_id": "dongzuo-video-001",
    "image_url": "https://example.com/portrait.jpg",
    "video_url": "https://example.com/driver.mp4",
    "video_duration_seconds": 12.5
  }'
```

---

## 响应示例

### 成功响应 (200)

```json
{
  "success": true,
  "task_id": "4f5a2fb5-0dbb-4d24-a1d1-9fbc5a3e9c52",
  "replicate_id": "766248713058972545",
  "credits_used": 30,
  "credits_balance": 970,
  "model_used": "jimeng-dreamactor-m20",
  "input_images_count": 1,
  "message": "动作模仿视频任务已提交，请通过 task_id 轮询获取结果"
}
```

### 错误响应示例

```json
{
  "error": "缺少必需参数: video_url"
}
```

---

## 轮询任务结果

调用 `/get-task?task_id={task_id}` 查询任务状态：

- `processing`：处理中
- `completed`：已完成，返回 `output_url`
- `failed`：失败，返回 `error_message`

```javascript
async function pollTask(taskId) {
  const response = await fetch(
    `https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-task?task_id=${taskId}`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: ANON_KEY,
      },
    },
  );

  const result = await response.json();
  if (result.status === "completed") {
    return result.output_url;
  }
  if (result.status === "failed") {
    throw new Error(result.error_message || "任务失败");
  }
  return null;
}
```

---

## 说明

- 本接口对接火山引擎 CV 动作模仿 2.0，服务端会将上游结果视频转存到 Supabase
  Storage 后返回稳定 `output_url`。
- 上游临时链接可能过期，请以 `/get-task` 返回的 `output_url` 为准。
