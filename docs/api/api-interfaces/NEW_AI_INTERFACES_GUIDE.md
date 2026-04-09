# 🎨 AI 功能接口对接文档

**文档版本**: v1.0  
**更新时间**: 2026-01-04  
**API 基础 URL**: `https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1`

---

## 📋 接口概览

本文档说明以下5个新接口的使用方法：

| 接口 | 路径 | 功能说明 | 返回类型 |
|------|------|----------|----------|
| **文生图** | `/text-to-image` | 根据文字描述生成图片 | 同步返回图片URL |
| **图生图** | `/image-to-image` | 基于输入图片生成新图片 | 同步返回图片URL |
| **文生视频** | `/text-to-video` | 根据文字描述生成视频 | 异步返回任务ID |
| **图生视频** | `/image-to-video` | 基于输入图片生成视频 | 异步返回任务ID |
| **视频换脸** | `/video-face-swap` | 将指定人脸替换到视频中 | 异步返回任务ID |

---

## 🔑 认证说明

### Headers 配置

所有接口请求必须包含以下 Headers：

```javascript
{
  'Authorization': `Bearer ${accessToken}`,  // 用户访问令牌（必需）
  'Content-Type': 'application/json',        // 请求内容类型（必需）
  'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'  // Supabase 匿名密钥（必需）
}
```

### SUPABASE_ANON_KEY（固定值）

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyZW5sZ3FwcHZxZmJpYnhwcGJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1MTIxODMsImV4cCI6MjA3ODA4ODE4M30.xVbKv4Es1sZRtWYsqbcu4eBoL1XZlMcyLcEJTTpddP4
```

### 获取 access_token

在调用这些接口之前，需要先通过 `/anonymous-login` 接口获取 `access_token`：

```javascript
// 1. 匿名登录获取 token
const loginResponse = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/anonymous-login',
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${ANON_KEY}`,
      'apikey': ANON_KEY
    },
    body: JSON.stringify({})
  }
);

const loginResult = await loginResponse.json();
const accessToken = loginResult.access_token;  // 保存这个 token 用于后续请求
```

---

## 📖 如何获取 item_id

所有接口都需要 `item_id` 参数，该参数来自 `/get-feature-configs` 接口。

### 调用示例

```javascript
// 获取功能配置列表
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

// 遍历 sections 和 items 找到对应的功能项
for (const section of result.sections) {
  for (const item of section.items) {
    console.log(`功能ID: ${item.id}, 标题: ${item.title}`);
    // item.id 就是需要的 item_id
  }
}
```

### 响应示例

```json
{
  "sections": [
    {
      "id": "feature_grid",
      "items": [
        {
          "id": "text-to-image-001",        // ← 这就是 item_id
          "title": "文生图功能",
          "model_type": "text_to_image",     // ← 根据此字段选择接口
          "estimated_credits": 10,
          "model_id": "doubao-seedream-4-0-250828",
          "prompt_template": "a beautiful landscape"
        },
        {
          "id": "image-to-image-001",       // ← 这就是 item_id
          "title": "图生图功能",
          "model_type": "image_to_image",    // ← 根据此字段选择接口
          "estimated_credits": 15
        }
      ]
    }
  ]
}
```

**重要提示**：
- `item.id` 是调用接口时需要的 `item_id` 参数
- `item.model_type` 用于判断应该调用哪个接口（见下方说明）

---

## 🎯 根据 model_type 选择接口

### 核心概念

`/get-feature-configs` 接口返回的每个 `item` 都包含 `model_type` 字段，该字段指示该功能项应该使用哪个接口来生成 AI 任务。

### model_type 与接口映射关系

| model_type 值 | 对应接口 | 说明 |
|--------------|---------|------|
| `text_to_image` | `/text-to-image` | 文生图接口 |
| `image_to_image` | `/image-to-image` | 图生图接口 |
| `text_to_video` | `/text-to-video` | 文生视频接口 |
| `image_to_video` | `/image-to-video` | 图生视频接口 |
| `video_face_swap` | `/video-face-swap` | 视频换脸接口 |

### 使用流程

1. **获取功能配置列表**：调用 `/get-feature-configs` 获取所有功能项
2. **解析 model_type**：从返回的 `item` 中读取 `model_type` 字段
3. **选择对应接口**：根据 `model_type` 的值调用相应的接口
4. **传递 item_id**：将 `item.id` 作为 `item_id` 参数传递给选定的接口

### 代码示例

```javascript
// 1. 获取功能配置列表
const configResponse = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-feature-configs',
  {
    method: 'GET',
    headers: {
      'apikey': ANON_KEY
    }
  }
);

const configResult = await configResponse.json();

// 2. 遍历功能项，根据 model_type 选择接口
for (const section of configResult.sections) {
  for (const item of section.items) {
    const { id, model_type, title } = item;
    
    console.log(`功能: ${title}, ID: ${id}, 类型: ${model_type}`);
    
    // 3. 根据 model_type 选择对应的接口
    let apiEndpoint = '';
    switch (model_type) {
      case 'text_to_image':
        apiEndpoint = '/text-to-image';
        break;
      case 'image_to_image':
        apiEndpoint = '/image-to-image';
        break;
      case 'text_to_video':
        apiEndpoint = '/text-to-video';
        break;
      case 'image_to_video':
        apiEndpoint = '/image-to-video';
        break;
      case 'video_face_swap':
        apiEndpoint = '/video-face-swap';
        break;
      default:
        console.warn(`未知的 model_type: ${model_type}`);
        continue;
    }
    
    // 4. 调用对应的接口
    // 注意：这里只是示例，实际调用时需要根据接口要求传递相应参数
    console.log(`应该调用接口: ${apiEndpoint}，item_id: ${id}`);
  }
}
```

### 完整使用示例

```javascript
// 统一的 AI 任务生成函数
async function generateAITask(itemId, userInput) {
  // 1. 先从缓存或重新获取功能配置
  const configResponse = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-feature-configs',
    {
      method: 'GET',
      headers: { 'apikey': ANON_KEY }
    }
  );
  
  const configResult = await configResponse.json();
  
  // 2. 找到对应的功能项
  let targetItem = null;
  for (const section of configResult.sections) {
    targetItem = section.items.find(item => item.id === itemId);
    if (targetItem) break;
  }
  
  if (!targetItem) {
    throw new Error(`未找到 item_id: ${itemId}`);
  }
  
  // 3. 根据 model_type 选择接口和构建请求参数
  const { model_type, id } = targetItem;
  let apiEndpoint = '';
  let requestBody = { item_id: id };
  
  switch (model_type) {
    case 'text_to_image':
      apiEndpoint = '/text-to-image';
      if (userInput.prompt) {
        requestBody.prompt = userInput.prompt;
      }
      break;
      
    case 'image_to_image':
      apiEndpoint = '/image-to-image';
      if (!userInput.image_url) {
        throw new Error('图生图接口需要 image_url 参数');
      }
      requestBody.image_url = userInput.image_url;
      if (userInput.prompt) {
        requestBody.prompt = userInput.prompt;
      }
      break;
      
    case 'text_to_video':
      apiEndpoint = '/text-to-video';
      if (userInput.prompt) {
        requestBody.prompt = userInput.prompt;
      }
      break;
      
    case 'image_to_video':
      apiEndpoint = '/image-to-video';
      if (!userInput.image_url) {
        throw new Error('图生视频接口需要 image_url 参数');
      }
      requestBody.image_url = userInput.image_url;
      if (userInput.prompt) {
        requestBody.prompt = userInput.prompt;
      }
      break;
      
    case 'video_face_swap':
      apiEndpoint = '/video-face-swap';
      if (!userInput.image_url) {
        throw new Error('视频换脸接口需要 image_url 参数');
      }
      requestBody.image_url = userInput.image_url;
      break;
      
    default:
      throw new Error(`不支持的 model_type: ${model_type}`);
  }
  
  // 4. 调用对应的接口
  const response = await fetch(
    `https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1${apiEndpoint}`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'apikey': ANON_KEY
      },
      body: JSON.stringify(requestBody)
    }
  );
  
  return await response.json();
}

// 使用示例
try {
  // 文生图
  const textToImageResult = await generateAITask('text-to-image-001', {
    prompt: 'a beautiful sunset'
  });
  
  // 图生图
  const imageToImageResult = await generateAITask('image-to-image-001', {
    image_url: 'https://example.com/image.jpg',
    prompt: 'make it look like a painting'
  });
  
  // 图生视频
  const imageToVideoResult = await generateAITask('image-to-video-001', {
    image_url: 'https://example.com/pet.jpg',
    prompt: 'make the pet dance'
  });
  
  // 视频换脸
  const faceSwapResult = await generateAITask('video-face-swap-001', {
    image_url: 'https://example.com/face.jpg'
  });
} catch (error) {
  console.error('生成失败:', error);
}
```

### 响应示例（包含 model_type）

```json
{
  "sections": [
    {
      "id": "feature_grid",
      "items": [
        {
          "id": "text-to-image-001",
          "title": "文生图功能",
          "model_type": "text_to_image",        // ← 关键字段
          "model_id": "doubao-seedream-4-0-250828",
          "estimated_credits": 10,
          "prompt_template": "a beautiful landscape"
        },
        {
          "id": "image-to-image-001",
          "title": "图生图功能",
          "model_type": "image_to_image",        // ← 关键字段
          "model_id": "doubao-seedream-4-0-250828",
          "estimated_credits": 15
        },
        {
          "id": "text-to-video-001",
          "title": "文生视频功能",
          "model_type": "text_to_video",         // ← 关键字段
          "model_id": "doubao-seedream-4-0-250828",
          "estimated_credits": 50
        },
        {
          "id": "image-to-video-001",
          "title": "图生视频功能",
          "model_type": "image_to_video",        // ← 关键字段
          "model_id": "doubao-seedream-4-0-250828",
          "estimated_credits": 50
        },
        {
          "id": "video-face-swap-001",
          "title": "视频换脸功能",
          "model_type": "video_face_swap",        // ← 关键字段
          "model_id": "104b4a39315349db50880757bc8c1c996c5309e3aa11286b0a3c84dab81fd440",
          "estimated_credits": 100,
          "face_swap_video_template": "https://example.com/template.mp4"
        }
      ]
    }
  ]
}
```

### 注意事项

1. **必须检查 model_type**：在调用接口前，务必检查 `model_type` 字段，确保调用正确的接口
2. **参数匹配**：不同 `model_type` 对应的接口参数要求不同，需要根据接口文档传递正确的参数
3. **错误处理**：如果遇到未知的 `model_type` 值，应该跳过或提示用户该功能暂不可用
4. **缓存配置**：建议在 App 启动时获取并缓存功能配置，避免每次调用都请求配置接口

---

## 1️⃣ 文生图接口 `/text-to-image`

### 接口信息

- **URL**: `POST /text-to-image`
- **认证**: ✅ 需要 access_token 和 apikey
- **返回**: 同步返回生成的图片URL

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `prompt` | string | 提示词，描述要生成的图片（最多 500 字） | ❌ 否 |

**注意**：
- 如果提供了 `prompt`，将使用你提供的提示词
- 如果没有提供 `prompt`，将使用功能配置项中的 `prompt_template`

### 请求示例

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

### 响应示例

#### 成功响应 (200)

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

#### 错误响应

```json
// 缺少必需参数
{
  "error": "缺少必需参数: item_id"
}

// 积分不足
{
  "error": "Insufficient credits. You need 10 credits but only have 5."
}

// 提示词过长
{
  "error": "prompt 长度超过限制（最多 500 字，当前 600 字）"
}
```

---

## 2️⃣ 图生图接口 `/image-to-image`

### 接口信息

- **URL**: `POST /image-to-image`
- **认证**: ✅ 需要 access_token 和 apikey
- **返回**: 同步返回生成的图片URL

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `image_url` | string 或 array | 输入图片 URL（单张为字符串，多张为数组） | ✅ 是 |
| `prompt` | string | 提示词，描述对图片的处理（最多 500 字） | ❌ 否 |

**注意**：
- `image_url` 可以是单张图片的URL字符串，也可以是多张图片的URL数组
- 如果提供了 `prompt`，将使用你提供的提示词
- 如果没有提供 `prompt`，将使用功能配置项中的 `prompt_template`

### 请求示例

#### 示例 1：单张图片

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-to-image',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'image-to-image-001',
      image_url: 'https://example.com/input.jpg',  // 单张图片（字符串）
      prompt: 'make it look like a painting'  // 可选
    })
  }
);

const result = await response.json();
console.log('生成的图片URL:', result.output_url);
```

#### 示例 2：多张图片

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-to-image',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'image-to-image-001',
      image_url: [  // 多张图片（数组）
        'https://example.com/image1.jpg',
        'https://example.com/image2.jpg'
      ],
      prompt: 'combine these images into one artistic composition'
    })
  }
);
```

### 响应示例

#### 成功响应 (200)

```json
{
  "success": true,
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "output_url": "https://lrenlgqppvqfbibxppbi.supabase.co/storage/v1/object/public/ai-generated/user123/image.jpg",
  "credits_used": 15,
  "credits_balance": 985,
  "model_used": "doubao-seedream-4-0-250828",
  "input_images_count": 1,
  "message": "图片生成成功"
}
```

---

## 3️⃣ 文生视频接口 `/text-to-video`

### 接口信息

- **URL**: `POST /text-to-video`
- **认证**: ✅ 需要 access_token 和 apikey
- **返回**: 异步返回任务ID（需要轮询获取结果）

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `prompt` | string | 提示词，描述要生成的视频（最多 500 字） | ❌ 否 |

**注意**：
- 视频生成是异步的，接口会立即返回 `task_id`
- 需要通过 `/get-task` 接口轮询获取最终结果
- 如果提供了 `prompt`，将使用你提供的提示词
- 如果没有提供 `prompt`，将使用功能配置项中的 `prompt_template`

### 请求示例

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

### 响应示例

#### 成功响应 (200)

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

### 获取视频生成结果

视频生成需要时间，需要通过 `/get-task` 接口轮询获取结果：

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
    return null;
  }
}

// 使用示例：每5秒轮询一次
const taskId = '550e8400-e29b-41d4-a716-446655440000';
const pollInterval = setInterval(async () => {
  const videoUrl = await getVideoResult(taskId);
  if (videoUrl) {
    clearInterval(pollInterval);
    console.log('视频生成完成:', videoUrl);
  }
}, 5000);  // 每5秒轮询一次
```

---

## 4️⃣ 图生视频接口 `/image-to-video`

### 接口信息

- **URL**: `POST /image-to-video`
- **认证**: ✅ 需要 access_token 和 apikey
- **返回**: 异步返回任务ID（需要轮询获取结果）

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `image_url` | string 或 array | 输入图片 URL（单张为字符串，多张为数组） | ✅ 是 |
| `prompt` | string | 提示词，描述对视频的处理（最多 500 字） | ❌ 否 |

**注意**：
- `image_url` 可以是单张图片的URL字符串，也可以是多张图片的URL数组
- 视频生成是异步的，接口会立即返回 `task_id`
- 需要通过 `/get-task` 接口轮询获取最终结果
- 如果提供了 `prompt`，将使用你提供的提示词
- 如果没有提供 `prompt`，将使用功能配置项中的 `prompt_template`

### 请求示例

#### 示例 1：单张图片生成视频

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-to-video',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'image-to-video-001',
      image_url: 'https://example.com/pet.jpg',  // 单张图片（字符串）
      prompt: 'make the pet dance happily'  // 可选
    })
  }
);

const result = await response.json();
console.log('任务ID:', result.task_id);
```

#### 示例 2：多张图片生成视频

```javascript
const response = await fetch(
  'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/image-to-video',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      item_id: 'image-to-video-001',
      image_url: [  // 多张图片（数组）
        'https://example.com/person.jpg',
        'https://example.com/scene.jpg'
      ],
      prompt: 'create a video where the person moves in the scene'
    })
  }
);
```

### 响应示例

#### 成功响应 (200)

```json
{
  "success": true,
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "credits_used": 50,
  "credits_balance": 950,
  "model_used": "doubao-seedream-4-0-250828",
  "input_images_count": 1,
  "message": "视频生成任务已提交，请通过 task_id 轮询获取结果"
}
```

### 获取视频生成结果

参考 [文生视频接口](#3️⃣-文生视频接口-text-to-video) 的轮询方法。

---

## 5️⃣ 视频换脸接口 `/video-face-swap`

### 接口信息

- **URL**: `POST /video-face-swap`
- **认证**: ✅ 需要 access_token 和 apikey
- **返回**: 异步返回任务ID（需要轮询获取结果）

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `item_id` | string | 功能配置项 ID（来自 `/get-feature-configs`） | ✅ 是 |
| `image_url` | string | 输入1张图片URL（必须是字符串，不能是数组） | ✅ 是 |

**注意**：
- `image_url` 必须是字符串，不能是数组（只能传入1张图片）
- 视频模板URL在功能配置项的 `face_swap_video_template` 字段中配置
- 视频生成是异步的，接口会立即返回 `task_id`
- 需要通过 `/get-task` 接口轮询获取最终结果

### 请求示例

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

### 响应示例

#### 成功响应 (200)

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

### 获取视频生成结果

参考 [文生视频接口](#3️⃣-文生视频接口-text-to-video) 的轮询方法。

---

## ⚠️ 错误处理

### 常见错误码

| HTTP 状态码 | 错误信息 | 说明 | 处理建议 |
|------------|---------|------|----------|
| 400 | `缺少必需参数: item_id` | 未提供必需的 `item_id` 参数 | 检查请求参数 |
| 400 | `缺少必需参数: image_url` | 图生图/图生视频/视频换脸接口缺少 `image_url` | 检查请求参数 |
| 400 | `prompt 长度超过限制（最多 500 字）` | 提示词超过500字限制 | 缩短提示词长度 |
| 400 | `Feature config item not found` | `item_id` 不存在 | 检查 `item_id` 是否正确 |
| 403 | `Insufficient credits` | 积分不足 | 提示用户充值或订阅 |
| 403 | `Your subscription has expired` | 订阅已过期 | 提示用户续费 |
| 500 | 服务器内部错误 | 服务端异常 | 稍后重试或联系技术支持 |

### 错误响应格式

```json
{
  "error": "错误信息描述"
}
```

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
  console.log('请求成功:', result);
} catch (error) {
  console.error('网络错误:', error);
}
```

---

## 💡 最佳实践

### 1. 获取功能配置列表

在 App 启动时，先调用 `/get-feature-configs` 获取所有可用功能：

```javascript
// App 启动时获取功能配置
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
  
  // 缓存功能配置
  const featureMap = {};
  for (const section of result.sections) {
    for (const item of section.items) {
      featureMap[item.id] = item;  // 使用 item.id 作为 key
    }
  }
  
  return featureMap;
}
```

### 2. 检查用户积分

在调用接口前，先检查用户积分是否足够：

```javascript
// 获取用户状态
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
  return {
    credits: result.credits_balance,
    hasSubscription: result.subscription_status === 'active'
  };
}

// 使用示例
const userStatus = await checkUserCredits();
const featureConfig = featureMap[itemId];

if (userStatus.credits < featureConfig.estimated_credits) {
  // 积分不足，提示用户
  showInsufficientCreditsDialog();
  return;
}
```

### 3. 上传图片

如果用户需要上传图片，先调用 `/upload-image` 接口：

```javascript
// 上传图片
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
        // 注意：不要设置 Content-Type，让浏览器自动设置（包含 boundary）
      },
      body: formData
    }
  );

  const result = await response.json();
  return result.url;  // 返回图片URL
}

// 使用示例
const imageFile = document.getElementById('fileInput').files[0];
const imageUrl = await uploadImage(imageFile);

// 然后使用 imageUrl 调用图生图或图生视频接口
```

### 4. 轮询视频结果

对于视频生成接口，建议使用指数退避策略进行轮询：

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
```

### 5. 错误重试

对于网络错误，建议实现重试机制：

```javascript
// 带重试的请求
async function fetchWithRetry(url, options, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const response = await fetch(url, options);
      if (response.ok) {
        return await response.json();
      }
      // 如果是4xx错误，不重试
      if (response.status >= 400 && response.status < 500) {
        return await response.json();
      }
      throw new Error(`HTTP ${response.status}`);
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      // 等待后重试
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
}
```

---

## 📊 接口对比表

| 特性 | 文生图 | 图生图 | 文生视频 | 图生视频 | 视频换脸 |
|------|--------|--------|----------|----------|----------|
| **必需参数** | `item_id` | `item_id`, `image_url` | `item_id` | `item_id`, `image_url` | `item_id`, `image_url` |
| **可选参数** | `prompt` | `prompt` | `prompt` | `prompt` | 无 |
| **返回类型** | 同步（图片URL） | 同步（图片URL） | 异步（任务ID） | 异步（任务ID） | 异步（任务ID） |
| **需要轮询** | ❌ 否 | ❌ 否 | ✅ 是 | ✅ 是 | ✅ 是 |
| **支持多图** | ❌ 否 | ✅ 是 | ❌ 否 | ✅ 是 | ❌ 否（仅1张） |

---

## 🔗 相关接口

- **获取功能配置**: `GET /get-feature-configs` - 获取所有可用功能和 `item_id`
- **查询任务状态**: `GET /get-task?task_id={task_id}` - 查询视频生成任务状态
- **用户状态查询**: `GET /user-status` - 查询用户积分和订阅状态
- **上传图片**: `POST /upload-image` - 上传用户图片获取URL
- **匿名登录**: `POST /anonymous-login` - 获取访问令牌

---

## 📞 技术支持

如有问题，请联系技术支持团队。

---

**文档版本**: v1.0  
**最后更新**: 2026-01-04
