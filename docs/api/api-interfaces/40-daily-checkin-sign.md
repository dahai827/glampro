# ✅ 每日签到执行接口

## 接口信息

- **URL**：`POST /daily-checkin-sign`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```

> 📖 关于认证和 Token 获取，请参考 [认证说明文档](./00-authentication.md)

---

## 功能说明

执行当日签到并发放积分。

- 同一用户同一 app 同一天只会发放一次积分（幂等）
- 断签后重置到 Day1
- Day7 后下一次签到自动回到 Day1
- 积分发放走系统统一积分链路（更新 `credits_balance`）

---

## 请求参数

无请求体（`app_id` 从用户 token 的 `user_metadata.app_id` 读取）

---

## 响应字段

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| app_id | string | 当前应用ID |
| already_signed_today | boolean | 今天是否已签到（true 表示本次未重复发积分） |
| checkin_date | string \| null | 本次签到日期（`YYYY-MM-DD`） |
| day_no | number \| null | 本次签到对应第几天（1-7） |
| credits_granted | number | 本次发放积分（已签到时为 0） |
| credits_balance | number \| null | 发放后的用户总积分 |
| next_claimable_day | number \| null | 下次可签到天数 |
| reset_from_interruption | boolean | 本次是否因为断签而重置 |
| message | string | 提示信息 |

---

## 请求示例

```bash
curl -X POST "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/daily-checkin-sign" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}"
```

---

## 响应示例

### 成功响应（签到成功）

```json
{
  "success": true,
  "app_id": "default",
  "already_signed_today": false,
  "checkin_date": "2026-04-14",
  "day_no": 1,
  "credits_granted": 10,
  "credits_balance": 1010,
  "next_claimable_day": 2,
  "reset_from_interruption": false,
  "message": "Check-in success"
}
```

### 成功响应（今天已签到，幂等返回）

```json
{
  "success": true,
  "app_id": "default",
  "already_signed_today": true,
  "checkin_date": "2026-04-14",
  "day_no": 1,
  "credits_granted": 0,
  "credits_balance": 1010,
  "next_claimable_day": 2,
  "reset_from_interruption": false,
  "message": "Already signed today"
}
```

### 错误响应（未授权）

```json
{
  "error": "未授权：缺少 Authorization header"
}
```

### 错误响应（签到未启用）

```json
{
  "error": "Daily check-in is disabled for this app"
}
```

