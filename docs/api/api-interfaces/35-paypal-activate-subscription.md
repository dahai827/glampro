## 💳 激活 PayPal 订阅

### 接口信息

- **URL**：`POST /paypal-activate-subscription`
- **认证**：✅ 需要 access_token
- **Headers**：
  ```
  Content-Type: application/json
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 功能概述

用户在 PayPal 完成订阅审批后，客户端调用此接口激活订阅、写入订阅记录、发放积分并更新用户状态。

### 请求参数

| 参数 | 类型 | 说明 | 必需 | 示例 |
|------|------|------|------|------|
| subscription_id | string | PayPal 订阅 ID（create 接口返回） | ✅ | "I-xxxxxxxxxxxxx" |
| app_id | string | 应用ID | ✅ | "portraai" |

### 响应

**HTTP Status**: `200 OK`

```json
{
  "success": true,
  "subscription_status": "active",
  "plan_type": "yearly",
  "subscription_expire_at": "2026-03-19T00:00:00.000Z",
  "credits_balance": 2000,
  "credits_granted": 2000
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| subscription_status | string | 订阅状态（active） |
| plan_type | string | 计划类型（yearly/weekly） |
| subscription_expire_at | string | 订阅过期时间（ISO 8601） |
| credits_balance | number | 当前积分余额 |
| credits_granted | number | 本次发放的积分 |

### 请求示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/paypal-activate-subscription" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {access_token}" \
  -H "apikey: {SUPABASE_ANON_KEY}" \
  -d '{
    "subscription_id": "I-xxxxxxxxxxxxx",
    "app_id": "portraai"
  }'
```

### 调用时机

- 用户从 PayPal 审批页面返回后，在 success 回调 URL 对应的页面中调用
- 若为 H5 支付页，需在页面加载时从 URL 参数获取 `subscription_id`（或 token）后调用

### 幂等说明

同一订阅多次调用会返回成功，`credits_granted` 为 0，不会重复发放积分。

### 错误响应

```
400 - Subscription is not active
403 - Subscription does not belong to this user
404 - Subscription configuration not found
500 - Failed to activate subscription
```

### 重要提示

⚠️ **必须在用户完成 PayPal 审批后调用**，否则订阅状态无效  
⚠️ 调用成功后用户状态已更新，可直接调用 `/user-status` 获取最新数据  
