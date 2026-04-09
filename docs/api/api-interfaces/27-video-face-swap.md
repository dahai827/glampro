# 🎭 视频换脸接口

## 接口信息

- **URL**：`POST /video-face-swap`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```
- **返回**：异步返回任务ID（需要轮询获取结果）

> 📖 关于认证和 Token 获取，请参考 [认证说明文档](./00-authentication.md)

## 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `image_url` | string | 输入1张图片URL（必须是字符串，不能是数组） | ✅ 是 |

**注意**：
- `image_url` 必须是字符串，不能是数组（只能传入1张图片）
- 视频模板URL在功能配置项的 `face_swap_video_template` 字段中配置
- 视频生成是异步的，接口会立即返回 `task_id`
- 需要通过 `/get-task` 接口轮询获取最终结果
- `item_id` 必须从 `/get-feature-configs` 接口获取，详见 [获取功能配置接口](./09-get-feature-configs.md)
- 图片URL可以通过 [上传图片接口](./03-upload-image.md) 获取

## 请求示例

### JavaScript 示例

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/video-face-swap',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'video-face-swap-001',
      image_url: 'https://example.com/face.jpg'  // 必须是字符串，1张图片
    })
  }
);

const result = await response.json();
console.log('任务ID:', result.task_id);
```

### cURL 示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/video-face-swap" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "item_id": "video-face-swap-001",
    "image_url": "https://example.com/face.jpg"
  }'
```

## 响应示例

### 成功响应 (200)

```json
{
  "success": true,
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "credits_used": 100,
  "credits_balance": 900,
  "model_used": "104b4a39315349db50880757bc8c1c996c5309e3aa11286b0a3c84dab81fd440",
  "message": "视频换脸任务已提交，请通过 task_id 轮询获取结果"
}
```

### 错误响应

#### 缺少必需参数

```json
{
  "error": "缺少必需参数: image_url"
}
```

#### 积分不足

```json
{
  "error": "Insufficient credits. You need 100 credits but only have 50."
}
```

## 响应字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `success` | boolean | 是否成功 |
| `task_id` | string | **任务ID（用于查询任务状态）** |
| `credits_used` | number | 本次任务扣除的积分 |
| `credits_balance` | number | 当前积分余额 |
| `model_used` | string | 使用的模型ID |
| `message` | string | 提示信息 |

## 获取视频生成结果

视频生成需要时间，需要通过 `/get-task` 接口轮询获取结果。

### 轮询方法

轮询方法与 [文生视频接口](./25-text-to-video.md) 相同，请参考文生视频接口文档中的轮询说明。

**快速参考**：

```javascript
// 轮询获取视频结果
async function getVideoResult(taskId) {
  const response = await fetch(
    `https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-task?task_id=${taskId}`,
    {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'apikey': ANON_KEY
      }
    }
  );

  const result = await response.json();

  if (result.status === 'completed') {
    // ✅ 视频生成完成
    return result.output_url;
  } else if (result.status === 'processing') {
    // ⏳ 还在处理中，继续轮询
    return null;
  } else if (result.status === 'failed') {
    // ❌ 生成失败
    throw new Error(result.error || '视频生成失败');
  }
  
  return null;
}

// 使用示例：每5秒轮询一次
const taskId = '550e8400-e29b-41d4-a716-446655440000';
const pollInterval = setInterval(async () => {
  try {
    const videoUrl = await getVideoResult(taskId);
    if (videoUrl) {
      clearInterval(pollInterval);
      console.log('视频生成完成:', videoUrl);
    }
  } catch (error) {
    clearInterval(pollInterval);
    console.error('轮询失败:', error);
  }
}, 5000);
```

> 📖 详细的轮询最佳实践（包括指数退避策略），请参考 [文生视频接口文档](./25-text-to-video.md#轮询最佳实践指数退避)

## 完整使用流程

```javascript
// 1. 上传图片（如果需要）
async function uploadImage(file) {
  const formData = new FormData();
  formData.append('file', file);

  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/upload-image',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'apikey': ANON_KEY
      },
      body: formData
    }
  );

  const result = await response.json();
  return result.url;  // 返回图片URL
}

// 2. 创建视频换脸任务
async function createFaceSwapTask(itemId, imageUrl) {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/video-face-swap',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'apikey': ANON_KEY
      },
      body: JSON.stringify({
        item_id: itemId,
        image_url: imageUrl  // 必须是字符串，不能是数组
      })
    }
  );
  
  const result = await response.json();
  
  if (result.success) {
    return result.task_id;
  } else {
    throw new Error(result.error);
  }
}

// 3. 轮询获取结果（参考文生视频接口的轮询方法）
async function pollVideoResult(taskId, maxAttempts = 60) {
  let attempt = 0;
  let delay = 2000;

  while (attempt < maxAttempts) {
    await new Promise(resolve => setTimeout(resolve, delay));

    const response = await fetch(
      `https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-task?task_id=${taskId}`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'apikey': ANON_KEY
        }
      }
    );

    const result = await response.json();

    if (result.status === 'completed') {
      return result.output_url;
    } else if (result.status === 'failed') {
      throw new Error(result.error || '视频生成失败');
    }

    delay = Math.min(delay * 1.5, 10000);
    attempt++;
  }

  throw new Error('视频生成超时');
}

// 4. 使用示例
try {
  // 上传图片
  const imageFile = document.getElementById('fileInput').files[0];
  const uploadedImageUrl = await uploadImage(imageFile);
  
  // 创建任务
  const taskId = await createFaceSwapTask(
    'video-face-swap-001',
    uploadedImageUrl
  );
  
  console.log('任务已创建，开始轮询...');
  
  // 轮询结果
  const videoUrl = await pollVideoResult(taskId);
  console.log('视频生成完成:', videoUrl);
  
  // 显示视频
  displayVideo(videoUrl);
} catch (error) {
  console.error('视频生成失败:', error);
}
```

## 错误处理

### 常见错误码

| HTTP 状态码 | 错误信息 | 说明 | 处理建议 |
|------------|---------|------|----------|
| 400 | `缺少必需参数: item_id` | 未提供必需的 `item_id` 参数 | 检查请求参数 |
| 400 | `缺少必需参数: image_url` | 未提供必需的 `image_url` 参数 | 检查请求参数 |
| 400 | `Feature config item not found` | `item_id` 不存在 | 检查 `item_id` 是否正确 |
| 403 | `Insufficient credits` | 积分不足 | 提示用户充值或订阅 |
| 500 | 服务器内部错误 | 服务端异常 | 稍后重试或联系技术支持 |

### 错误处理示例

```javascript
try {
  const response = await fetch(url, options);
  const result = await response.json();

  if (!response.ok) {
    // 处理错误
    if (result.error.includes('积分不足')) {
      // 提示用户充值
      showRechargeDialog();
    } else if (result.error.includes('缺少必需参数')) {
      // 检查参数
      console.error('参数错误:', result.error);
    } else {
      // 其他错误
      console.error('请求失败:', result.error);
    }
    return;
  }

  // 处理成功响应
  console.log('任务已创建:', result.task_id);
} catch (error) {
  console.error('网络错误:', error);
}
```

## 重要提示

1. **获取 item_id**：必须先调用 `/get-feature-configs` 接口获取功能配置，使用返回的 `item.id` 作为 `item_id` 参数
2. **图片数量限制**：`image_url` 必须是字符串，不能是数组（只能传入1张图片）
3. **视频模板**：视频模板URL在功能配置项的 `face_swap_video_template` 字段中配置，无需在请求中传递
4. **异步处理**：视频生成是异步的，接口立即返回 `task_id`，需要通过轮询获取最终结果
5. **轮询频率**：建议使用指数退避策略，初始2秒，最大10秒，避免频繁请求（详见 [文生视频接口](./25-text-to-video.md)）
6. **积分扣除**：任务创建时立即扣除积分，生成失败时自动回滚
7. **超时处理**：建议设置最大轮询次数（如60次），避免无限等待

## 相关接口

- **[获取功能配置](./09-get-feature-configs.md)** - 获取所有可用功能和 `item_id`（包含 `face_swap_video_template`）
- **[上传图片](./03-upload-image.md)** - 上传用户图片获取URL
- **[查询任务状态](./04-get-task.md)** - 查询视频生成任务状态（轮询使用）
- **[文生视频接口](./25-text-to-video.md)** - 参考轮询最佳实践
- **[用户状态查询](./07-user-status.md)** - 查询用户积分和订阅状态
- **[匿名登录](./01-anonymous-login.md)** - 获取访问令牌

---

**最后更新**：2026-01-26
