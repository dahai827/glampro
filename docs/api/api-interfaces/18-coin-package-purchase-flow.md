## 💰 内购金币包购买流程指南

### 概述

本指南详细说明了从获取金币包列表到支付完成的完整流程，涵盖所有必要的API调用和状态管理。

---

## 📊 流程架构

```
┌──────────────────────────────────────────────────────────────────┐
│                         用户启动App                               │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                    1️⃣  │ 获取金币包列表
                         ▼
            ┌─────────────────────────────────┐
            │  GET /iap-coin-packages         │
            │  (platform=stripe/apple/google) │
            └────────┬────────────────────────┘
                     │ 返回可购买金币包列表
                     │ (display_name, amount, total_coins)
                     ▼
        ┌──────────────────────────────────┐
        │  显示金币包选项给用户              │
        │  (275/550/1100等)                │
        └────────┬─────────────────────────┘
                 │ 用户选择金币包
                 │
            2️⃣  │ 请求支付链接
                 ▼
    ┌──────────────────────────────────────────┐
    │  POST /stripe-create-checkout            │
    │  (app_id, price_id, product_id)         │
    └──────┬───────────────────────────────────┘
           │ 返回 session_id + checkout_url
           │      + purchase_coins预期金币数
           │
       3️⃣ │ 创建pending购买记录（服务器自动）
           │ (session_id, purchase_coins...)
           │
           ▼
    ┌──────────────────────────────────────────┐
    │  打开Stripe Checkout页面                 │
    │  用户输入支付信息                        │
    └──────┬───────────────────────────────────┘
           │ 用户完成支付
           │
       4️⃣ │ 实时查询支付状态（可选，但推荐）
           ▼
    ┌──────────────────────────────────────────┐
    │  GET /check-coin-purchase-status         │
    │  (session_id)                            │
    └──────┬───────────────────────────────────┘
           │ 返回支付状态 (pending/completed)
           │
           ├─ pending: 继续等待(轮询)
           └─ completed: 显示成功, 更新余额
           │
       5️⃣ │ Stripe Webhook触发（自动）
           ▼
    ┌──────────────────────────────────────────┐
    │  stripe-webhook (后台处理)               │
    │  1. 验证session_id对应的pending记录     │
    │  2. 更新状态为completed                  │
    │  3. 调用grant_user_credits发放积分      │
    └──────┬───────────────────────────────────┘
           │ 积分已发放完成
           │
       6️⃣ │ 再次查询支付状态确认（推荐）
           ▼
    ┌──────────────────────────────────────────┐
    │  GET /check-coin-purchase-status         │
    │  (session_id)                            │
    └──────┬───────────────────────────────────┘
           │ 返回completed状态 + 最新total_coins
           │
           ▼
    ┌──────────────────────────────────────────┐
    │  显示"购买成功"                          │
    │  更新UI显示新的金币余额                  │
    │  回到主界面或功能选择页面                │
    └──────────────────────────────────────────┘
```

---

## 🔄 详细流程说明

### 第1步：获取金币包列表

**API调用**：
```bash
GET /iap-coin-packages?app_id=default&platform=stripe
```

**响应**（示例）：
```json
{
  "success": true,
  "data": [
    {
      "product_id": "coins_275",
      "display_name": "275 coins",
      "amount": 19.99,
      "base_coins": 275,
      "bonus_percentage": 10,
      "total_coins": 302,
      "tags": [],
      "platform_price_id": "price_1234567890"
    },
    {
      "product_id": "coins_550",
      "display_name": "550 coins + 15% BONUS",
      "amount": 34.99,
      "base_coins": 550,
      "bonus_percentage": 15,
      "total_coins": 632,
      "tags": ["POPULAR", "BEST VALUE"],
      "platform_price_id": "price_0987654321"
    }
  ]
}
```

**UI显示**：
```
┌─ 275 coins - $19.99 ─┐
│  获得: 302枚 (含10%奖励) │
└─────────────────────┘

┌─ 550 coins - $34.99 ─┐
│  获得: 632枚 (含15%奖励) │ ⭐ POPULAR
│  💰 最值               │ 🏆 BEST VALUE
└─────────────────────┘
```

---

### 第2步：请求支付链接

**用户操作**：点击"购买"按钮

**API调用**：
```bash
POST /stripe-create-checkout
Content-Type: application/json
Authorization: Bearer {access_token}
apikey: {ANON_KEY}

{
  "app_id": "default",
  "price_id": "price_1234567890",        // Stripe price ID
  "product_id": "coins_275"              // 新增：用于识别金币包购买
}
```

**重要说明**：
- `price_id`：来自Stripe的价格ID（由管理后台生成）
- `product_id`：来自金币包配置的产品ID（用于服务器识别是金币包购买）

**响应**（示例）：
```json
{
  "data": {
    "session_id": "cs_test_1234567890abcdef",
    "checkout_url": "https://checkout.stripe.com/pay/cs_test_xxx",
    "purchase_coins": 302,              // ⭐ 新增：预期获得的金币数
    "error": null
  },
  "status": 200
}
```

**关键信息**：
- `session_id`：用于后续查询和防重复处理
- `checkout_url`：用户需要打开的支付页面
- `purchase_coins`：App可立即显示给用户"购买后将获得XX金币"

---

### 第3步：用户支付

**用户操作**：
1. App打开 `checkout_url`（Web或原生支付）
2. 用户填写支付信息
3. 用户确认支付

**后端操作**（自动）：
- Supabase自动创建pending购买记录
- 保存session_id + 金币包信息
- 等待支付完成

---

### 第4步：查询支付状态（可选但推荐）

**支付进行中**，App可调用状态查询接口实时获取状态：

**API调用**：
```bash
GET /check-coin-purchase-status?session_id=cs_test_1234567890abcdef
Authorization: Bearer {access_token}
apikey: {ANON_KEY}
```

**响应**（支付进行中）：
```json
{
  "success": true,
  "data": {
    "status": "pending",
    "purchase_coins": 302,
    "total_coins": 1502,              // 当前余额
    "message": "支付进行中，请稍候..."
  }
}
```

**响应**（支付成功 - 仅在Webhook处理后返回）：
```json
{
  "success": true,
  "data": {
    "status": "completed",
    "purchase_coins": 302,
    "total_coins": 1804,              // 已更新的总余额
    "is_credited": true,
    "message": "支付成功，已发放302金币"
  }
}
```

**轮询策略**：
```javascript
// 建议每2秒查询一次，最多查询30次（共1分钟）
const pollStatus = async () => {
  for (let i = 0; i < 30; i++) {
    const status = await checkCoinPurchaseStatus(sessionId);

    if (status === 'completed') {
      // 支付成功，退出轮询
      showSuccessMessage('购买成功');
      updateCoinsBalance();
      break;
    } else if (status === 'failed') {
      // 支付失败
      showErrorMessage('支付失败，请重试');
      break;
    }
    // pending状态继续等待
    await delay(2000);
  }
};
```

---

### 第5步：Webhook处理（后台自动）

**Stripe发送webhook**（自动触发）：
```
POST /stripe-webhook
X-Stripe-Signature: {signature}

{
  "type": "checkout.session.completed",
  "data": {
    "object": {
      "id": "cs_test_1234567890abcdef",
      "metadata": {
        "user_id": "user-123",
        "app_id": "default",
        "purchase_type": "coin_package"  // ⭐ 新增：标识金币包购买
      },
      "payment_intent": "pi_test_abcdef123456"
    }
  }
}
```

**后端处理流程**：
```
1. 验证webhook签名
2. 判断 purchase_type == 'coin_package'
3. 查询pending购买记录（用session_id）
4. 更新记录状态为completed
5. 设置transaction_id (payment_intent)
6. 调用 grant_user_credits 发放积分
7. 返回成功响应给Stripe
```

**防重复机制**：
- 唯一约束：`UNIQUE(platform, transaction_id)`
- 同一笔交易（同transaction_id）只能处理一次
- Webhook重复不会导致积分重复发放

---

### 第6步：最终确认（推荐）

**App再次查询状态确保完成**：

```bash
GET /check-coin-purchase-status?session_id=cs_test_1234567890abcdef
```

**响应**（最终确认）：
```json
{
  "success": true,
  "data": {
    "status": "completed",
    "purchase_coins": 302,
    "total_coins": 1804,              // 最新的总金币数
    "transaction_id": "pi_test_abcdef",
    "is_credited": true,
    "message": "支付成功，已发放302金币"
  }
}
```

**UI更新**：
- 显示"购买成功"提示
- 更新显示的金币余额（1804）
- 提示用户可以使用获得的金币

---

## 💡 关键概念

### purchase_coins vs total_coins

| 字段 | 说明 | 示例 |
|------|------|------|
| `purchase_coins` | 本次购买获得的金币 | 302 (275+27奖励) |
| `total_coins` | 用户当前的**总**金币余额 | 1804 (之前1502+本次302) |

**重要**：
- `purchase_coins` 用于显示"购买后获得多少金币"
- `total_coins` 用于显示"用户现在有多少金币"（最新余额）

### session_id vs transaction_id

| 字段 | 何时获得 | 用途 |
|------|---------|------|
| `session_id` | 调用stripe-create-checkout时 | App用来查询支付状态，防重复 |
| `transaction_id` | Stripe支付完成后 | 后端防重复处理，对账用 |

### 状态流转

```
pending ──[支付成功]──> completed
   │
   ├─[支付失败]──> failed
   │
   └─[已退款]──> refunded
```

---

## 🚀 实现建议

### 最小化实现

```typescript
// 1. 获取金币包列表
const packages = await fetch('/iap-coin-packages?platform=stripe')

// 2. 用户选择并购买
const { session_id, checkout_url } = await fetch('/stripe-create-checkout', {
  method: 'POST',
  body: {
    app_id: 'default',
    price_id: selectedPackage.platform_price_id,
    product_id: selectedPackage.product_id
  }
})

// 3. 打开支付页面
window.location.href = checkout_url

// 4. 返回后查询状态
const status = await fetch(`/check-coin-purchase-status?session_id=${session_id}`)
```

### 完整实现

```typescript
// 1. 获取金币包列表
const fetchCoinPackages = async () => {
  const res = await fetch('/iap-coin-packages?platform=stripe')
  return res.json().data
}

// 2. 创建支付
const createPayment = async (productId, priceId) => {
  const res = await fetch('/stripe-create-checkout', {
    method: 'POST',
    body: JSON.stringify({
      app_id: 'default',
      price_id: priceId,
      product_id: productId
    })
  })
  const { session_id, checkout_url, purchase_coins } = res.json().data
  return { session_id, checkout_url, purchase_coins }
}

// 3. 轮询查询状态
const pollPaymentStatus = async (sessionId) => {
  return new Promise((resolve) => {
    const interval = setInterval(async () => {
      const res = await fetch(`/check-coin-purchase-status?session_id=${sessionId}`)
      const { status, total_coins } = res.json().data

      if (status === 'completed') {
        clearInterval(interval)
        resolve({ success: true, total_coins })
      } else if (status === 'failed') {
        clearInterval(interval)
        resolve({ success: false })
      }
    }, 2000)
  })
}

// 4. 完整流程
const handlePurchase = async (package) => {
  // 创建支付
  const { session_id, checkout_url, purchase_coins } = await createPayment(
    package.product_id,
    package.platform_price_id
  )

  // 显示预期金币数
  showMessage(`购买后将获得 ${purchase_coins} 个金币`)

  // 打开支付页面
  window.location.href = checkout_url

  // 返回后轮询状态
  const result = await pollPaymentStatus(session_id)
  if (result.success) {
    updateCoinsBalance(result.total_coins)
    showSuccessMessage('购买成功！')
  } else {
    showErrorMessage('购买失败，请重试')
  }
}
```

---

## ⚠️ 注意事项

### 必读事项

1. **always获取最新的total_coins**
   - Webhook处理完成后total_coins会自动更新
   - 不要使用purchase_coins作为用户余额
   - 每次更新UI时重新调用查询接口获取最新值

2. **支持多平台支付**
   - Stripe：使用 `/stripe-create-checkout`
   - Apple/Google：需要App端调用原生支付APIs后验证
   - 详见后续的Apple/Google集成指南

3. **错误处理**
   - 网络错误时提示用户重试
   - 支付超时（>1分钟pending）提示用户检查网络
   - Failed状态时允许用户重新购买

4. **防重复保证**
   - 由服务器保证，不需要App端处理
   - 同一transaction_id只会处理一次
   - 可安心多次调用查询接口

### 常见问题

**Q: 为什么purchase_coins和total_coins不同？**
```
A: purchase_coins是本次购买获得的金币
   total_coins是用户现在拥有的全部金币
   例：之前有1200枚 + 本次购买302枚 = 1502枚
```

**Q: 支付页面关闭后如何继续？**
```
A: 使用保存的session_id查询状态即可
   调用check-coin-purchase-status获取最新状态
   无需担心支付中途关闭app的情况
```

**Q: 能否重复购买同一金币包？**
```
A: 可以！没有购买次数限制
   每次购买都会生成新的session_id和transaction_id
   防重复只防止同一笔交易重复处理，不防止重复购买
```

---

## 📞 集成支持

### Stripe集成检查清单

- [ ] 已配置Stripe Secret Key和Publishable Key
- [ ] 已创建金币包对应的Stripe Product和Price
- [ ] 已配置Webhook Endpoint（/stripe-webhook）
- [ ] 已在后台管理系统配置金币包（iap_coin_packages表）
- [ ] 已联系技术团队获取platform_price_id

### Apple内购集成（后续）

- [ ] 已创建App内购ID
- [ ] 已配置Apple Shared Secret
- [ ] 已在后台管理系统配置Apple金币包
- [ ] 已实现/subscription-verify接口调用

### Google Play计费集成（后续）

- [ ] 已配置Google Play Console
- [ ] 已创建In-App Product
- [ ] 已获取Play Billing credentials
- [ ] 已在后台管理系统配置Google金币包

---

**最后更新**：2026-01-17
