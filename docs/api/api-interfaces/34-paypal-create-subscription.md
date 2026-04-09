## 💳 创建 PayPal 订阅

### 接口信息

- **URL**：`POST /paypal-create-subscription`
- **认证**：✅ 需要 access_token
- **Headers**：
  ```
  Content-Type: application/json
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 功能概述

创建 PayPal 订阅，返回用户审批链接。用户在 PayPal 页面完成审批后，需调用 `/paypal-activate-subscription` 激活订阅。

### 请求参数

| 参数 | 类型 | 说明 | 必需 | 示例 |
|------|------|------|------|------|
| app_id | string | 应用ID | ✅ | "portraai" |
| plan_id | string | 订阅计划ID，对应 subscription_configs.product_id | ✅ | "paypal_yearly_pro" |

### 响应

**HTTP Status**: `200 OK`

```json
{
  "data": {
    "subscription_id": "I-xxxxxxxxxxxxx",
    "approval_url": "https://www.sandbox.paypal.com/subscribe/..."
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| subscription_id | string | PayPal 订阅 ID，用户审批后需传给 activate 接口 |
| approval_url | string | PayPal 审批页面 URL，客户端需打开此 URL |

### 请求示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/paypal-create-subscription" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {access_token}" \
  -H "apikey: {SUPABASE_ANON_KEY}" \
  -d '{
    "app_id": "portraai",
    "plan_id": "paypal_yearly_pro"
  }'
```

### 订阅流程

```
1. 获取订阅产品列表 → GET /subscription-products?app_id=xxx&platform=paypal
2. 用户选择订阅计划（取 product_id 作为 plan_id）
3. 调用本接口 → POST /paypal-create-subscription
4. 打开 approval_url，用户在 PayPal 完成审批
5. 审批完成后调用 → POST /paypal-activate-subscription
6. 查询状态 → GET /user-status
```

### 错误响应

```
400 - Missing required fields: app_id, plan_id
404 - Subscription config not found
500 - Failed to create subscription
```

### 重要提示

⚠️ **plan_id** 对应 `subscription_configs` 表中 `platform='paypal'` 的 `product_id`  
⚠️ **approval_url** 需在浏览器或 WebView 中打开，用户完成 PayPal 审批后返回  
⚠️ 用户审批后**必须**调用 `/paypal-activate-subscription` 激活订阅并发放积分
