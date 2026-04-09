## 9️⃣ 审核测试账号登录

### 接口信息

- **URL**：`POST /review-login`
- **认证**：✅ 需要 apikey 和 Authorization（使用ANON_KEY）
- **Headers**：
  ```
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  Authorization: Bearer {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| app_id | string | 应用标识，用于区分不同APP的审核测试账号 | ❌ |

**请求 Body（可选）**:
```json
{
  "app_id": "default"    // 可选，不传则使用默认审核账号
}
```

**app_id 说明**:
- ✅ 可选参数，不传则使用默认审核测试账号（向后兼容）
- ✅ 新APP建议传入自定义的 `app_id`（如 `"ios_v2"`, `"android_v1"` 等）
- ✅ 不同 `app_id` 会创建独立的审核测试账号

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| user.id | string | 用户唯一ID |
| user.is_review_user | boolean | 是否为审核测试用户 |
| session.access_token | string | **访问令牌（重要）** |
| session.refresh_token | string | 刷新令牌 |
| message | string | 提示信息 |

### 使用场景

- App Store 审核时，通过隐藏手势（点击 10 次）触发
- 获取审核测试账号的 token，之后所有请求使用该 token
- 审核测试账号拥有永久订阅状态和至少 200 积分

### 前端实现建议

```javascript
let tapCount = 0;
let lastTapTime = 0;

function handleReviewLoginTap() {
  const now = Date.now();
  
  // 重置计数（超过 2 秒未点击）
  if (now - lastTapTime > 2000) {
    tapCount = 0;
  }
  
  tapCount++;
  lastTapTime = now;
  
  // 点击 10 次触发
  if (tapCount >= 10) {
    tapCount = 0;
    triggerReviewLogin();
  }
}

async function triggerReviewLogin() {
  try {
    const response = await fetch(`${API_BASE}/review-login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`
      },
      body: JSON.stringify({
        app_id: 'ios_v2'  // 可选，不传则使用默认审核账号
      })
    });
    
    const data = await response.json();
    
    // 保存审核测试账号的 token
    localStorage.setItem('access_token', data.session.access_token);
    localStorage.setItem('refresh_token', data.session.refresh_token);
    localStorage.setItem('is_review_user', 'true');
    
    // 重新加载用户状态
    await getUserStatus();
    
    showMessage('审核测试模式已激活');
  } catch (error) {
    console.error('审核登录失败:', error);
  }
}
```

### 重要提示

⚠️ **仅用于审核**：仅用于 App Store 审核，不应在生产环境对普通用户开放  
⚠️ **永久订阅**：审核测试账号拥有永久订阅状态  
⚠️ **积分保障**：审核测试账号自动补充到 >= 200 积分

---