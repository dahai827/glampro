## 💳 捕获 PayPal 订单（金币包）

### 接口信息

- **URL**：`POST /paypal-capture-order`
- **认证**：✅ 需要 access_token
- **Headers**：
  ```
  Content-Type: application/json
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 功能概述

用户在 PayPal 完成支付后，客户端调用此接口捕获订单、发放金币并更新用户积分余额。

### 请求参数

| 参数 | 类型 | 说明 | 必需 | 示例 |
|------|------|------|------|------|
| order_id | string | PayPal 订单 ID（create-order 接口返回） | ✅ | "xxxxxxxxxxxxx" |
| app_id | string | 应用ID | ✅ | "portraai" |

### 响应

**HTTP Status**: `200 OK`

```json
{
  "success": true,
  "credits_granted": 500,
  "credits_balance": 2500
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| credits_granted | number | 本次发放的金币数 |
| credits_balance | number | 当前积分余额 |

### 请求示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/paypal-capture-order" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {access_token}" \
  -H "apikey: {SUPABASE_ANON_KEY}" \
  -d '{
    "order_id": "xxxxxxxxxxxxx",
    "app_id": "portraai"
  }'
```

### 调用时机

- 用户从 PayPal 支付页面返回后，在 success 回调 URL 对应的页面中调用
- 若为 H5 支付页，需在页面加载时从 URL 参数获取 `order_id` 后调用

### 幂等说明

同一订单多次调用会返回成功，`credits_granted` 为 0，不会重复发放金币。

### 错误响应

```
400 - Order capture not completed
404 - Purchase record not found
500 - Failed to capture order
```

### 重要提示

⚠️ **必须在用户完成 PayPal 支付后调用**  
⚠️ 调用成功后积分已发放，可直接调用 `/user-status` 获取最新余额  
