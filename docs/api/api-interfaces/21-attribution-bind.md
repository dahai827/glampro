## 2️⃣1️⃣ 归因绑定

### 接口信息

- **URL**：`POST /attribution-bind`
- **认证**：✅ 需要 JWT token（从 Authorization header 获取）
- **Headers**:
  ```
  Content-Type: application/json
  Authorization: Bearer {JWT_TOKEN}
  ```

### 接口描述

App 用户登录后调用此接口，将广告点击信息绑定到用户账号。使用 `install_token` 方式完成绑定：

- 从 H5 页面获取 `install_token`（通过 `/attribution-click` 接口）
- App 读取剪贴板或 Deep Link 中的 `install_token`
- 调用本接口进行绑定

**重要说明**：
- ⚠️ **user_id 自动获取**：`user_id` 从 JWT token 中自动获取，**不需要在请求体中传递**
- ⚠️ **统一使用 install_token**：归因绑定统一通过 `install_token` 完成，需先调用 `/attribution-click` 获取 token
- ⚠️ **设备指纹**：可选传 `fingerprint_v1` / `fingerprint_sig_v1`，用于 IP+时间窗口+指纹联合匹配；详见 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md)

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `install_token` | string | 从 `/attribution-click` 获得的一次性 token（UUID，36字符） | ✅ |
| `app_id` | string | 应用 ID，可选，默认为 `default` | ❌ |
| `fingerprint_v1` | object | 设备指纹 v1（固定 9 字段），可选 | ❌ |
| `fingerprint_sig_v1` | string | 指纹签名 `SHA256(stable_json(fingerprint_v1))`，与 `fingerprint_v1` 配套 | ❌ |

**请求 Body 示例**:
```json
{
  "install_token": "550e8400-e29b-41d4-a716-446655440000",
  "app_id": "default"
}
```

**请求 Body 示例（含设备指纹）**:
```json
{
  "install_token": "550e8400-e29b-41d4-a716-446655440000",
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

**install_token**：
- 从 `/attribution-click` 接口获得的一次性安装令牌
- 格式：UUID（36 个字符）
- 有效期：24 小时
- 只能使用一次，绑定后即失效

**app_id**：
- 应用标识，用于区分不同应用
- 可选，不传则默认为 `"default"`
- 可选值：`"default"`、`"velour"` 等

**fingerprint_v1**（可选）：
- 设备指纹对象，仅含规范 9 字段；用于 IP+时间窗口+指纹联合匹配
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
    "install_token": "550e8400-e29b-41d4-a716-446655440000",
    "app_id": "default"
  }'
```

**TypeScript/JavaScript 示例**:
```typescript
import { supabase } from './supabaseClient';

async function bindAttribution(installToken: string) {
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
        install_token: installToken,
        app_id: 'default'
      })
    }
  );

  const result = await response.json();

  if (result.success) {
    console.log('Attribution bound successfully', result.data);
    // 清空剪贴板（可选）
    if (navigator.clipboard) {
      await navigator.clipboard.writeText('');
    }
  } else {
    console.error('Failed to bind attribution:', result.error);
  }
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

    func bindAttribution(installToken: String) async throws {
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
            "install_token": installToken,
            "app_id": "default"
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
            // 清空剪贴板（可选）
            UIPasteboard.general.string = ""
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
  "error": "Missing required parameter: install_token must be provided"
}
```

**400 Bad Request - install_token 格式无效**:
```json
{
  "success": false,
  "error": "Invalid install_token format: must be 36 characters"
}
```

**400 Bad Request - install_token 无效或已过期**:
```json
{
  "success": false,
  "error": "Invalid, expired, or already used token"
}
```

**500 Internal Server Error - 绑定 token 失败**:
```json
{
  "success": false,
  "error": "Failed to bind token"
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

#### H5 → App 流程

**完整流程**：
```
1. 用户点击广告（Meta/Google）
   ↓
2. H5 页面加载（URL 携带 gclid/fbclid）
   ↓
3. H5 调用 /attribution-click → 获得 install_token
   ↓
4. H5 将 install_token 写入剪贴板
   ↓
5. App 首次打开 + 用户登录
   ↓
6. App 从剪贴板读取 install_token
   ↓
7. App 调用 /attribution-bind（传 install_token）
   ↓
8. 绑定成功，App 清空剪贴板
```

**代码示例**：
```swift
// iOS 示例
func bindAttributionFromClipboard() async {
    // 1. 读取剪贴板
    guard let installToken = UIPasteboard.general.string,
          installToken.count == 36 else {
        print("No valid install token in clipboard")
        return
    }

    // 2. 确保用户已登录（获取 JWT token）
    guard let session = try? await supabaseClient.auth.session else {
        print("User not logged in")
        return
    }

    // 3. 调用绑定接口
    do {
        try await bindAttribution(installToken: installToken)
        // 4. 清空剪贴板
        UIPasteboard.general.string = ""
        print("Attribution bound successfully")
    } catch {
        print("Failed to bind attribution: \(error)")
    }
}
```

### 重要提示

⚠️ **user_id 自动获取**：
- `user_id` 从 JWT token 中自动获取，**不需要在请求体中传递**
- 确保请求头中包含有效的 `Authorization: Bearer {JWT_TOKEN}`

⚠️ **install_token 限制**：
- `install_token` 格式必须为 UUID（36 个字符）
- `install_token` 有效期为 24 小时
- `install_token` 只能使用一次，绑定后即失效

⚠️ **Meta 广告自动上报**：
- 如果绑定的广告来源是 Meta（`click_type: "meta"`），系统会自动上报 ViewContent 事件到 Meta Conversions API
- 上报失败不会影响绑定结果，只会在日志中记录错误

⚠️ **Token 恢复机制**：
- 如果 `install_token` 验证失败，系统会尝试通过 IP + 平台 + OS 版本查找备选 token
- 如果找到匹配的 token，会自动绑定

⚠️ **设备指纹**：
- `fingerprint_v1` / `fingerprint_sig_v1` 可选，用于 IP+时间窗口+指纹联合匹配
- 格式见 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md)

---

### 相关文档

- [设备指纹参数规范](./30-device-fingerprint-fields-spec.md) - fingerprint_v1 字段定义与签名规则

---

**最后更新**：2026-03-02
