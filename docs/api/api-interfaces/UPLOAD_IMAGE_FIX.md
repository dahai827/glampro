# 🔧 图片上传接口修复记录

## 问题概述

测试上传图片时返回 **Server error 400**，根据接口文档进行修复。

## 根本原因

1. **响应字段不匹配**：
   - 接口文档定义：`image_url`, `file_name`, `file_size`, `success`
   - 旧模型定义：`url`, `size`, `filename`

2. **请求格式问题**：
   - 错误提示：`"The request of a upload task should not contain a body or a body stream"`
   - 说明不应该在构建 URLRequest 时同时设置 httpBody

## 修改清单

### 1. 更新模型定义 (AI/Domain/Models/Models.swift)

```swift
/// 上传图片响应
struct UploadImageResponse: Codable {
    let success: Bool              // ✅ 新增
    let image_url: String          // ✅ 改为 image_url
    let file_name: String?         // ✅ 改为 file_name
    let file_size: Int?            // ✅ 改为 file_size
}
```

**关键改动：**
- `url` → `image_url`
- `size` → `file_size`
- `filename` → `file_name`
- 新增 `success` 字段

### 2. 修复上传服务 (AI/Services/Networking/ImageUploadService.swift)

**改进点：**
- 分离请求头构建和 body 构建
- `buildRequest()` 只构建 URL、Method、Headers
- `buildMultipartBody()` 单独构建 multipart body
- 上传时使用 `uploadWithProgress(request:imageData:)`

```swift
private func buildRequest(boundary: String) throws -> URLRequest {
    // 只构建请求头和 URL，不设置 body
    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "Content-Type")
    return request
}

private func buildMultipartBody(
    imageData: Data,
    fileName: String,
    boundary: String
) throws -> Data {
    // 单独构建 multipart body
    var body = Data()
    // ... 构建过程
    return body
}
```

### 3. 更新测试方法 (AI/Debug/TestRunner.swift)

**testImageUpload():**
```swift
guard response.success && !response.image_url.isEmpty else {
    throw NSError(domain: "Upload failed", code: -1)
}
return "图片上传成功 - URL: \(response.image_url), 文件大小: \(response.file_size ?? 0) bytes"
```

**testImageUploadWithPhoto():**
```swift
guard response.success && !response.image_url.isEmpty else {
    throw NSError(domain: "Upload failed", code: -1)
}
return "从相册上传成功 - URL: \(response.image_url), ..."
```

**testUploadAndGenerateFlow():**
```swift
let generateResponse = try await self.aiGenerationRepository.processImage(
    itemId: "integration_upload_test",
    imageUrl: uploadResponse.image_url  // ✅ 改为 image_url
)
```

### 4. 优化 UI 显示 (AI/Debug/DebugTestView.swift)

```swift
Text("尺寸: \(Int(image.size.width)) × \(Int(image.size.height)) px")
```

## 测试验证步骤

1. **构建项目**
   ```bash
   xcodebuild build -scheme AI
   ```

2. **运行上传测试**
   - 打开 Debug Test Panel
   - 点击"选择图片"按钮从相册选择图片
   - 点击"上传选中图片"按钮
   - 查看测试结果，应该看到：
     ```
     ✅ 从相册上传图片 - URL: https://..., 文件大小: XXXXX bytes
     ```

3. **验证响应格式**
   - 响应包含 `success: true`
   - `image_url` 非空且有效
   - `file_size` 正确反映文件大小

## 接口文档参考

**完整响应示例：**
```json
{
  "success": true,
  "image_url": "https://lrenlgqppvqfbibxppbi.supabase.co/storage/v1/object/public/...",
  "file_name": "uploaded_image_1234567890.jpg",
  "file_size": 124832
}
```

## 后续影响

- ✅ 上传图片功能恢复正常
- ✅ 图片到图片处理流程（integration test）可正常使用返回的 URL
- ✅ 相册选择上传流程完整可用

---

**修改日期:** 2026-01-15
**修改者:** iOS Architecture Lead
