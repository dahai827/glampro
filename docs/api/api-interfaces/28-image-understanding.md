# 🧠 图片理解接口

## 接口信息

- **URL**：`POST /image-understanding`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```
- **返回**：同步返回 AI 分析的结构化 JSON 结果

> 📖 关于认证和 Token 获取，请参考 [认证说明文档](./00-authentication.md)

## 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `image_url` | string | 需要分析的图片 URL | ✅ 是 |
| `prompt` | string | 提示词，描述需要分析的内容（最多 2000 字） | ❌ 否 |
| `language` | string | 返回结果的语言代码（en/zh/ja/ko 等），默认 "en" | ❌ 否 |

**提示词优先级**：
1. 如果后台功能配置项设置了 `prompt_template`，**优先使用后台配置的提示词**
2. 如果后台没有配置 `prompt_template`，则使用 App 传入的 `prompt`
3. 如果两者都没有，接口将返回错误

**注意**：
- `item_id` 必须从 `/get-feature-configs` 接口获取，详见 [获取功能配置接口](./09-get-feature-configs.md)
- 图片URL可以通过 [上传图片接口](./03-upload-image.md) 获取
- 支持的图片格式：JPEG、PNG、WebP、GIF

## 请求示例

### JavaScript 示例

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-understanding',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'emotion-recognition-001',
      image_url: 'https://example.com/pet.jpg',
      language: 'zh'
    })
  }
);

const result = await response.json();
console.log('分析结果:', result.output);
```

### cURL 示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-understanding" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "item_id": "emotion-recognition-001",
    "image_url": "https://example.com/pet.jpg",
    "language": "zh"
  }'
```

### 使用自定义提示词

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-understanding',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'image-analysis-001',
      image_url: 'https://example.com/photo.jpg',
      prompt: 'Analyze this image and return a JSON with: subject, mood, colors, composition',
      language: 'en'
    })
  }
);
```

## 响应示例

### 成功响应 (200)

```json
{
  "success": true,
  "task_id": "770e8400-e29b-41d4-a716-446655440002",
  "status": "completed",
  "output": {
    "breed": "法国斗牛犬",
    "age": "1-2岁",
    "behavior": "放松",
    "emotion_score": 7,
    "emotion_description": "狗狗看起来非常放松和舒适，眼睛半闭，身体姿态自然。",
    "behavior_analysis": "狗狗趴在地毯上，头部轻轻靠在爪子上，表明它处于安全舒适的环境中。",
    "owner_suggestion": "主人可以继续保持当前的环境和氛围，给予狗狗足够的休息空间。"
  },
  "credits_used": 100,
  "credits_balance": 1900,
  "model_used": "qwenvl",
  "message": "Qwen VL Plus 图片理解完成"
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

#### 缺少提示词

```json
{
  "error": "缺少提示词: 后台未配置 prompt_template，且请求未提供 prompt"
}
```

## 响应字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `success` | boolean | 是否成功 |
| `task_id` | string | 任务ID（可用于查询任务历史） |
| `status` | string | 任务状态，图片理解固定为 `"completed"` |
| `output` | object/string | AI 分析的结构化结果（JSON 对象或文本） |
| `credits_used` | number | 本次任务扣除的积分 |
| `credits_balance` | number | 当前积分余额 |
| `model_used` | string | 使用的模型ID |
| `message` | string | 提示信息 |

## 错误处理

### 常见错误码

| HTTP 状态码 | 错误信息 | 说明 | 处理建议 |
|------------|---------|------|----------|
| 400 | `缺少必需参数: item_id` | 未提供必需的 `item_id` | 检查请求参数 |
| 400 | `缺少必需参数: image_url` | 未提供必需的 `image_url` | 检查请求参数 |
| 400 | `prompt 长度超过限制` | 提示词超过 2000 字限制 | 缩短提示词 |
| 400 | `Feature config item not found` | `item_id` 不存在 | 检查 `item_id` 是否正确 |
| 400 | `缺少提示词` | 后台和请求都没有提示词 | 提供 `prompt` 参数 |
| 400 | `不支持的模型 ID` | 功能配置绑定的模型不存在 | 检查后台模型配置 |
| 403 | `Insufficient credits` | 积分不足 | 提示用户充值或订阅 |
| 403 | `subscription has expired` | 订阅已过期 | 提示用户续费 |
| 500 | 服务器内部错误 | AI 模型调用失败等 | 稍后重试 |

### 错误处理示例

```javascript
try {
  const response = await fetch(url, options);
  const result = await response.json();

  if (!response.ok || !result.success) {
    const errorMsg = result.error || result.message;
    if (errorMsg.includes('Insufficient credits')) {
      showRechargeDialog();
    } else if (errorMsg.includes('subscription')) {
      showSubscriptionDialog();
    } else {
      console.error('请求失败:', errorMsg);
    }
    return;
  }

  // 处理成功响应
  displayAnalysisResult(result.output);
} catch (error) {
  console.error('网络错误:', error);
}
```

## 使用流程

### 完整使用示例

```javascript
// 1. 上传图片
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
  return result.url;
}

// 2. 调用图片理解
async function analyzeImage(itemId, imageUrl, language) {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-understanding',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'apikey': ANON_KEY
      },
      body: JSON.stringify({
        item_id: itemId,
        image_url: imageUrl,
        language: language
      })
    }
  );

  const result = await response.json();

  if (result.success) {
    return result.output;
  } else {
    throw new Error(result.error || result.message);
  }
}

// 使用示例
const imageFile = document.getElementById('fileInput').files[0];
const uploadedUrl = await uploadImage(imageFile);
const analysis = await analyzeImage('emotion-recognition-001', uploadedUrl, 'zh');

console.log('品种:', analysis.breed);
console.log('情绪评分:', analysis.emotion_score);
console.log('行为分析:', analysis.behavior_analysis);
console.log('建议:', analysis.owner_suggestion);
```

## 支持的语言

| 语言代码 | 语言名称 |
|---------|---------|
| `en` | English |
| `zh` | 中文 |
| `ja` | 日本語 |
| `ko` | 한국어 |
| `es` | Español |
| `fr` | Français |
| `de` | German |
| `it` | Italian |
| `pt` | Portuguese |
| `ru` | Russian |
| `ar` | Arabic |
| `hi` | Hindi |

## 与其他接口的区别

| 对比项 | 图片理解 (`/image-understanding`) | 图生图 (`/image-to-image`) |
|--------|----------------------------------|--------------------------|
| 输入 | 1 张图片 + 提示词 | 1 张或多张图片 + 提示词 |
| 输出 | 结构化 JSON 文本（分析结果） | 生成的图片 URL |
| 处理方式 | 同步返回 | 同步返回 |
| 典型用途 | 情绪识别、内容分析、图片描述 | 风格转换、图片编辑、图片合成 |
| 模型类型 | `image_understanding` | `image_to_image` |

## 重要提示

1. **同步返回**：图片理解接口是同步的，直接返回分析结果，无需轮询
2. **提示词优先级**：后台配置的 `prompt_template` 优先级高于 App 传入的 `prompt`，这样便于后台统一管理分析逻辑
3. **结果格式**：`output` 字段通常是 JSON 对象，具体结构取决于后台配置的提示词
4. **积分扣除**：任务创建时立即扣除积分
5. **多语言支持**：通过 `language` 参数控制返回结果的语言
6. **获取 item_id**：必须先调用 `/get-feature-configs` 接口获取功能配置，使用返回的 `item.id` 作为 `item_id` 参数

## 相关接口

- **[获取功能配置](./09-get-feature-configs.md)** - 获取所有可用功能和 `item_id`
- **[上传图片](./03-upload-image.md)** - 上传用户图片获取URL
- **[用户状态查询](./07-user-status.md)** - 查询用户积分和订阅状态
- **[匿名登录](./01-anonymous-login.md)** - 获取访问令牌

---

**最后更新**：2026-02-18
