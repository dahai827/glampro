## 🔍 查询金币包购买状态

### 接口信息

- **URL**：`GET /check-coin-purchase-status`
- **认证**：✅ 需要 access_token
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| session_id | string | Stripe Checkout Session ID | ✅ |

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| data | object | 购买状态详情 |
| error | string | 错误信息（仅当失败时返回） |

### 购买状态对象字段

| 字段 | 类型 | 说明 |
|------|------|------|
| status | string | 支付状态：pending / completed / failed / refunded |
| session_id | string | Checkout Session ID |
| purchase_coins | number | 本次购买获得的金币数（包括奖励） |
| total_coins | number | 用户当前的总金币余额 |
| transaction_id | string | 交易ID（仅在completed时返回） |
| is_credited | boolean | 是否已发放积分 |
| payment_status | string | 支付状态（同status字段） |
| created_at | string | 购买记录创建时间（ISO 8601） |
| message | string | 用户友好的状态提示信息 |

### 使用场景

- 用户完成支付后查询支付结果
- 支付进行中查询实时状态（无需等待webhook）
- 用户中途关闭App重新打开时继续查询支付状态
- 支付结果确认前更新App的UI界面

### 请求示例

```bash
# 查询支付状态
curl "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/check-coin-purchase-status?session_id=cs_test_xxx" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "apikey: ${ANON_KEY}"
```

### 响应示例

**支付进行中 (pending)**:
```json
{
  "success": true,
  "data": {
    "status": "pending",
    "session_id": "cs_test_1234567890abcdef",
    "purchase_coins": 302,
    "total_coins": 1502,
    "transaction_id": null,
    "is_credited": false,
    "payment_status": "pending",
    "created_at": "2026-01-17T10:00:00Z",
    "message": "支付进行中，请稍候..."
  }
}
```

**支付成功 (completed)**:
```json
{
  "success": true,
  "data": {
    "status": "completed",
    "session_id": "cs_test_1234567890abcdef",
    "purchase_coins": 302,
    "total_coins": 1502,
    "transaction_id": "pi_test_1234567890",
    "is_credited": true,
    "payment_status": "completed",
    "created_at": "2026-01-17T10:00:00Z",
    "message": "支付成功，已发放302金币"
  }
}
```

**支付失败 (failed)**:
```json
{
  "success": true,
  "data": {
    "status": "failed",
    "session_id": "cs_test_1234567890abcdef",
    "purchase_coins": 302,
    "total_coins": 1200,
    "transaction_id": null,
    "is_credited": false,
    "payment_status": "failed",
    "created_at": "2026-01-17T10:00:00Z",
    "message": "支付失败，请重试"
  }
}
```

**未找到购买记录**:
```json
{
  "success": false,
  "error": "未找到相关的购买记录"
}
```

**缺少必需参数**:
```json
{
  "success": false,
  "error": "缺少 session_id 参数"
}
```

**认证失败**:
```json
{
  "success": false,
  "error": "无效的授权令牌"
}
```

### 重要提示

⚠️ **需要认证**：必须使用有效的 access_token 调用此接口
⚠️ **查询权限**：用户只能查询自己的购买记录
⚠️ **session_id 必需**：是查询购买状态的唯一标识
⚠️ **两个关键字段**：
  - `purchase_coins`：本次购买获得的金币数（包括奖励）
  - `total_coins`：用户当前的总金币余额（包含之前的金币）
⚠️ **状态含义**：
  - `pending`：支付进行中，还未完成
  - `completed`：支付成功，积分已发放
  - `failed`：支付失败或被取消
  - `refunded`：已退款
⚠️ **实时性**：无需等待webhook，可实时查询支付状态
⚠️ **幂等性**：同一session_id多次查询返回相同结果

### 支付状态说明

| 状态 | 说明 | 是否发放积分 | 用户操作 |
|------|------|----------|--------|
| pending | 支付进行中 | ❌ | 等待支付完成或取消 |
| completed | 支付成功 | ✅ | 已获得金币，可使用 |
| failed | 支付失败 | ❌ | 可重新尝试购买 |
| refunded | 已退款 | ❌ | 联系客服处理 |

### 字段说明

- `purchase_coins`：本次购买获得的总金币数
  - 例：275基础金币 + 10%奖励(27枚) = 302枚
  - 这是用户本次购买获得的所有金币

- `total_coins`：用户当前的总金币余额
  - 例：之前有1200枚 + 本次购买302枚 = 1502枚
  - 用于显示用户的最新金币余额

- `transaction_id`：Stripe的支付交易ID
  - 仅在payment_status为completed时返回
  - 用于后端防重复处理和对账

### 典型使用流程

```
1. 用户选择购买金币包
   ↓
2. 调用 stripe-create-checkout 获取 session_id 和支付链接
   ↓
3. 用户打开支付链接进行支付
   ↓
4. App调用此接口查询支付状态（session_id）
   ├─ 如果 status=pending → 继续等待（2秒后重新查询）
   ├─ 如果 status=completed → 显示"支付成功"，更新UI
   └─ 如果 status=failed → 显示"支付失败"，提示重试
   ↓
5. Webhook更新支付状态并发放积分（自动触发）
   ↓
6. App再次查询 → 获得最新的total_coins余额
```

### 建议的轮询策略

```javascript
// 查询支付状态（轮询）
async function checkPaymentStatus(sessionId, maxRetries = 30) {
  let retries = 0;
  const interval = setInterval(async () => {
    try {
      const response = await fetch(
        `/check-coin-purchase-status?session_id=${sessionId}`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'apikey': anonKey
          }
        }
      );

      const data = await response.json();

      if (data.data.status === 'completed') {
        // 支付成功
        showSuccessMessage(`已发放 ${data.data.purchase_coins} 个金币`);
        updateCoinsBalance(data.data.total_coins);
        clearInterval(interval);
      } else if (data.data.status === 'failed') {
        // 支付失败
        showErrorMessage('支付失败，请重试');
        clearInterval(interval);
      }
      // pending 状态继续等待

      retries++;
      if (retries >= maxRetries) {
        clearInterval(interval);
        showWarningMessage('查询超时，请检查网络后重试');
      }
    } catch (error) {
      console.error('查询支付状态失败:', error);
    }
  }, 2000); // 每2秒查询一次
}
```

---
