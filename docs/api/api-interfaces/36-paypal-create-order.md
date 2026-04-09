## 💳 创建 PayPal 订单（金币包）

### 接口信息

- **URL**：`POST /paypal-create-order`
- **认证**：✅ 需要 access_token
- **Headers**：
  ```
  Content-Type: application/json
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 功能概述

创建 PayPal 一次性支付订单，用于金币包购买。返回审批链接，用户完成支付后需调用 `/paypal-capture-order` 捕获订单并发放金币。

### 请求参数

| 参数 | 类型 | 说明 | 必需 | 示例 |
|------|------|------|------|------|
| app_id | string | 应用ID | ✅ | "portraai" |
| product_id | string | 金币包产品ID，来自 /iap-coin-packages（platform=paypal） | ✅ | "paypal_coins_500" |

### 响应

**HTTP Status**: `200 OK`

```json
{
  "data": {
    "order_id": "xxxxxxxxxxxxx",
    "approval_url": "https://www.sandbox.paypal.com/checkoutnow?token=...",
    "purchase_coins": 500
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| order_id | string | PayPal 订单 ID，用户支付后需传给 capture 接口 |
| approval_url | string | PayPal 支付页面 URL |
| purchase_coins | number | 本次购买将获得的金币数 |

### 请求示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/paypal-create-order" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {access_token}" \
  -H "apikey: {SUPABASE_ANON_KEY}" \
  -d '{
    "app_id": "portraai",
    "product_id": "paypal_coins_500"
  }'
```

### 金币包购买流程

```
1. 获取金币包列表 → GET /iap-coin-packages?app_id=xxx&platform=paypal
2. 用户选择金币包
3. 调用本接口 → POST /paypal-create-order
4. 打开 approval_url，用户在 PayPal 完成支付
5. 支付完成后调用 → POST /paypal-capture-order
6. 查询状态 → GET /user-status
```

### 错误响应

```
400 - Missing required fields: app_id, product_id
404 - Coin package not found
500 - Failed to create order
```

### 重要提示

⚠️ **product_id** 来自 `/iap-coin-packages` 接口，需筛选 `platform=paypal`  
⚠️ **approval_url** 需在浏览器或 WebView 中打开  
⚠️ 用户支付后**必须**调用 `/paypal-capture-order` 捕获订单并发放金币  
