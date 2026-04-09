## 7️⃣ 订阅验证（⚠️ 已升级到 Apple Server API V3）

### 接口信息

- **URL**：`POST /subscription-verify`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```
- **安全机制**：双重验证（JWS 签名验证 + Apple API 实时查询）

### ⚠️ 重要变更：已升级到新版 API

**从旧版 verifyReceipt 迁移到 App Store Server API V3**:
- ❌ **不再使用**: `receipt`（Base64 编码的收据）
- ✅ **新版参数**: `transactionId` + `signedTransactionInfo` + `signedRenewalInfo`（可选）
- ✅ **安全升级**: JWS 签名验证防止伪造
- ✅ **实时查询**: 调用 Apple API 获取最新订阅状态
- ✅ **数据校验**: 交叉验证 JWS vs API 数据

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| transactionId | string | 交易 ID（从 StoreKit 2 Transaction 获取）| ✅ |
| signedTransactionInfo | string | 签名的交易信息 JWS（从 StoreKit 2 获取）| ✅ |
| signedRenewalInfo | string | 签名的续订信息 JWS（从 StoreKit 2 获取）| ⚠️ 可选但推荐 |


### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| subscription_status | string | 订阅状态（active/expired/canceled）|
| subscription_expire_at | string | 订阅过期时间（ISO 8601）|
| plan_type | string | 订阅类型（yearly/weekly）|
| credits_balance | number | 当前积分余额 |
| credits_granted | number | **本次发放的积分数（当次新增）** |
| message | string | 提示信息 |

### 使用场景

- 用户完成 Apple 内购后调用
- 使用 StoreKit 2 获取交易信息
- 验证订阅凭证并激活订阅
- 自动发放对应的积分额度
- 首次订阅立即发放积分
- 恢复购买时自动迁移订阅和积分

### 安全流程说明

```
客户端上传 JWS
    ↓
服务器验证 JWS 签名（Apple Root CA）
    ↓ 签名有效？
    ├─ ❌ 否 → 拒绝（防伪造）
    └─ ✅ 是 → 继续
    ↓
调用 Apple Get All Subscription Statuses API
    ↓
交叉验证 JWS vs API 数据
    ↓ 数据一致？
    ├─ ❌ 否 → 拒绝（防篡改）
    └─ ✅ 是 → 继续
    ↓
检查退款状态
    ↓
更新数据库 + 发放积分
    ↓
异步上报 Adjust 事件
    ↓
返回成功响应
```

### 字段说明

- `credits_granted`: 当次新增的积分（首充积分 + 周期性积分）
  - 首次订阅：年订阅 2000，周订阅 500
  - 后续验证：0（不重复发放首充积分）
- `credits_balance`: 当前积分余额

### 幂等性说明

- 基于 `original_transaction_id` 实现幂等控制
- 同一订阅多次验证不会重复发放首充积分
- 恢复购买时自动迁移订阅和积分余额

### 请求示例

```bash
# 使用新版 API（StoreKit 2）
curl -X POST "${BASE_URL}/subscription-verify" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -d '{
    "transactionId": "1000000123456789",
    "signedTransactionInfo": "eyJhbGciOiJFUzI1NiIsIng1YyI6W...",
    "signedRenewalInfo": "eyJhbGciOiJFUzI1NiIsIng1YyI6W..."
  }'
```

### 响应示例

**成功响应**:
```json
{
  "success": true,
  "subscription_status": "active",
  "subscription_expire_at": "2026-11-15T16:40:41.829Z",
  "plan_type": "yearly",
  "credits_balance": 2000,
  "credits_granted": 2000,
  "message": "订阅验证成功"
}
```

**失败响应（JWS 签名验证失败）**:
```json
{
  "code": 400,
  "message": "JWS 签名验证失败"
}
```

**失败响应（订阅已退款）**:
```json
{
  "code": 400,
  "message": "订阅已被退款"
}
```

### 重要提示

⚠️ **API 升级**：必须使用 StoreKit 2 获取交易信息（不再支持旧版 receipt）
⚠️ **双重验证**：JWS 签名验证 + Apple API 实时查询，安全性更高
⚠️ **首次订阅**：立即发放全额积分（年付2000，周付500）
⚠️ **周期发放**：后续自动按周期累积发放
⚠️ **过期处理**：订阅过期后积分冻结，无法使用
⚠️ **幂等性**：同一订阅多次验证不会重复发放首充积分
⚠️ **恢复购买**：自动迁移订阅和积分余额到新设备
⚠️ **退款检测**：自动检测退款状态，拒绝已退款的订阅

### 积分发放规则

| 订阅类型 | Product ID | 积分额度 | 发放周期 |
|---------|-----------|---------|---------|
| 年付订阅 | yearly_pro | 2000 积分/月 | 每月累积 |
| 周付订阅 | weekly_pro | 500 积分/周 | 每周累积 |

### StoreKit 2 迁移指南

**旧版代码（verifyReceipt）**:
```swift
// ❌ 旧版方式（不再支持）
let receiptURL = Bundle.main.appStoreReceiptURL
let receiptData = try Data(contentsOf: receiptURL!)
let receiptBase64 = receiptData.base64EncodedString()

// 调用旧版接口
let body = ["receipt": receiptBase64]
```


---