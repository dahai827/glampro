# 1️⃣2️⃣ 上传视频

## 接口信息

- **URL**：`POST /upload-video`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```
- **Content-Type**：`multipart/form-data`

---

## 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `file` | File | 视频文件 | ✅ |
| `purpose` | string | 可选。动作模仿场景传 `image_to_motionvideo`，会额外校验时长 `<=30s` | ❌ |

---

## 视频要求

- **格式**：`mp4` / `mov` / `webm`
- **大小**：最大 `200MB`
- **动作模仿场景**（`purpose=image_to_motionvideo`）：
  - 服务端要求视频时长 `<=30s`
  - 若无法识别时长，会返回错误并提示重试/更换视频

### App 端建议（动作模仿必须执行）

1. 上传前先将视频压缩/转码为 **480p**
2. 在 App 提示用户：视频长度不要超过 **30 秒**

---

## 响应字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `success` | boolean | 是否成功 |
| `videoUID` | string | Cloudflare Stream 视频 ID |
| `webPlaybackURL` | string | Cloudflare 网页播放地址 |
| `hlsManifestURL` | string | Cloudflare HLS 清单地址 |
| `video_url` | string | Supabase Storage 公网视频 URL（可直接传给动作模仿接口） |
| `video_duration_seconds` | number \| null | 视频时长（秒） |
| `storage_bucket` | string | 存储 bucket |
| `storage_path` | string | 存储路径 |
| `message` | string | 提示信息 |

---

## 成功响应示例

```json
{
  "success": true,
  "videoUID": "f65014bc6ff5419ea86e7972a047ba22",
  "webPlaybackURL": "https://watch.cloudflarestream.com/f65014bc6ff5419ea86e7972a047ba22",
  "hlsManifestURL": "https://customer-xxxxx.cloudflarestream.com/f65014bc6ff5419ea86e7972a047ba22/manifest/video.m3u8",
  "video_url": "https://xxx.supabase.co/storage/v1/object/public/user-uploads/uid/videos/1711111111111_ab12cd.mp4",
  "video_duration_seconds": 12.48,
  "storage_bucket": "user-uploads",
  "storage_path": "uid/videos/1711111111111_ab12cd.mp4",
  "message": "视频上传成功"
}
```

---

## 错误示例

```json
{
  "error": "动作模仿视频时长不能超过 30 秒（当前 38.7 秒）"
}
```

---

## 与动作模仿接口配合方式

1. 调用本接口上传视频，拿到 `video_url` 和 `video_duration_seconds`
2. 调用 [`/image-to-dongzuo-video`](./38-image-to-dongzuo-video.md) 时，直接透传这两个字段
3. 任务创建后调用 [`/get-task`](./04-get-task.md) 轮询结果

