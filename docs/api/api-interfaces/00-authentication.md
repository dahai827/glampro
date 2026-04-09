# 🔑 认证说明

## API 基础信息

**API 基础 URL**：`https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1`

## Header 配置规则

所有接口请求必须包含以下 Headers：

| Header | 值 | 说明 | 必需 |
|--------|---|------|------|
| `Content-Type` | `application/json` | 请求内容类型 | ✅ 是 |
| `Authorization` | `Bearer {access_token}` | 用户访问令牌 | ✅ 是 |
| `apikey` | `{SUPABASE_ANON_KEY}` | Supabase 匿名密钥 | ✅ 是（所有接口）|

## SUPABASE_ANON_KEY（固定值）

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyZW5sZ3FwcHZxZmJpYnhwcGJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1MTIxODMsImV4cCI6MjA3ODA4ODE4M30.xVbKv4Es1sZRtWYsqbcu4eBoL1XZlMcyLcEJTTpddP4
```

### 🔒 安全说明

**ANON_KEY 可以安全地嵌入在 App 中**：
- ✅ 此密钥设计为公开使用
- ✅ 只有最低权限（anon 角色）
- ✅ 数据访问受 RLS（行级安全策略）保护
- ✅ 用户只能访问自己创建的数据
- ✅ 无法访问其他用户的任务
- ✅ 无法执行管理员操作

**绝不能暴露的密钥**：
- ❌ SUPABASE_SERVICE_ROLE_KEY（服务端专用）
- ❌ REPLICATE_API_TOKEN（服务端专用）

## Token 流转机制

```
1. 调用匿名登录 → 获取 access_token 和 refresh_token
2. 保存 access_token 和 refresh_token 到本地
3. 后续所有请求都使用 access_token
4. access_token 有效期：1小时
5. 过期后优先使用 refresh_token 刷新 session（推荐）
6. 如果 refresh_token 也过期，重新调用匿名登录
```

## 📱 多应用支持（app_id）

系统现已支持多个 APP 共用同一套后端服务。通过 `app_id` 参数可以区分不同的应用：

**使用方式**:
- **现有APP（无需改动）**: 不传 `app_id` 参数，系统自动使用默认值 `"default"`
- **新APP**: 在 `/anonymous-login` 接口中传入 `app_id` 参数进行标识

**示例**:
```json
// 现有APP（不传 app_id，自动使用 "default"）
POST /anonymous-login
{}

// 新APP（传入 app_id）
POST /anonymous-login
{
  "app_id": "ios_v2"  // 或 "android_v1", "web_app" 等
}
```

**重要说明**:
- ✅ `app_id` 为可选参数，不传则默认为 `"default"`
- ✅ 现有APP无需任何改动，完全向后兼容
- ✅ `app_id` 会保存到用户元数据中，并在响应中返回
- ✅ 不同 `app_id` 的用户数据相互独立，互不影响

**推荐的 app_id 命名规范**:
- `default` - 现有APP（默认值）
- `ios_v1`, `ios_v2` - iOS 不同版本
- `android_v1`, `android_v2` - Android 不同版本
- `web` - Web版本
- `mini_program` - 小程序

## HTTP 状态码

| 状态码 | 说明 | App 处理 |
|--------|------|----------|
| 200 | 成功 | 正常处理响应 |
| 400 | 参数错误 | 显示 error 信息 |
| 401 | 未授权 | Token 无效，重新登录 |
| 403 | 禁止访问 | 积分不足或订阅失效，引导用户订阅 |
| 404 | 未找到 | 任务不存在 |
| 500 | 服务器错误 | 提示稍后重试 |
