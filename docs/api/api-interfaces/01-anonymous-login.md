## 1️⃣ 匿名登录

### 接口信息

- **URL**：`POST /anonymous-login`
- **认证**：✅ 需要 apikey 和 Authorization（使用ANON_KEY）
- **Headers**:
  ```
  Content-Type: application/json
  Authorization: Bearer {SUPABASE_ANON_KEY}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| user_id | string | 用户ID（可选） | ❌ |
| app_id | string | 应用标识（可选，用于区分不同APP） | ❌ |
| idfa | string | iOS 广告标识符（IDFA，可选） | ❌ |
| idfv | string | iOS 供应商标识符（IDFV，可选） | ❌ |
| adid | string | Android 广告ID（ADID，可选） | ❌ |
| gps_adid | string | Google Play Services 广告ID（可选） | ❌ |
| **country** | **string** | **⚠️ 新增：ISO 3166-1 alpha-2 国家代码（可选）** | **❌** |
| **channel** | **string** | **⚠️ 新增：用户来源渠道（可选）** | **❌** |
| **platform** | **string** | **⚠️ 新增：设备平台（可选）** | **❌** |

**请求 Body（可选）**:
```json
{
  "user_id": "uuid",           // 可选，如果提供且用户存在，则刷新 session
  "app_id": "ios_v2",          // 可选，应用标识（默认为 "default"）
  "idfa": "00000000-0000-0000-0000-000000000000",     // 可选，iOS 广告标识符
  "idfv": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",     // 可选，iOS 供应商标识符
  "adid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",     // 可选，Android 广告ID
  "gps_adid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", // 可选，Google Play Services 广告ID

  // ⚠️ 新增：BI 维度字段（所有参数均为可选）
  "country": "CN",             // 可选，ISO 3166-1 alpha-2 国家代码（如 "CN", "US", "JP"）
  "channel": "organic",        // 可选，用户来源渠道（如 "organic", "paid_ads", "referral", "social"）
  "platform": "ios"            // 可选，设备平台（如 "ios", "android", "web", "macos"）
}
```

**app_id 说明**:
- ✅ 可选参数，不传则默认为 `"default"`（现有APP自动使用此值）
- ✅ 新APP建议传入自定义的 `app_id`（如 `"ios_v2"`, `"android_v1"` 等）
- ✅ `app_id` 会保存到用户元数据中，用于标识用户所属的应用
- ✅ 不同 `app_id` 的用户数据相互独立

**设备标识符说明**（所有参数均为可选）:

**iOS 平台**:
- `idfa`（Identifier for Advertisers）：iOS 广告标识符
  - 用于广告跟踪和归因
  - iOS 14.5+ 需要用户授权（ATTrackingManager）
  - 如果用户拒绝授权，可能为全0值：`00000000-0000-0000-0000-000000000000`
- `idfv`（Identifier for Vendor）：iOS 供应商标识符
  - 同一开发者的应用共享相同的 IDFV
  - 不需要用户授权
  - 用户卸载后重装会保持不变（除非卸载了该开发者的所有应用）

**Android 平台**:
- `adid`（Advertising ID）：Android 广告ID
  - Google Play Services 提供的广告标识符
  - 用户可以在设置中重置或选择限制广告跟踪
- `gps_adid`（Google Play Services ADID）：Google Play Services 广告ID
  - 与 `adid` 类似，通过 Google Play Services 获取
  - 用于广告归因和用户分析

**使用原则**:
- ✅ 所有设备标识符都是**可选参数**
- ✅ 获取到哪个就传哪个，没获取到可以不传
- ✅ 建议尽可能传递设备标识符，有助于：
  - 广告归因分析
  - 用户行为分析
  - 防止滥用和欺诈检测
  - 设备唯一性识别
- ⚠️ 需遵守相关隐私政策和用户授权要求

**BI 维度字段说明**（⚠️ Phase 4 新增，所有参数均为可选）:

**国家代码 (country)**:
- `country`（ISO 3166-1 alpha-2 标准）：用户所在国家/地区代码
  - 格式：2 位大写字母的国家代码（如 "CN", "US", "JP", "GB" 等）
  - 推荐来源：
    - 从用户 IP 地址推断（地理位置 API）
    - 从用户设置或语言环境推断
    - 从 App 运行时的设备位置获取（如果有权限）
  - 用途：
    - 用户地域分布分析
    - 按国家/地区的转化漏斗分析
    - 地区合规性管理
  - 示例：`"country": "CN"` 或 `"country": "US"`

**用户来源渠道 (channel)**:
- `channel`：用户从哪个渠道获取 App 的标识符
  - 常见值：
    - `"organic"` - 自然流量（应用商店搜索、口碑）
    - `"paid_ads"` - 付费广告（Google Ads、Facebook 等）
    - `"referral"` - 推荐链接/分享
    - `"social"` - 社交媒体
    - `"direct"` - 直接访问
    - `"campaign"` - 活动推广
    - 其他自定义值
  - 用途：
    - App 推广渠道效果分析
    - 用户获取成本（CAC）计算
    - 不同渠道的用户质量评估
    - 营销决策优化
  - 示例：`"channel": "organic"` 或 `"channel": "paid_ads"`

**设备平台 (platform)**:
- `platform`：用户使用的设备平台
  - 常见值：
    - `"ios"` - iOS/iPhone
    - `"android"` - Android 设备
    - `"web"` - Web 浏览器
    - `"macos"` - macOS
    - `"windows"` - Windows
    - 其他自定义值
  - 用途：
    - 平台分布分析
    - 按平台的功能使用分析
    - 平台特定问题诊断
    - 平台优化优先级决策
  - 示例：`"platform": "ios"` 或 `"platform": "android"`

**使用建议**:
- ✅ 所有 BI 维度字段都是**可选参数**
- ✅ 如果能获取到这些信息，强烈建议在匿名登录时传入
- ✅ 这些字段会被后续的任务创建函数自动使用，用于 BI 数据分析
- ✅ 不提供这些字段不影响用户登录，只是会缺少相应的数据维度
- ⚠️ 注意：
  - country 代码必须符合 ISO 3166-1 alpha-2 标准
  - 所有字段值长度建议 <= 50 个字符
  - 尽量使用英文小写或按约定的标准格式


### 响应

**场景 1：首次登录或创建新用户**
| 字段 | 类型 | 说明 |
|------|------|------|
| user.id | string | 用户唯一ID |
| user.is_anonymous | boolean | 是否为匿名用户 |
| user.app_id | string | **应用标识**（新增，如 "default", "ios_v2" 等） |
| session.access_token | string | **访问令牌（重要）** |
| session.refresh_token | string | **刷新令牌（重要，必须保存）** |
| message | string | 提示信息 |

**场景 2：提供 user_id 且用户已存在**
| 字段 | 类型 | 说明 |
|------|------|------|
| user.id | string | 用户唯一ID |
| user.is_anonymous | boolean | 是否为匿名用户 |
| user.app_id | string | **应用标识**（新增，如 "default", "ios_v2" 等） |
| session | null | **为 null，需要使用 refresh_token 刷新** |
| message | string | 提示信息 |
| requires_refresh_token | boolean | **是否需要使用 refresh_token 刷新 session**（仅当提供 user_id 且用户已存在时为 true） |

**响应示例（场景 1）**:
```json
{
  "user": {
    "id": "uuid",
    "is_anonymous": true,
    "app_id": "default"  // 应用标识，未传 app_id 时为 "default"，传入时返回传入的值
  },
  "session": {
    "access_token": "eyJhbGci...",
    "refresh_token": "..."
  },
  "message": "匿名登录成功"
}
```

**响应示例（场景 2）**:
```json
{
  "user": {
    "id": "uuid",
    "is_anonymous": true,
    "app_id": "default"  // 应用标识
  },
  "session": null,
  "message": "用户已存在。Supabase 不支持直接为匿名用户创建新 session，请使用之前保存的 refresh_token 刷新 session。如果没有 refresh_token，可以重新调用接口（不提供 user_id）以创建新用户，但会丢失原用户的数据。",
  "requires_refresh_token": true
}
```

**响应示例（新APP传入 app_id）**:
```json
{
  "user": {
    "id": "uuid",
    "is_anonymous": true,
    "app_id": "ios_v2"  // 返回传入的 app_id
  },
  "session": {
    "access_token": "eyJhbGci...",
    "refresh_token": "..."
  },
  "message": "匿名登录成功"
}
```

### 使用场景

- **首次启动（现有APP）**: 不带 `user_id` 和 `app_id` 调用，创建新用户，`app_id` 自动为 `"default"`
- **首次启动（新APP）**: 不带 `user_id` 但带 `app_id` 调用（如 `{"app_id": "ios_v2"}`），创建新用户并保存 `app_id`
- **提供 user_id 且用户已存在**: 返回 `requires_refresh_token: true` 和 `session: null`，需要使用 `refresh_token` 刷新 session
- **Token 过期**: **优先使用 `refresh_token` 刷新 session**（推荐方式），而不是调用 `/anonymous-login` 并提供 `user_id`

**app_id 使用建议**:
- ✅ **现有APP**: 无需传入 `app_id`，系统自动使用 `"default"`，完全兼容
- ✅ **新APP**: 在首次登录时传入固定的 `app_id`（如 `"ios_v2"`），后续不需要再传
- ✅ **保存 app_id**: 可以将响应中的 `user.app_id` 保存到本地，用于识别用户所属应用

**BI 维度字段使用建议**（⚠️ Phase 4 新增）:
- ✅ **强烈推荐**：在首次启动时传入 `country`、`channel`、`platform` 参数
- ✅ **country 来源**：
  - 推荐从用户 IP 推断（通过地理位置 API 或 GeoIP 库）
  - 或根据用户设备语言/区域设置推断
  - 或通过定位权限获取用户设备位置
- ✅ **channel 来源**：
  - 根据 App 的下载/安装来源跟踪（App Store 搜索、广告链接等）
  - 通过深链接（Deep Link）的查询参数传递
  - 通过 UTM 参数或自定义分析标签标识
- ✅ **platform 来源**：
  - 直接从设备平台标识（如 UIDevice.current.systemName for iOS）
  - 或根据运行时环境检测（如 Web 浏览器识别）
- ⚠️ **不影响登录**：如果无法获取这些信息，可以不传，不会影响用户登录和使用
- ⚠️ **可在登录后更新**：可以在用户登录后的任何时机，通过再次调用 anonymous-login（提供 user_id）来更新这些信息

### 重要提示

⚠️ **保存 access_token 和 refresh_token**：后续所有接口都需要 access_token，refresh_token 用于刷新 session  
⚠️ **Token 有效期**：access_token 有效期 1 小时，过期后优先使用 refresh_token 刷新  
⚠️ **requires_refresh_token**：当返回此字段为 true 时，表示用户已存在但无法直接创建新 session，必须使用 `refresh_token` 刷新

---