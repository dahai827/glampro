# 3️⃣0️⃣ 设备指纹参数规范（Web + iOS + Server）

### 文档目的

本规范用于统一 `W2A` 归因链路中的设备指纹字段，供后端与 iOS 开发对齐实现。  
`IP` 不属于设备指纹字段，统一由服务端从请求中获取。

---

### 字段清单（固定 9 个）

1. `device_type`
2. `os_family`
3. `os_major`
4. `language`
5. `screen_bucket`
6. `pixel_ratio_bucket`
7. `color_depth`
8. `max_touch_points`
9. `device_model_bucket`

---

### 字段定义与采集方式

| 字段 | 类型 | 示例 | Web 获取 | iOS 获取 | 说明 |
|------|------|------|----------|----------|------|
| `device_type` | string | `phone` | UA + 屏幕短边判断 | `UIDevice.current.userInterfaceIdiom` | 取值：`phone`/`tablet`/`desktop` |
| `os_family` | string | `ios` | UA 解析 | `UIDevice.current.systemName` 归一化 | 固定归一化：`ios`/`android`/`unknown` |
| `os_major` | string | `18` | UA 解析主版本 | `UIDevice.current.systemVersion` 取主版本 | 仅主版本号，取不到用 `unknown` |
| `language` | string | `en-us` | `navigator.language` | `Locale.preferredLanguages.first` | 全部转小写，`_` 转 `-` |
| `screen_bucket` | string | `390x840` | `screen.width/height` 分桶 | `UIScreen.main.bounds`（points）分桶 | 分桶规则见下文 |
| `pixel_ratio_bucket` | string | `3x` | `window.devicePixelRatio` | `UIScreen.main.scale` | 分桶：`1x`/`2x`/`3x`/`4x+` |
| `color_depth` | number | `24` | `screen.colorDepth` | iOS 固定填 `24` | 取不到可回退 `24` |
| `max_touch_points` | number | `5` | `navigator.maxTouchPoints` | iPhone 建议 `5`，iPad 建议 `5` | 取不到可回退 `5` |
| `device_model_bucket` | string | `iphone_pro_max` | 通常不可用，填 `unknown` | `hw.machine` 映射分桶 | 机型分桶，不上传精确型号 |

---

### 归一化规则（必须一致）

1. 缺失值：统一填 `unknown`（数值字段按回退值填充）。
2. 字符串：去首尾空格，转小写。
3. `language`：`en_US` -> `en-us`。
4. `screen_bucket`：
   - 使用逻辑分辨率（points/CSS pixels），不是物理像素。
   - 计算短边和长边，分别按 `20` 为步长四舍五入。
   - 结果格式：`{shortBucket}x{longBucket}`，如 `390x840`。
5. `pixel_ratio_bucket`：
   - `<1.5 => 1x`
   - `<2.5 => 2x`
   - `<3.5 => 3x`
   - `>=3.5 => 4x+`

---

### `device_model_bucket` 建议分桶（iOS）

只传分桶，不传具体型号（如 `iPhone15,3`）。

- `iphone_standard`
- `iphone_plus`
- `iphone_pro`
- `iphone_pro_max`
- `iphone_se`
- `ipad`
- `unknown`

---

### 指纹签名规则（用于后端索引/去重）

```text
fingerprint_sig_v1 = SHA256(stable_json(fingerprint_v1))
```

要求：

1. `stable_json` 必须按 key 字典序排序。
2. 不参与签名的字段不要混入（例如 event_time、click_id、ip）。
3. `fingerprint_v1` 仅包含本规范 9 个字段。

---

### Web 请求示例

```json
{
  "fingerprint_v1": {
    "device_type": "phone",
    "os_family": "ios",
    "os_major": "18",
    "language": "en-us",
    "screen_bucket": "390x840",
    "pixel_ratio_bucket": "3x",
    "color_depth": 24,
    "max_touch_points": 5,
    "device_model_bucket": "unknown"
  },
  "fingerprint_sig_v1": "ab12cd..."
}
```

### iOS 请求示例

```json
{
  "fingerprint_v1": {
    "device_type": "phone",
    "os_family": "ios",
    "os_major": "18",
    "language": "en-us",
    "screen_bucket": "390x840",
    "pixel_ratio_bucket": "3x",
    "color_depth": 24,
    "max_touch_points": 5,
    "device_model_bucket": "iphone_pro_max"
  },
  "fingerprint_sig_v1": "ef34gh..."
}
```

---

### 服务端处理要求

1. `IP` 与 `ip_prefix` 只从服务端请求上下文获取，不信任客户端传入 IP。
2. 入库前再次做字段归一化，避免端侧实现差异。
3. 对未知值保持兼容，不因为单字段缺失拒绝归因。
4. 打分匹配时建议：`IP前缀 + 时间窗口 + 指纹字段` 联合判断。

---

### 对齐检查清单

1. Web 与 iOS 是否只上报这 9 个字段。
2. `screen_bucket` 是否都基于逻辑分辨率。
3. `os_major` 是否仅主版本（如 `18`）。
4. `device_model_bucket` 是否只在 iOS 真实分桶，Web 固定 `unknown`。
5. 后端计算 `fingerprint_sig_v1` 与端侧是否一致。
