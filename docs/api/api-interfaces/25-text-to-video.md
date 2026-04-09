# 🎬 文生视频接口

## 接口信息

- **URL**：`POST /text-to-video`
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
| `prompt` | string | 提示词，描述要生成的视频（最多 500 字） | ❌ 否 |

**注意**：
- 视频生成是异步的，接口会立即返回 `task_id`
- 需要通过 `/get-task` 接口轮询获取最终结果
- 如果提供了 `prompt`，将使用你提供的提示词
- 如果没有提供 `prompt`，将使用功能配置项中的 `prompt_template`
- `item_id` 必须从 `/get-feature-configs` 接口获取，详见 [获取功能配置接口](./09-get-feature-configs.md)

## 请求示例

### JavaScript 示例

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/text-to-video',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'text-to-video-001',
      prompt: 'a cat playing with a ball in a sunny garden'  // 可选
    })
  }
);

const result = await response.json();
console.log('任务ID:', result.task_id);
```

### cURL 示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/text-to-video" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "item_id": "text-to-video-001",
    "prompt": "a cat playing with a ball in a sunny garden"
  }'
```

## 响应示例

### 成功响应 (200)

```json
{
  "success": true,
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "credits_used": 50,
  "credits_balance": 950,
  "model_used": "doubao-seedream-4-0-250828",
  "message": "视频生成任务已提交，请通过 task_id 轮询获取结果"
}
```

### 错误响应

#### 缺少必需参数

```json
{
  "error": "缺少必需参数: item_id"
}
```

#### 积分不足

```json
{
  "error": "Insufficient credits. You need 50 credits but only have 20."
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
    console.log('视频URL:', result.output_url);
    return result.output_url;
  } else if (result.status === 'processing') {
    // ⏳ 还在处理中，继续轮询
    console.log('视频生成中，请稍候...');
    return null;
  } else if (result.status === 'failed') {
    // ❌ 生成失败
    console.error('视频生成失败:', result.error);
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
      // 显示视频
    }
  } catch (error) {
    clearInterval(pollInterval);
    console.error('轮询失败:', error);
  }
}, 5000);  // 每5秒轮询一次
```

### 轮询状态说明

| 状态 | 说明 | 处理方式 |
|------|------|----------|
| `processing` | 正在处理中 | 继续轮询 |
| `completed` | 生成完成 | 获取 `output_url` 显示视频 |
| `failed` | 生成失败 | 显示错误信息，停止轮询 |

### 轮询最佳实践（指数退避）

建议使用指数退避策略进行轮询，避免频繁请求：

```javascript
// 轮询视频结果（带指数退避）
async function pollVideoResult(taskId, maxAttempts = 60) {
  let attempt = 0;
  let delay = 2000;  // 初始延迟2秒

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
      return result.output_url;  // 返回视频URL
    } else if (result.status === 'failed') {
      throw new Error(result.error || '视频生成失败');
    }

    // 指数退避：延迟时间逐渐增加（最大10秒）
    delay = Math.min(delay * 1.5, 10000);
    attempt++;
  }

  throw new Error('视频生成超时');
}

// 使用示例
try {
  const videoUrl = await pollVideoResult(taskId);
  console.log('视频生成完成:', videoUrl);
} catch (error) {
  console.error('视频生成失败:', error);
}
```

## 完整使用流程

```javascript
// 1. 创建视频生成任务
async function createVideoTask(itemId, prompt) {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/text-to-video',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'apikey': ANON_KEY
      },
      body: JSON.stringify({
        item_id: itemId,
        prompt: prompt
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

// 2. 轮询获取结果
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

// 3. 使用示例
try {
  // 创建任务
  const taskId = await createVideoTask(
    'text-to-video-001',
    'a cat playing with a ball in a sunny garden'
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
| 400 | `prompt 长度超过限制（最多 500 字）` | 提示词超过500字限制 | 缩短提示词长度 |
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
2. **异步处理**：视频生成是异步的，接口立即返回 `task_id`，需要通过轮询获取最终结果
3. **轮询频率**：建议使用指数退避策略，初始2秒，最大10秒，避免频繁请求
4. **提示词模板**：如果功能配置项中设置了 `prompt_template`，且用户未提供 `prompt`，将使用模板中的提示词
5. **积分扣除**：任务创建时立即扣除积分，生成失败时自动回滚
6. **超时处理**：建议设置最大轮询次数（如60次），避免无限等待

## 相关接口

- **[获取功能配置](./09-get-feature-configs.md)** - 获取所有可用功能和 `item_id`
- **[查询任务状态](./04-get-task.md)** - 查询视频生成任务状态（轮询使用）
- **[用户状态查询](./07-user-status.md)** - 查询用户积分和订阅状态
- **[匿名登录](./01-anonymous-login.md)** - 获取访问令牌

---

**最后更新**：2026-01-26
