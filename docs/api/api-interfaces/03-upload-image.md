## 2️⃣ 上传图片

### 接口信息

- **URL**：`POST /upload-image`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```
- **Content-Type**：`multipart/form-data`

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| file | File | 图片文件 | ✅ |

### 图片要求

- **格式**：JPG、PNG、WebP、GIF
- **大小**：最大 10MB
- **内容**：建议包含清晰正面人脸

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| image_url | string | **图片公开访问 URL（重要）** |
| file_name | string | 原始文件名 |
| file_size | number | 文件大小（字节）|

### 使用场景

- 用户选择或拍摄人脸照片后调用
- 获取 image_url 用于后续创建任务

---