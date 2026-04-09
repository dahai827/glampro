## 8️⃣ 用户状态查询

### 接口信息

- **URL**：`GET /user-status`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

无需参数

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| subscription_status | string | 订阅状态（active/expired/canceled/none）|
| subscription_expire_at | string | 订阅过期时间（ISO 8601）|
| plan_type | string | 订阅类型（yearly/weekly/null）|
| credits_balance | number | 当前积分余额 |
| is_anonymous | boolean | 是否为匿名用户 |

### 使用场景

- App 启动时查询用户状态
- 创建任务前检查积分余额
- 显示用户订阅信息页面
- 自动触发周期性积分发放

### 请求示例

```bash
curl -X GET "${BASE_URL}/user-status" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "apikey: ${ANON_KEY}"
```

### 响应示例

**订阅用户**:
```json
{
  "subscription_status": "active",
  "subscription_expire_at": "2026-11-15T16:40:41.829+00:00",
  "plan_type": "yearly",
  "credits_balance": 1940,
  "is_anonymous": true
}
```

**匿名用户（无订阅）**:
```json
{
  "subscription_status": "none",
  "subscription_expire_at": null,
  "plan_type": null,
  "credits_balance": 0,
  "is_anonymous": true
}
```

### 重要提示

⚠️ **自动发放**：调用此接口会自动检查并发放周期性积分
⚠️ **实时查询**：积分余额为实时数据
⚠️ **匿名订阅**：匿名用户也可以成为订阅用户
⚠️ **审核测试用户**：审核测试用户自动补充到 >= 200 积分

---