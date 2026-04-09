## 📊 上报活动事件

### 接口信息

- **URL**：`POST /report-activity-event`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Content-Type: application/json
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| event_name | string | 事件类型（见下方事件类型列表） | ✅ |
| event_time | string | 事件发生时间（ISO 8601 格式）| ✅ |
| metadata | object | 事件元数据（可选，不同事件类型有不同的字段） | ❌ |

### 支持的事件类型（14 种）

#### 1️⃣ 页面浏览事件（Page View）

| 事件名称 | event_name | 说明 | 元数据字段 |
|---------|-----------|------|----------|
| 启动页浏览 | `splash_pageview` | 用户打开启动屏幕 | page_type, duration_ms |
| 引导页浏览 | `guide_pageview` | 用户查看引导页 | page_index, total_pages |
| 付费墙浏览 | `paywall_pageview` | 用户查看订阅/充值页面 | page_type |

#### 2️⃣ 用户操作事件（User Action）

| 事件名称 | event_name | 说明 | 元数据字段 |
|---------|-----------|------|----------|
| 付费墙关闭 | `paywall_close_click` | 用户关闭付费墙 | reason (back/confirm) |
| 换脸功能使用 | `swapface_click` | 用户点击使用换脸功能 | feature_id, template_id |

#### 3️⃣ 订阅事件（Subscription）

| 事件名称 | event_name | 说明 | 元数据字段 |
|---------|-----------|------|----------|
| 周订阅（Stripe）| `subs_weekly_stripe` | 用户订阅周付计划 | plan_id, amount, currency |
| 月订阅（Stripe）| `subs_monthly_stripe` | 用户订阅月付计划 | plan_id, amount, currency |
| 年订阅（Stripe）| `subs_yearly_stripe` | 用户订阅年付计划 | plan_id, amount, currency |

#### 4️⃣ 生成事件（Generation）

| 事件名称 | event_name | 说明 | 元数据字段 |
|---------|-----------|------|----------|
| 生成开始 | `generation_start` | 用户开始生成视频/图片 | task_type, model_type |
| 生成成功 | `generation_success` | 生成任务完成 | task_id, task_type, duration_ms |

#### 5️⃣ App 事件（App）

| 事件名称 | event_name | 说明 | 元数据字段 |
|---------|-----------|------|----------|
| App 打开 | `app_open` | 用户打开 App | app_version, build_number |
| App 关闭 | `app_close` | 用户关闭 App | session_duration_ms |
| 页面浏览 | `page_view` | 用户浏览页面 | page_name, referrer |

### 请求示例

#### 示例 1：上报页面浏览事件

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/report-activity-event" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "event_name": "paywall_pageview",
    "event_time": "2025-01-15T10:30:00Z",
    "metadata": {
      "page_type": "subscription"
    }
  }'
```

#### 示例 2：上报生成成功事件

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/report-activity-event" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "event_name": "generation_success",
    "event_time": "2025-01-15T10:30:00Z",
    "metadata": {
      "task_id": "task-uuid-12345",
      "task_type": "text-to-video",
      "duration_ms": 45000
    }
  }'
```

#### 示例 3：上报订阅事件

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/report-activity-event" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "event_name": "subs_yearly_stripe",
    "event_time": "2025-01-15T10:30:00Z",
    "metadata": {
      "plan_id": "plan_yearly",
      "amount": 99.99,
      "currency": "USD"
    }
  }'
```

### 响应

#### 成功响应 (200)

```json
{
  "success": true,
  "data": {
    "event_id": "event-uuid-12345",
    "event_name": "generation_success",
    "event_time": "2025-01-15T10:30:00Z",
    "created_at": "2025-01-15T10:30:01Z"
  },
  "message": "事件上报成功"
}
```

#### 错误响应 (400)

```json
{
  "error": "event_name is required"
}
```

#### 错误响应 (401)

```json
{
  "error": "未授权：需要有效的 access_token"
}
```

### 使用场景

#### 场景 1：用户打开 App

```javascript
async function onAppStart() {
  const response = await fetch('/report-activity-event', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      event_name: 'app_open',
      event_time: new Date().toISOString(),
      metadata: {
        app_version: '1.0.0',
        build_number: '100'
      }
    })
  });

  const data = await response.json();
  if (data.success) {
    console.log('App 打开事件已上报');
  }
}
```

#### 场景 2：用户完成生成任务

```javascript
async function onGenerationComplete(taskId, taskType, durationMs) {
  const response = await fetch('/report-activity-event', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      event_name: 'generation_success',
      event_time: new Date().toISOString(),
      metadata: {
        task_id: taskId,
        task_type: taskType,
        duration_ms: durationMs
      }
    })
  });

  const data = await response.json();
  if (data.success) {
    console.log('生成成功事件已上报');
  }
}
```

#### 场景 3：用户订阅

```javascript
async function onSubscriptionComplete(planId, amount, currency) {
  const response = await fetch('/report-activity-event', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
      'apikey': ANON_KEY
    },
    body: JSON.stringify({
      event_name: 'subs_yearly_stripe',
      event_time: new Date().toISOString(),
      metadata: {
        plan_id: planId,
        amount: amount,
        currency: currency
      }
    })
  });

  const data = await response.json();
  if (data.success) {
    console.log('订阅事件已上报');
  }
}
```

### 完整的事件追踪集成示例

```javascript
class EventTracker {
  constructor(accessToken, anonKey) {
    this.accessToken = accessToken;
    this.anonKey = anonKey;
    this.apiBase = 'https://your-project.supabase.co/functions/v1';
  }

  async reportEvent(eventName, metadata = {}) {
    try {
      const response = await fetch(`${this.apiBase}/report-activity-event`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.accessToken}`,
          'apikey': this.anonKey
        },
        body: JSON.stringify({
          event_name: eventName,
          event_time: new Date().toISOString(),
          metadata: metadata
        })
      });

      const data = await response.json();

      if (data.success) {
        console.log(`✅ 事件上报成功: ${eventName}`, data.data);
        return true;
      } else {
        console.error(`❌ 事件上报失败: ${eventName}`, data.error);
        return false;
      }
    } catch (error) {
      console.error(`❌ 事件上报异常: ${eventName}`, error);
      return false;
    }
  }

  // 便利方法
  async reportAppOpen(appVersion, buildNumber) {
    return this.reportEvent('app_open', {
      app_version: appVersion,
      build_number: buildNumber
    });
  }

  async reportAppClose(sessionDurationMs) {
    return this.reportEvent('app_close', {
      session_duration_ms: sessionDurationMs
    });
  }

  async reportGenerationStart(taskType, modelType) {
    return this.reportEvent('generation_start', {
      task_type: taskType,
      model_type: modelType
    });
  }

  async reportGenerationSuccess(taskId, taskType, durationMs) {
    return this.reportEvent('generation_success', {
      task_id: taskId,
      task_type: taskType,
      duration_ms: durationMs
    });
  }

  async reportSubscription(planId, amount, currency, planType) {
    const eventNameMap = {
      'weekly': 'subs_weekly_stripe',
      'monthly': 'subs_monthly_stripe',
      'yearly': 'subs_yearly_stripe'
    };

    return this.reportEvent(eventNameMap[planType], {
      plan_id: planId,
      amount: amount,
      currency: currency
    });
  }

  async reportPaywallView(pageType) {
    return this.reportEvent('paywall_pageview', {
      page_type: pageType
    });
  }

  async reportPageView(pageName, referrer = null) {
    return this.reportEvent('page_view', {
      page_name: pageName,
      referrer: referrer
    });
  }
}

// 使用示例
const tracker = new EventTracker(accessToken, anonKey);

// 在 App 启动时
tracker.reportAppOpen('1.0.0', '100');

// 在生成成功时
tracker.reportGenerationSuccess('task-123', 'text-to-video', 45000);

// 在用户订阅时
tracker.reportSubscription('plan_yearly', 99.99, 'USD', 'yearly');

// 在页面浏览时
tracker.reportPageView('home', 'push_notification');
```

### 重要提示

⚠️ **事件必须认证**：所有事件上报都需要有效的 access_token
⚠️ **时间格式**：event_time 必须使用 ISO 8601 格式（`YYYY-MM-DDTHH:mm:ssZ`）
⚠️ **异步上报**：建议在后台异步上报事件，不阻塞用户操作
⚠️ **重试机制**：网络失败时应实现重试逻辑
⚠️ **元数据可选**：metadata 字段为可选，某些事件可能无需提供

### 错误处理

| HTTP Status | 错误说明 | 建议处理 |
|-------------|---------|--------|
| 200 | 成功 | 正常处理 |
| 400 | 参数错误 | 检查 event_name 和 event_time 格式 |
| 401 | 未授权 | Token 无效，重新登录 |
| 500 | 服务器错误 | 重试或记录日志 |

---