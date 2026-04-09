## 1.1 刷新 Session（使用 refresh_token）

**重要**: 当 `access_token` 过期时，应该使用 `refresh_token` 刷新 session，而不是重新调用 `/anonymous-login`。

### 方法 1：直接调用 Supabase Auth API（推荐）

**接口**: `POST https://lrenlgqppvqfbibxppbi.supabase.co/auth/v1/token?grant_type=refresh_token`

**请求 Headers**:
```
Content-Type: application/json
apikey: {SUPABASE_ANON_KEY}
```

**请求 Body**:
```json
{
  "refresh_token": "your_refresh_token_here"
}
```

**响应示例**:
```json
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "new_refresh_token_here",
  "user": {
    "id": "uuid",
    "is_anonymous": true
  }
}
```

**前端实现**:
```javascript
const SUPABASE_URL = 'https://lrenlgqppvqfbibxppbi.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

// 使用 refresh_token 刷新 session
async function refreshSession() {
  const refreshToken = localStorage.getItem('refresh_token');
  
  if (!refreshToken) {
    // 如果没有 refresh_token，重新匿名登录
    return await anonymousLogin();
  }
  
  try {
    const response = await fetch(
      `${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': ANON_KEY
        },
        body: JSON.stringify({
          refresh_token: refreshToken
        })
      }
    );
    
    const data = await response.json();
    
    if (response.ok && data.access_token) {
      // 更新本地存储（包括新的 refresh_token）
      localStorage.setItem('access_token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      
      return {
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        user: data.user
      };
    } else {
      // refresh_token 已过期，重新登录
      console.warn('refresh_token 已过期，重新登录');
      return await anonymousLogin();
    }
  } catch (error) {
    console.error('刷新 session 失败:', error);
    // 刷新失败，重新登录
    return await anonymousLogin();
  }
}
```

### 方法 2：使用 Supabase JS SDK（如果使用了 SDK）

```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, ANON_KEY);

// 使用 refresh_token 刷新 session
async function refreshSession() {
  const refreshToken = localStorage.getItem('refresh_token');
  
  if (!refreshToken) {
    return await anonymousLogin();
  }
  
  try {
    const { data, error } = await supabase.auth.refreshSession({
      refresh_token: refreshToken
    });
    
    if (error) {
      console.error('刷新 session 失败:', error);
      return await anonymousLogin();
    }
    
    // 更新本地存储
    localStorage.setItem('access_token', data.session.access_token);
    localStorage.setItem('refresh_token', data.session.refresh_token);
    
    return data;
  } catch (error) {
    console.error('刷新 session 异常:', error);
    return await anonymousLogin();
  }
}
```

### 完整的 Token 管理示例

```javascript
class TokenManager {
  constructor() {
    this.supabaseUrl = 'https://lrenlgqppvqfbibxppbi.supabase.co';
    this.anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
  }
  
  // 获取有效的 access_token
  async getValidToken() {
    const accessToken = localStorage.getItem('access_token');
    const refreshToken = localStorage.getItem('refresh_token');
    
    // 如果没有 token，重新登录
    if (!accessToken || !refreshToken) {
      return await this.anonymousLogin();
    }
    
    // 检查 access_token 是否过期（可选，也可以直接尝试使用）
    // 如果过期，使用 refresh_token 刷新
    try {
      // 尝试刷新（即使未过期也可以刷新）
      const refreshed = await this.refreshSession(refreshToken);
      return refreshed.access_token;
    } catch (error) {
      // 刷新失败，重新登录
      console.warn('刷新失败，重新登录');
      const loginData = await this.anonymousLogin();
      return loginData.session.access_token;
    }
  }
  
  // 刷新 session
  async refreshSession(refreshToken) {
    const response = await fetch(
      `${this.supabaseUrl}/auth/v1/token?grant_type=refresh_token`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.anonKey
        },
        body: JSON.stringify({ refresh_token: refreshToken })
      }
    );
    
    const data = await response.json();
    
    if (!response.ok || !data.access_token) {
      throw new Error(data.error_description || '刷新失败');
    }
    
    // 更新本地存储
    localStorage.setItem('access_token', data.access_token);
    localStorage.setItem('refresh_token', data.refresh_token);
    
    return {
      access_token: data.access_token,
      refresh_token: data.refresh_token,
      user: data.user
    };
  }
  
  // 匿名登录
  async anonymousLogin() {
    const response = await fetch(
      `${this.supabaseUrl}/functions/v1/anonymous-login`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.anonKey
        }
      }
    );
    
    const data = await response.json();
    
    localStorage.setItem('user_id', data.user.id);
    localStorage.setItem('access_token', data.session.access_token);
    localStorage.setItem('refresh_token', data.session.refresh_token);
    
    return data;
  }
}

// 使用示例
const tokenManager = new TokenManager();

// 在 API 调用前获取有效 token
async function apiCall(endpoint, options = {}) {
  const token = await tokenManager.getValidToken();
  
  const response = await fetch(endpoint, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Bearer ${token}`,
      'apikey': tokenManager.anonKey
    }
  });
  
  // 如果是 401 错误，再次尝试刷新
  if (response.status === 401) {
    const newToken = await tokenManager.getValidToken();
    return fetch(endpoint, {
      ...options,
      headers: {
        ...options.headers,
        'Authorization': `Bearer ${newToken}`,
        'apikey': tokenManager.anonKey
      }
    });
  }
  
  return response;
}
```

**重要提示**:
- ✅ **优先使用 `refresh_token` 刷新**：这是 Supabase 推荐的方式
- ✅ **保存新的 `refresh_token`**：刷新后会返回新的 `refresh_token`，需要更新本地存储
- ✅ **自动重试**：如果刷新失败，自动降级到重新匿名登录
- ⚠️ **`refresh_token` 有效期**：通常比 `access_token` 长得多，但如果长期未使用也可能过期

---