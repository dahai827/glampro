## 🔄 通过支付页短 Token 换取 access_token

### 接口信息

- **URL**：`GET /get-token-by-payment-token?pt={payment_token}`
- **认证**：❌ 不需要 access_token，仅需 apikey
- **Headers**：
  ```
  apikey: {SUPABASE_ANON_KEY}
  ```

### 功能概述

Web 支付页用短 token（URL 中的 `pt` 参数）换取 access_token，用于调用需认证的 API（如 `/stripe-create-checkout`、`/user-status`、`/check-coin-purchase-status`）。

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| pt | string | 支付页短 token（来自 create-payment-token 或 URL） | ✅ |

### 响应

**HTTP Status**: `200 OK`

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "app_id": "default"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| access_token | string | JWT 访问令牌 |
| expires_in | number | 有效秒数（通常 3600） |
| user_id | string | 用户 ID |
| app_id | string | 应用标识，来自 create-payment-token 请求 |

### 请求示例

```bash
curl "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/get-token-by-payment-token?pt=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6" \
  -H "apikey: ${ANON_KEY}"
```

### 错误响应

**HTTP Status**: `400 Bad Request` - 缺少参数

```json
{
  "error": "Missing required parameter: pt (payment_token)"
}
```

**HTTP Status**: `401 Unauthorized` - token 无效或过期

```json
{
  "error": "Invalid or expired payment token"
}
```

```json
{
  "error": "Payment token has expired"
}
```

### 重要提示

⚠️ **一次性使用**：兑换成功后短 token 立即删除，不可重复使用
⚠️ **有效期 15 分钟**：超时需用户重新从 App 进入支付页
⚠️ **Web 页调用时机**：页面加载后立即调用，获取 access_token 后再请求 /user-status、/iap-coin-packages 等
