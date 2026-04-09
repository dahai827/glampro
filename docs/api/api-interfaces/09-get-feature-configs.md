## 🎨 获取AI首页列表

### 接口信息

- **URL**：`GET /get-feature-configs`
- **认证**：❌ 公开接口（无需 Token，仅需 apikey）
- **Headers**:
  ```
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  Authorization: Bearer {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 | 默认值 |
|------|------|------|------|--------|
| app_id | string | 应用标识（用于区分不同APP的配置） | ✅| "default" |
| page_type | string | 页面类型（default=默认页面, ad=广告页面） | ✅ | "default" |
| menu | string | 菜单类型过滤：`image`=图片功能, `video`=视频功能, `ai_girlfriend`=AI女友, `grid`=**功能卡片**（返回一个 section，最多 5 个 item），为空则返回全部 | ❌ | "" |
| version | string | 版本号(例如: 1.5) | ✅ | "" |
| limit | number | 每页返回的分类数量（1-100） | ❌ | 3 |
| cursor | number | 游标，用于获取下一页（第一页无需提供，从上一页响应的 `next_cursor` 获取） | ❌ | null |

**请求示例**:
```bash
# 获取默认应用的默认页面配置（首页，不传page_type时默认为default）
GET /get-feature-configs

# 获取默认应用的广告页面配置
GET /get-feature-configs?page_type=ad&version=1.5

# 获取特定应用的配置
GET /get-feature-configs?app_id=ios_v2&version=1.5

# 获取特定应用的广告页面配置
GET /get-feature-configs?app_id=ios_v2&page_type=ad

# 获取图片菜单的功能配置（首页，每页3条）
GET /get-feature-configs?menu=image&limit=3

# 获取视频菜单的功能配置
GET /get-feature-configs?menu=video

# 获取功能卡片配置（首页入口：一个 section，最多 5 个 item）
GET /get-feature-configs?menu=grid

# 组合条件查询（应用+页面类型+菜单）
GET /get-feature-configs?app_id=ios_v2&page_type=ad&menu=image&limit=3

# 获取下一页（使用上一页返回的 next_cursor）
GET /get-feature-configs?app_id=ios_v2&page_type=ad&limit=3&cursor=section_id_2
```

### 响应结构

**响应 HTTP Status**: `200 OK`

**响应 Body**:
```json
{
  "sections": [
    {
      "id": 1,
      "type": "grid|section",
      "title": "分类标题",
      "subtitle": "分类副标题",
      "layout": "grid|horizontal_scroll|mixed_grid",
      "menu": "grid|image|video|ai_girlfriend",
      "sort_order": 1,
      "items": [
        {
          "id": "temp-aadnetzt6",
          "title": "功能标题",
          "subtitle": "功能副标题",
          "icon_url": "https://example.com/icon.png",
          "cover_image_url": "https://example.com/cover.jpg",
          "cover_video": "https://example.com/cover-video.mp4",
          "cover_video_thumbnail": "http://example.com/cover_video_thumbnail.jpg",
          "placeholder_gradient": [
            "#2E3A41",
            "#F48F21"
          ],
          "preview_style": "image_comparison",
          "is_ad": false,
          "ad_apk_url": "https://example.com/app.apk",
          "ad_ios_url": "https://apps.apple.com/app/id123456",
          "badge": "NEW|HOT|LABS|null",
          "card_type": "large|small|null",
          "text_mode": "text|image|null",
          "text_image_url": "https://example.com/text.png",
          "sort_order": 1,
          "requires_preview": true,
          "estimated_credits": 15,
          "scene": "FeatureGrid.agemorph",
          "template": "agemorph",
          "model_type": "image_to_image",
          "model_id": "doubao-seedream-4-0-250828",
          "prompt_template": "transform the person to look {age} years old",
          "enable_image_merge": false,
          "preview_config": {
            "before_image_url": "https://example.com/before.jpg",
            "after_image_url": "https://example.com/after.jpg",
            "title": "Age Morph Preview",
            "description": "Transform your age with AI magic"
          },
          "material_requirements": [
            {
              "id": "material_id",
              "type": "single_image|multiple_images|text|number|picker",
              "label": "Upload Photo",
              "description": "Select a photo",
              "required": true,
              "image_count": 2,
              "picker_options": [{"value": "option1", "label": "Option 1"}],
              "text_constraints": {
                "min_length": 1,
                "max_length": 100,
                "placeholder": "Enter text"
              },
              "number_constraints": {
                "min": 1,
                "max": 100,
                "step": 1,
                "unit": "岁"
              },
              "cover_required": true,
              "cover_images": ["https://example.com/cover1.jpg", "https://example.com/cover2.jpg"]
            }
          ]
        }
      ]
    }
  ],
  "pagination": {
    "limit": 3,
    "has_next": true,
    "next_cursor": 2
  },
  "version": "1.0.0"
}
```

### 字段说明

#### 分类（Section）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 分类ID |
| type | string | 分类类型：`grid`（**功能卡片**网格，通常配合 `menu=grid` 返回一个 section）、`section`（普通分类） |
| title | string\|null | 分类标题 |
| subtitle | string\|null | 分类副标题 |
| layout | string | 布局方式：`grid`（普通网格）、`horizontal_scroll`（横向滚动）、`mixed_grid`（混合网格） |
| menu | string | 菜单类型：`image`（图片功能菜单）、`video`（视频功能菜单）、`grid`（功能卡片）、`ai_girlfriend`（AI女友） |
| sort_order | number | 排序权重（数字越小越靠前） |
| items | array | 该分类下的功能项数组（当 `type=grid` 且 `menu=grid` 时，最多 5 个 item） |

#### 功能项（Item）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 功能唯一ID |
| title | string | 功能标题 |
| subtitle | string\|null | 功能副标题 |
| model_type | string\|null | 模型类型(image_to_image: 图生图) |
| model_id | string\|null | 模型ID |
| icon_url | string\|null | 功能图标URL |
| cover_image_url | string\|null | 功能封面图URL(注意如果cover_image_url返回空字符串则使用cover_video_thumbnail字段) |
| cover_video | string\|null | **功能项封面视频URL（新增）** |
| cover_video_thumbnail | string\|null | **封面视频缩略图URL（新增）** |
| placeholder_gradient | array | 封面背景的双色渐变(例如：["#2E3A41","#F48F21"]) | 
| preview_style | string\|null | **预览样式（新增）：`image_comparison`（效果图对比）或 `video_effect`（视频效果）** |
| is_ad | boolean | **是否广告（新增）：`true`（是广告）、`false`（不是广告），默认为 `false`** |
| ad_apk_url | string\|null | **广告APK下载地址（新增）：当 `is_ad=true` 时使用，用于Android平台** |
| ad_ios_url | string\|null | **广告iOS下载地址（新增）：当 `is_ad=true` 时使用，用于iOS平台** |
| badge | string\|null | 徽章：`NEW`（新功能）、`HOT`（热门）、`LABS`（实验室）或 null |
| card_type | string\|null | 卡片类型：`large`（大卡）、`small`（小卡）或 null |
| text_mode | string\|null | 文字显示模式：`text`（文字）、`image`（艺术字）或 null |
| text_image_url | string\|null | 艺术字图片URL（仅当 text_mode="image" 时有效） |
| sort_order | number | 排序权重（数字越小越靠前） |
| requires_preview | boolean | 是否需要预览（左右滑动对比效果） |
| estimated_credits | number | 预估积分消耗 |
| scene | string | 场景分类字符串 |
| template | string | 模板标识字符串 |
| prompt_template | string | 提示词模板（可包含占位符如 {age}） |
| enable_image_merge | boolean | **是否支持图片合成到视频（新增）：`true`（支持）、`false`（不支持），默认为 `false`。当为 `true` 时，表示该功能支持将两张图片合成一张，然后生成视频** |
| preview_config | object\|undefined | 预览配置（仅当 requires_preview=true 时返回） |
| material_requirements | array | 物料需求数组；**二级页**需按此配置展示对应 UI 素材（输入框、上传区、选择器等）供用户操作 |

#### 预览配置（Preview Config）

| 字段 | 类型 | 说明 |
|------|------|------|
| before_image_url | string | 原始图片URL |
| after_image_url | string | 处理后图片URL |
| title | string | 预览标题 |
| description | string\|null | 预览描述文案 |

#### 物料需求（Material Requirement）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 物料ID |
| type | string | 物料类型：`single_image`、`multiple_images`、`text`、`number`、`picker` |
| label | string | 显示标签 |
| description | string\|null | 描述说明 |
| required | boolean | 是否必需 |
| image_count | number\|null | 图片数量（仅当 type="multiple_images" 时有效） |
| picker_options | array\|null | 选择器选项（仅当 type="picker" 时有效） |
| text_constraints | object\|null | 文本约束（仅当 type="text" 时有效） |
| number_constraints | object\|null | 数字约束（仅当 type="number" 时有效） |
| cover_required | boolean\|null | **是否需要展示在封面（新增）：`true`（需要）、`false`（不需要），仅当 type="single_image" 或 "multiple_images" 时有效** |
| cover_images | array\|null | **封面展示图片数组（新增）：图片URL数组，格式如 `["http://xx.jpg","http://aa.jpg"]`，仅当 `cover_required=true` 时返回** |

#### 广告相关字段说明

当功能项的 `is_ad` 字段为 `true` 时，表示这是一个广告项目。广告项目具有以下特点：

- **显示内容简化**：广告项目只显示项目名称、启用状态、封面图、封面视频等核心信息
- **下载地址**：
  - `ad_apk_url`：Android 平台的 APK 下载地址（可选）
  - `ad_ios_url`：iOS 平台的 App Store 下载地址（可选）
  - ⚠️ **注意**：`ad_apk_url` 和 `ad_ios_url` 不能同时为空，至少需要填写一个

**使用场景**：
- 在 App 中展示推广的其他应用或功能
- 根据用户平台（Android/iOS）显示对应的下载链接
- 点击广告项目时，跳转到对应的下载地址

**示例代码**：
```javascript
// 检查是否为广告项目
if (item.is_ad) {
  // 根据平台显示对应的下载地址
  const downloadUrl = Platform.OS === 'ios' 
    ? item.ad_ios_url 
    : item.ad_apk_url;
  
  if (downloadUrl) {
    // 打开下载链接
    Linking.openURL(downloadUrl);
  }
}
```

#### 封面展示相关字段说明

当物料类型为 `single_image` 或 `multiple_images` 时，可能包含封面展示配置：

- **`cover_required`**：是否需要在封面展示该物料图片
  - `true`：需要展示，此时会包含 `cover_images` 字段
  - `false` 或不存在：不需要展示封面
  
- **`cover_images`**：封面展示图片URL数组
  - 仅当 `cover_required=true` 时返回
  - 格式：`["http://example.com/cover1.jpg", "http://example.com/cover2.jpg"]`
  - 数组长度与物料类型相关：
    - `single_image`：通常 1 张图片
    - `multiple_images`：与 `image_count` 一致

**使用场景**：
- App 首页或功能列表中展示物料的封面示例图
- 帮助用户理解该功能需要什么样的输入图片
- 提升用户体验，降低使用门槛

**示例代码**：
```javascript
// 渲染物料需求时检查是否需要显示封面
materials.forEach(material => {
  if (material.cover_required && material.cover_images?.length > 0) {
    // 显示封面图片预览
    console.log(`物料 ${material.label} 的封面图片：`);
    material.cover_images.forEach((imageUrl, index) => {
      console.log(`  封面 ${index + 1}: ${imageUrl}`);
      // 在 UI 中展示封面图片
      renderCoverImage(imageUrl);
    });
  }
  
  // 正常渲染物料输入控件
  renderMaterialInput(material);
});
```

#### 功能卡片（grid）使用规范

当 `menu=grid` 时，接口用于获取**功能卡片**配置：返回**一个** section，该 section 内包含多个 item，**最多 5 个**。用于首页横向一排的功能入口（如：文生图、图生图、换装等）。

**首页功能卡片展示：**

| 展示项 | 数据来源 | 说明 |
|--------|----------|------|
| 卡片图标 | `item.icon_url` | 每个功能卡片的图标 URL |
| 卡片标题 | `item.title` | 每个功能卡片的标题文案 |

**二级页（点击卡片进入后的创作页）展示：**

- 根据当前 item 的 `material_requirements` 字段配置，动态渲染对应的 UI 素材，供用户输入或选择：
  - `single_image`：单图上传（相册/拍照）
  - `multiple_images`：多图上传（数量见 `image_count`）
  - `text`：文本输入（占位、长度等见 `text_constraints`）
  - `number`：数字输入（范围、步长、单位等见 `number_constraints`）
  - `picker`：选择器（选项见 `picker_options`）
- 每个物料的 `label`、`description`、`required` 用于表单项的标签、说明和必填校验。
- 若物料包含 `cover_required: true` 与 `cover_images`，可在二级页或封面区展示示例图，帮助用户理解需要上传的内容。

**请求示例：**
```bash
GET /get-feature-configs?menu=grid&app_id=default
```

**响应特点：** `sections` 数组仅含 1 个 section，其 `items` 长度 1～5。

#### 分页信息（Pagination）

| 字段 | 类型 | 说明 |
|------|------|------|
| limit | number | 本页返回的分类数量 |
| has_next | boolean | 是否还有下一页 |
| next_cursor | int\|null | 下一页的游标（用于请求下一页）。当 `has_next=false` 时，此字段为 null |

### 响应示例

**示例 1：完整响应**

```json
{
  "sections": [
    {
      "id": 1,
      "type": "grid",
      "title": null,
      "subtitle": null,
      "layout": "grid",
      "items": [
        {
          "id": "agemorph",
          "title": "Age Morph",
          "subtitle": null,
          "icon_url": "https://example.com/icons/agemorph.png",
          "cover_image_url": null,
          "cover_video": null,
          "cover_video_thumbnail":"http://cover_video_thumbnail.jpg",
          "preview_style": null,
          "badge": "NEW",
          "card_type": null,
          "text_mode": null,
          "text_image_url": null,
          "sort_order": 1,
          "requires_preview": true,
          "estimated_credits": 15,
          "scene": "FeatureGrid.agemorph",
          "template": "agemorph",
          "prompt_template": "transform the person to look {age} years old",
          "enable_image_merge": false,
          "preview_config": {
            "before_image_url": "https://example.com/previews/before.jpg",
            "after_image_url": "https://example.com/previews/after.jpg",
            "title": "Age Morph Preview",
            "description": "Transform your age with AI magic"
          },
          "material_requirements": [
            {
              "id": "image",
              "type": "single_image",
              "label": "Upload Photo",
              "description": "Select a photo of a person",
              "required": true
            },
            {
              "id": "age",
              "type": "number",
              "label": "Target Age",
              "description": "Select the target age",
              "required": true,
              "number_constraints": {
                "min": 1,
                "max": 100,
                "step": 1,
                "unit": "岁"
              }
            },
            {
              "id": "pet_image",
              "type": "single_image",
              "label": "Upload Pet Photo",
              "description": "Select a photo of your pet",
              "required": true,
              "cover_required": true,
              "cover_images": ["https://example.com/pet-cover1.jpg", "https://example.com/pet-cover2.jpg"]
            }
          ]
        }
      ]
    },
    {
      "id": 2,
      "type": "section",
      "title": "Holiday Season",
      "subtitle": "AI FILTER",
      "layout": "mixed_grid",
      "items": [
        {
          "id": "christmas-special",
          "title": "Christmas",
          "subtitle": null,
          "icon_url": null,
          "cover_image_url": "https://example.com/covers/christmas.jpg",
          "cover_video": "https://example.com/videos/christmas-demo.mp4",
          "preview_style": "video_effect",
          "badge": null,
          "card_type": "large",
          "text_mode": "image",
          "text_image_url": "https://example.com/text/christmas.png",
          "sort_order": 1,
          "requires_preview": false,
          "estimated_credits": 15,
          "scene": "Holiday.christmas-special",
          "template": "christmas-special",
          "prompt_template": "add christmas decorations and festive atmosphere",
          "enable_image_merge": false,
          "material_requirements": [
            {
              "id": "image",
              "type": "single_image",
              "label": "Upload Photo",
              "required": true
            }
          ]
        }
      ]
    }
  ],
  "version": "1.0.0"
}
```

### 使用场景

1. **App 启动时**：调用此接口获取首页功能配置（使用默认的 limit=3），用于构建功能菜单和分类展示
2. **功能卡片（首页入口）**：传 `menu=grid` 获取一个 section（最多 5 个 item），用 `item.icon_url`、`item.title` 渲染功能卡片；点击卡片进入二级页后，按 `item.material_requirements` 展示输入/上传等 UI 素材（详见上文「功能卡片（grid）使用规范」）
3. **功能分类展示**：根据 `layout` 字段选择不同的 UI 布局（网格、滚动、混合）
4. **功能详情页**：使用 `id`、`preview_config` 和 `material_requirements` 构建功能详情和输入表单
5. **多应用支持**：通过 `app_id` 参数获取不同应用的配置
6. **下拉刷新加载更多**：当用户滑动到底部时，使用上一页返回的 `next_cursor` 请求下一页分类数据

### 分页加载流程

**首页加载：**
```
1. 调用 GET /get-feature-configs?app_id=default&limit=3
2. 获取首3个分类及其下的功能项
3. 记录响应中的 pagination.next_cursor
```

**加载更多：**
```
1. 用户滑动到页面底部
2. 调用 GET /get-feature-configs?app_id=default&limit=3&cursor={next_cursor}
3. 获取下一批分类，更新 UI
4. 更新 next_cursor 用于下一次加载
```

**分页终止：**
```
当 pagination.has_next = false 时，表示已加载所有分类
```

### 客户端集成建议

```javascript
// 获取功能配置（支持分页）
async function getFeatureConfigs(appId = 'default', limit = 3, cursor = null) {
  let url = `https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-feature-configs?app_id=${appId}&limit=${limit}`;
  if (cursor) {
    url += `&cursor=${cursor}`;
  }

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    }
  });

  if (!response.ok) {
    throw new Error(`API Error: ${response.status}`);
  }

  return await response.json();
}

// 使用示例：初始化加载
let allSections = [];
let nextCursor = null;

async function loadInitialConfigs() {
  const data = await getFeatureConfigs('default', 3);
  allSections = data.sections;
  nextCursor = data.pagination.next_cursor;

  // 渲染分类到 UI
  renderSections(data.sections);
}

// 加载更多（滚动到底部时调用）
async function loadMoreConfigs() {
  if (!nextCursor) {
    console.log('已加载所有分类');
    return;
  }

  const data = await getFeatureConfigs('default', 3, nextCursor);
  allSections = [...allSections, ...data.sections];
  nextCursor = data.pagination.next_cursor;

  // 追加渲染到 UI
  appendSections(data.sections);
}

// 渲染分类
function renderSections(sections) {
  sections.forEach(section => {
    console.log(`分类: ${section.id}, 功能项数: ${section.items.length}`);
    section.items.forEach(item => {
      console.log(`  - ${item.title} (${item.id})`);
    });
  });
}

function appendSections(sections) {
  // 追加分类到现有列表
  renderSections(sections);
}

// 使用示例
await loadInitialConfigs();
// ... 用户滚动到底部时
await loadMoreConfigs();
```
-----------------------------