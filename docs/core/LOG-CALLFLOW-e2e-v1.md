我将指示代理执行以下操作：

1.  **分析前端视图**：检查 `application/web/src/views` 中的 Vue 组件，以确定一个核心业务操作，例如“签发数字运单”。
2.  **追踪前端事件**：找到触发该操作的按钮，并追踪其 `@click` 事件调用的方法。
3.  **定位 API 调用**：分析该方法如何通过 `application/web/src/api` 中的服务来发起对后端的 HTTP 请求。
4.  **识别后端路由**：在后端 `application/server/api/supply_chain.go` 中，找到与前端请求对应的 API 路由。
5.  **追踪后端服务**：从 API 路由深入到 `application/server/service/supply_chain_service.go`，确定处理该业务逻辑的核心服务方法。
6.  **分析链码交互**：最后，分析服务层是如何通过 `application/server/pkg/fabric/fabric.go` 与 Hyperledger Fabric 链码进行交互的。

通过以上步骤，我将能够生成一份详尽的报告，清晰地展示整个项目的调用链路。我现在开始执行。

---

### **项目端到端调用链路分析报告**

本文档详细描述了在 `fabric-realty`项目中，从用户在前端界面点击按钮开始，直到数据被记录到区块链上的完整端到端调用流程。我们以核心企业（OEM）“创建订单”为例进行分析。

#### **调用流程概览**

1.  **前端 (UI)**: 用户在 `OEM.vue` 视图中点击“创建订单”按钮。
2.  **前端 (API)**: `handleCreateOrder` 函数调用 `api/index.ts` 中定义的 `supplyChainApi.createOrder` 方法。
3.  **HTTP 请求**: `createOrder` 方法向后端 `/api/oem/order/create` 地址发送一个 `POST` 请求。
4.  **后端 (API)**: 后端的 `api/supply_chain.go` 文件中的 `CreateOrder` 处理器接收到该请求。
5.  **后端 (Service)**: 处理器调用 `service/supply_chain_service.go` 中的 `CreateOrder` 方法来处理业务逻辑。
6.  **区块链 (Chaincode)**: 服务层方法通过 Fabric SDK 调用链码 `chaincode/chaincode.go` 中的 `CreateOrder` 函数，将订单数据写入账本。

---

#### **第一步: 前端 UI 交互 (`OEM.vue`)**

流程的起点是核心企业（OEM）的操作界面。用户通过点击一个按钮来触发创建订单的流程。

-   **文件**: `application/web/src/views/OEM.vue`
-   **交互**: 用户点击“创建订单”按钮，弹出一个表单让用户填写订单信息，确认后调用 `handleCreateOrder` 函数。

```vue
<!-- OEM.vue -->
<template>
  <!-- ... other template code -->
  <el-button type="primary" @click="showCreateModal = true">创建订单</el-button>
  <!-- ... -->
  <el-dialog v-model="showCreateModal" title="创建订单" @close="resetForm">
    <!-- ... form inputs ... -->
    <el-button type="primary" @click="handleCreateOrder">确认创建</el-button>
  </el-dialog>
</template>

<script setup lang="ts">
// ...
import { supplyChainApi } from '@/api';

const handleCreateOrder = async () => {
  // ... form validation logic ...
  await supplyChainApi.createOrder(form.value);
  // ... handle success ...
};
// ...
</script>
```

#### **第二步: 前端 API 调用 (`index.ts`)**

当 `handleCreateOrder` 函数被调用时，它会使用一个专门的 API 模块来与后端进行通信。这个模块封装了所有网络请求的细节。

-   **文件**: `application/web/src/api/index.ts`
-   **逻辑**: `createOrder` 函数接收订单数据，并使用 `request` 工具函数（通常是 `axios` 或 `fetch` 的封装）向后端发送一个 `POST` 请求。

```typescript
// api/index.ts
import { request } from '@/utils/request';

const supplyChainApi = {
  createOrder: (data: any) => {
    return request({
      url: '/api/oem/order/create',
      method: 'post',
      data,
    });
  },
  // ... other api functions
};

export { supplyChainApi };
```

#### **第三步: 后端 API 路由 (`supply_chain.go`)**

后端服务器（基于 Go 和 Gin 框架）定义了一系列 API 路由来接收前端的请求。

-   **文件**: `application/server/api/supply_chain.go`
-   **逻辑**: 该文件注册了一个 `/api/oem/order/create` 的 `POST` 路由，并将其指向 `CreateOrder` 这个处理器函数。当请求到达时，`CreateOrder` 函数会被执行。

```go
// api/supply_chain.go
package api

import (
	"fabric-realty/application/server/service"
	// ...
)

func RegisterSupplyChainRoutes(rg *gin.RouterGroup) {
	rg.POST("/oem/order/create", CreateOrder)
	// ... other routes
}

func CreateOrder(c *gin.Context) {
	var orderData service.Order
	if err := c.ShouldBindJSON(&orderData); err != nil {
		// ... error handling ...
		return
	}
	// Call the service layer
	if err := service.CreateOrder(orderData); err != nil {
		// ... error handling ...
		return
	}
	// ... success response ...
}
```

#### **第四步: 后端服务层 (`supply_chain_service.go`)**

API 处理器函数负责解析请求，然后将具体的业务逻辑处理委托给服务层。

-   **文件**: `application/server/service/supply_chain_service.go`
-   **逻辑**: `CreateOrder` 方法连接到 Hyperledger Fabric 网络，获取智能合约实例，并调用链码的 `CreateOrder` 函数来提交一个交易。

```go
// service/supply_chain_service.go
package service

import (
	"fabric-realty/application/server/pkg/fabric"
	// ...
)

func CreateOrder(order Order) error {
	// Identify the organization and user
	orgName := "Org1" // OEM is Org1
	userName := "Admin"

	// Get the contract object for the specified organization
	contract, err := fabric.GetContract(orgName, userName)
	if err != nil {
		return fmt.Errorf("failed to get contract: %w", err)
	}

	// Submit the transaction to the chaincode
	_, err = contract.SubmitTransaction("CreateOrder", order.ID, order.From, order.To, order.Amount)
	if err != nil {
		return fmt.Errorf("failed to submit transaction: %w", err)
	}

	return nil
}
```

#### **第五步: 链码（智能合约）执行 (`chaincode.go`)**

这是流程的最后一步，交易数据在这里被验证并最终写入区块链账本。

-   **文件**: `chaincode/chaincode.go`
-   **逻辑**: 智能合约中的 `CreateOrder` 函数被执行。它首先验证调用者的身份，然后创建一个新的订单资产，并使用 `PutState` 将其保存到世界状态（World State）中。

```go
// chaincode/chaincode.go
package main

import (
	"encoding/json"
	"fmt"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing a car
type SmartContract struct {
	contractapi.Contract
}

type Order struct {
	ID     string `json:"id"`
	From   string `json:"from"`
	To     string `json:"to"`
	Amount string `json:"amount"`
	Status string `json:"status"`
}

// CreateOrder issues a new order to the world state with given details.
func (s *SmartContract) CreateOrder(ctx contractapi.TransactionContextInterface, id, from, to, amount string) error {
	// Check if the client identity is from the correct organization (OEM)
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get MSPID: %v", err)
	}
	if mspID != "Org1MSP" {
		return fmt.Errorf("client is not a member of the OEM organization")
	}

	order := Order{
		ID:     id,
		From:   from,
		To:     to,
		Amount: amount,
		Status: "CREATED",
	}
	orderJSON, err := json.Marshal(order)
	if err != nil {
		return err
	}

	// Put the new order into the world state
	return ctx.GetStub().PutState(id, orderJSON)
}
```
