## 💳 创建支付会话 (Stripe Checkout)

### 接口信息

- **URL**：`POST /stripe-create-checkout`
- **认证**：✅ 需要 access_token
- **Headers**：
  ```
  Content-Type: application/json
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 功能概述

此接口支持两种购买场景：
1. **订阅购买** - 创建订阅类型的Checkout Session
2. **金币包购买** - 创建一次性支付的Checkout Session（新增）

### 请求参数

#### 基础参数（两种场景都需要）

| 参数 | 类型 | 说明 | 必需 | 示例 |
|------|------|------|------|------|
| app_id | string | 应用ID | ✅ | "default" / "velour" |
| price_id | string | Stripe价格ID | ✅ | "price_1xxxxx" |
| success_url | string | 成功跳转URL（可选，不传使用配置默认值） | ❌ | "https://app.com/success" |
| cancel_url | string | 取消跳转URL（可选，不传使用配置默认值） | ❌ | "https://app.com/cancel" |

#### 金币包购买专用参数

| 参数 | 类型 | 说明 | 必需 | 示例 |
|------|------|------|------|------|
| product_id | string | 金币包的product_id（有此参数时识别为金币包购买） | ❌ | "coins_275" |

**参数说明**：
- `success_url` 和 `cancel_url` 都是可选参数
- 如果不传入这两个参数，系统会根据 `app_id` 自动使用配置的默认值
- 优先级：传入的参数值 > 配置中的默认值 > 错误返回
- 当前支持的 app_id 默认配置：
  - `velour`: success → https://subpage-5ep.pages.dev/velour-success.html
  - `velour`: cancel → https://subpage-5ep.pages.dev/velour-cancel.html
  - `default`: success → https://stripe-payment-pages.vercel.app/success.html
  - `default`: cancel → https://stripe-payment-pages.vercel.app/cancel.html

### 使用场景

#### 订阅购买流程
1. 用户选择订阅计划
2. 调用此接口获取`checkout_url`
3. 在浏览器或WebView中打开`checkout_url`
4. 用户完成支付
5. Stripe自动跳转到配置的`success_url`
6. App通过深链接返回到应用，显示订阅成功提示

#### 金币包购买流程 ⭐ 新增
1. 获取金币包列表 → `/iap-coin-packages`
2. 用户选择金币包
3. 调用此接口获取支付链接（传递 `product_id` 参数）
4. 返回的响应包含 `purchase_coins`（预期获得的金币数）
5. 在浏览器或WebView中打开`checkout_url`
6. 用户完成支付
7. App调用 `/check-coin-purchase-status` 查询支付结果
8. 积分自动发放

### 请求示例

#### 方式 1：订阅购买 - 使用默认配置
```bash
POST /stripe-create-checkout
Content-Type: application/json
Authorization: Bearer {access_token}
apikey: {SUPABASE_ANON_KEY}

{
  "app_id": "default",
  "price_id": "price_1xxxxx"
}
```

#### 方式 2：订阅购买 - 自定义支付页面URL
```bash
POST /stripe-create-checkout
Content-Type: application/json
Authorization: Bearer {access_token}
apikey: {SUPABASE_ANON_KEY}

{
  "app_id": "default",
  "price_id": "price_1xxxxx",
  "success_url": "https://custom-domain.com/payment/success",
  "cancel_url": "https://custom-domain.com/payment/cancel"
}
```

#### 方式 3：金币包购买 ⭐ 新增
```bash
POST /stripe-create-checkout
Content-Type: application/json
Authorization: Bearer {access_token}
apikey: {SUPABASE_ANON_KEY}

{
  "app_id": "default",
  "price_id": "price_1xxxxx",
  "product_id": "coins_275"  // ← 新增：用于识别金币包购买
}
```

### 响应

#### 订阅购买 - 响应示例

**HTTP Status**: `200 OK`

```json
{
  "data": {
    "session_id": "cs_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "checkout_url": "https://checkout.stripe.com/pay/cs_test_xxxxx",
    "error": null
  },
  "status": 200
}
```

#### 金币包购买 - 响应示例 ⭐ 新增

**HTTP Status**: `200 OK`

```json
{
  "data": {
    "session_id": "cs_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "checkout_url": "https://checkout.stripe.com/pay/cs_test_xxxxx",
    "purchase_coins": 302,  // ⭐ 新增：本次购买预期获得的金币数
    "error": null
  },
  "status": 200
}
```

### 响应字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| session_id | string | Checkout Session ID（用于追踪和查询） |
| checkout_url | string | Stripe支付页面URL（客户端需要打开此URL） |
| purchase_coins | number | **⭐ 新增**：本次购买预期获得的金币数（仅金币包购买返回） |

### 金币包购买关键说明

#### purchase_coins 字段说明

- 仅在 `product_id` 参数存在时返回
- 表示用户完成支付后会获得的**总金币数**（包括基础金币+奖励金币）
- 示例：275基础金币 + 10%奖励(27枚) = 302枚 → purchase_coins = 302
- App可立即显示给用户"购买后将获得XX金币"

#### pending购买记录

当请求包含 `product_id` 时，后端自动：
1. 创建一个 `pending` 状态的购买记录
2. 保存 `session_id` 和 `purchase_coins` 信息
3. 用户支付完成后，Webhook自动更新记录为 `completed` 并发放积分

#### 与金币包查询接口的关系

必须同时使用：
- `product_id` - 金币包配置的产品ID（来自 `/iap-coin-packages`）
- `price_id` - Stripe的价格ID

系统会根据这两个参数查询 `iap_coin_packages` 表，获取完整的金币配置信息

### 错误响应

**HTTP Status**: `400 Bad Request`

```json
{
  "error": "Missing required fields: app_id, price_id",
  "status": 400
}
```

**HTTP Status**: `404 Not Found` - 金币包不存在

```json
{
  "error": "Coin package configuration not found",
  "status": 404
}
```

**HTTP Status**: `500 Internal Server Error`

```json
{
  "error": "Failed to create purchase record",
  "status": 500
}
```

### 重要提示

⚠️ **需要认证**：必须使用有效的 access_token 调用此接口
⚠️ **两种购买模式**：
  - 无 `product_id` → 订阅购买（mode: subscription）
  - 有 `product_id` → 金币包购买（mode: payment）
⚠️ **金币包识别**：通过 `product_id` 参数识别购买类型
⚠️ **价格匹配**：系统使用 `product_id` + `platform_price_id` 联合查询，支持一个product_id对应多个price_id的场景
⚠️ **pending记录**：金币包购买时自动创建pending状态的购买记录
⚠️ **购买金币数**：`purchase_coins` 字段包含基础金币+奖励金币，是用户最终获得的总数
⚠️ **后续查询**：金币包购买后，App应调用 `/check-coin-purchase-status` 查询支付状态

### 典型集成流程

#### 订阅购买流程
```
1. 用户选择订阅计划
   ↓
2. 调用 /stripe-create-checkout
   - 传递 app_id 和 price_id
   - 不传 product_id
   ↓
3. 获得 session_id 和 checkout_url
   ↓
4. 打开 checkout_url 进行支付
   ↓
5. Stripe webhook自动处理
   ↓
6. 显示订阅成功
```

#### 金币包购买流程 ⭐ 新增
```
1. 获取金币包列表 (/iap-coin-packages)
   ↓
2. 用户选择金币包
   ↓
3. 调用 /stripe-create-checkout
   - 传递 app_id、price_id 和 product_id
   ↓
4. 获得 session_id、checkout_url 和 purchase_coins
   - App立即显示"购买后将获得XX金币"
   ↓
5. 打开 checkout_url 进行支付
   ↓
6. App轮询 /check-coin-purchase-status 查询状态
   - 返回 pending 则继续等待
   - 返回 completed 则显示成功，更新积分
   ↓
7. Stripe webhook自动发放积分
```

### 代码示例（JavaScript/TypeScript）

#### 订阅购买
```typescript
async function createSubscriptionCheckout(priceId: string) {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/stripe-create-checkout',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        'apikey': anonKey
      },
      body: JSON.stringify({
        app_id: 'default',
        price_id: priceId
      })
    }
  )

  const { data } = await response.json()
  window.location.href = data.checkout_url
}
```

#### 金币包购买
```typescript
async function createCoinPackageCheckout(
  productId: string,
  priceId: string
) {
  const response = await fetch(
    'https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/stripe-create-checkout',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        'apikey': anonKey
      },
      body: JSON.stringify({
        app_id: 'default',
        price_id: priceId,
        product_id: productId  // ← 新增
      })
    }
  )

  const { data } = await response.json()

  // 显示预期金币数
  console.log(`购买后将获得 ${data.purchase_coins} 个金币`)

  // 保存session_id用于后续查询
  sessionStorage.setItem('checkoutSessionId', data.session_id)

  // 打开支付页面
  window.location.href = data.checkout_url
}
```

---
