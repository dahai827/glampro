# 归因点击记录（Attribution Click）

### 接口信息

- **URL**：`POST /attribution-click`
- **认证**：❌ 不需要 JWT token（公开接口）
- **Headers**:
  ```
  Content-Type: application/json
  User-Agent: {浏览器/客户端 User-Agent，服务端自动获取}
  ```

### 接口描述

用于 **W2A（Web to App）推广投放**场景下的落地页。当用户从广告平台（Google Ads、Meta、TikTok）点击广告进入 H5 落地页时，调用此接口记录广告点击信息，并生成 `install_token`。

**典型流程**：
1. 用户点击广告 → 跳转到 H5 落地页（带 `gclid`/`fbclid` 等参数）
2. 落地页加载时调用 `/attribution-click` → 记录点击、生成 `install_token`
3. 将 `install_token` 存入 localStorage 或通过 Deep Link 传递给 App
4. 用户下载并打开 App、完成登录后 → 调用 `/attribution-bind` 传入 `install_token` 完成归因绑定

**重要说明**：
- 服务端会自动从请求中获取并标准化 **User-Agent** 和 **客户端 IP**，无需客户端传递（IP 不信任客户端传入）
- `install_token` 有效期为 **24 小时**，过期后需用户重新从广告入口进入
- 支持可选 **设备指纹**（`fingerprint_v1` / `fingerprint_sig_v1`），用于 IP+时间窗口+指纹 联合匹配，详见 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md)

---

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `click_id` | string | 广告点击 ID（如 `gclid`、`fbclid`、TikTok 的 click_id） | ✅ |
| `click_type` | string | 广告来源类型，取值：`google_ads`、`meta`、`tiktok` | ✅ |
| `landing_url` | string | 落地页完整 URL（建议包含查询参数） | ✅ |
| `app_id` | string | 应用 ID，可选，默认为 `default` | ❌ |
| `ts` | number | 点击时间戳（毫秒），可选，不传则使用服务端当前时间 | ❌ |
| `fingerprint_v1` | object | 设备指纹 v1（固定 9 字段），可选，用于归因匹配 | ❌ |
| `fingerprint_sig_v1` | string | 指纹签名 `SHA256(stable_json(fingerprint_v1))`，与 `fingerprint_v1` 配套使用 | ❌ |

**请求 Body 示例（基础）**:
```json
{
  "click_id": "EAABkZB1234567890xxxxxxxx",
  "click_type": "meta",
  "landing_url": "https://h5.example.com/landing?fbclid=EAABkZB1234567890xxxxxxxx",
  "app_id": "default",
  "ts": 1709452800000
}
```

**请求 Body 示例（含设备指纹）**:
```json
{
  "click_id": "EAABkZB1234567890xxxxxxxx",
  "click_type": "meta",
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
    "device_model_bucket": "unknown"
  },
  "fingerprint_sig_v1": "a1b2c3d4e5f6..."
}
```

**参数说明**：

**click_id**：
- 广告平台返回的点击 ID
  - **Meta**：URL 参数 `fbclid` 的值
  - **Google Ads**：URL 参数 `gclid` 的值
  - **TikTok**：TikTok 广告的 click_id 参数值

**click_type**：
- 必须为以下之一：`google_ads`、`meta`、`tiktok`
- 需与 `click_id` 来源一致

**landing_url**：
- 当前 H5 落地页的完整 URL
- 建议包含 `gclid`/`fbclid` 等查询参数，便于后续归因分析

**app_id**：
- 应用标识，用于区分不同应用
- 可选，不传则默认为 `"default"`

**ts**：
- 客户端记录的点击时间戳（毫秒）
- 可选，不传则使用服务端接收请求的时间

**fingerprint_v1**（可选）：
- 设备指纹对象，仅包含规范定义的 9 个字段：`device_type`、`os_family`、`os_major`、`language`、`screen_bucket`、`pixel_ratio_bucket`、`color_depth`、`max_touch_points`、`device_model_bucket`
- 用于归因匹配：服务端建议使用 **IP 前缀 + 时间窗口 + 指纹字段** 联合判断
- 对未知值保持兼容，不因单字段缺失拒绝归因
- 详见 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md)

**fingerprint_sig_v1**（可选）：
- 指纹签名：`SHA256(stable_json(fingerprint_v1))`，`stable_json` 按 key 字典序排序
- 与 `fingerprint_v1` 配套传递时，服务端会校验签名；校验失败则仅存储 `fingerprint_v1` 不存签名
- 用于后端索引与去重

---

### 响应说明

#### 成功响应（200）

```json
{
  "success": true,
  "data": {
    "install_token": "550e8400-e29b-41d4-a716-446655440000",
    "expire_at": "2026-03-03T12:00:00.000Z",
    "ttl_seconds": 86400
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `install_token` | string | 安装令牌，用于后续 `/attribution-bind` 绑定归因 |
| `expire_at` | string | 过期时间（ISO 8601 格式） |
| `ttl_seconds` | number | 有效期秒数（固定 86400，即 24 小时） |

#### 错误响应

**400 - 缺少必填参数**
```json
{
  "success": false,
  "error": "Missing required parameters: click_id, click_type, landing_url"
}
```

**400 - click_type 非法**
```json
{
  "success": false,
  "error": "Invalid click_type. Must be one of: google_ads, meta, tiktok"
}
```

**405 - 方法不允许**
```json
{
  "success": false,
  "error": "Method not allowed"
}
```

**500 - 服务端错误**
```json
{
  "success": false,
  "error": "Failed to process attribution click"
}
```

---

### 请求示例

**cURL 示例**:
```bash
curl -X POST https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/attribution-click \
  -H "Content-Type: application/json" \
  -d '{
    "click_id": "EAABkZB1234567890xxxxxxxx",
    "click_type": "meta",
    "landing_url": "https://h5.example.com/landing?fbclid=EAABkZB1234567890xxxxxxxx",
    "app_id": "default"
  }'
```

**JavaScript（H5 落地页）示例**:
```javascript
// 采集设备指纹（按 30-device-fingerprint-fields-spec.md 规范）
function collectFingerprintV1() {
  const w = window.screen?.width ?? 0;
  const h = window.screen?.height ?? 0;
  const short = Math.round(Math.min(w, h) / 20) * 20;
  const long = Math.round(Math.max(w, h) / 20) * 20;
  const screenBucket = `${short}x${long}`;
  const dpr = window.devicePixelRatio ?? 1;
  const ratioBucket = dpr < 1.5 ? '1x' : dpr < 2.5 ? '2x' : dpr < 3.5 ? '3x' : '4x+';
  const lang = (navigator.language || 'unknown').toLowerCase().replace('_', '-');

  return {
    device_type: (w < 768 ? 'phone' : w < 1024 ? 'tablet' : 'desktop'),
    os_family: /iphone|ipad|ipod/i.test(navigator.userAgent) ? 'ios' : /android/i.test(navigator.userAgent) ? 'android' : 'unknown',
    os_major: 'unknown',
    language: lang,
    screen_bucket: screenBucket,
    pixel_ratio_bucket: ratioBucket,
    color_depth: window.screen?.colorDepth ?? 24,
    max_touch_points: navigator.maxTouchPoints ?? 5,
    device_model_bucket: 'unknown'
  };
}

// 计算 fingerprint_sig_v1
async function computeFingerprintSig(fp) {
  const sorted = {};
  Object.keys(fp).sort().forEach(k => { sorted[k] = fp[k]; });
  const str = JSON.stringify(sorted);
  const buf = new TextEncoder().encode(str);
  const hash = await crypto.subtle.digest('SHA-256', buf);
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('');
}

// 从 URL 解析 click_id 和 click_type
const urlParams = new URLSearchParams(window.location.search);
const fbclid = urlParams.get('fbclid');
const gclid = urlParams.get('gclid');
const ttclid = urlParams.get('ttclid');

let clickId = null, clickType = null;
if (fbclid) { clickId = fbclid; clickType = 'meta'; }
else if (gclid) { clickId = gclid; clickType = 'google_ads'; }
else if (ttclid) { clickId = ttclid; clickType = 'tiktok'; }

if (clickId && clickType) {
  const body = { click_id: clickId, click_type: clickType, landing_url: window.location.href, app_id: 'default' };
  const fp = collectFingerprintV1();
  body.fingerprint_v1 = fp;
  body.fingerprint_sig_v1 = await computeFingerprintSig(fp);

  fetch('https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/attribution-click', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  })
    .then(res => res.json())
    .then(data => {
      if (data.success) {
        localStorage.setItem('install_token', data.data.install_token);
        localStorage.setItem('install_token_expire_at', data.data.expire_at);
      }
    });
}
```

---

### 使用场景

1. **W2A 落地页**：用户从 Meta/Google/TikTok 广告点击进入 H5 页，页面加载时调用
2. **Deep Link 前置**：落地页将 `install_token` 写入 URL，用户点击「下载 App」后通过 Universal Link / App Link 传递给 App
3. **WebView 桥接**：App 内嵌 WebView 打开落地页，落地页通过 JS Bridge 将 `install_token` 传给原生

---

### 与 attribution-bind 的关系

| 接口 | 调用时机 | 认证 | 作用 |
|------|----------|------|------|
| `/attribution-click` | 用户进入 H5 落地页时 | ❌ 不需要 | 记录点击，生成 `install_token` |
| `/attribution-bind` | 用户安装 App 并登录后 | ✅ 需要 JWT | 用 `install_token` 或 `click_id` 绑定归因到用户 |

**两种绑定方式**：
- **install_token 方式**：先调 `/attribution-click` 拿 token，App 登录后调 `/attribution-bind` 传 `install_token`
- **click_id 方式**：App 直接从 URL/Deep Link 拿到 `click_id`，登录后直接调 `/attribution-bind` 传 `click_id` 和 `landing_url`（无需先调 `/attribution-click`）

---

### 重要提示

- ⚠️ **CORS**：接口支持跨域，可直接从 H5 页面发起请求
- ⚠️ **有效期**：`install_token` 仅 24 小时有效，超时需用户重新从广告入口进入
- ⚠️ **幂等**：同一 `click_id` 多次调用会创建多条记录，建议落地页做去重（如 sessionStorage 标记）
- ⚠️ **User-Agent / IP**：由服务端自动从请求头获取，**不信任客户端传入 IP**
- ⚠️ **设备指纹**：`fingerprint_v1` 可选，用于 IP+时间窗口+指纹联合匹配；格式见 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md)；对未知值保持兼容，不因单字段缺失拒绝归因

---

### 相关文档

- [设备指纹参数规范](./30-device-fingerprint-fields-spec.md) - fingerprint_v1 字段定义、采集方式与签名规则

---

**最后更新**：2026-03-02
