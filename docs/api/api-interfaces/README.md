# 📱 App API 接口文档导航

**API 基础 URL**：`https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1`

> 📖 本文档是 API 接口文档的导航索引。所有接口文档已按功能分类拆分为独立文件，方便查阅和维护。

## 📋 文档版本历史

| 版本号 | 更新时间 | 更新内容 |
|--------|----------|----------|
| v2.30 | 2026-04-14 | 📝 新增视频上传文档：`/upload-video`（返回 `video_url`、`video_duration_seconds`）；补充 `image_to_dongzuo_video` 完整调用链：先传图、再传视频（建议 App 先压缩至 480p）、再创建任务并轮询 |
| v2.29 | 2026-04-14 | 🆕 新增每日签到接口：`/daily-checkin-status`（查询签到面板状态）和 `/daily-checkin-sign`（执行签到发放积分），支持 7 天循环、断签重置、按 app 配置每日积分 |
| v2.28 | 2026-04-14 | 🆕 新增动作模仿图生视频接口：`/image-to-dongzuo-video`，对接火山引擎 DreamActor M2.0，返回异步任务并通过 `/get-task` 轮询 |
| v2.27 | 2026-03-19 | 🆕 新增 PayPal 支付接口：`/paypal-create-subscription`、`/paypal-activate-subscription` 订阅流程；`/paypal-create-order`、`/paypal-capture-order` 金币包流程；`subscription-products`、`iap-coin-packages` 支持 platform=paypal |
| v2.26 | 2026-03-05 | 🆕 新增订阅产品列表接口文档：`/subscription-products` 获取 Stripe/Apple/Google 订阅配置，支持按 app_id、platform 筛选 |
| v2.25 | 2026-03-03 | 📝 `create-payment-token` 新增：直接返回 `payment_url`，支持请求体 `app_id`、`source`、`return_scheme`，便于灵活扩展 |
| v2.24 | 2026-03-03 | 🆕 Web 支付页短 Token：`/create-payment-token`、`/get-token-by-payment-token`，用于 iOS App 跳转 H5 支付时避免长 JWT 放 URL 导致截断 |
| v2.23 | 2026-03-02 | 📝 `21-attribution-bind.md` 文档精简：移除 click_id 参数描述，统一使用 install_token 方式 |
| v2.22 | 2026-03-02 | 🆕 `/attribution-bind` 新增设备指纹支持：`fingerprint_v1`、`fingerprint_sig_v1` 可选参数，用于 click_id 方式下写入归因记录；兼容生产环境，不传则行为不变 |
| v2.21 | 2026-03-02 | 🆕 `/attribution-click` 新增设备指纹支持：`fingerprint_v1`、`fingerprint_sig_v1` 可选参数，用于 IP+时间窗口+指纹联合匹配；新增 [设备指纹参数规范](./30-device-fingerprint-fields-spec.md) |
| v2.20 | 2026-03-02 | 🆕 新增归因点击记录接口文档：`/attribution-click` 用于 W2A 推广投放落地页记录广告点击、生成 install_token；支持 google_ads、meta、tiktok 三种广告来源 |
| v2.19 | 2026-02-26 | 🆕 `get-feature-configs` 的 `menu` 参数新增 `grid` 类型：用于**功能卡片**场景，返回一个 section、最多 5 个 item；卡片展示用 `item.icon_url`/`item.title`，二级页按 `item.material_requirements` 展示 UI 素材 |
| v2.18 | 2026-02-18 | 🆕 新增图片理解接口：`/image-understanding` 支持 AI 视觉分析，同步返回结构化 JSON 结果；适用于情绪识别、内容分析等场景；新增完整的接口文档（28-image-understanding.md） |
| v2.17 | 2026-01-26 | 🆕 拆分 AI 生成接口文档：将 `NEW_AI_INTERFACES_GUIDE.md` 中的5个AI接口拆分为独立文档；新增文生图（23-text-to-image.md）、图生图（24-image-to-image.md）、文生视频（25-text-to-video.md）、图生视频（26-image-to-video.md）、视频换脸（27-video-face-swap.md）接口文档 |
| v2.16 | 2026-01-24 | 🆕 新增苹果内购验证统一接口：`/apple-iap-verify` 统一处理订阅和金币包的验证；整合了 JWS 签名校验、产品识别、自动发放以及归因上报逻辑；新增完整的接口文档（22-apple-iap-verify.md） |
| v2.15 | 2026-01-23 | 🆕 新增归因追踪接口：`/attribution-bind` 归因绑定接口，支持通过 `install_token` 或 `click_id` 绑定广告点击信息到用户账号；`user_id` 从 JWT token 中自动获取，无需在请求体中传递；新增完整的接口文档（21-attribution-bind.md） |
| v2.14 | 2026-01-17 | 🆕 新增内购金币包系统：`/iap-coin-packages` 获取金币包列表、`/check-coin-purchase-status` 查询支付状态；`/stripe-create-checkout` 支持 `product_id` 参数用于识别金币包购买；新增完整的接口文档（stripe-create-checkout.md、iap-coin-packages.md、check-coin-purchase-status.md）和金币包购买流程指南 |
| v2.13 | 2026-01-07 | `/get-feature-configs` 和 `/get-item-configs` 接口新增封面图换头像的图标字段：`cover_required`（true则需要展示）、`cover_images`（展示图片的列表） |
| v2.12 | 2026-01-07 |  `/anonymous-login` 接口新增country/channel/platform参数支持 |
| v2.11 | 2026-01-06 | 新增活动事件上报接口 `/report-activity-event`（支持14种事件类型）；`/submit-feedback` 接口新增 `complaint_type` 和 `task_id` 参数支持 |
| v2.10 | 2026-01-01 | `/get-feature-configs` 和 `/get-item-configs` 接口新增广告相关字段：`is_ad`（是否广告）、`ad_apk_url`（广告APK下载地址）、`ad_ios_url`（广告iOS下载地址） |
| v2.9 | 2025-12-31 | 新增 IP 归属地检查接口 `/check-ip-location`（公开接口，用于检查客户端 IP 归属地并限制特定地区访问） |
| v2.8 | 2025-12-30 | `/get-feature-configs` 接口新增 cover_video_thumbnail字段(封面视频缩略图) |
| v2.7 | 2025-12-30 | 新增获取应用审核版本号接口 `/get-app-newversion`（公开接口，用于客户端检查应用版本） |
| v2.6 | 2025-12-17 | `/get-feature-configs` 接口新增 `page_type` 参数支持（default/ad） |
| v2.2 | 2025-01-20 | `/anonymous-login` 接口新增设备标识符参数支持（idfa/idfv/adid/gps_adid） |
| v2.1 | 2025-01-20 | 新增多应用支持，`/review-login` 和 `/anonymous-login` 支持 `app_id` 参数 |
| v2.0 | 2025-11-17 | 新增 `/review-login` 审核测试账号登录接口，订阅验证优化 |

---

## 🔑 认证说明

在开始使用接口之前，请先阅读认证说明：

👉 **[认证说明文档](./00-authentication.md)**

👉 **[W2A 支付业务流程测试指南](../W2A-Payment-Testing-Guide.md)** - H5 生成 install_token → App 获取支付页 URL → ThirdPayH5 完成订阅/金币购买（含 portraai、PayPal 接入说明）

---

## 📚 接口分类

### 🔐 认证相关接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 匿名登录 | `/anonymous-login` | POST | ❌ | [查看文档](./01-anonymous-login.md) |
| 刷新 Session | `/auth/v1/token` | POST | ❌ | [查看文档](./02-refresh-session.md) |
| 审核测试登录 | `/review-login` | POST | ❌ | [查看文档](./08-review-login.md) |

### 📤 任务相关接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 上传图片 | `/upload-image` | POST | ✅ | [查看文档](./03-upload-image.md) |
| 上传视频 | `/upload-video` | POST | ✅ | [查看文档](./12-upload-video.md) |
| 查询任务 | `/get-task` | GET | ✅ | [查看文档](./04-get-task.md) |
| 任务列表 | `/list-tasks` | GET | ✅ | [查看文档](./05-list-tasks.md) |

### 💳 支付相关接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 订阅产品列表 | `/subscription-products` | GET | ❌ | [查看文档](./33-subscription-products.md) |
| 订阅验证 | `/subscription-verify` | POST | ✅ | [查看文档](./06-subscription-verify.md) |
| 苹果内购统一验证 | `/apple-iap-verify` | POST | ✅ | [查看文档](./22-apple-iap-verify.md) |
| 用户状态 | `/user-status` | GET | ✅ | [查看文档](./07-user-status.md) |
| 创建支付会话 | `/stripe-create-checkout` | POST | ✅ | [查看文档](./19-stripe-create-checkout.md) |

### 💳 PayPal 支付接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 创建 PayPal 订阅 | `/paypal-create-subscription` | POST | ✅ | [查看文档](./34-paypal-create-subscription.md) |
| 激活 PayPal 订阅 | `/paypal-activate-subscription` | POST | ✅ | [查看文档](./35-paypal-activate-subscription.md) |
| 创建 PayPal 订单（金币包） | `/paypal-create-order` | POST | ✅ | [查看文档](./36-paypal-create-order.md) |
| 捕获 PayPal 订单（金币包） | `/paypal-capture-order` | POST | ✅ | [查看文档](./37-paypal-capture-order.md) |

### 💰 内购金币包接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 获取金币包列表 | `/iap-coin-packages` | GET | ❌ | [查看文档](./16-iap-coin-packages.md) |
| 查询支付状态 | `/check-coin-purchase-status` | GET | ✅ | [查看文档](./17-check-coin-purchase-status.md) |

### 🌐 Web 支付页 Token（iOS App 跳转 H5 支付）

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 创建支付页短 Token | `/create-payment-token` | POST | ✅ | [查看文档](./31-create-payment-token.md) |
| 通过短 Token 换取 access_token | `/get-token-by-payment-token` | GET | ❌ | [查看文档](./32-get-token-by-payment-token.md) |

### ⚙️ 配置相关接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 首页列表 | `/get-feature-configs` | GET | ❌ | [查看文档](./09-get-feature-configs.md) |
| 功能分类列表 | `/get-sections-configs` | GET | ❌ | [查看文档](./10-get-sections-configs.md) |
| 指定分类功能列表 | `/get-item-configs` | GET | ❌ | [查看文档](./11-get-item-configs.md) |
| 应用审核版本号 | `/get-app-newversion` | GET | ❌ | [查看文档](./13-get-app-newversion.md) |

### 🎨 AI 生成相关接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 文生图 | `/text-to-image` | POST | ✅ | [查看文档](./23-text-to-image.md) |
| 图生图 | `/image-to-image` | POST | ✅ | [查看文档](./24-image-to-image.md) |
| 文生视频 | `/text-to-video` | POST | ✅ | [查看文档](./25-text-to-video.md) |
| 图生视频 | `/image-to-video` | POST | ✅ | [查看文档](./26-image-to-video.md) |
| 动作模仿图生视频 | `/image-to-dongzuo-video` | POST | ✅ | [查看文档](./38-image-to-dongzuo-video.md) |
| 视频换脸 | `/video-face-swap` | POST | ✅ | [查看文档](./27-video-face-swap.md) |
| 图片理解 | `/image-understanding` | POST | ✅ | [查看文档](./28-image-understanding.md) |

### 📊 归因追踪接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 归因点击记录 | `/attribution-click` | POST | ❌ | [查看文档](./21-attribution-click.md) |
| 归因绑定 | `/attribution-bind` | POST | ✅ | [查看文档](./21-attribution-bind.md) |

### 📐 归因相关规范

| 文档 | 说明 |
|------|------|
| 设备指纹参数规范 | [查看文档](./30-device-fingerprint-fields-spec.md) - fingerprint_v1 字段定义、采集方式与签名规则 |

### 📝 其他接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 提交用户反馈 | `/submit-feedback` | POST | ❌ | [查看文档](./14-submit-feedback.md) |
| 上报活动事件 | `/report-activity-event` | POST | ✅ | [查看文档](./15-report-activity-event.md) |

### 🎁 每日签到接口

| 接口 | 路径 | 方法 | 需要 Token | 文档 |
|------|------|------|-----------|------|
| 每日签到状态 | `/daily-checkin-status` | GET | ✅ | [查看文档](./39-daily-checkin-status.md) |
| 每日签到执行 | `/daily-checkin-sign` | POST | ✅ | [查看文档](./40-daily-checkin-sign.md) |

### 📖 开发指南

| 文档 | 说明 |
|------|------|
| 用户认证与状态管理流程 | [查看文档](./16-user-auth-subscription-flow.md) |
| 内购金币包购买流程 | [查看文档](./18-coin-package-purchase-flow.md) |

---

## 🚀 快速开始

### 1. 阅读认证说明

首先阅读 [认证说明文档](./00-authentication.md)，了解：
- API 基础 URL
- Header 配置规则
- Token 管理机制
- 多应用支持（app_id）

### 2. 用户认证流程

1. **首次启动**：调用 [匿名登录接口](./01-anonymous-login.md) 获取 `access_token` 和 `refresh_token`
2. **Token 过期**：使用 [刷新 Session 接口](./02-refresh-session.md) 刷新 token
3. **保存 Token**：将 token 保存到本地存储，后续请求使用

### 3. 常用业务流程

#### 用户认证与状态管理流程 ⭐
```
1. App 启动 → 检查本地 token
   ├─> 有有效 token → 调用 [用户状态接口](./07-user-status.md) 更新状态
   └─> 无 token → [匿名登录](./01-anonymous-login.md) → 调用 [用户状态接口](./07-user-status.md)
2. 积分实时更新 → AI 任务完成后自动更新
3. UI 响应式显示 → 使用 SessionManager.creditsBalance
```
👉 **详细流程说明**: [用户认证与状态管理流程文档](./16-user-auth-subscription-flow.md)

#### 每日签到流程 ⭐
```
1. App 启动/进入首页 → 调用 [每日签到状态接口](./39-daily-checkin-status.md)
2. 若 signed_today = false → 展示可领取按钮和 claimable_credits
3. 用户点击领取 → 调用 [每日签到执行接口](./40-daily-checkin-sign.md)
4. 更新 UI 积分余额与签到天数（day_no / next_claimable_day）
```

#### 创建任务流程
```
1. 上传图片 → [上传图片接口](./03-upload-image.md)
2. 创建任务 → 使用功能配置中的接口（如自定义图生图、图生视频等）
3. 查询状态 → [查询任务接口](./04-get-task.md)（轮询）
4. 查看历史 → [任务列表接口](./05-list-tasks.md)
```

#### 订阅流程
```
# Stripe 订阅
1. 获取订阅产品列表 → [订阅产品接口](./33-subscription-products.md)
2. 创建支付会话 → [创建支付会话接口](./19-stripe-create-checkout.md)（不传product_id）
3. 验证订阅 → [订阅验证接口](./06-subscription-verify.md)
4. 查询状态 → [用户状态接口](./07-user-status.md)

# PayPal 订阅
1. 获取订阅产品列表 → [订阅产品接口](./33-subscription-products.md)?platform=paypal
2. 创建订阅 → [创建 PayPal 订阅](./34-paypal-create-subscription.md)
3. 打开 approval_url，用户在 PayPal 完成审批
4. 激活订阅 → [激活 PayPal 订阅](./35-paypal-activate-subscription.md)
5. 查询状态 → [用户状态接口](./07-user-status.md)
```

#### 获取功能配置
```
1. 获取分类列表 → [功能分类列表接口](./10-get-sections-configs.md)
2. 获取功能列表 → [功能配置列表接口](./09-get-feature-configs.md) 或 [指定分类功能列表接口](./11-get-item-configs.md)
3. 根据配置调用对应的生成接口
```

#### 功能卡片⭐
```
1. 获取功能卡片配置 → GET [功能配置列表](./09-get-feature-configs.md)?menu=grid
   → 返回一个 section，内含最多 5 个 item
2. 首页展示功能卡片 → 每个卡片：图标 = item.icon_url，标题 = item.title
3. 用户点击某卡片 → 进入该功能的二级页（创作页）
4. 二级页展示素材 UI → 根据当前 item.material_requirements 配置渲染：
   - 单图/多图上传、文本输入、数字、选择器等
   - 用 label/description/required 做表单项说明与校验
5. 用户填写并提交 → 根据 item 的 model_type 等调用对应生成接口（文生图/图生图等）
```
👉 **详细字段与规范**：[09-get-feature-configs.md - 功能卡片（grid）使用规范](./09-get-feature-configs.md#功能卡片grid使用规范)

#### AI 生成流程 ⭐ 新增
```
1. 获取功能配置 → [功能配置列表接口](./09-get-feature-configs.md)（获取 item_id 和 model_type）
2. 根据 model_type 选择对应接口：
   - text_to_image → [文生图接口](./23-text-to-image.md)
   - image_to_image → [图生图接口](./24-image-to-image.md)
   - text_to_video → [文生视频接口](./25-text-to-video.md)
   - image_to_video → [图生视频接口](./26-image-to-video.md)
   - image_to_dongzuo_video（动作模仿）→ [动作模仿图生视频接口](./38-image-to-dongzuo-video.md)
   - video_face_swap → [视频换脸接口](./27-video-face-swap.md)
   - image_understanding → [图片理解接口](./28-image-understanding.md)
3. 上传素材（按模型要求）：
   - 图片素材 → [上传图片接口](./03-upload-image.md)
   - 视频素材（如动作模仿）→ [上传视频接口](./12-upload-video.md)
4. 调用生成接口 → 同步返回图片URL/分析结果 或 异步返回任务ID
5. 轮询结果（视频接口）→ [查询任务接口](./04-get-task.md)
```
👉 **详细使用指南**: [图片和视频生成接口指南](./NEW_AI_INTERFACES_GUIDE.md)

#### 动作模仿图生视频（image_to_dongzuo_video）完整调用链 ⭐
```
1. 上传图片 → [上传图片接口](./03-upload-image.md)
   - App 侧先等比缩放（宽高建议不超过 1024）并压缩体积
2. 上传驱动视频 → [上传视频接口](./12-upload-video.md)
   - App 侧先将视频压缩/转码为 480p 再上传
   - 建议在 App 提示用户：视频时长不要超过 30 秒
   - 上传接口返回 video_url、video_duration_seconds
3. 创建动作模仿任务 → [动作模仿图生视频接口](./38-image-to-dongzuo-video.md)
4. 轮询任务状态 → [查询任务接口](./04-get-task.md)
```

#### 金币包购买流程 ⭐
```
# Stripe 金币包
1. 获取金币包列表 → [获取金币包接口](./16-iap-coin-packages.md)
2. 创建支付链接 → [创建支付会话接口](./19-stripe-create-checkout.md)（传递product_id参数）
3. 用户支付 → 打开checkout_url进行支付
4. 查询支付状态 → [查询支付状态接口](./17-check-coin-purchase-status.md)（实时轮询）
5. 支付完成 → 获得金币，更新用户余额

# PayPal 金币包
1. 获取金币包列表 → [获取金币包接口](./16-iap-coin-packages.md)?platform=paypal
2. 创建订单 → [创建 PayPal 订单](./36-paypal-create-order.md)
3. 打开 approval_url，用户在 PayPal 完成支付
4. 捕获订单 → [捕获 PayPal 订单](./37-paypal-capture-order.md)
5. 支付完成 → 获得金币，更新用户余额
```
👉 **详细流程说明**: [金币包购买流程文档](./18-coin-package-purchase-flow.md)

---

## 📖 接口文档说明

### 文档结构

每个接口文档包含以下部分：
- **接口信息**：URL、认证要求、Headers
- **请求参数**：参数说明、类型、是否必需
- **响应说明**：响应字段、示例
- **使用场景**：典型使用场景
- **重要提示**：注意事项和最佳实践

### 文档命名规则

- `00-authentication.md` - 认证说明（共享文档）
- `01-{接口名}.md` - 认证相关接口
- `02-{接口名}.md` - 认证相关接口
- `03-{接口名}.md` - 任务相关接口
- `04-{接口名}.md` - 任务相关接口
- `05-{接口名}.md` - 任务相关接口
- `06-{接口名}.md` - 支付相关接口
- `07-{接口名}.md` - 支付相关接口
- `08-{接口名}.md` - 认证相关接口
- `09-{接口名}.md` - 配置相关接口
- `10-{接口名}.md` - 配置相关接口
- `11-{接口名}.md` - 配置相关接口
- `12-{接口名}.md` - 任务相关接口（上传视频）
- `13-{接口名}.md` - 配置相关接口
- `14-{接口名}.md` - 其他接口
- `15-{接口名}.md` - 其他接口
- `16-{接口名}.md` - 开发指南/流程文档
- `17-{接口名}.md` - 内购相关接口
- `18-{接口名}.md` - 内购相关流程指南
- `19-{接口名}.md` - 支付相关接口
- `21-{接口名}.md` - 归因追踪接口
- `22-{接口名}.md` - 支付相关接口
- `23-{接口名}.md` - AI 生成相关接口
- `24-{接口名}.md` - AI 生成相关接口
- `25-{接口名}.md` - AI 生成相关接口
- `26-{接口名}.md` - AI 生成相关接口
- `27-{接口名}.md` - AI 生成相关接口
- `28-{接口名}.md` - AI 生成相关接口
- `33-{接口名}.md` - 支付相关接口（订阅产品列表）
- `34-{接口名}.md` - PayPal 订阅创建
- `35-{接口名}.md` - PayPal 订阅激活
- `36-{接口名}.md` - PayPal 订单创建（金币包）
- `37-{接口名}.md` - PayPal 订单捕获（金币包）
- `38-{接口名}.md` - AI 生成相关接口（动作模仿图生视频）
- `39-{接口名}.md` - 每日签到相关接口（状态查询）
- `40-{接口名}.md` - 每日签到相关接口（执行签到）

---

## ⚠️ 重要提示

### 已废弃的接口

以下接口已废弃，不再推荐使用：
- ❌ `/create-task` - 创建视频任务（已废弃）
- ❌ `/list-video-templates` - 视频模板列表（已废弃）
- ❌ `/custom-image-generation` - 自定义图生图（已废弃）
- ❌ `/custom-video-generation` - 自定义图生视频（已废弃）
- ❌ `/custom-video-face-swap` - 自定义视频换脸（已废弃）
- ❌ `/check-ip-location` - IP 归属地检查（已废弃）

### 推荐使用的新接口

- ✅ 使用 `/get-feature-configs` 获取首页列表，然后调用对应的生成接口
- ✅ 使用 `/get-item-configs` 获取指定分类下的功能列表
- ✅ 使用 `/get-sections-configs` 获取功能分类列表

---

## 🔗 相关文档

- [完整 API 文档](../APP_API_GUIDE.md) - 原始完整文档（已拆分）
- [API 接口分析](../API_INTERFACE_ANALYSIS.md) - 接口分析文档
- [图片和视频生成接口指南](./NEW_AI_INTERFACES_GUIDE.md) - 图片和视频生成接口使用指南

---

## 📞 技术支持

如有问题，请查看：
- 各接口文档中的"重要提示"部分
- 各接口文档中的"错误处理"部分
- 认证说明文档中的"HTTP 状态码"部分

---

**最后更新**：2026-04-14
