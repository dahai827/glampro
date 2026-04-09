# iOS App ↔ Web 支付页 集成方案

## 一、背景与目标

- **场景**：iOS App 内点击支付 → 跳转到 ThirdPayH5 网页 → 用户完成 Stripe 订阅/金币购买 → 返回 App 首页
- **目标**：完成 App 与网页之间的用户信息传递、三方支付流程、支付完成后回到 App

---

## 二、整体架构

```
┌─────────────────┐    ① 打开 URL      ┌──────────────────────┐    ② 调用 API     ┌─────────────┐
│   iOS App       │ ─────────────────► │  ThirdPayH5 网页     │ ◄───────────────► │  后端 API   │
│                 │  payment_url 打开   │  (支付选择页)         │   access_token   │  Supabase   │
└────────┬────────┘                    └──────────┬───────────┘                    └──────┬──────┘
         │                                        │                                       │
         │                                        │ ③ 跳转 Stripe Checkout                │
         │                                        ▼                                       │
         │                               ┌──────────────────────┐                         │
         │                               │  Stripe 支付页       │                         │
         │                               │  (第三方)             │                         │
         │                               └──────────┬───────────┘                         │
         │                                        │                                       │
         │                                        │ ④ 支付完成，Stripe 重定向到 success_url │
         │                                        ▼                                       │
         │                               ┌──────────────────────┐                         │
         │                               │  /success 成功页     │                         │
         │                               │  轮询购买状态        │                         │
         │                               └──────────┬───────────┘                         │
         │                                        │                                       │
         │    ⑤ 通过 Deep Link 回到 App           │ 调用 /check-coin-purchase-status      │
         ◄────────────────────────────────────────┘ 或 /user-status                     │
                                                                                          │
                                                                                          ▼
                                                                                  Webhook 更新状态
```

---

## 三、用户信息传递：App → 网页

### 3.1 传递方式（推荐：短 Token 方案）

为避免长 JWT 放在 URL 导致截断或泄露，后端提供 **短 Token 交换** 机制：

| 参数 | 说明 | 示例 |
|------|------|------|
| `pt` | 支付页短 token（约 32 字符） | `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6` |
| `userId` | 用户 ID（用于顶部展示） | `USER4319472442` |
| `source` | 来源标识（可选，用于 success 页判断是否回 App） | `ios` |
| `returnScheme` | 回 App 的 URL Scheme | `myapp` |

**流程**：
1. App 调用 `POST /create-payment-token`（携带 access_token，可选 Body：`app_id`、`source`、`return_scheme`、`type`）
2. 接口返回 `payment_url`（完整 URL，可直接打开）或 `payment_token` + `user_id`（需自行拼接）；当 `type=subscription` 时，`payment_url` 会拼接 `type=subscription` 参数
3. 打开支付页 URL
4. Web 页加载后调用 `GET /get-token-by-payment-token?pt={payment_token}` → 获得 `access_token`
5. 用 access_token 调用 `/stripe-create-checkout`、`/user-status` 等接口

**接口响应**（需在 payment-urls-config 中配置 `payment_page_base` 才会返回 `payment_url`）：
- 内购金币（不传 type 或 type 非 subscription）：
```json
{
  "payment_url": "https://your-domain.com/payment?pt=xxx&userId=uuid&source=ios&returnScheme=myapp",
  "payment_token": "a1b2c3d4...",
  "user_id": "550e8400-...",
  "expires_in": 900
}
```
- 订阅支付（传 `type: "subscription"`）：
```json
{
  "payment_url": "https://your-domain.com/payment?pt=xxx&userId=uuid&source=ios&returnScheme=myapp&type=subscription",
  "payment_token": "a1b2c3d4...",
  "user_id": "550e8400-...",
  "expires_in": 900
}
```

### 3.2 URL 格式

**内购金币**：
```
https://your-thirdpay-domain.com/payment?pt={payment_token}&userId={user_id}&source=ios&returnScheme=myapp
```

**订阅支付**（需追加 `type=subscription`）：
```
https://your-thirdpay-domain.com/payment?pt={payment_token}&userId={user_id}&source=ios&returnScheme=myapp&type=subscription
```

**安全说明**：
- 短 token 仅 32 字符，不会导致 URL 截断
- 短 token 有效期 15 分钟，一次性使用（兑换后立即失效）
- 仅持有有效 access_token 的 App 可创建短 token，避免 user_id 直接换 token 的安全风险

### 3.3 iOS 端构造并打开 URL

**方式 A：直接使用 payment_url（推荐）**

```swift
func openPaymentWebPage() async {
    guard let token = SessionManager.shared.accessToken else { return }
    
    let paymentURL = try await fetchPaymentURL(accessToken: token)
    
    let session = ASWebAuthenticationSession(
        url: paymentURL,
        callbackURLScheme: "myapp"
    ) { callbackURL, _ in
        if let url = callbackURL { self.handlePaymentReturn(url: url) }
    }
    session.presentationContextProvider = self
    session.start()
}

func fetchPaymentURL(accessToken: String, isSubscription: Bool = false) async throws -> URL {
    let url = URL(string: "https://xxx.supabase.co/functions/v1/create-payment-token")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    var body: [String: Any] = ["app_id": "default", "source": "ios", "return_scheme": "myapp"]
    if isSubscription { body["type"] = "subscription" }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    if let paymentURLString = json["payment_url"] as? String, let u = URL(string: paymentURLString) {
        return u
    }
    // 未配置 payment_page_base 时，自行拼接
    let pt = json["payment_token"] as! String
    let userId = json["user_id"] as! String
    var c = URLComponents(string: "https://your-domain.com/payment")!
    var items = [
        URLQueryItem(name: "pt", value: pt),
        URLQueryItem(name: "userId", value: userId),
        URLQueryItem(name: "source", value: "ios"),
        URLQueryItem(name: "returnScheme", value: "myapp")
    ]
    if isSubscription { items.append(URLQueryItem(name: "type", value: "subscription")) }
    c.queryItems = items
    return c.url!
}
```

若接口未返回 `payment_url`（未配置 payment_page_base），可用 `payment_token` 和 `user_id` 自行拼接 URL。

**create-payment-token 请求体（可选）**：

| 参数 | 说明 |
|------|------|
| app_id | 应用 ID，默认 "default"，用于选择 payment_page_base 配置 |
| source | 来源标识，如 "ios"，会拼入 URL |
| return_scheme | 回 App 的 URL Scheme，如 "myapp"，会拼入 URL |
| type | 支付类型：`"subscription"` 表示订阅支付；不传或传其他值表示内购金币。当为 `subscription` 时，返回的 `payment_url` 会拼接 `type=subscription` 参数 |

---

## 四、三方支付流程（Stripe）

### 4.1 两种购买类型

| 类型 | 接口参数 | success 后处理 |
|------|----------|----------------|
| **订阅** | 不传 `product_id`，只传 `price_id` | 调用 `/user-status` 获取订阅状态 |
| **金币包** | 传 `product_id` + `price_id` | 轮询 `/check-coin-purchase-status` |

### 4.2 网页端支付流程

#### 步骤 1：获取金币包列表（金币购买时）

```
GET /iap-coin-packages?app_id=default&platform=stripe
Headers: apikey: {SUPABASE_ANON_KEY}
```

无需 token，公开接口。

#### 步骤 2：创建 Checkout Session

```
POST /stripe-create-checkout
Headers:
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  Content-Type: application/json

Body（订阅）:
{
  "app_id": "default",
  "price_id": "price_xxxxx",
  "success_url": "https://your-domain.com/success?session_id={CHECKOUT_SESSION_ID}&source=ios&returnScheme=myapp&type=subscription",
  "cancel_url": "https://your-domain.com/cancel?source=ios&returnScheme=myapp&type=subscription"
}

Body（金币包）:
{
  "app_id": "default",
  "price_id": "price_xxxxx",
  "product_id": "coins_275",
  "success_url": "https://your-domain.com/success?session_id={CHECKOUT_SESSION_ID}&source=ios&returnScheme=myapp",
  "cancel_url": "https://your-domain.com/cancel?source=ios&returnScheme=myapp"
}
```

**注意**：`success_url` 中的 `{CHECKOUT_SESSION_ID}` 是 Stripe 占位符，Stripe 会自动替换为真实的 `session_id`。

**订阅与金币包区别**：订阅场景的 `success_url` 和 `cancel_url` 需额外拼接 `&type=subscription`，以便 success 页识别为订阅支付、轮询 `/user-status` 而非 `/check-coin-purchase-status`；金币包不传 `type`。

#### 步骤 3：跳转 Stripe 支付页

```javascript
const { data } = await response.json();
window.location.href = data.checkout_url;
```

用户完成支付后，Stripe 会重定向到 `success_url`。

---

## 五、支付完成后回到 App

### 5.1 success 页逻辑

success 页 URL 示例（Stripe 重定向后）：
```
https://your-domain.com/success?session_id=cs_xxx&source=ios&returnScheme=myapp
```

**success 页需要**：
1. 从 URL 读取 `session_id`、`source`、`returnScheme`
2. 从进入支付页时的存储中读取 `token`（可用 sessionStorage 在支付页存一份）
3. **金币购买**：轮询 `/check-coin-purchase-status?session_id=xxx`，直到 `status === 'completed'`
4. **订阅**：可选轮询 `/user-status` 确认订阅激活，或直接认为成功（Stripe Webhook 会处理）
5. 若 `source === 'ios'` 且 `returnScheme` 存在，则跳转回 App：

```javascript
// 回 App 的 Deep Link
window.location.href = `${returnScheme}://payment-success?status=completed&session_id=${session_id}`;
```

### 5.2 cancel 页逻辑

用户取消支付时，Stripe 重定向到 `cancel_url`。cancel 页同样可跳回 App：

```javascript
window.location.href = `${returnScheme}://payment-cancel`;
```

### 5.3 iOS 配置 Deep Link（URL Scheme）

在 Xcode 中：
1. 选中 Target → Info → URL Types
2. 添加 URL Scheme，如 `myapp`
3. 这样 `myapp://payment-success?status=completed` 会唤起你的 App

**AppDelegate / SceneDelegate 处理**：

```swift
// 使用 SwiftUI 时，可用 .onOpenURL
.onOpenURL { url in
    if url.scheme == "myapp" && url.host == "payment-success" {
        // 支付成功，刷新用户状态并回到首页
        Task {
            await SessionManager.shared.fetchAndSaveUserStatus()
        }
        coordinator.popToRoot()  // 或你的回到首页逻辑
    } else if url.host == "payment-cancel" {
        // 用户取消，直接关闭 WebView
    }
}
```

### 5.4 token 在 success 页的获取

支付页跳转到 Stripe 后，success 页是新的页面加载，**无法直接拿到支付页的 URL 参数**。

**方案 A：sessionStorage（推荐）**

在支付页点击「去支付」前，把 access_token 存到 sessionStorage：

```javascript
// 支付页（获取 token 后，调用 /get-token-by-payment-token 得到 access_token）
sessionStorage.setItem('payment_token', accessToken);  // 存 access_token
sessionStorage.setItem('payment_return_scheme', returnScheme);
sessionStorage.setItem('payment_source', source);
window.location.href = data.checkout_url;
```

success 页从 sessionStorage 读取：

```javascript
const token = sessionStorage.getItem('payment_token');
const returnScheme = sessionStorage.getItem('payment_return_scheme');
const source = sessionStorage.getItem('payment_source');
```

**方案 B：success_url 带 token**

不推荐：token 会出现在 Stripe 重定向的 URL 中，增加泄露风险。

---

## 六、网页端需要新增/修改的内容

### 6.1 路由

| 路径 | 说明 |
|------|------|
| `/payment` | 支付选择页（现有 PaymentPage），需从 URL 读取 pt、userId |
| `/success` | 支付成功页，轮询状态 + 回 App |
| `/cancel` | 支付取消页，回 App 或提示 |

### 6.2 支付页改造要点

1. 使用 `useSearchParams()` 或 `window.location.search` 读取 `pt`、`userId`、`source`、`returnScheme`
2. **首次加载**：调用 `GET /get-token-by-payment-token?pt={pt}` 获取 `access_token`
3. 顶部展示 `userId`
4. 金币包数据从 `/iap-coin-packages` 获取
5. 用户余额从 `/user-status` 获取（需 access_token）
6. 点击 Stripe 支付时：
   - 调用 `/stripe-create-checkout`（带 access_token）
   - 将 access_token、returnScheme、source 存入 sessionStorage
   - 跳转 `checkout_url`

### 6.3 success 页实现要点

```javascript
// 伪代码
const params = new URLSearchParams(location.search);
const sessionId = params.get('session_id');
const source = params.get('source');
const returnScheme = params.get('returnScheme');

const token = sessionStorage.getItem('payment_token');

// 金币购买：轮询
const pollStatus = async () => {
  const res = await fetch(
    `${API_BASE}/check-coin-purchase-status?session_id=${sessionId}`,
    { headers: { Authorization: `Bearer ${token}`, apikey } }
  );
  const { data } = await res.json();
  if (data.status === 'completed') {
    if (source === 'ios' && returnScheme) {
      window.location.href = `${returnScheme}://payment-success?status=completed`;
    } else {
      // 非 App，显示成功页
    }
  } else if (data.status === 'failed') {
    // 显示失败
  } else {
    setTimeout(pollStatus, 2000);
  }
};
pollStatus();
```

---

## 七、Stripe 沙盒测试准备清单

### 7.1 订阅（年订 / 周订）

| 准备项 | 说明 |
|--------|------|
| Stripe Product | Dashboard → Products → 创建 **Subscription** 类型产品 |
| 年订 Price | 为该产品添加 **Yearly** 价格，复制 Price ID（如 `price_xxxxx`） |
| 周订 Price | 为该产品添加 **Weekly** 价格，复制 Price ID |
| ThirdPayH5 配置 | 在 `.env` 中配置：`VITE_STRIPE_PRICE_YEARLY`、`VITE_STRIPE_PRICE_WEEKLY` |

### 7.2 金币购买（内购）

| 准备项 | 说明 |
|--------|------|
| Stripe Product | 为每个金币包创建 **One-time** 类型产品（非 Subscription） |
| Stripe Price | 为每个产品添加一次性价格，复制 Price ID |
| 后端 `iap_coin_packages` | 在表中配置每条记录，**必须**包含： |

**iap_coin_packages 表字段示例**：

| 字段 | 说明 | 示例 |
|------|------|------|
| product_id | 业务标识，与 Stripe 产品对应 | `coins_700`、`coins_1000` |
| platform_price_id | **Stripe Price ID**（必需） | `price_1xxxxx` |
| platform | `stripe` | |
| app_id | 应用 ID | `default` |
| base_coins | 基础金币数 | 700 |
| bonus_percentage | 奖励百分比 | 10 |
| 自动计算 | bonus_coins、total_coins | 70、770 |
| amount | 价格（美元） | 6.99 |
| currency | `usd` | |
| display_name | 展示名称 | `700 coins` |
| sort_order | 排序 | 1 |
| is_active | `true` | |

**金币包数量**：按你实际需要的档位创建（如 700、1000、2500、4000、7000、10000 等）。

**Stripe 操作步骤**：

1. Dashboard → Products → Add product
2. 选择 **One-time**（一次性），非 Recurring
3. 设置产品名称（如 "700 Coins"）和价格
4. 保存后复制 Price ID（如 `price_1ABC123...`）
5. 将该 Price ID 填入后端 `iap_coin_packages` 的 `platform_price_id`

### 7.3 其他准备

- Stripe 测试卡号：`4242 4242 4242 4242`
- 后端 Webhook：配置 `checkout.session.completed` 等事件，用于支付完成后发放积分/更新订阅

---

## 八、检查清单

### iOS App

- [ ] 配置 URL Scheme（如 `myapp`）
- [ ] 调用 `POST /create-payment-token`（Body 传 `app_id`、`source`、`return_scheme`；订阅时传 `type: "subscription"`）
- [ ] 优先使用返回的 `payment_url` 打开，未返回时用 `payment_token` + `user_id` 自行拼接
- [ ] 使用 `ASWebAuthenticationSession` 或 `SFSafariViewController` 打开支付页
- [ ] 处理 `myapp://payment-success` 和 `myapp://payment-cancel`
- [ ] 支付成功后调用 `fetchAndSaveUserStatus()` 刷新状态

### ThirdPayH5 网页

- [ ] 支付页从 URL 读取 token、userId 等
- [ ] 对接 `/iap-coin-packages`、`/user-status`、`/stripe-create-checkout`
- [ ] 跳转 Stripe 前将 token 等存入 sessionStorage
- [ ] 新增 `/success` 页：轮询 `/check-coin-purchase-status`，完成后根据 source 回 App
- [ ] 新增 `/cancel` 页：根据 source 回 App 或展示取消提示
- [ ] `stripe-create-checkout` 的 `success_url`、`cancel_url` 指向你的域名

### 后端

- [ ] 在 `payment-urls-config.ts` 或 env 中配置 `payment_page_base`（支付页部署地址），否则 create-payment-token 不返回 payment_url
- [ ] 确认 `success_url`、`cancel_url` 的域名在白名单/允许列表
- [ ] Stripe Webhook 已配置，能正确处理支付完成

---

## 九、数据流小结

| 阶段 | App | 网页 | 后端 |
|------|-----|------|------|
| 打开支付 | 调用 create-payment-token，用 payment_url 或拼接 URL 打开 | 读取 pt、userId，兑换 access_token | 返回 payment_url / payment_token |
| 选择商品 | - | 调用 /iap-coin-packages | 返回金币包列表 |
| 创建支付 | - | 调用 /stripe-create-checkout | 返回 checkout_url |
| 支付 | - | 跳转 Stripe | - |
| 支付完成 | - | Stripe 重定向到 success | Webhook 更新状态 |
| 确认状态 | - | 轮询 /check-coin-purchase-status | 返回 completed |
| 回 App | 接收 Deep Link，刷新状态 | 跳转 myapp://payment-success | - |

---

## 十、安全与注意

1. **Token**：仅通过 HTTPS 传递，避免在日志中打印
2. **URL Scheme**：使用不易冲突的 scheme（如 `yourappname`）
3. **Universal Links**：若希望用 `https://your-domain.com/success` 直接打开 App，可配置 Universal Links，与 URL Scheme 二选一或并存
4. **审核**：确保支付流程符合 App Store 规范，使用官方支付方式（Stripe 等）通常无问题
