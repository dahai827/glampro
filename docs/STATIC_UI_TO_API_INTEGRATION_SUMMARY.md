# Morpho 静态 UI → API 对接总结

## 对接范围

- **app_id**：`morpho`（见 `APIConfig.appId`）
- **启动流程**：Splash → Onboarding → Paywall → Main
- **数据源**：匿名登录、user-status、get-feature-configs（menu=image/video/grid）

## 问题与方案

### 1. 全局配置

- `APIConfig.appId = "morpho"`，所有接口统一使用
- `APIConfig.appVersion` 从 Info.plist 读取

### 2. 认证与 Session

- 匿名登录传 `app_id`、`adid`（Keychain 持久化）、`idfv`、`idfa`
- adid 与 idfa 必须不同，避免订阅丢失
- Token 存 UserDefaults，供后续请求携带

### 3. 启动预加载

- Splash 期间并行执行：匿名登录 → user-status，get-feature-configs（image/video/grid）
- `AppBootstrapStore.prepareIfNeeded()` 在 RootView `.task` 中触发
- Splash 动画结束后等待 `isPrepared` 或最多 5 秒再进入引导页

### 4. 首页数据绑定

- **Discover**：`appBootstrap.discoverItems`（来自 menu=video，优先展示视频封面）
- **AI Video**：`appBootstrap.videoSections`
- **AI Image**：`appBootstrap.imageSections`
- API 失败时使用 fallback 占位数据（渐变卡片）

### 5. 积分与订阅

- `SessionManager.creditsBalance`、`SessionManager.isPro` 为数据源
- Mine 页、付费墙关闭后调用 `refreshUserStatus()` 更新

### 6. 广告项点击

- `is_ad=true` 且 `ad_ios_url` 非空时，用 `UIApplication.shared.open` 在 Safari 中打开
- 不进入预览/创作流程

## 新增文件结构

```
Morpho/
├── Data/
│   ├── Network/
│   │   ├── APIConfig.swift
│   │   ├── APIClient.swift
│   │   ├── APIError.swift
│   │   └── SessionManager.swift
│   └── Repositories/
│       ├── UserRepository.swift
│       └── AppConfigRepository.swift
├── Domain/
│   └── Models/
│       └── APIModels.swift
├── Services/
│   └── KeychainManager.swift
└── App/
    └── AppBootstrapStore.swift
```

## 解码策略

- 使用 `JSONDecoder.keyDecodingStrategy = .useDefaultKeys`
- DTO 均显式 `CodingKeys`（snake_case → camelCase）
- `next_cursor`、`id` 等字段兼容 Int/String（自定义 init）
