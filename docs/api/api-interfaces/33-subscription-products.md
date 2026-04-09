## 📋 获取订阅产品列表

### 接口信息

- **URL**：`GET /subscription-products`
- **认证**：❌ 不需要认证（公开接口）
- **Headers**：
  ```
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| app_id | string | 应用ID | ✅ |
| platform | string | 支付平台：stripe / apple / google / paypal，不传则返回该应用下所有平台的产品 | ❌ |

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| data | array | 订阅产品配置列表 |
| error | string \| null | 错误信息（成功时为 null） |
| status | number | HTTP 状态码 |

### 订阅产品对象字段

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 配置唯一ID（UUID） |
| platform | string | 支付平台（stripe / apple / google / paypal） |
| product_id | string | 平台的产品ID（如 prod_xxxxx） |
| product_name | string | 产品名称（如「Pro 年度会员」） |
| description | string | 产品描述 |
| plan_type | string | 计划类型（如 yearly / monthly） |
| billing_interval | string | 计费周期（如 year / month） |
| billing_interval_count | number | 计费周期数量 |
| amount | number | 价格 |
| currency | string | 货币代码（如 usd） |
| platform_price_id | string | 平台价格ID（如 price_1xxxxx） |
| credits_per_cycle | number | 每周期赠送积分 |
| credits_grant_type | string | 积分发放类型 |
| initial_credits | number | 首次发放积分 |
| trial_period_days | number | 试用期天数 |
| trial_credits | number | 试用期积分 |
| tags | array | 标签数组 |
| features | array | 功能特性列表 |

### 使用场景

- 订阅付费墙展示前获取可用的订阅产品列表
- 按 `app_id` 和 `platform` 筛选对应平台的订阅配置
- 支持 Stripe、Apple、Google、PayPal 等多平台订阅产品配置

### 请求示例

```bash
# 获取默认应用的 Stripe 订阅产品
curl -X GET "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/subscription-products?app_id=default&platform=stripe" \
  -H "Content-Type: application/json" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyZW5sZ3FwcHZxZmJpYnhwcGJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1MTIxODMsImV4cCI6MjA3ODA4ODE4M30.xVbKv4Es1sZRtWYsqbcu4eBoL1XZlMcyLcEJTTpddP4"

# 获取默认应用下所有平台的订阅产品
curl -X GET "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/subscription-products?app_id=default" \
  -H "Content-Type: application/json" \
  -H "apikey: {SUPABASE_ANON_KEY}"
```

### 响应示例

**成功响应**:
```json
{
  "data": [
    {
      "id": "uuid",
      "platform": "stripe",
      "product_id": "prod_xxxxx",
      "product_name": "Pro 年度会员",
      "description": "年度订阅，享受全部功能",
      "plan_type": "yearly",
      "billing_interval": "year",
      "billing_interval_count": 1,
      "amount": 99.99,
      "currency": "usd",
      "platform_price_id": "price_1xxxxx",
      "credits_per_cycle": 2000,
      "credits_grant_type": "recurring",
      "initial_credits": 0,
      "trial_period_days": 0,
      "trial_credits": 0,
      "tags": ["POPULAR"],
      "features": ["无限生成", "优先处理"]
    }
  ],
  "error": null,
  "status": 200
}
```

**错误响应 - 缺少 app_id**:
```json
{
  "error": "app_id query parameter is required"
}
```
HTTP 状态码：400

**错误响应 - 服务异常**:
```json
{
  "error": "Failed to fetch subscription configs",
  "status": 500
}
```

### 重要提示

- `app_id` 为必填参数，缺失会返回 400
- 仅返回 `is_active = true` 的订阅配置
- 结果按 `sort_order` 升序排列
- 订阅流程中，获取产品列表后需调用 [创建支付会话接口](./19-stripe-create-checkout.md) 创建 Stripe Checkout
