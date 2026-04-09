## 5️⃣ 任务历史列表

### 接口信息

- **URL**：`GET /list-tasks?limit={limit}&offset={offset}`（可选 `status`、`menu` 见下表）
- **认证**：✅ 需要 access_token 和 apikey
- **Headers**：
  ```
  Authorization: Bearer {access_token}
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 位置 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| limit | Query | number | 10 | 每页数量（1-100）|
| offset | Query | number | 0 | 偏移量 |
| status | Query | string | 无 | 任务状态: pending/processing/completed/failed（可选）|
| menu | Query | string | 无 | 板块菜单筛选（可选）：`grid`、`image`、`video`、`ai_girlfriend`，与 CMS 分类 `menu` 一致；仅返回 `section_menu` 等于该值的记录 |

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| tasks | array | 任务列表 |
| total | number | 总任务数 |
| limit | number | 每页数量 |
| offset | number | 偏移量 |

### 任务对象结构

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 任务ID |
| scene | string | 场景类型 |
| status | string | 任务状态: pending/processing/completed/failed  |
| output_url | string | 输出视频URL（成功时）|
| credits_used | number | **本次任务扣除的积分** |
| created_at | string | 创建时间 |
| section_menu | string \| null | 所属功能分类菜单（`grid` / `image` / `video` / `ai_girlfriend`），与 `feature_config_sections.menu` 一致；历史任务可能为 `null` |

### 使用场景

- 显示用户的历史生成记录
- 支持分页加载
- 可按状态筛选
- AI 女友等独立板块：调用 `GET /list-tasks?menu=ai_girlfriend&limit=20&offset=0` 仅拉取该板块下图生视频等任务（需任务创建时已写入 `section_menu`，见 `image-to-video` 接口）

### 请求示例

```
GET .../functions/v1/list-tasks?menu=ai_girlfriend&limit=20&offset=0
```

---