## 🏪 获取内购金币包列表

### 接口信息

- **URL**：`GET /iap-coin-packages`
- **认证**：❌ 不需要认证（公开接口）
- **Headers**：
  ```
  Content-Type: application/json
  apikey: {SUPABASE_ANON_KEY}
  ```

### 请求参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| app_id | string | 应用ID（不传则默认为 'default'） | ❌ |
| platform | string | 购买平台：apple / stripe / google / paypal | ❌ |

### 响应

| 字段 | 类型 | 说明 |
|------|------|------|
| success | boolean | 是否成功 |
| data | array | 金币包配置列表 |
| count | number | 返回的金币包数量 |
| error | string | 错误信息（仅当失败时返回） |

### 金币包对象字段

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 金币包唯一ID |
| app_id | string | 应用ID |
| platform | string | 购买平台（apple / stripe / google / paypal） |
| product_id | string | 平台的产品ID |
| display_name | string | 显示名称（如"275 coins"） |
| description | string | 产品描述 |
| amount | number | 价格（美元） |
| currency | string | 货币代码（usd / cny等） |
| platform_price_id | string | 平台特定的价格ID |
| base_coins | number | 基础金币数量 |
| bonus_percentage | number | 奖励百分比（0-100） |
| bonus_coins | number | 额外赠送金币（自动计算） |
| total_coins | number | 总金币数（base_coins + bonus_coins） |
| tags | array | 标签数组（如["POPULAR", "BEST VALUE"]） |
| sort_order | number | 排序顺序 |
| is_active | boolean | 是否激活 |
| created_at | string | 创建时间（ISO 8601） |
| updated_at | string | 更新时间（ISO 8601） |

### 使用场景

- App 启动时获取可用金币包列表
- 用户点击购买时显示当前可购买的金币包
- 支持多平台（Apple、Stripe、Google、PayPal）不同的金币包配置
- 按应用ID隔离金币包配置

### 请求示例

```bash
# 获取默认应用的所有激活金币包
curl "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/iap-coin-packages" \
  -H "apikey: ${ANON_KEY}"

# 获取特定应用的 Stripe 金币包
curl "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/iap-coin-packages?app_id=velour&platform=stripe" \
  -H "apikey: ${ANON_KEY}"

# 获取特定应用的 Apple 金币包
curl "https://lrenlgqppvqfbibxppbi.supabase.co/functions/v1/iap-coin-packages?app_id=default&platform=apple" \
  -H "apikey: ${ANON_KEY}"
```

### 响应示例

**成功响应**:
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "app_id": "default",
      "platform": "stripe",
      "product_id": "coins_275",
      "display_name": "275 coins",
      "description": "Get 275 coins to create amazing videos",
      "amount": 19.99,
      "currency": "usd",
      "platform_price_id": "price_xxxxx",
      "base_coins": 275,
      "bonus_percentage": 10,
      "bonus_coins": 27,
      "total_coins": 302,
      "tags": [],
      "sort_order": 1,
      "is_active": true,
      "created_at": "2026-01-17T10:00:00Z",
      "updated_at": "2026-01-17T10:00:00Z"
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "app_id": "default",
      "platform": "stripe",
      "product_id": "coins_550",
      "display_name": "550 coins + BONUS",
      "description": "Get 550 coins + 15% bonus (最值)",
      "amount": 34.99,
      "currency": "usd",
      "platform_price_id": "price_yyyyy",
      "base_coins": 550,
      "bonus_percentage": 15,
      "bonus_coins": 82,
      "total_coins": 632,
      "tags": ["POPULAR", "BEST VALUE"],
      "sort_order": 2,
      "is_active": true,
      "created_at": "2026-01-17T10:00:00Z",
      "updated_at": "2026-01-17T10:00:00Z"
    }
  ],
  "count": 2
}
```

**失败响应**:
```json
{
  "success": false,
  "data": [],
  "error": "数据库查询失败"
}
```

### 重要提示

⚠️ **公开接口**：此接口不需要认证，可直接调用
⚠️ **只返回激活的金币包**：`is_active=true` 的金币包才会返回
⚠️ **按排序顺序返回**：按 `sort_order` 升序排列
⚠️ **计算字段说明**：`bonus_coins` 和 `total_coins` 是自动计算的，客户端不需要手动计算
⚠️ **平台隔离**：同一应用的不同平台可配置不同的金币包列表
⚠️ **缓存建议**：建议App启动时缓存金币包列表，降低服务器压力

### 字段说明

- `base_coins`：基础金币数量，用户购买后立即获得
- `bonus_percentage`：奖励百分比，范围 0-100
  - 0% = 无奖励，只获得base_coins
  - 10% = base_coins * 0.1
  - 15% = base_coins * 0.15（最常见）
- `bonus_coins`：自动计算的奖励金币数，= FLOOR(base_coins * bonus_percentage / 100)
- `total_coins`：用户最终获得的总金币数 = base_coins + bonus_coins
- `tags`：用于UI标记特殊金币包（如"POPULAR"、"BEST VALUE"）

### 示例金币包配置

| 金币包 | 价格 | 基础金币 | 奖励 | 最终获得 | 标签 |
|--------|------|---------|------|---------|------|
| 275 coins | $19.99 | 275 | 10% | 302 | 无 |
| 550 coins | $34.99 | 550 | 15% | 632 | POPULAR, BEST VALUE |
| 1100 coins | $59.99 | 1100 | 15% | 1265 | 无 |
| 3000 coins | $149.99 | 3000 | 20% | 3600 | SUPER VALUE |

---
