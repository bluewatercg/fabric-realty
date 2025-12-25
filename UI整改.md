
---

# **监管系统 UI 设计文档（Markdown 版）**  
**Hyperledger Fabric 区块链历史记录监管视图设计**

---

# **目录**

1. 概述  
2. 设计目标  
3. 页面结构总览  
4. 时间轴（Timeline）设计  
5. JSON 展开视图设计  
6. Diff（Git 风格）对比视图设计  
7. 交互流程  
8. 前端组件结构  
9. 后端 API 结构设计  
10. 字段级 Diff 算法设计  
11. UI 草图（接近 Figma 风格）  
12. 监管视角下的价值  

---

# **1. 概述**

本设计文档用于指导监管系统前端展示 Hyperledger Fabric 区块链历史记录（Blockchain History）。  
目标是让监管人员能够：

- 清晰查看每次链上写入的历史记录  
- 快速定位“改了什么”  
- 查看完整 JSON 数据  
- 审计不可篡改的链上交易  

采用 **时间轴（Timeline） + JSON 展开 + Git 风格 Diff** 的组合展示方式。

---

# **2. 设计目标**

| 目标 | 描述 |
|------|------|
| 可读性 | 历史记录清晰、结构化展示 |
| 可审计性 | 每次变更可追踪、可对比 |
| 可监管性 | 展示 TxID、时间戳、删除标记 |
| 可扩展性 | 支持更多字段、更多对象类型 |
| 可用性 | 操作简单、交互直观 |

---

# **3. 页面结构总览**

```
┌───────────────────────────────────────────────────────────────┐
│                        订单历史记录（Blockchain）              │
├───────────────────────────────────────────────────────────────┤
│  Timeline（左）                                                │
│     └── 历史节点（每次交易）                                   │
│           ├── 元数据（TxID、时间戳、isDelete）                │
│           ├── JSON 展开视图（Tree）                           │
│           └── Diff 对比视图（Git 风格）                       │
└───────────────────────────────────────────────────────────────┘
```

---

# **4. 时间轴（Timeline）设计**

### **4.1 节点展示结构**

```
● 2025-12-26 08:30:12   SHIPPED
   TxID: 3ac9...
   isDelete: false
   [ 展开 JSON ▼ ]  [ 展开 Diff ▼ ]
```

### **4.2 字段说明**

| 字段 | 来源 | 说明 |
|------|------|------|
| 时间戳 | Blockchain | 交易写入区块的时间 |
| 状态 | value.status | 从链码数据中提取 |
| TxID | Blockchain | 审计必需 |
| isDelete | Blockchain | 是否为删除操作 |

---

# **5. JSON 展开视图设计**

### **5.1 展示方式**

```
▼ JSON（当前版本）
{
  "id": "123",
  "status": "SHIPPED",
  "totalPrice": 246,
  "shipmentId": "ABC123",
  "items": [...],
  "updateTime": "2025-12-26T08:30:12Z"
}
```

### **5.2 设计要求**

- 使用 Tree View（树形结构）  
- 支持折叠/展开字段  
- JSON 自动格式化  
- key/value 使用不同颜色  

---

# **6. Diff（Git 风格）对比视图设计**

### **6.1 展示方式**

```
▼ Diff（与上一版本对比）

- "status": "CREATED"
+ "status": "SHIPPED"

+ "shipmentId": "ABC123"

  "totalPrice": 246

- "updateTime": "2025-12-25T05:27:39Z"
+ "updateTime": "2025-12-26T08:30:12Z"
```

### **6.2 样式规范**

| 类型 | 样式 |
|------|------|
| `+` 新增/修改后 | 绿色背景 |
| `-` 删除/修改前 | 红色背景 |
| 未变化 | 灰色或默认色 |

### **6.3 对比规则**

- 字段新增 → `+`  
- 字段删除 → `-`  
- 字段修改 → `- old` + `+ new`  
- 字段未变化 → 可隐藏  

---

# **7. 交互流程**

### **7.1 用户操作流程**

1. 用户进入“订单历史记录”页面  
2. 左侧看到 Timeline  
3. 点击某个历史节点  
4. 展开 JSON（完整 value）  
5. JSON 下方自动展示 Diff（与上一版本）  
6. 用户可切换到其他节点继续查看  

### **7.2 交互要求**

- Timeline 节点可点击  
- JSON 和 Diff 可独立展开/折叠  
- Diff 自动与上一版本对比  
- 支持分页（历史记录多时）  

---

# **8. 前端组件结构**

```
HistoryTimeline
   ├── TimelineItem
   │     ├── MetadataPanel
   │     ├── JsonViewer (Tree)
   │     └── DiffViewer (Git Style)
   └── Pagination
```

---

# **9. 后端 API 结构设计**

### **9.1 API 返回结构（推荐）**

```json
[
  {
    "txId": "0a63...",
    "timestamp": "2025-12-25T05:27:39Z",
    "isDelete": false,
    "value": {
      "id": "123",
      "status": "CREATED",
      "totalPrice": 246
    },
    "diff": {
      "status": { "old": "PENDING", "new": "CREATED" },
      "totalPrice": { "old": 246, "new": 246 }
    }
  }
]
```

### **9.2 字段说明**

| 字段 | 说明 |
|------|------|
| value | 当前版本的完整 JSON |
| diff | 与上一版本的字段级差异 |
| txId | 区块链交易 ID |
| timestamp | 写入时间 |
| isDelete | 是否删除 |

---

# **10. 字段级 Diff 算法设计**

### **10.1 Diff 规则**

| 情况 | diff 输出 |
|------|-----------|
| 字段新增 | `{ old: null, new: value }` |
| 字段删除 | `{ old: value, new: null }` |
| 字段修改 | `{ old: oldValue, new: newValue }` |
| 字段未变化 | `{ old: value, new: value }`（前端可隐藏） |

---

### **10.2 Diff 伪代码**

```js
function diffObjects(oldObj, newObj) {
  const diff = {};

  const allKeys = new Set([
    ...Object.keys(oldObj),
    ...Object.keys(newObj)
  ]);

  for (const key of allKeys) {
    const oldVal = oldObj[key];
    const newVal = newObj[key];

    if (oldVal === undefined && newVal !== undefined) {
      diff[key] = { old: null, new: newVal };
      continue;
    }

    if (oldVal !== undefined && newVal === undefined) {
      diff[key] = { old: oldVal, new: null };
      continue;
    }

    if (isObject(oldVal) && isObject(newVal)) {
      const nested = diffObjects(oldVal, newVal);
      if (Object.keys(nested).length > 0) {
        diff[key] = nested;
      }
      continue;
    }

    if (oldVal !== newVal) {
      diff[key] = { old: oldVal, new: newVal };
      continue;
    }

    diff[key] = { old: oldVal, new: newVal };
  }

  return diff;
}
```

---

# **11. UI 草图（接近 Figma 风格）**

```
● 2025-12-26 08:30:12   SHIPPED
   TxID: 3ac9...
   isDelete: false

   ▼ JSON（当前版本）
   {
     "status": "SHIPPED",
     "shipmentId": "ABC123",
     "totalPrice": 246,
     ...
   }

   ▼ Diff（与上一版本）
   - "status": "CREATED"
   + "status": "SHIPPED"
   + "shipmentId": "ABC123"
     "totalPrice": 246
```

---

# **12. 监管视角下的价值**

| 监管需求 | 本方案如何满足 |
|----------|----------------|
| 快速定位变更 | Diff 直接展示“改了什么” |
| 查看完整数据 | JSON 展开提供完整 value |
| 审计链上不可篡改历史 | Timeline 展示所有 Tx |
| 追踪责任人 | TxID 可关联 MSP 身份 |
| 适合大量历史记录 | Timeline + 分页 |

---
