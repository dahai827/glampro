## 🔑 创建支付页短 Token

### 接口信息

- **URL**：`POST /create-payment-token`
- **认证**：✅ 需要 access_token
- **Headers**：
  ```
  Content-Type: application/json
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 功能概述

iOS App 在跳转 Web 支付页前调用此接口，获取短 token 或**完整 payment_url**，避免长 JWT 导致 URL 截断，便于后续灵活扩展。

### 请求参数（Body 可选）

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| app_id | string | 应用 ID，用于选择支付页配置 | ❌，默认 "default" |
| source | string | 来源标识（如 "ios"），会拼入 URL | ❌ |
| return_scheme | string | 回 App 的 URL Scheme（如 "myapp"），会拼入 URL | ❌ |
| type | string | 支付类型：`"subscription"` 表示订阅支付；不传或传其他值表示内购金币。当为 `subscription` 时，返回的 `payment_url` 会拼接 `type=subscription` 参数 | ❌ |

**return_scheme 说明**：传你在 **Xcode → Target → Info → URL Types** 中配置的 URL Scheme。支付完成后，Web 页会跳转 `{returnScheme}://payment-success` 唤起你的 App。例如 App 配置了 Scheme `myapp`，则传 `"return_scheme": "myapp"`。

**source 说明**：来源标识，如 `"ios"`，用于 Web 页判断是否来自 App，从而决定是否通过 Deep Link 回跳。

**type 说明**：当 `type` 为 `"subscription"` 时，返回的 `payment_url` 会自动拼接 `&type=subscription`，Web 页会展示订阅支付 UI（年订/周订）；否则展示内购金币 UI。

### 响应

**HTTP Status**: `200 OK`

**内购金币**（不传 type 或 type 非 subscription）：
```json
{
  "payment_url": "https://thirdpayh5.pages.dev/payment?pt=a1b2c3d4...&userId=uuid&source=ios&returnScheme=myapp",
  "payment_token": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "expires_in": 900
}
```

**订阅支付**（传 `type: "subscription"`）：
```json
{
  "payment_url": "https://thirdpayh5.pages.dev/payment?pt=a1b2c3d4...&userId=uuid&source=ios&returnScheme=myapp&type=subscription",
  "payment_token": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "expires_in": 900
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| payment_url | string | **完整支付页 URL**，App 可直接打开（需在 payment-urls-config 或 env 中配置 payment_page_base）。当请求中 `type=subscription` 时，URL 会拼接 `&type=subscription` |
| payment_token | string | 短 token，放入 URL 的 `pt` 参数 |
| user_id | string | 用户 ID |
| expires_in | number | 有效秒数（900 = 15 分钟） |

**说明**：若未配置 `payment_page_base`，响应中不包含 `payment_url`，仅返回 `payment_token`、`user_id`、`expires_in`，App 需自行拼接 URL。当请求 Body 中 `type` 为 `"subscription"` 时，返回的 `payment_url` 会自动拼接 `type=subscription` 参数，Web 页会展示订阅支付 UI。

### 使用流程

```
1. App 调用 POST /create-payment-token（携带 access_token，可选传 app_id、source、return_scheme、type）
   ↓
2. 获得 payment_url（或 payment_token + user_id）；type=subscription 时 payment_url 会带 type=subscription
   ↓
3. 若有 payment_url，直接打开；否则自行拼接 URL
   ↓
4. Web 页加载后调用 GET /get-token-by-payment-token?pt={payment_token}
   ↓
5. 获得 access_token，用于后续 /stripe-create-checkout、/user-status 等接口
```

### 配置 payment_page_base

在 `supabase/functions/_shared/payment-urls-config.ts` 中为各 app_id 配置 `payment_page_base`，或设置环境变量 `PAYMENT_PAGE_BASE_URL` 作为默认值。

**当前部署地址**：`https://thirdpayh5.pages.dev`（Cloudflare Pages 部署的 ThirdPayH5 项目）

配置示例：
- `payment_page_base`: `https://thirdpayh5.pages.dev`
- 内购金币页：`https://thirdpayh5.pages.dev/payment?pt=xxx&userId=xxx&source=ios&returnScheme=myapp`
- 订阅支付页：`https://thirdpayh5.pages.dev/payment?pt=xxx&userId=xxx&source=ios&returnScheme=myapp&type=subscription`

### 请求示例

```bash
# 仅获取 token（不返回 payment_url，若未配置 base）
curl -X POST "${BASE_URL}/create-payment-token" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "apikey: ${ANON_KEY}"

# 获取完整 payment_url（内购金币）
curl -X POST "${BASE_URL}/create-payment-token" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"app_id":"default","source":"ios","return_scheme":"myapp"}'

# 获取完整 payment_url（订阅支付，URL 会拼接 type=subscription）
curl -X POST "${BASE_URL}/create-payment-token" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"app_id":"default","source":"ios","return_scheme":"myapp","type":"subscription"}'
```

### 错误响应

**HTTP Status**: `401 Unauthorized`

```json
{
  "error": "Unauthorized"
}
```

### 重要提示

⚠️ **短 token 有效期 15 分钟**，超时需重新调用
⚠️ **一次性使用**：Web 页兑换 access_token 后，短 token 立即失效
⚠️ **payment_url**：需在 payment-urls-config 或 env 中配置 payment_page_base 才会返回
⚠️ **灵活扩展**：通过 app_id、source、return_scheme、type 可适配不同应用和回跳逻辑
⚠️ **type 参数**：传 `type: "subscription"` 时，返回的 payment_url 会拼接 `type=subscription`，Web 页展示订阅支付 UI
