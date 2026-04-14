## 📝 提交用户反馈

> **响应格式说明**：成功时 HTTP 200 的 JSON 为**顶层** `id` + `message`（见下节）。若你仍持有旧版文档中 `success` + `data` 嵌套的描述，以本文档为准。

### 接口信息

- **URL**：`POST /submit-feedback`
- **认证**：❌ 公开接口（无需 Token，仅需 apikey）
- **Headers**:
  ```
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 | 默认值 |
|------|------|------|------|--------|
| app_id | string | 应用标识（用于区分不同APP的反馈） | ❌ | "default" |
| user_id | string | 用户ID（UUID格式） | ✅ | - |
| feedback_time | string | 反馈时间（ISO 8601 格式，如：2025-01-15T10:30:00Z） | ✅ | - |
| app_version | string | 应用版本号（如：1.0.0） | ❌ | null |
| content | string | 反馈内容（最大 5000 字符） | ✅ | - |
| complaint_type | string | **⚠️ 新增：投诉类型**（可选，值：quality/timeout/content/other） | ❌ | "other" |
| task_id | string | **⚠️ 新增：关联的任务ID**（可选，当提供时自动更新任务的投诉标记） | ❌ | null |

**请求 Body**:
```json
{
  "app_id": "default",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "feedback_time": "2025-01-15T10:30:00Z",
  "app_version": "1.0.0",
  "content": "这是一个用户反馈内容，可以包含多行文本。",
  "complaint_type": "quality",                           // ⚠️ 可选：投诉类型 (quality/timeout/content/other)
  "task_id": "task-uuid-12345"                          // ⚠️ 可选：关联的任务ID
}
```

### 响应

**成功响应** (HTTP 200)：Body 为**顶层**字段，**无** `success` / `data` 包装。

```json
{
  "id": "9d7d30a6-d0f5-4f73-b30e-0e38b99e0193",
  "message": "Feedback submitted successfully."
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 反馈记录 ID（UUID） |
| message | string | 成功提示文案（英文或运营配置文案） |

**错误响应** (400):
```json
{
  "error": "user_id is required"
}
```

**错误响应** (404):
```json
{
  "error": "User not found"
}
```

### 字段说明（错误体）

| 字段 | 类型 | 说明 |
|------|------|------|
| error | string | 错误信息（失败时返回） |

### 重要提示

⚠️ **公开接口**：无需认证，支持匿名用户提交反馈
⚠️ **用户ID验证**：必须提供有效的 user_id（通过 `/anonymous-login` 获取）
⚠️ **内容长度限制**：反馈内容最大 5000 字符，超出会返回错误
⚠️ **时间格式**：`feedback_time` 必须使用 ISO 8601 格式（如：`2025-01-15T10:30:00Z`）
⚠️ **自动处理**：反馈内容会自动去除首尾空格
⚠️ **状态管理**：新提交的反馈状态默认为 `pending`（待处理）

**新增参数说明**（Phase 2）：
- ✅ **complaint_type**（投诉类型）：可选参数，允许值 `quality`（质量问题）/ `timeout`（超时问题）/ `content`（内容问题）/ `other`（其他）。如不提供或无效值，默认为 `"other"`
- ✅ **task_id**（任务ID）：可选参数，当提供时自动将该任务标记为有投诉，并保存投诉理由
- ✅ **向后兼容**：老版本 App 不提供这两个参数也能正常工作

### 使用示例

```javascript
// 提交用户反馈
async function submitFeedback(userId, appVersion, content, appId = 'default') {
  try {
    const response = await fetch(
      `${API_BASE}/submit-feedback`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': ANON_KEY
        },
        body: JSON.stringify({
          app_id: appId,
          user_id: userId,
          feedback_time: new Date().toISOString(), // 使用当前时间
          app_version: appVersion,
          content: content.trim() // 建议在客户端也做 trim 处理
        })
      }
    );

    const data = await response.json();

    if (response.ok && data.id && !data.error) {
      console.log('✅ 反馈提交成功，ID:', data.id);
      return {
        success: true,
        feedbackId: data.id,
        message: data.message
      };
    } else {
      console.error('❌ 反馈提交失败:', data.error);
      return {
        success: false,
        error: data.error || '提交失败'
      };
    }
  } catch (error) {
    console.error('提交反馈时发生错误:', error);
    return {
      success: false,
      error: error.message || '网络错误'
    };
  }
}

// 使用示例 - 基础调用（兼容旧版本）
const result = await submitFeedback(
  '550e8400-e29b-41d4-a716-446655440000', // user_id
  '1.0.0', // app_version
  '这个功能很好用，但是希望能添加更多模板。', // content
  'default' // app_id（可选）
);

if (result.success) {
  alert('反馈提交成功，感谢您的反馈！');
} else {
  alert(`反馈提交失败：${result.error}`);
}

// 使用示例 - 新增参数调用（提交投诉并关联任务）
const complaintResult = await submitFeedback(
  '550e8400-e29b-41d4-a716-446655440000', // user_id
  '1.0.0', // app_version
  '生成的视频质量很差，背景模糊', // content
  'default', // app_id
  'quality', // complaint_type: 'quality', 'timeout', 'content', 'other'
  'task-uuid-12345' // task_id: 关联的任务ID
);

if (complaintResult.success) {
  alert('投诉提交成功！我们会尽快处理');
}
```

### 完整集成示例

```javascript
// 完整的反馈提交流程
class FeedbackManager {
  constructor(userId, appVersion, appId = 'default') {
    this.userId = userId;
    this.appVersion = appVersion;
    this.appId = appId;
    this.apiBase = 'https://aipixvideo.hangzhouqiqiba.shop/functions/v1';
    this.anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyZW5sZ3FwcHZxZmJpYnhwcGJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1MTIxODMsImV4cCI6MjA3ODA4ODE4M30.xVbKv4Es1sZRtWYsqbcu4eBoL1XZlMcyLcEJTTpddP4';
  }

  async submit(content) {
    // 验证内容长度
    if (!content || content.trim().length === 0) {
      return {
        success: false,
        error: '反馈内容不能为空'
      };
    }

    if (content.length > 5000) {
      return {
        success: false,
        error: '反馈内容不能超过 5000 字符'
      };
    }

    // 验证 user_id
    if (!this.userId) {
      return {
        success: false,
        error: '用户ID不能为空'
      };
    }

    try {
      const response = await fetch(
        `${this.apiBase}/submit-feedback`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': this.anonKey
          },
          body: JSON.stringify({
            app_id: this.appId,
            user_id: this.userId,
            feedback_time: new Date().toISOString(),
            app_version: this.appVersion,
            content: content.trim()
          })
        }
      );

      const data = await response.json();

      if (response.ok && data.id && !data.error) {
        return {
          success: true,
          feedbackId: data.id,
          message: data.message
        };
      } else {
        return {
          success: false,
          error: data.error || '提交失败'
        };
      }
    } catch (error) {
      return {
        success: false,
        error: error.message || '网络错误'
      };
    }
  }
}

// 使用示例
const feedbackManager = new FeedbackManager(
  '550e8400-e29b-41d4-a716-446655440000', // user_id
  '1.0.0', // app_version
  'default' // app_id
);

// 提交反馈
const result = await feedbackManager.submit('这是一个测试反馈');

if (result.success) {
  console.log('反馈提交成功，ID:', result.feedbackId);
} else {
  console.error('反馈提交失败:', result.error);
}
```

### 错误处理

| HTTP Status | 错误说明 | 建议处理 |
|-------------|---------|---------|
| 200 | 成功 | 正常处理响应数据，显示成功提示 |
| 400 | 参数错误 | 检查请求参数格式，显示错误提示给用户 |
| 404 | 用户不存在 | 提示用户重新登录 |
| 405 | 方法不允许 | 确保使用 POST 方法 |
| 500 | 服务器错误 | 重试或提示用户稍后再试 |

### 常见错误

1. **`user_id is required`**
   - 原因：未提供 user_id 参数
   - 解决：确保传入有效的 user_id（通过 `/anonymous-login` 获取）

2. **`Invalid user_id format`**
   - 原因：user_id 格式不正确（不是有效的 UUID）
   - 解决：确保 user_id 是有效的 UUID 格式

3. **`content exceeds maximum length of 5000 characters`**
   - 原因：反馈内容超过 5000 字符限制
   - 解决：提示用户缩短反馈内容

4. **`Invalid feedback_time format`**
   - 原因：feedback_time 格式不正确
   - 解决：使用 `new Date().toISOString()` 生成 ISO 8601 格式的时间字符串

5. **`User not found`**
   - 原因：提供的 user_id 对应的用户不存在
   - 解决：提示用户重新登录获取新的 user_id

### 最佳实践

1. **时间戳使用**：建议使用客户端设备的本地时间，使用 `new Date().toISOString()` 生成
2. **内容验证**：在客户端也进行内容长度验证，提供更好的用户体验
3. **错误提示**：根据不同的错误类型，给用户提供友好的错误提示
4. **成功反馈**：提交成功后给用户明确的成功提示
5. **重试机制**：对于网络错误，可以实现自动重试机制

---