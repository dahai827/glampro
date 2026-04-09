## 4️⃣ 查询任务状态

### 接口信息

- **URL**：`GET /get-task?task_id={task_id}`
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 位置 | 类型 | 说明 | 必需 |
|------|------|------|------|------|
| task_id | Query | string | 任务ID | ✅ |

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 任务ID |
| status | string | **任务状态（关键）** |
| scene | string | 场景类型 |
| video_url | string | 输入视频URL |
| image_url | string | 输入图片URL |
| output_url | string | **输出视频URL（成功时）** |
| error_message | string | 错误信息（失败时）|
| credits_used | number | **本次任务扣除的积分** |
| created_at | string | 创建时间 |
| updated_at | string | 更新时间 |

### 任务状态说明

| status 值 | 说明 | App 处理 |
|-----------|------|----------|
| `processing` | 处理中 | 继续轮询（每3秒）|
| `completed` | 已完成 | 播放 output_url |
| `failed` | 已失败 | 显示 error_message |

### 使用场景

- 创建任务后立即开始轮询
- 每 3 秒调用一次
- 直到状态变为 `completed` 或 `failed`

### 轮询机制

```
创建任务 → task_id
  ↓
每3秒轮询一次
  ↓
status = processing → 继续轮询
status = completed → 展示视频（output_url）
status = failed → 显示错误
```

### 预期等待时间

- **短视频（<10秒）**：1-2 分钟
- **中等视频（10-30秒）**：2-4 分钟
- **长视频（30-60秒）**：4-6 分钟

---