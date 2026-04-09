# 🎨 文生图接口

## 接口信息

- **URL**：`POST /text-to-image`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```
- **返回**：同步返回生成的图片URL

> 📖 关于认证和 Token 获取，请参考 [认证说明文档](./00-authentication.md)

## 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `prompt` | string | 提示词，描述要生成的图片（最多 500 字） | ❌ 否 |

**注意**：
- 如果提供了 `prompt`，将使用你提供的提示词
- 如果没有提供 `prompt`，将使用功能配置项中的 `prompt_template`
- `item_id` 必须从 `/get-feature-configs` 接口获取，详见 [获取功能配置接口](./09-get-feature-configs.md)

## 请求示例

### JavaScript 示例

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/text-to-image',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'text-to-image-001',  // 来自 /get-feature-configs
      prompt: 'a beautiful sunset over the ocean with birds flying'  // 可选
    })
  }
);

const result = await response.json();
console.log('生成的图片URL:', result.output_url);
```

### cURL 示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/text-to-image" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "item_id": "text-to-image-001",
    "prompt": "a beautiful sunset over the ocean with birds flying"
  }'
```

## 响应示例

### 成功响应 (200)

```json
{
  "success": true,
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "output_url": "https://lrenlgqppvqfbibxppbi.supabase.co/storage/v1/object/public/ai-generated/user123/image.jpg",
  "credits_used": 10,
  "credits_balance": 990,
  "model_used": "doubao-seedream-4-0-250828",
  "message": "图片生成成功"
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
  "error": "Insufficient credits. You need 10 credits but only have 5."
}
```

#### 提示词过长

```json
{
  "error": "prompt 长度超过限制（最多 500 字，当前 600 字）"
}
```

#### 功能配置项不存在

```json
{
  "error": "Feature config item not found"
}
```

## 响应字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `success` | boolean | 是否成功 |
| `task_id` | string | 任务ID（可用于查询任务历史） |
| `output_url` | string | 生成的图片URL（可直接使用） |
| `credits_used` | number | 本次任务扣除的积分 |
| `credits_balance` | number | 当前积分余额 |
| `model_used` | string | 使用的模型ID |
| `message` | string | 提示信息 |

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
  console.log('图片生成成功:', result.output_url);
} catch (error) {
  console.error('网络错误:', error);
}
```

## 使用流程

### 完整使用示例

```javascript
// 1. 获取功能配置列表（App 启动时）
async function loadFeatureConfigs() {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-feature-configs',
    {
      method: 'GET',
      headers: {
        'apikey': ANON_KEY
      }
    }
  );
  const result = await response.json();
  
  // 找到文生图功能项
  let textToImageItem = null;
  for (const section of result.sections) {
    textToImageItem = section.items.find(
      item => item.model_type === 'text_to_image'
    );
    if (textToImageItem) break;
  }
  
  return textToImageItem;
}

// 2. 检查用户积分
async function checkUserCredits() {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/user-status',
    {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'apikey': ANON_KEY
      }
    }
  );
  const result = await response.json();
  return result.credits_balance;
}

// 3. 生成图片
async function generateImage(itemId, prompt) {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/text-to-image',
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
    return result.output_url;
  } else {
    throw new Error(result.error);
  }
}

// 使用示例
const featureConfig = await loadFeatureConfigs();
const userCredits = await checkUserCredits();

if (userCredits >= featureConfig.estimated_credits) {
  try {
    const imageUrl = await generateImage(
      featureConfig.id,
      'a beautiful sunset over the ocean'
    );
    console.log('生成的图片:', imageUrl);
  } catch (error) {
    console.error('生成失败:', error);
  }
} else {
  console.log('积分不足，请充值');
}
```

## 重要提示

1. **获取 item_id**：必须先调用 `/get-feature-configs` 接口获取功能配置，使用返回的 `item.id` 作为 `item_id` 参数
2. **提示词模板**：如果功能配置项中设置了 `prompt_template`，且用户未提供 `prompt`，将使用模板中的提示词
3. **积分扣除**：任务创建时立即扣除积分，生成失败时自动回滚
4. **同步返回**：文生图接口是同步的，直接返回生成的图片URL，无需轮询
5. **图片URL有效期**：生成的图片URL是永久有效的，可以保存使用

## 相关接口

- **[获取功能配置](./09-get-feature-configs.md)** - 获取所有可用功能和 `item_id`
- **[用户状态查询](./07-user-status.md)** - 查询用户积分和订阅状态
- **[匿名登录](./01-anonymous-login.md)** - 获取访问令牌

---

**最后更新**：2026-01-26
