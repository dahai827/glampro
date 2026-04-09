## 2️⃣1️⃣ 归因绑定（Click ID 方式）

### 接口信息

- **URL**：`POST /attribution-bind`
- **认证**：✅ 需要 JWT token（从 Authorization header 获取）
- **Headers**:
  ```
  Content-Type: application/json
  Authorization: Bearer {JWT_TOKEN}
  ```

### 接口描述

App 用户登录后调用此接口，将广告点击信息绑定到用户账号。该接口通过 `click_id` 方式直接绑定广告点击信息，无需先调用 `/attribution-click` 接口。

**绑定流程**：
- App 直接从 URL 参数中获取 `click_id`（如 `fbclid`、`gclid`）
- 传入 `click_id`、`landing_url` 和 `app_id`
- 系统自动判断广告来源（Meta 或 Google Ads）

**重要说明**：
- ⚠️ **user_id 自动获取**：`user_id` 从 JWT token 中自动获取，**不需要在请求体中传递**
- ⚠️ **必需参数**：传 `click_id` 时必须同时传 `landing_url` 和 `app_id`
- ⚠️ **设备指纹**：可选传 `fingerprint_v1` / `fingerprint_sig_v1`，会写入归因记录用于 IP+时间窗口+指纹联合匹配；详见 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md)

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `click_id` | string | 广告点击 ID（如 `fbclid`、`gclid`） | ✅ |
| `landing_url` | string | H5 页面的完整 URL（包含查询参数），必须包含 `fbclid` 或 `gclid` | ✅ |
| `app_id` | string | 应用 ID，可选，默认为 `default` | ❌ |
| `fingerprint_v1` | object | 设备指纹 v1（固定 9 字段），可选 | ❌ |
| `fingerprint_sig_v1` | string | 指纹签名 `SHA256(stable_json(fingerprint_v1))`，与 `fingerprint_v1` 配套 | ❌ |

**请求 Body 示例**:
```json
{
  "click_id": "EAABkZB1234567890xxxxxxxx",
  "landing_url": "https://h5.example.com/landing?fbclid=EAABkZB1234567890xxxxxxxx",
  "app_id": "default"
}
```

**请求 Body 示例（含设备指纹）**:
```json
{
  "click_id": "EAABkZB1234567890xxxxxxxx",
  "landing_url": "https://h5.example.com/landing?fbclid=EAABkZB1234567890xxxxxxxx",
  "app_id": "default",
  "fingerprint_v1": {
    "device_type": "phone",
    "os_family": "ios",
    "os_major": "18",
    "language": "en-us",
    "screen_bucket": "390x840",
    "pixel_ratio_bucket": "3x",
    "color_depth": 24,
    "max_touch_points": 5,
    "device_model_bucket": "iphone_pro_max"
  },
  "fingerprint_sig_v1": "a1b2c3d4e5f6..."
}
```

**参数说明**：

**click_id**：
- 广告点击 ID，来自 URL 参数
  - Meta 广告：`fbclid` 参数值
  - Google Ads：`gclid` 参数值
- 示例：`"EAABkZB1234567890xxxxxxxx"` 或 `"CjwKCAiAi--kBhBQEiwAyLbyjxxx"`

**landing_url（必需）**：
- H5 页面的完整 URL，必须包含查询参数
- 必须包含以下参数之一：
  - `fbclid`：表示来自 Meta 广告
  - `gclid`：表示来自 Google Ads
- 系统会自动从 URL 中识别广告来源类型
- 示例：`"https://h5.example.com/landing?fbclid=EAABkZB1234567890xxxxxxxx"`

**app_id**：
- 应用标识，用于区分不同应用
- 可选，不传则默认为 `"default"`
- 可选值：`"default"`、`"velour"` 等

**fingerprint_v1**（可选）：
- 设备指纹对象，仅含规范 9 字段；会写入归因记录用于 IP+时间窗口+指纹联合匹配
- 详见 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md)

**fingerprint_sig_v1**（可选）：
- 指纹签名：`SHA256(stable_json(fingerprint_v1))`，与 `fingerprint_v1` 配套传递

### 请求示例

**cURL 示例**:
```bash
curl -X POST https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/attribution-bind \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -d '{
    "click_id": "EAABkZB1234567890xxxxxxxx",
    "landing_url": "https://h5.example.com/landing?fbclid=EAABkZB1234567890xxxxxxxx",
    "app_id": "default"
  }'
```

**TypeScript/JavaScript 示例**:
```typescript
import { supabase } from './supabaseClient';

async function bindAttributionWithClickId(clickId: string, landingUrl: string) {
  // 1. 获取当前用户的 JWT token
  const { data: { session }, error: sessionError } = await supabase.auth.getSession();

  if (sessionError || !session) {
    console.error('Failed to get session');
    return;
  }

  // 2. 调用绑定接口（注意：不需要传 user_id，从 token 中自动获取）
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/attribution-bind',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`
      },
      body: JSON.stringify({
        click_id: clickId,
        landing_url: landingUrl,
        app_id: 'default'
      })
    }
  );

  const result = await response.json();

  if (result.success) {
    console.log('Attribution bound successfully', result.data);
  } else {
    console.error('Failed to bind attribution:', result.error);
  }
}

// 使用示例：从 URL 参数中获取 click_id
const urlParams = new URLSearchParams(window.location.search);
const fbclid = urlParams.get('fbclid');
const gclid = urlParams.get('gclid');

if (fbclid || gclid) {
  const clickId = fbclid || gclid;
  const landingUrl = window.location.href;
  bindAttributionWithClickId(clickId!, landingUrl);
}
```

**Swift 示例（iOS）**:
```swift
import Supabase

class AttributionManager {
    let supabaseClient = SupabaseClient(
        supabaseURL: URL(string: "https://lrenlgqppvqfbibxppbi.supabase.co")!,
        supabaseKey: "YOUR_ANON_KEY"
    )

    func bindAttributionWithClickId(clickId: String, landingUrl: String, appId: String = "default") async throws {
        // 1. 获取当前用户的 session
        guard let session = try? await supabaseClient.auth.session else {
            throw NSError(domain: "AttributionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }

        // 2. 调用绑定接口
        let url = URL(string: "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/attribution-bind")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "click_id": clickId,
            "landing_url": landingUrl,
            "app_id": appId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AttributionManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Request failed"])
        }

        let result = try JSONDecoder().decode(AttributionBindResponse.self, from: data)
        if result.success {
            print("Attribution bound successfully: \(result.data)")
        } else {
            throw NSError(domain: "AttributionManager", code: -3, userInfo: [NSLocalizedDescriptionKey: result.error ?? "Unknown error"])
        }
    }
}

struct AttributionBindResponse: Codable {
    let success: Bool
    let data: AttributionBindData?
    let error: String?
}

struct AttributionBindData: Codable {
    let message: String
    let click_type: String
    let landing_url_domain: String
}
```

### 响应

**成功响应 (200 OK)**:
```json
{
  "success": true,
  "data": {
    "message": "Attribution binding successful",
    "click_type": "meta",
    "landing_url_domain": "https://web3.fuliapp.site/"
  }
}
```

**响应字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `success` | boolean | 请求是否成功 |
| `data.message` | string | 成功信息 |
| `data.click_type` | string | 广告点击类型：`"meta"`（Meta 广告）或 `"google_ads"`（Google Ads） |
| `data.landing_url_domain` | string | 广告点击来源网页的域名（不含路径） |

### 错误响应

**401 Unauthorized - 缺少或无效的 Authorization header**:
```json
{
  "success": false,
  "error": "Missing or invalid Authorization header"
}
```

**401 Unauthorized - 无效或过期的 JWT token**:
```json
{
  "success": false,
  "error": "Invalid or expired token"
}
```

**400 Bad Request - 缺少必需参数**:
```json
{
  "success": false,
  "error": "Missing required parameter: install_token or click_id must be provided"
}
```

**400 Bad Request - click_id 方式缺少参数**:
```json
{
  "success": false,
  "error": "Missing required parameters: landing_url and app_id are required when click_id is provided"
}
```

**400 Bad Request - landing_url 无效**:
```json
{
  "success": false,
  "error": "Invalid landing_url: must contain fbclid (for meta) or gclid (for google_ads) parameter"
}
```

**500 Internal Server Error - 查询归因记录失败**:
```json
{
  "success": false,
  "error": "Failed to query attribution record"
}
```

**500 Internal Server Error - 更新归因记录失败**:
```json
{
  "success": false,
  "error": "Failed to update attribution record"
}
```

**500 Internal Server Error - 创建归因记录失败**:
```json
{
  "success": false,
  "error": "Failed to create attribution record"
}
```

**500 Internal Server Error - 处理失败**:
```json
{
  "success": false,
  "error": "Failed to process attribution binding"
}
```

### 使用场景

#### App 内直接绑定（使用 click_id）

**适用场景**：
- App 通过深链接（Deep Link）打开，URL 中包含 `fbclid` 或 `gclid`
- App 内 WebView 加载 H5 页面，需要绑定广告点击
- App 从其他渠道获取到广告点击信息，需要直接绑定

**完整流程**：
```
1. App 通过深链接打开（URL 携带 fbclid/gclid）
   ↓
2. App 解析 URL 参数，获取 click_id 和 landing_url
   ↓
3. 用户登录（获取 JWT token）
   ↓
4. App 调用 /attribution-bind（传 click_id + landing_url + app_id）
   ↓
5. 系统自动判断广告来源（从 landing_url 识别 fbclid/gclid）
   ↓
6. 绑定成功
```

**代码示例**：
```swift
// iOS 示例：处理深链接
func handleDeepLink(url: URL) async {
    // 1. 解析 URL 参数
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems else {
        return
    }

    // 2. 查找 fbclid 或 gclid
    let fbclid = queryItems.first(where: { $0.name == "fbclid" })?.value
    let gclid = queryItems.first(where: { $0.name == "gclid" })?.value

    guard let clickId = fbclid ?? gclid else {
        print("No click ID found in URL")
        return
    }

    // 3. 确保用户已登录
    guard let session = try? await supabaseClient.auth.session else {
        print("User not logged in")
        return
    }

    // 4. 调用绑定接口
    do {
        try await bindAttributionWithClickId(
            clickId: clickId,
            landingUrl: url.absoluteString,
            appId: "default"
        )
        print("Attribution bound successfully")
    } catch {
        print("Failed to bind attribution: \(error)")
    }
}
```

**JavaScript/TypeScript 示例（WebView 场景）**:
```typescript
// 在 App 的 WebView 中调用
function bindAttributionFromWebView() {
  // 1. 从当前页面 URL 获取 click_id
  const urlParams = new URLSearchParams(window.location.search);
  const fbclid = urlParams.get('fbclid');
  const gclid = urlParams.get('gclid');

  if (!fbclid && !gclid) {
    console.log('No click ID found in URL');
    return;
  }

  const clickId = fbclid || gclid;
  const landingUrl = window.location.href;

  // 2. 通过 App 的桥接方法调用原生绑定接口
  // 假设 App 提供了 window.appBridge.bindAttribution 方法
  if (window.appBridge && window.appBridge.bindAttribution) {
    window.appBridge.bindAttribution({
      click_id: clickId,
      landing_url: landingUrl,
      app_id: 'default'
    });
  }
}

// 页面加载时自动调用
window.addEventListener('load', bindAttributionFromWebView);
```

### 重要提示

⚠️ **user_id 自动获取**：
- `user_id` 从 JWT token 中自动获取，**不需要在请求体中传递**
- 确保请求头中包含有效的 `Authorization: Bearer {JWT_TOKEN}`

⚠️ **必需参数**：
- 传 `click_id` 时必须同时传 `landing_url` 和 `app_id`
- `landing_url` 必须包含 `fbclid`（Meta）或 `gclid`（Google Ads）参数
- 系统会自动从 `landing_url` 中识别广告来源类型

⚠️ **用户绑定记录处理**：
- 如果用户已有绑定记录，会更新现有记录的 `click_id`、`click_type` 和 `landing_url`
- 如果用户没有绑定记录，会创建新记录并自动生成 `install_token`（标记为已使用）

⚠️ **Meta 广告自动上报**：
- 如果绑定的广告来源是 Meta（`click_type: "meta"`），系统会自动上报 ViewContent 事件到 Meta Conversions API
- 上报失败不会影响绑定结果，只会在日志中记录错误

⚠️ **click_id 获取方式**：
- **深链接场景**：从 App 启动时的 URL 参数中获取
- **WebView 场景**：从 WebView 加载的 H5 页面 URL 中获取
- **其他场景**：从其他渠道（如推送通知、分享链接等）获取的 URL 中提取

⚠️ **landing_url 格式要求**：
- 必须是完整的 URL（包含协议、域名、路径和查询参数）
- 查询参数中必须包含 `fbclid` 或 `gclid`
- 示例：
  - ✅ `"https://h5.example.com/landing?fbclid=EAABkZB1234567890xxxxxxxx"`
  - ✅ `"https://h5.example.com/landing?gclid=CjwKCAiAi--kBhBQEiwAyLbyjxxx"`
  - ❌ `"https://h5.example.com/landing"`（缺少 click_id 参数）
  - ❌ `"/landing?fbclid=xxx"`（不是完整 URL）

---

**最后更新**：2026-03-02
