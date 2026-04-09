## 获取AI功能分类列表

### 接口信息

- **URL**：`GET /get-sections-configs`
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
| version | string | 客户端版本号；若与 feature_config_apps.review_version 一致，仅返回 is_review_blacklisted=false 的分类 | ✅ | - |
| app_id | string | 应用标识（用于区分不同APP的配置） | ❌ | "default" |
| page_type | string | 页面类型（default=默认页面, ad=广告页面） | ❌ | "default" |
| menu | string | 菜单类型过滤（image=图片功能, video=视频功能，为空则返回全部） | ❌ | "" |

**请求示例**:
```bash
# 获取默认应用的默认页面配置（version 必传）
GET /get-sections-configs?version=1.0.0

# 获取默认应用的广告页面配置
GET /get-sections-configs?version=1.0.0&page_type=ad

# 获取特定应用的配置
GET /get-sections-configs?version=1.0.0&app_id=ios_v2

# 获取特定应用的广告页面配置
GET /get-sections-configs?version=1.0.0&app_id=ios_v2&page_type=ad

# 获取视频菜单的功能配置
GET /get-sections-configs?version=1.0.0&menu=video

# 组合条件查询（应用+页面类型+菜单）
GET /get-sections-configs?version=1.0.0&app_id=ios_v2&page_type=ad&menu=image

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
      "menu": "image|video",
      "sort_order": 1,
    }
  ]
}
```

### 字段说明

#### 分类（Section）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 分类唯一ID |
| type | string | 分类类型：`grid`（功能网格）、`section`（普通分类） |
| title | string\|null | 分类标题 |
| subtitle | string\|null | 分类副标题 |
| layout | string | 布局方式：`grid`（普通网格）、`horizontal_scroll`（横向滚动）、`mixed_grid`（混合网格） |
| menu | string | 菜单类型：`image`（图片功能菜单）、`video`（视频功能菜单） |
| sort_order | number | 排序权重（数字越小越靠前） |


### 响应示例

**示例 1：完整响应**

```json
{
  "sections": [
    {
      "id": 22,
      "type": "section",
      "title": "home",
      "subtitle": "",
      "layout": "grid",
      "menu": "image",
      "sort_order": 0
    },
    {
      "id": 40,
      "type": "section",
      "title": "ttt",
      "subtitle": "",
      "layout": "horizontal_scroll",
      "menu": "image",
      "sort_order": 0
    }
  ]
}
```

### 使用场景
调用此接口获取指定menu下的分类下的列表