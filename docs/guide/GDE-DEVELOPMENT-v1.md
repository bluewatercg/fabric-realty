# 二次开发快速指南

> 本文档提供页面微调和后端业务调整的具体开发步骤

---

## 目录

1. [页面 UI 微调](#1-页面-ui-微调)
2. [后端业务调整](#2-后端业务调整)
3. [数据模型扩展](#3-数据模型扩展)
4. [常见修改场景](#4-常见修改场景)

---

## 1. 页面 UI 微调

### 1.1 添加新的字段展示

#### 场景：在订单列表中增加"负责人"字段

**步骤 1：修改前端类型定义**

编辑 `application/web/src/types/index.ts`：

```typescript
export interface Order {
  id: string;
  oemId: string;
  manufacturerId: string;
  items: OrderItem[];
  status: OrderStatus;
  totalPrice: number;
  shipmentId: string;
  createTime: string;
  updateTime: string;
  // 新增字段
  manager?: string;  // 负责人
  department?: string;  // 部门
}
```

**步骤 2：修改页面列配置**

编辑对应的页面（如 `OEM.vue`）：

```vue
<script setup lang="ts">
const columns = [
  { title: '订单ID', dataIndex: 'id', key: 'id' },
  { title: '厂商ID', dataIndex: 'manufacturerId', key: 'manufacturerId' },
  { title: '负责人', dataIndex: 'manager', key: 'manager' },  // 新增
  { title: '部门', dataIndex: 'department', key: 'department' },  // 新增
  { title: '状态', key: 'status' },
  { title: '总价', key: 'totalPrice' },
  { title: '创建时间', dataIndex: 'createTime', key: 'createTime' },
  { title: '操作', key: 'action', width: 200 }
];
</script>
```

**步骤 3：在详情弹窗中展示**

```vue
<a-descriptions bordered v-if="selectedOrder">
  <a-descriptions-item label="订单ID">{{ selectedOrder.id }}</a-descriptions-item>
  <a-descriptions-item label="厂商ID">{{ selectedOrder.manufacturerId }}</a-descriptions-item>
  <a-descriptions-item label="负责人">{{ selectedOrder.manager || '--' }}</a-descriptions-item>
  <a-descriptions-item label="部门">{{ selectedOrder.department || '--' }}</a-descriptions-item>
  <!-- ... 其他字段 -->
</a-descriptions>
```

### 1.2 修改表单字段

#### 场景：创建订单时增加"优先级"字段

**步骤 1：修改类型定义**

```typescript
// application/web/src/types/index.ts
export interface Order {
  // ... 其他字段
  priority?: 'LOW' | 'MEDIUM' | 'HIGH';  // 优先级
}
```

**步骤 2：修改表单**

```vue
<!-- OEM.vue -->
<a-form :model="orderForm" layout="vertical">
  <a-form-item label="订单ID" required>
    <a-input v-model:value="orderForm.id" placeholder="请输入订单ID" />
  </a-form-item>
  <a-form-item label="零部件厂商ID" required>
    <a-input v-model:value="orderForm.manufacturerId" placeholder="请输入厂商ID" />
  </a-form-item>
  <!-- 新增优先级字段 -->
  <a-form-item label="优先级">
    <a-select v-model:value="orderForm.priority" placeholder="请选择优先级">
      <a-select-option value="LOW">低</a-select-option>
      <a-select-option value="MEDIUM">中</a-select-option>
      <a-select-option value="HIGH">高</a-select-option>
    </a-select>
  </a-form-item>
  <!-- ... 其他字段 -->
</a-form>
```

**步骤 3：修改 API 调用**

```typescript
// application/web/src/api/index.ts
export const supplyChainApi = {
  createOrder: (data: {
    id: string;
    manufacturerId: string;
    items: OrderItem[];
    priority?: string;  // 新增
  }) => request.post<never, void>('/oem/order/create', data),
  // ...
};
```

**步骤 4：修改表单数据结构**

```typescript
// OEM.vue
const orderForm = ref({
  id: '',
  manufacturerId: '',
  priority: 'MEDIUM',  // 默认值
  items: [{ name: '', quantity: 1, price: 0 }] as OrderItem[]
});
```

### 1.3 修改状态显示

#### 场景：新增"已取消"状态

**步骤 1：修改类型定义**

```typescript
export type OrderStatus =
  | 'CREATED'
  | 'ACCEPTED'
  | 'PRODUCING'
  | 'PRODUCED'
  | 'READY'
  | 'SHIPPED'
  | 'DELIVERED'
  | 'RECEIVED'
  | 'CANCELLED';  // 新增
```

**步骤 2：修改状态映射**

```typescript
// 在各个页面中
const getStatusColor = (status: string) => {
  const colorMap: Record<string, string> = {
    CREATED: 'blue',
    ACCEPTED: 'cyan',
    PRODUCING: 'orange',
    PRODUCED: 'purple',
    READY: 'geekblue',
    SHIPPED: 'gold',
    DELIVERED: 'lime',
    RECEIVED: 'green',
    CANCELLED: 'red',  // 新增
  };
  return colorMap[status] || 'default';
};

const getStatusText = (status: string) => {
  const textMap: Record<string, string> = {
    CREATED: '已创建',
    ACCEPTED: '已接受',
    PRODUCING: '生产中',
    PRODUCED: '已生产',
    READY: '待取货',
    SHIPPED: '运输中',
    DELIVERED: '已送达',
    RECEIVED: '已签收',
    CANCELLED: '已取消',  // 新增
  };
  return textMap[status] || status;
};
```

### 1.4 修改页面布局

#### 场景：在 OEM 页面顶部添加统计卡片

```vue
<!-- OEM.vue -->
<template>
  <div class="oem-page">
    <a-page-header
      title="主机厂 (OEM)"
      sub-title="发布采购订单并确认收货"
      @back="() => $router.push('/')"
    >
      <template #extra>
        <a-button type="primary" @click="showCreateModal = true">
          <PlusOutlined /> 创建订单
        </a-button>
      </template>
    </a-page-header>

    <div class="content">
      <!-- 新增统计卡片 -->
      <a-row :gutter="16" style="margin-bottom: 24px">
        <a-col :span="6">
          <a-statistic
            title="总订单数"
            :value="stats.total"
            value-style="{ color: '#1890ff' }"
          />
        </a-col>
        <a-col :span="6">
          <a-statistic
            title="进行中"
            :value="stats.inProgress"
            value-style="{ color: '#faad14' }"
          />
        </a-col>
        <a-col :span="6">
          <a-statistic
            title="已完成"
            :value="stats.completed"
            value-style="{ color: '#52c41a' }"
          />
        </a-col>
        <a-col :span="6">
          <a-statistic
            title="总金额"
            :value="stats.totalAmount"
            prefix="¥"
            :precision="2"
          />
        </a-col>
      </a-row>

      <!-- 订单列表 -->
      <a-card title="订单列表" :loading="loading">
        <!-- ... -->
      </a-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';

const orders = ref<Order[]>([]);

// 计算统计数据
const stats = computed(() => {
  const list = orders.value;
  return {
    total: list.length,
    inProgress: list.filter(o => !['RECEIVED', 'CANCELLED'].includes(o.status)).length,
    completed: list.filter(o => o.status === 'RECEIVED').length,
    totalAmount: list.reduce((sum, o) => sum + o.totalPrice, 0),
  };
});
</script>
```

---

## 2. 后端业务调整

### 2.1 添加新的业务接口

#### 场景：添加"取消订单"接口

**步骤 1：在链码中添加方法**

编辑 `chaincode/chaincode.go`：

```go
// CancelOrder 取消订单 (仅 OEM 可调用)
func (s *SmartContract) CancelOrder(ctx contractapi.TransactionContextInterface, id string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != OEM_ORG_MSPID {
        return fmt.Errorf("无权限: 仅限主机厂取消订单")
    }

    orderBytes, err := ctx.GetStub().GetState(id)
    if err != nil || orderBytes == nil {
        return fmt.Errorf("订单 %s 不存在", id)
    }

    var order Order
    json.Unmarshal(orderBytes, &order)

    // 检查是否可以取消
    if order.Status == ORDER_RECEIVED {
        return fmt.Errorf("订单已签收，无法取消")
    }
    if order.Status == "CANCELLED" {
        return fmt.Errorf("订单已取消")
    }

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }

    order.Status = "CANCELLED"
    order.UpdateTime = now

    newOrderBytes, _ := json.Marshal(order)
    return ctx.GetStub().PutState(id, newOrderBytes)
}
```

**步骤 2：在 Service 层添加方法**

编辑 `application/server/service/supply_chain_service.go`：

```go
// CancelOrder 取消订单
func (s *SupplyChainService) CancelOrder(id string) error {
    contract := fabric.GetContract(OEM_ORG)
    _, err := submitWithRetry(contract, "CancelOrder", id)
    if err != nil {
        return fmt.Errorf("取消订单失败：%s", fabric.ExtractErrorMessage(err))
    }
    return nil
}
```

**步骤 3：在 API 层添加 Handler**

编辑 `application/server/api/supply_chain.go`：

```go
// CancelOrder 取消订单
// @Summary 取消订单
// @Description OEM 取消未完成的订单
// @Tags OEM
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Success 200 {object} utils.Response
// @Router /api/oem/order/{id}/cancel [put]
func (h *SupplyChainHandler) CancelOrder(c *gin.Context) {
    id := c.Param("id")
    if err := h.scService.CancelOrder(id); err != nil {
        log.Printf("CancelOrder Error: %v", err)
        utils.ServerError(c, err.Error())
        return
    }
    utils.SuccessWithMessage(c, "订单已取消", nil)
}
```

**步骤 4：注册路由**

编辑 `application/server/main.go`：

```go
oemGroup := apiGroup.Group("/oem")
{
    oemGroup.POST("/order/create", scHandler.CreateOrder)
    oemGroup.PUT("/order/:id/cancel", scHandler.CancelOrder)  // 新增
    oemGroup.PUT("/order/:id/receive", scHandler.ConfirmReceipt)
    // ...
}
```

**步骤 5：前端调用**

编辑 `application/web/src/api/index.ts`：

```typescript
export const supplyChainApi = {
  // ...
  cancelOrder: (id: string) =>
    request.put<never, void>(`/oem/order/${id}/cancel`),
  // ...
};
```

在页面中添加按钮：

```vue
<a-button
  v-if="['CREATED', 'ACCEPTED', 'PRODUCING', 'PRODUCED'].includes(record.status)"
  danger
  size="small"
  @click="cancelOrder(record.id)"
>
  取消订单
</a-button>
```

### 2.2 修改业务逻辑

#### 场景：限制订单总价不能超过 100 万

**步骤 1：修改链码逻辑**

```go
// CreateOrder 主机厂创建订单
func (s *SmartContract) CreateOrder(ctx contractapi.TransactionContextInterface, id string, manufacturerId string, itemsJson string) error {
    // ... 原有代码

    var totalPrice float64
    for _, item := range items {
        totalPrice += float64(item.Quantity) * item.Price
    }

    // 新增：总价限制
    if totalPrice > 1000000 {
        return fmt.Errorf("订单总价超过限制（100万元）")
    }

    // ... 后续代码
}
```

### 2.3 添加数据验证

#### 场景：验证零件名称不能为空

**步骤 1：修改链码**

```go
// CreateOrder
var items []OrderItem
if err := json.Unmarshal([]byte(itemsJson), &items); err != nil {
    return fmt.Errorf("解析零件清单失败: %v", err)
}

// 新增：验证零件名称
for i, item := range items {
    if strings.TrimSpace(item.Name) == "" {
        return fmt.Errorf("第 %d 个零件名称不能为空", i+1)
    }
    if item.Quantity <= 0 {
        return fmt.Errorf("第 %d 个零件数量必须大于0", i+1)
    }
    if item.Price < 0 {
        return fmt.Errorf("第 %d 个零件单价不能为负数", i+1)
    }
}
```

---

## 3. 数据模型扩展

### 3.1 扩展订单字段

#### 场景：增加订单备注和交付日期

**步骤 1：修改链码数据模型**

```go
// chaincode/chaincode.go
type Order struct {
    ID             string      `json:"id"`
    ObjectType     string      `json:"objectType"`
    OEMID          string      `json:"oemId"`
    ManufacturerID string      `json:"manufacturerId"`
    Items          []OrderItem `json:"items"`
    Status         OrderStatus `json:"status"`
    TotalPrice     float64     `json:"totalPrice"`
    ShipmentID     string      `json:"shipmentId"`
    CreateTime     time.Time   `json:"createTime"`
    UpdateTime     time.Time   `json:"updateTime"`
    // 新增字段
    Remark         string      `json:"remark"`         // 备注
    DeliveryDate   string      `json:"deliveryDate"`   // 交付日期（YYYY-MM-DD）
    Priority       string      `json:"priority"`       // 优先级：LOW/MEDIUM/HIGH
}
```

**步骤 2：修改 CreateOrder 方法**

```go
func (s *SmartContract) CreateOrder(
    ctx contractapi.TransactionContextInterface,
    id string,
    manufacturerId string,
    itemsJson string,
    remark string,      // 新增
    deliveryDate string, // 新增
) error {
    // ... 原有逻辑

    order := Order{
        ID:             id,
        ObjectType:     ORDER,
        OEMID:          clientMSPID,
        ManufacturerID: manufacturerId,
        Items:          items,
        Status:         ORDER_CREATED,
        TotalPrice:     totalPrice,
        CreateTime:     now,
        UpdateTime:     now,
        Remark:         remark,         // 新增
        DeliveryDate:   deliveryDate,   // 新增
        Priority:       "MEDIUM",       // 新增，默认值
    }

    // ... 后续代码
}
```

**步骤 3：修改前端类型和表单**

```typescript
// application/web/src/types/index.ts
export interface Order {
  // ... 原有字段
  remark?: string;
  deliveryDate?: string;
  priority?: string;
}
```

```vue
<!-- OEM.vue 表单 -->
<a-form-item label="备注">
  <a-textarea
    v-model:value="orderForm.remark"
    placeholder="请输入订单备注"
    :rows="3"
  />
</a-form-item>
<a-form-item label="交付日期">
  <a-date-picker
    v-model:value="orderForm.deliveryDate"
    style="width: 100%"
  />
</a-form-item>
```

### 3.2 扩展物流单字段

#### 场景：增加物流预计到达时间

**步骤 1：修改链码**

```go
type Shipment struct {
    ID         string    `json:"id"`
    ObjectType string    `json:"objectType"`
    OrderID    string    `json:"orderId"`
    CarrierID  string    `json:"carrierId"`
    Location   string    `json:"location"`
    Status     string    `json:"status"`
    UpdateTime time.Time `json:"updateTime"`
    // 新增
    EstimatedArrivalTime string `json:"estimatedArrivalTime"` // 预计到达时间
    Distance             int    `json:"distance"`             // 运输距离（公里）
}
```

---

## 4. 常见修改场景

### 4.1 修改列表默认排序

```typescript
// 在页面组件中添加排序逻辑
const columns = [
  {
    title: '创建时间',
    dataIndex: 'createTime',
    key: 'createTime',
    sorter: true,  // 启用排序
    sortOrder: 'descend',  // 默认降序
  },
  // ...
];
```

### 4.2 添加搜索功能

```vue
<template>
  <div class="search-bar">
    <a-input
      v-model:value="searchKeyword"
      placeholder="搜索订单ID"
      style="width: 200px"
      @change="handleSearch"
    />
    <a-select
      v-model:value="searchStatus"
      placeholder="选择状态"
      style="width: 150px; margin-left: 10px"
      @change="handleSearch"
    >
      <a-select-option value="">全部</a-select-option>
      <a-select-option value="CREATED">已创建</a-select-option>
      <!-- ... 其他状态 -->
    </a-select>
  </div>
</template>

<script setup lang="ts">
const searchKeyword = ref('');
const searchStatus = ref('');

const filteredOrders = computed(() => {
  return orders.value.filter(order => {
    const matchKeyword = order.id.includes(searchKeyword.value);
    const matchStatus = !searchStatus.value || order.status === searchStatus.value;
    return matchKeyword && matchStatus;
  });
});
</script>
```

### 4.3 添加导出功能

```typescript
import * as XLSX from 'xlsx';

const exportToExcel = () => {
  const data = orders.value.map(order => ({
    '订单ID': order.id,
    '状态': getStatusText(order.status),
    '总价': order.totalPrice,
    '创建时间': order.createTime,
  }));

  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, '订单列表');
  XLSX.writeFile(wb, 'orders.xlsx');
};
```

### 4.4 添加批量操作

```vue
<template>
  <a-table
    :row-selection="rowSelection"
    :data-source="orders"
  />
  <a-button
    type="primary"
    :disabled="selectedRowKeys.length === 0"
    @click="batchCancel"
  >
    批量取消 ({{ selectedRowKeys.length }})
  </a-button>
</template>

<script setup lang="ts">
const selectedRowKeys = ref<string[]>([]);

const rowSelection = {
  selectedRowKeys,
  onChange: (keys: string[]) => {
    selectedRowKeys.value = keys;
  },
};

const batchCancel = async () => {
  for (const orderId of selectedRowKeys.value) {
    await supplyChainApi.cancelOrder(orderId);
  }
  message.success(`成功取消 ${selectedRowKeys.value.length} 个订单`);
  selectedRowKeys.value = [];
  loadOrders();
};
</script>
```

---

## 5. 测试与调试

### 5.1 本地测试流程

1. **启动 Fabric 网络**
   ```bash
   cd network
   ./install.sh
   ```

2. **启动后端**
   ```bash
   cd application/server
   go run main.go
   ```

3. **启动前端**
   ```bash
   cd application/web
   npm run dev
   ```

4. **测试功能**
   - 打开浏览器访问 http://localhost:5173
   - 按照业务流程测试新功能

### 5.2 调试技巧

#### 后端调试

```go
// 添加日志
log.Printf("DEBUG: 请求参数 - %+v", req)
```

#### 前端调试

```typescript
console.log('订单数据:', orders.value);
```

#### 区块链调试

```bash
# 查询链上数据
docker exec -it cli bash
peer chaincode query -C mychannel -n mychaincode -c '{"Args":["QueryOrder","ORDER-001"]}'
```

---

## 6. 部署更新

### 6.1 更新链码

```bash
# 重新部署网络（简单方案）
cd network
./uninstall.sh
./install.sh
```

### 6.2 更新后端

```bash
cd application/server
docker build -t togettoyou/fabric-realty.server:latest .
# 重启容器
docker-compose restart fabric-realty.server
```

### 6.3 更新前端

```bash
cd application/web
docker build -t togettoyou/fabric-realty.web:latest .
# 重启容器
docker-compose restart fabric-realty.web
```

---

**文档版本：** v1.0
**更新日期：** 2024-12-24
