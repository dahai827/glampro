# 📅 每日签到状态接口

## 接口信息

- **URL**：`GET /daily-checkin-status`
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

查询用户当前签到面板状态，包括：

- 今天是否已签到
- 今天可签到第几天和可得积分
- 7天奖励列表及每一天状态（`signed` / `signed_today` / `claimable` / `upcoming` / `locked`）

**重要规则**：

- 按 app 配置的时区切日（默认 `Asia/Shanghai`）
- 7 天循环（第 7 天后下一天回到第 1 天）
- 断签后从第 1 天重新开始

---

## 请求参数

无（`app_id` 从用户 token 的 `user_metadata.app_id` 读取，不需要客户端传）

---

## 响应字段

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| app_id | string | 当前应用ID |
| today | string | 当前签到日期（`YYYY-MM-DD`） |
| timezone | string | 签到时区 |
| cycle_days | number | 周期天数（固定 7） |
| is_active | boolean | 当前 app 是否启用签到 |
| signed_today | boolean | 今天是否已签到 |
| claimable_day | number \| null | 今天可签到的天数（1-7） |
| claimable_credits | number | 今天可得积分 |
| next_claimable_day | number \| null | 下次可签到天数 |
| current_streak_day | number | 当前连续签到天数位置 |
| reset_from_interruption | boolean | 当前是否处于断签重置状态 |
| rewards | array | 7天奖励列表 |

`rewards` 单项结构：

| 字段 | 类型 | 说明 |
|------|------|------|
| day | number | 第几天（1-7） |
| credits | number | 该天奖励积分 |
| status | string | 当天状态（`signed` / `signed_today` / `claimable` / `upcoming` / `locked`） |

---

## 请求示例

```bash
curl -X GET "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/daily-checkin-status" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}"
```

---

## 响应示例

### 成功响应（可签到）

```json
{
  "success": true,
  "app_id": "default",
  "today": "2026-04-14",
  "timezone": "Asia/Shanghai",
  "cycle_days": 7,
  "is_active": true,
  "signed_today": false,
  "claimable_day": 1,
  "claimable_credits": 10,
  "next_claimable_day": 1,
  "current_streak_day": 0,
  "reset_from_interruption": false,
  "rewards": [
    { "day": 1, "credits": 10, "status": "claimable" },
    { "day": 2, "credits": 10, "status": "locked" },
    { "day": 3, "credits": 10, "status": "locked" },
    { "day": 4, "credits": 10, "status": "locked" },
    { "day": 5, "credits": 10, "status": "locked" },
    { "day": 6, "credits": 20, "status": "locked" },
    { "day": 7, "credits": 30, "status": "locked" }
  ]
}
```

### 成功响应（今天已签到）

```json
{
  "success": true,
  "app_id": "default",
  "today": "2026-04-14",
  "timezone": "Asia/Shanghai",
  "cycle_days": 7,
  "is_active": true,
  "signed_today": true,
  "claimable_day": null,
  "claimable_credits": 0,
  "next_claimable_day": 2,
  "current_streak_day": 1,
  "reset_from_interruption": false,
  "rewards": [
    { "day": 1, "credits": 10, "status": "signed_today" },
    { "day": 2, "credits": 10, "status": "upcoming" }
  ]
}
```

### 错误响应（未授权）

```json
{
  "error": "未授权：缺少 Authorization header"
}
```

