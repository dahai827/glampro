# 用户认证与订阅状态管理流程

## 📋 概述

本文档说明 AI iOS App 中用户认证、订阅状态和积分管理的完整流程。开发者阅读本文档可以快速了解：

- App 启动时的认证流程
- 用户状态（订阅、积分）的获取和更新机制
- 积分余额的实时更新逻辑
- UI 中如何显示和使用这些数据

---

## 🔄 完整流程

### App 启动流程

```
App 启动 (AIApp.initializeApp())
    ↓
检查本地是否有有效 token
    ├─> 有有效 token
    │   ├─> 验证 token 有效性 (ensureValidToken)
    │   │   ├─> Token 有效 → 调用 user-status 更新状态
    │   │   └─> Token 过期 → 刷新 token → 调用 user-status
    │   └─> Token 无效 → 执行登录流程
    │
    └─> 无 token
        └─> 执行登录 (根据用户类型)
            ├─> 匿名登录 (login)
            └─> 审核登录 (reviewLogin)
                ↓
            登录成功后 → 调用 user-status 更新状态
```

**关键点**：
- ✅ **每次启动都会调用 `user-status`**，确保状态最新
- ✅ 有有效 token 时跳过登录，直接获取状态
- ✅ Token 过期时自动刷新，无需重新登录

---

## 🏗️ 架构实现

### 1. SessionManager - 核心状态管理

**文件位置**: `AI/Data/Network/SessionManager.swift`

#### 核心属性

```swift
@Published var userStatus: UserStatus?        // 用户状态（订阅、积分等）
@Published var creditsBalance: Int = 0         // 积分余额（UI 可观察）
@Published var accessToken: String?           // 访问令牌
@Published var refreshToken: String?          // 刷新令牌
@Published var isAuthenticated: Bool           // 认证状态
```

#### 关键方法

**`fetchAndSaveUserStatus()`**
- 功能：获取并保存用户状态
- 调用时机：App 启动时、登录成功后
- 作用：
  - 调用 `/user-status` 接口
  - 更新 `userStatus` 和 `creditsBalance`
  - 保存到本地存储（UserDefaults）

**`updateCreditsBalance(_ newBalance: Int)`**
- 功能：更新积分余额
- 调用时机：AI 任务完成后
- 作用：
  - 更新 `creditsBalance`（@Published，UI 自动刷新）
  - 从 `AITaskResponse.credits_balance` 获取新值

**`ensureValidToken()`**
- 功能：确保 token 有效
- 逻辑：
  - 无 token → 执行登录
  - Token 过期 → 刷新 token
  - Token 有效 → 直接返回

#### 数据持久化

使用 `UserDefaults` 存储：
- Token（access_token, refresh_token）
- 用户 ID
- 用户状态（UserStatus JSON）
- 用户类型（anonymous/review）

**数据在 App 退出后保留**，重启后自动加载。

---

### 2. AIApp - 启动逻辑

**文件位置**: `AI/App/AIApp.swift`

#### 启动流程实现

```swift
initializeApp()
  └─> initializeAuthAndUserStatus()
      ├─> 检查本地 token
      ├─> 有 token → 验证 → 调用 user-status
      └─> 无 token → 登录 → 调用 user-status
```

**关键逻辑**：
1. 先检查本地是否有有效 token
2. 有 token 时跳过登录，直接获取状态
3. 每次启动都调用 `user-status`，确保状态最新
4. 后台异步执行，不阻塞 UI

---

### 3. AIGenerationRepository - 积分更新

**文件位置**: `AI/Data/Repositories/AIGenerationRepository.swift`

#### 积分更新机制

所有 AI 任务方法完成后都会更新积分：

```swift
// 示例：generateImage
let response: AITaskResponse = try await apiClient.request(...)
SessionManager.shared.updateCreditsBalance(response.credits_balance)
return response
```

**更新的方法**：
- `generateImage()` - 文生图
- `processImage()` - 图生图
- `generateVideo()` - 文生视频
- `generateVideoFromImage()` - 图生视频
- `swapFace()` - 视频换脸
- `generateImageCustom()` - 自定义图生图
- `generateVideoCustom()` - 自定义图生视频
- `swapFaceCustom()` - 自定义视频换脸

**工作流程**：
```
AI 任务完成
  ↓
AITaskResponse 包含 credits_balance
  ↓
SessionManager.updateCreditsBalance()
  ↓
@Published creditsBalance 更新
  ↓
UI 自动刷新（响应式）
```

---

## 💻 UI 使用方式

### 在 View 中显示积分

```swift
import SwiftUI

struct MyView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        VStack {
            // 显示积分余额
            Text("积分: \(sessionManager.creditsBalance)")
            
            // 显示订阅状态
            if let userStatus = sessionManager.userStatus {
                Text("订阅状态: \(userStatus.subscription_status)")
                if userStatus.isSubscriptionActive {
                    Text("✅ 订阅中")
                }
            }
        }
    }
}
```

### 在 App 中注入 SessionManager

```swift
// AIApp.swift
@StateObject var sessionManager = SessionManager.shared

var body: some Scene {
    WindowGroup {
        coordinator.navigationStack
            .environmentObject(sessionManager)  // 注入到环境
    }
}
```

### 响应式更新

由于 `creditsBalance` 是 `@Published` 属性：
- ✅ UI 会自动响应积分变化
- ✅ 无需手动刷新
- ✅ 任务完成后积分立即更新

---

## 📊 数据模型

### UserStatus

**文件位置**: `AI/Domain/Models/Models.swift`

```swift
struct UserStatus: Codable {
    let subscription_status: String      // "active", "expired", "canceled", "none"
    let subscription_expire_at: String?  // ISO 8601 格式
    let plan_type: String?               // "yearly", "weekly", null
    let credits_balance: Int            // 当前积分余额
    let is_anonymous: Bool              // 是否为匿名用户
}
```

**计算属性**：
- `isSubscriptionActive: Bool` - 订阅是否激活
- `hasSubscription: Bool` - 是否有订阅（包括已过期）

---

## 🔑 关键设计决策

### 1. 为什么每次启动都调用 user-status？

**原因**：
- ✅ 确保订阅状态最新（用户可能在其他设备取消订阅）
- ✅ 同步服务器端的积分余额
- ✅ 触发服务器端的周期性积分发放
- ✅ 不依赖本地时间判断（避免用户修改系统时间导致的问题）

### 2. 为什么使用 @Published 属性？

**原因**：
- ✅ SwiftUI 响应式更新
- ✅ UI 自动刷新，无需手动管理
- ✅ 符合 MVVM 架构模式

### 3. 为什么在 Repository 层更新积分？

**原因**：
- ✅ 任务响应直接包含最新积分
- ✅ 避免额外的 API 调用
- ✅ 实时更新，用户体验更好

### 4. 数据持久化策略

**使用 UserDefaults**：
- ✅ 简单高效
- ✅ 自动持久化
- ✅ App 重启后自动恢复
- ✅ 适合存储小量数据（token、状态等）

---

## 🔍 代码位置索引

### 核心文件

| 文件 | 路径 | 说明 |
|------|------|------|
| SessionManager | `Data/Network/SessionManager.swift` | 认证和状态管理 |
| AIApp | `App/AIApp.swift` | App 启动逻辑 |
| AIGenerationRepository | `Data/Repositories/AIGenerationRepository.swift` | AI 任务和积分更新 |
| UserStatus | `Domain/Models/Models.swift` | 用户状态模型 |
| AuthAPI | `Data/Network/AuthAPI.swift` | 认证 API 端点 |

### 关键方法

| 方法 | 位置 | 说明 |
|------|------|------|
| `fetchAndSaveUserStatus()` | SessionManager | 获取并保存用户状态 |
| `updateCreditsBalance()` | SessionManager | 更新积分余额 |
| `ensureValidToken()` | SessionManager | 确保 token 有效 |
| `initializeAuthAndUserStatus()` | AIApp | 启动时的认证流程 |

---

## 📝 开发指南

### 添加新的积分消耗功能

如果添加新的 AI 功能，需要在任务完成后更新积分：

```swift
func myNewAIFeature() async throws -> AITaskResponse {
    let response: AITaskResponse = try await apiClient.request(...)
    
    // 更新积分余额
    SessionManager.shared.updateCreditsBalance(response.credits_balance)
    
    return response
}
```

### 在 UI 中显示积分

```swift
@EnvironmentObject var sessionManager: SessionManager

Text("\(sessionManager.creditsBalance) 积分")
```

### 检查订阅状态

```swift
if let userStatus = sessionManager.userStatus {
    if userStatus.isSubscriptionActive {
        // 订阅用户逻辑
    } else {
        // 免费用户逻辑
    }
}
```

---

## ⚠️ 注意事项

### 1. Token 管理
- Token 存储在 UserDefaults，App 卸载后会被清除
- Token 过期时会自动刷新，无需手动处理
- 刷新失败时会自动重新登录

### 2. 积分更新时机
- ✅ AI 任务完成后立即更新
- ✅ App 启动时从服务器同步
- ❌ 不要手动修改 `creditsBalance`，应通过 `updateCreditsBalance()` 方法

### 3. 订阅状态
- 订阅状态每次启动时从服务器获取
- 本地存储仅用于 UI 显示，不应作为业务逻辑判断依据
- 关键操作（如创建任务）应使用服务器返回的最新状态

### 4. 错误处理
- `fetchAndSaveUserStatus()` 失败不会影响 App 启动
- 积分更新失败不会影响任务创建
- 所有错误都会记录到日志，便于调试

---

## 🧪 测试

### 测试方法

在 `DebugTestView` 中提供了测试方法：

- **审核登录+用户状态** (`testReviewLoginAndUserStatus`)
  - 测试完整的登录和状态获取流程
  - 验证积分和订阅状态的更新

- **查询用户状态** (`testGetUserStatus`)
  - 测试单独的用户状态查询

### 测试页面

在 Settings 页面可以进入 Debug Test Panel：
- 查看实时积分余额
- 查看订阅状态
- 执行各种测试

---

## 🔗 相关文档

- [用户状态接口文档](./07-user-status.md) - `/user-status` 接口详细说明
- [匿名登录接口文档](./01-anonymous-login.md) - 匿名登录流程
- [审核登录接口文档](./08-review-login.md) - 审核测试账号登录
- [API 接口导航](./README.md) - 所有 API 接口文档索引

---

## 📅 更新历史

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-01-XX | v1.0 | 初始版本，实现用户认证和状态管理流程 |

---

**最后更新**: 2026-01-XX
