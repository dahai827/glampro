## 📱 获取应用审核版本号

### 接口信息

- **URL**：`GET /get-app-newversion?app_id={app_id}`
- **认证**：❌ 公开接口（无需 Token，仅需 apikey）
- **Headers**:
  ```
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  Authorization: Bearer {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 位置 | 类型 | 说明 | 必需 | 默认值 |
|------|------|------|------|------|--------|
| app_id | Query | string | 应用标识（用于区分不同APP） | ❌ | "default" |

**请求示例**:
```bash
# 获取默认应用的审核版本号
GET /get-app-newversion

# 获取指定应用的审核版本号
GET /get-app-newversion?app_id=annyrsai
```

### 响应示例

**响应 HTTP Status**: `200 OK`

**响应 Body（有版本号）**:
```json
{
  "success": true,
  "app_id": "default",
  "review_version": "1.0.0",
  "message": "获取成功"
}
```

**响应 Body（无版本号或应用不存在）**:
```json
{
  "success": true,
  "app_id": "default",
  "review_version": "",
  "message": "未设置审核版本号"
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 请求是否成功 |
| app_id | string | 应用ID |
| review_version | string | 审核版本号（如：1.0.0），未设置时为空字符串 |
| message | string | 响应消息 |

### 使用场景

- App 启动时检查是否有新版本
- 用于 iOS App Store 审核版本管理
- 客户端版本更新检查

### 重要提示

⚠️ **公开接口**：无需认证，任何人可访问
⚠️ **版本号格式**：标准语义化版本号（如：1.0.0、1.0.1等）
⚠️ **空值处理**：如果应用不存在或未设置版本号，返回空字符串 `""`，而不是 `null`

### 使用示例

```javascript
// 检查应用审核版本号
async function checkAppVersion(appId = 'default') {
  const response = await fetch(
    `${API_BASE}/get-app-newversion?app_id=${appId}`,
    {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`
      }
    }
  );
  
  const data = await response.json();
  
  if (data.success && data.review_version) {
    console.log(`当前审核版本号: ${data.review_version}`);
    // 可以用于版本比较逻辑
    return data.review_version;
  } else {
    console.log('未设置审核版本号');
    return '';
  }
}

// 使用示例
const version = await checkAppVersion('default');
if (version) {
  // 处理版本号逻辑
  console.log(`App 审核版本: ${version}`);
}
```

### 错误处理

| HTTP Status | 错误说明 | 建议处理 |
|-------------|---------|---------|
| 200 | 成功 | 正常处理响应数据 |
| 400 | 参数错误 | 检查请求参数格式 |
| 405 | 方法不允许 | 确保使用 GET 方法 |
| 500 | 服务器错误 | 重试或联系技术支持 |

---

### 错误处理

| HTTP Status | 错误说明 | 建议处理 |
|-------------|---------|---------|
| 200 | 成功 | 正常处理响应数据 |
| 400 | 参数错误 | 检查 app_id 参数格式 |
| 401 | 认证失败 | 检查 apikey 是否正确 |
| 500 | 服务器错误 | 重试或联系技术支持 |

---