# 22-Apple 内购验证统一接口 (Apple IAP Verify)

此接口用于验证苹果应用内购买（IAP）交易结果，支持**消耗型（金币包）**和**订阅型**两种产品类型。

## 接口说明
- **请求方法**: `POST`
- **请求地址**: `/functions/v1/apple-iap-verify`
- **认证方式**: 需要 `Authorization: Bearer <UserToken>`

## 请求参数 (JSON)

| 参数名 | 类型 | 必选 | 说明 |
| :--- | :--- | :--- | :--- |
| `transactionId` | String | 是 | 苹果交易 ID |
| `signedTransactionInfo` | String | 是 | 苹果返回的 JWS 格式交易信息（**iOS 必须使用 `VerificationResult.jwsRepresentation` 获取，不能使用 `Transaction.jsonRepresentation`**） |
| `signedRenewalInfo` | String | 否 | 苹果返回的 JWS 格式续订信息（仅订阅类型可选） |

### 示例
```json
{
  "transactionId": "1000000123456789",
  "signedTransactionInfo": "eyJhbGciOiJFUzI1NiIsIng1YyI6Wy..."
}
```

## 响应结果

### 场景一：消耗型内购（金币包）成功响应
```json
{
  "success": true,
  "type": "consumable",
  "product_id": "com.app.coins.100",
  "credits_granted": 100,
  "message": "购买成功，金币已发放"
}
```

### 场景二：订阅型内购成功响应
```json
{
  "success": true,
  "type": "subscription",
  "subscription_status": "active",
  "subscription_expire_at": "2026-01-24T12:00:00Z",
  "plan_type": "yearly",
  "credits_balance": 2500,
  "credits_granted": 2000,
  "message": "订阅验证成功",
  "environment": "Production"
}
```

### 错误响应
```json
{
  "success": false,
  "error": "Bundle ID 不匹配",
  "message": "Bundle ID 不匹配"
}
```

## 业务逻辑说明
1. **身份验证**: 接口通过 JWT 验证用户身份，并获取用户的 `app_id`。
2. **JWS 验证**: 后端验证 `signedTransactionInfo` 的数字签名，确保交易数据未被篡改且来自苹果。
3. **产品识别**:
   - 接口首先查询 `iap_coin_packages` 配置表。
   - 如果 `product_id` 匹配配置，则识别为**消耗型**，立即为用户增加金币，并记录购买日志。
   - 如果不匹配，则识别为**订阅型**，通过 Apple Server API 获取最新订阅状态，并更新用户的订阅特权。
4. **防重复处理**: 接口通过 `transaction_id` 进行幂等性检查，防止重复发放。
5. **归因追踪**: 验证成功后，接口会自动向 Adjust、Meta Conversions API 和 Google Ads 上报转化事件（仅生产环境）。

## 常见状态码
- `200`: 处理成功。
- `400`: 参数缺失、Bundle ID 不匹配、数据不一致或已被退款。
- `401`: 用户未授权（Token 无效）。
- `500`: 内部服务器错误或 Apple API 调用失败。

## 常见错误排查

### JWS Protected Header is invalid / JWS 签名验证失败
- **原因**: `signedTransactionInfo` 不是有效的 JWS 格式，常见于 iOS 端传错字段。
- **解决**: 必须使用 `VerificationResult.jwsRepresentation` 获取 JWS 字符串，**不能**使用 `Transaction.jsonRepresentation`。
- **示例**:
  ```swift
  // ✅ 正确：购买结果中的 jwsRepresentation
  case .success(let verification):
      let signedTransactionInfo = verification.jwsRepresentation
  
  // ❌ 错误：jsonRepresentation 是已解码的 JSON，不是 JWS
  let signedTransactionInfo = transaction.jsonRepresentation  // 错误！
  ```
