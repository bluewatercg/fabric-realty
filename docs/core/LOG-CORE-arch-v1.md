# 汽配供应链协同系统 - 详细技术文档

> 文档版本：v1.0
> 更新日期：2024-12-24
> 本文档提供系统架构、接口定义、数据结构、部署及二次开发的完整指南

---

## 目录

1. [系统概述](#1-系统概述)
2. [技术架构](#2-技术架构)
3. [环境配置](#3-环境配置)
4. [智能合约开发指南](#4-智能合约开发指南)
5. [后端开发指南](#5-后端开发指南)
6. [前端开发指南](#6-前端开发指南)
7. [API 接口文档](#7-api-接口文档)
8. [数据模型](#8-数据模型)
9. [部署指南](#9-部署指南)
10. [常见问题与调试](#10-常见问题与调试)

---

## 1. 系统概述

### 1.1 业务场景

本系统是一个基于 Hyperledger Fabric 的汽车零部件供应链协同平台，实现了从订单下达、生产管理、物流配送到签收确认的全程区块链溯源。

### 1.2 角色定义

| 逻辑角色 | 物理组织 | 组织ID (MSPID) | 主要职责 |
|---------|---------|----------------|---------|
| 主机厂 (OEM) | Org1 | Org1MSP | 发布采购订单、确认收货 |
| 零部件厂商 (Manufacturer) | Org2 | Org2MSP | 接受订单、更新生产状态 |
| 承运商 (Carrier) | Org3 | Org3MSP | 取货、更新物流位置 |
| 物流平台 (Platform) | Org3 | Org3MSP | 供应链全景监管、查询历史 |

### 1.3 业务流程

```
[OEM] 创建订单 → [Manufacturer] 接受订单 → [Manufacturer] 更新生产状态
    ↓
[Manufacturer] 标记待取货 → [Carrier] 取货生成物流单 → [Carrier] 更新位置
    ↓
[Carrier] 送达 → [OEM] 确认收货 → [Platform] 审计追踪
```

### 1.4 订单状态机

| 状态 | 说明 | 触发条件 | 触发角色 |
|-----|------|---------|---------|
| CREATED | 已创建 | 下单 | OEM |
| ACCEPTED | 已接受 | 接受订单 | Manufacturer |
| PRODUCING | 生产中 | 开始生产 | Manufacturer |
| PRODUCED | 已生产 | 完成生产 | Manufacturer |
| READY | 待取货 | 准备发货 | Manufacturer |
| SHIPPED | 运输中 | 取货发货 | Carrier |
| DELIVERED | 已送达 | 到达目的地 | Carrier |
| RECEIVED | 已签收 | 确认收货 | OEM |

---

## 2. 技术架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      前端层 (Vue 3)                          │
│  ┌──────┐  ┌──────────┐  ┌────────┐  ┌──────────┐         │
│  │ OEM  │  │Manufacturer│  │Carrier │  │Platform │         │
│  └──┬───┘  └────┬─────┘  └───┬────┘  └────┬─────┘         │
└─────┼────────────┼────────────┼────────────┼───────────────┘
      │            │            │            │
      └────────────┴────────────┴────────────┘
                           │
                    ┌──────▼──────┐
                    │ API Gateway │
                    │  (Gin 8888) │
                    └──────┬──────┘
                           │
┌──────────────────────────┼──────────────────────────────────┐
│         后端层 (Go 1.23)  │                                  │
│  ┌────────────────────────────────────────┐                │
│  │  Service Layer (业务逻辑)              │                │
│  └────────────┬───────────────────────────┘                │
│  ┌────────────▼───────────────────────────┐                │
│  │  Fabric Gateway SDK (合约调用)          │                │
│  └────────────┬───────────────────────────┘                │
└───────────────┼────────────────────────────────────────────┘
                │
    ┌───────────┼───────────┬───────────┐
    │           │           │           │
┌───▼───┐   ┌──▼────┐  ┌──▼──────┐  ┌──▼──────┐
│ Org1  │   │ Org2  │  │ Org3    │  │Orderer  │
│ Peer  │   │ Peer  │  │ Peer    │  │Raft集群 │
└───────┘   └───────┘  └─────────┘  └─────────┘
```

### 2.2 技术栈

#### 区块链层
- **Hyperledger Fabric**: v2.5.10
- **共识机制**: Raft (etcdraft)
- **通道配置**: 3个组织，单通道 mychannel
- **智能合约**: Fabric Contract API Go v2

#### 后端层
- **语言**: Go 1.23.4
- **Web框架**: Gin v1.10.0
- **Fabric SDK**: Fabric Gateway SDK v1.7.0
- **持久化**: BoltDB (用于区块事件存储)
- **配置管理**: YAML (gopkg.in/yaml.v3)
- **API文档**: Swagger (gin-swagger)

#### 前端层
- **框架**: Vue 3.3.8 (Composition API)
- **构建工具**: Vite 4.5.0
- **语言**: TypeScript 5.0.2
- **UI库**: Ant Design Vue 3.2.20
- **路由**: Vue Router 4.2.5
- **状态管理**: Pinia 2.1.7
- **HTTP客户端**: Axios 1.6.2

#### 容器化
- **容器引擎**: Docker
- **编排工具**: Docker Compose
- **基础镜像**: 
  - 后端: golang:1.23.4-alpine → alpine:3.21
  - 前端: nginx:alpine

### 2.3 目录结构

```
fabric-realty/
├── network/                          # Fabric 网络配置
│   ├── configtx.yaml                 # 通道配置
│   ├── crypto-config.yaml            # 证书配置
│   ├── docker-compose.yaml           # 网络编排
│   ├── install.sh                    # 网络安装脚本
│   └── uninstall.sh                  # 网络卸载脚本
│
├── chaincode/                        # 智能合约
│   ├── chaincode.go                  # 合约主文件
│   ├── go.mod                        # Go模块定义
│   └── go.sum                        # 依赖锁定
│
├── application/
│   ├── server/                       # 后端服务
│   │   ├── main.go                   # 服务入口
│   │   ├── go.mod                    # Go模块
│   │   ├── api/                      # API处理器
│   │   │   └── supply_chain.go      # 供应链API
│   │   ├── service/                  # 业务逻辑层
│   │   │   └── supply_chain_service.go
│   │   ├── pkg/fabric/               # Fabric SDK封装
│   │   │   ├── fabric.go             # 连接管理
│   │   │   └── block_listener.go     # 区块监听器
│   │   ├── config/                   # 配置管理
│   │   │   ├── config.go             # 配置结构
│   │   │   ├── config.yaml           # 本地开发配置
│   │   │   └── config-docker.yaml    # Docker环境配置
│   │   ├── utils/                    # 工具函数
│   │   │   └── response.go           # 响应封装
│   │   └── Dockerfile                # 后端镜像构建
│   │
│   ├── web/                          # 前端应用
│   │   ├── src/
│   │   │   ├── views/                # 页面组件
│   │   │   │   ├── Home.vue          # 角色选择页
│   │   │   │   ├── OEM.vue           # 主机厂页面
│   │   │   │   ├── Manufacturer.vue   # 厂商页面
│   │   │   │   ├── Carrier.vue       # 承运商页面
│   │   │   │   └── Platform.vue      # 平台页面
│   │   │   ├── api/                  # API调用
│   │   │   │   └── index.ts
│   │   │   ├── types/                # TypeScript类型
│   │   │   │   └── index.ts
│   │   │   ├── utils/                # 工具函数
│   │   │   │   └── request.ts        # Axios封装
│   │   │   ├── router/               # 路由配置
│   │   │   │   └── index.ts
│   │   │   └── main.ts               # 应用入口
│   │   ├── package.json
│   │   ├── vite.config.ts            # Vite配置
│   │   └── Dockerfile                # 前端镜像构建
│   │
│   └── docker-compose.yml            # 应用服务编排
│
├── install.sh                        # 一键部署脚本
├── uninstall.sh                      # 一键卸载脚本
├── dev.md                            # 开发指南
└── README.md                          # 项目说明
```

---

## 3. 环境配置

### 3.1 本地开发环境

#### 必需软件
- Go 1.23.4+
- Node.js 18.20.0 - 18.x
- npm 9+
- Docker 20.10+
- Docker Compose 2.x

#### 环境变量（可选）
```bash
# 设置 Go 代理（国内推荐）
export GOPROXY=https://goproxy.cn,direct

# 设置 npm 镜像
npm config set registry https://registry.npmmirror.com
```

### 3.2 配置文件详解

#### 后端配置 (config.yaml)

```yaml
server:
  port: 8888  # 服务端口

fabric:
  channelName: mychannel        # Fabric 通道名
  chaincodeName: mychaincode    # 链码名称
  organizations:
    org1:
      mspID: Org1MSP
      # 证书路径（相对于 application/server/）
      certPath: ../../network/crypto-config/peerOrganizations/org1.togettoyou.com/users/User1@org1.togettoyou.com/msp/signcerts
      keyPath: ../../network/crypto-config/peerOrganizations/org1.togettoyou.com/users/User1@org1.togettoyou.com/msp/keystore
      tlsCertPath: ../../network/crypto-config/peerOrganizations/org1.togettoyou.com/peers/peer0.org1.togettoyou.com/tls/ca.crt
      peerEndpoint: localhost:7051      # Peer节点地址
      gatewayPeer: peer0.org1.togettoyou.com
    org2:  # ... 类似配置
    org3:  # ... 类似配置
```

**注意**：
- 本地开发使用 `config.yaml`
- Docker 部署使用 `config-docker.yaml`
- Docker 环境中 `peerEndpoint` 使用容器名称（如 `peer0.org1.togettoyou.com:7051`）
- Docker 环境中证书路径使用绝对路径 `/network/crypto-config/...`

#### 前端配置 (vite.config.ts)

```typescript
export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8888',  // 后端地址
        changeOrigin: true,
      },
    },
  },
})
```

---

## 4. 智能合约开发指南

### 4.1 合约结构

```go
// SmartContract 智能合约结构体
type SmartContract struct {
    contractapi.Contract
}

// 组织 MSP ID 常量
const (
    OEM_ORG_MSPID          = "Org1MSP"
    MANUFACTURER_ORG_MSPID = "Org2MSP"
    PLATFORM_ORG_MSPID     = "Org3MSP"
)
```

### 4.2 数据模型

#### Order（订单）

```go
type Order struct {
    ID             string      `json:"id"`             // 订单ID（主键）
    ObjectType     string      `json:"objectType"`     // 资产类型标识 "ORDER"
    OEMID          string      `json:"oemId"`          // 主机厂组织ID
    ManufacturerID string      `json:"manufacturerId"` // 零部件厂商ID
    Items          []OrderItem `json:"items"`          // 零件清单
    Status         OrderStatus `json:"status"`         // 订单状态
    TotalPrice     float64     `json:"totalPrice"`     // 总价（自动计算）
    ShipmentID     string      `json:"shipmentId"`     // 关联物流单ID
    CreateTime     time.Time   `json:"createTime"`     // 创建时间（链上时间）
    UpdateTime     time.Time   `json:"updateTime"`     // 更新时间（链上时间）
}

type OrderItem struct {
    Name     string  `json:"name"`     // 零件名称
    Quantity int     `json:"quantity"` // 数量
    Price    float64 `json:"price"`    // 单价
}
```

#### Shipment（物流单）

```go
type Shipment struct {
    ID         string    `json:"id"`         // 物流单ID（主键）
    ObjectType string    `json:"objectType"` // 资产类型标识 "SHIPMENT"
    OrderID    string    `json:"orderId"`    // 关联订单ID
    CarrierID  string    `json:"carrierId"`  // 承运商ID
    Location   string    `json:"location"`   // 当前位置
    Status     string    `json:"status"`     // 运输状态
    UpdateTime time.Time `json:"updateTime"` // 更新时间
}
```

### 4.3 核心合约方法

#### CreateOrder - 创建订单

```go
// 仅 Org1 (OEM) 可调用
func (s *SmartContract) CreateOrder(
    ctx contractapi.TransactionContextInterface,
    id string,
    manufacturerId string,
    itemsJson string,
) error
```

**参数说明**：
- `id`: 订单唯一标识（需确保不重复）
- `manufacturerId`: 目标厂商ID（Org2MSP）
- `itemsJson`: 零件清单JSON字符串

**权限检查**：
```go
clientMSPID, _ := s.getClientIdentityMSPID(ctx)
if clientMSPID != OEM_ORG_MSPID {
    return fmt.Errorf("无权限: 仅限主机厂创建订单")
}
```

#### AcceptOrder - 接受订单

```go
// 仅 Org2 (Manufacturer) 可调用
func (s *SmartContract) AcceptOrder(
    ctx contractapi.TransactionContextInterface,
    id string,
) error
```

**状态转换**：
- `CREATED` → `ACCEPTED`

#### UpdateProductionStatus - 更新生产状态

```go
// 仅 Org2 (Manufacturer) 可调用
func (s *SmartContract) UpdateProductionStatus(
    ctx contractapi.TransactionContextInterface,
    id string,
    status string,
) error
```

**允许的状态**：
- `PRODUCING` - 生产中
- `PRODUCED` - 已生产
- `READY` - 待取货

#### PickupGoods - 承运商取货

```go
// 仅 Org3 (Carrier) 可调用
func (s *SmartContract) PickupGoods(
    ctx contractapi.TransactionContextInterface,
    orderId string,
    shipmentId string,
) error
```

**操作说明**：
1. 更新订单状态为 `SHIPPED`
2. 关联物流单ID
3. 创建新的物流单记录

#### UpdateLocation - 更新位置

```go
// 仅 Org3 (Carrier) 可调用
func (s *SmartContract) UpdateLocation(
    ctx contractapi.TransactionContextInterface,
    shipmentId string,
    location string,
) error
```

#### ConfirmReceipt - 确认收货

```go
// 仅 Org1 (OEM) 可调用
func (s *SmartContract) ConfirmReceipt(
    ctx contractapi.TransactionContextInterface,
    orderId string,
) error
```

**状态转换**：
- `SHIPPED/DELIVERED` → `RECEIVED`

### 4.4 查询方法

#### QueryOrder - 查询订单详情

```go
func (s *SmartContract) QueryOrder(
    ctx contractapi.TransactionContextInterface,
    id string,
) (*Order, error)
```

#### QueryShipment - 查询物流详情

```go
func (s *SmartContract) QueryShipment(
    ctx contractapi.TransactionContextInterface,
    id string,
) (*Shipment, error)
```

#### QueryOrderList - 分页查询订单

```go
func (s *SmartContract) QueryOrderList(
    ctx contractapi.TransactionContextInterface,
    pageSize int32,
    bookmark string,
) (*QueryResponse, error)
```

**返回结构**：
```go
type QueryResponse struct {
    Records             []interface{} `json:"records"`
    RecordsCount        int32         `json:"recordsCount"`
    Bookmark            string        `json:"bookmark"`         // 下一页标记
    FetchedRecordsCount int32         `json:"fetchedRecordsCount"`
}
```

#### QueryOrderHistory - 查询订单历史

```go
func (s *SmartContract) QueryOrderHistory(
    ctx contractapi.TransactionContextInterface,
    id string,
) ([]OrderHistoryRecord, error)
```

**使用 GetHistoryForKey API 获取完整的历史记录**

### 4.5 合约开发流程

#### 1. 修改合约代码

编辑 `chaincode/chaincode.go`，添加或修改合约方法。

#### 2. 本地测试

```bash
cd chaincode
go test  # 如果有测试文件
```

#### 3. 重新部署链码

```bash
# 方法1：完全重新部署网络（开发阶段推荐）
cd ../network
./install.sh

# 方法2：仅升级链码（生产环境推荐）
docker exec cli peer lifecycle chaincode package ...
# ... 参考官方文档
```

### 4.6 合约开发最佳实践

1. **权限控制**：每个写操作都应验证调用者 MSP ID
2. **参数验证**：对输入参数进行完整性和格式检查
3. **状态转换**：确保状态流转符合业务规则
4. **错误处理**：使用 `fmt.Errorf` 返回明确的错误信息
5. **事件发布**：可考虑在关键操作时发布链码事件（当前未实现）
6. **复合键设计**：如果需要复杂查询，可使用复合键（CompositeKey）

---

## 5. 后端开发指南

### 5.1 项目结构

```
application/server/
├── main.go                 # 应用入口，路由注册
├── api/                    # HTTP 请求处理器
│   └── supply_chain.go     # 供应链 API handlers
├── service/                # 业务逻辑层
│   └── supply_chain_service.go
├── pkg/fabric/             # Fabric SDK 封装
│   ├── fabric.go           # 连接、合约管理
│   └── block_listener.go   # 区块事件监听
├── config/                 # 配置管理
│   ├── config.go           # 配置结构体
│   ├── config.yaml         # 本地配置
│   └── config-docker.yaml  # Docker配置
└── utils/                  # 工具函数
    └── response.go         # 响应封装
```

### 5.2 代码分层说明

#### API 层 (api/)

职责：
- 接收 HTTP 请求
- 参数绑定与验证
- 调用 Service 层
- 返回 HTTP 响应

示例：
```go
func (h *SupplyChainHandler) CreateOrder(c *gin.Context) {
    var req struct {
        ID             string      `json:"id"`
        ManufacturerID string      `json:"manufacturerId"`
        Items          interface{} `json:"items"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.BadRequest(c, "无效的请求参数")
        return
    }

    if err := h.scService.CreateOrder(req.ID, req.ManufacturerID, req.Items); err != nil {
        log.Printf("CreateOrder Error: %v", err)
        utils.ServerError(c, err.Error())
        return
    }

    utils.SuccessWithMessage(c, "订单已发布", nil)
}
```

#### Service 层 (service/)

职责：
- 调用 Fabric 合约
- 数据转换
- 业务逻辑处理
- 错误处理与重试

示例：
```go
func (s *SupplyChainService) CreateOrder(id string, manufacturerId string, items interface{}) error {
    contract := fabric.GetContract(OEM_ORG)  // 获取 OEM 组织的合约
    itemsBytes, _ := json.Marshal(items)
    _, err := submitWithRetry(contract, "CreateOrder", id, manufacturerId, string(itemsBytes))
    if err != nil {
        return fmt.Errorf("创建订单失败：%s", fabric.ExtractErrorMessage(err))
    }
    return nil
}
```

#### Fabric SDK 层 (pkg/fabric/)

职责：
- 管理 Gateway 连接
- 提供合约客户端
- 区块事件监听
- 错误信息提取

### 5.3 添加新接口流程

#### 步骤1：在 Service 层添加方法

编辑 `service/supply_chain_service.go`：

```go
func (s *SupplyChainService) NewBusinessMethod(param1 string, param2 int) (map[string]interface{}, error) {
    contract := fabric.GetContract(OEM_ORG)  // 选择合适的组织
    result, err := contract.EvaluateTransaction("NewChaincodeMethod", param1, fmt.Sprintf("%d", param2))
    if err != nil {
        return nil, fmt.Errorf("调用链码失败：%s", fabric.ExtractErrorMessage(err))
    }

    var data map[string]interface{}
    if err := json.Unmarshal(result, &data); err != nil {
        return nil, fmt.Errorf("解析结果失败：%v", err)
    }

    return data, nil
}
```

#### 步骤2：在 API 层添加 Handler

编辑 `api/supply_chain.go`：

```go
// NewBusinessHandler 新业务接口
// @Summary 新业务接口
// @Description 新业务接口描述
// @Tags OEM
// @Accept json
// @Produce json
// @Param request body NewBusinessRequest true "请求参数"
// @Success 200 {object} utils.Response
// @Router /api/oem/new-business [post]
func (h *SupplyChainHandler) NewBusinessHandler(c *gin.Context) {
    var req struct {
        Param1 string `json:"param1"`
        Param2 int    `json:"param2"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.BadRequest(c, "参数错误")
        return
    }

    result, err := h.scService.NewBusinessMethod(req.Param1, req.Param2)
    if err != nil {
        utils.ServerError(c, err.Error())
        return
    }

    utils.Success(c, result)
}
```

#### 步骤3：注册路由

编辑 `main.go`：

```go
// 在对应角色组下添加路由
oemGroup := apiGroup.Group("/oem")
{
    oemGroup.POST("/order/create", scHandler.CreateOrder)
    oemGroup.POST("/new-business", scHandler.NewBusinessHandler)  // 新增
    // ...
}
```

### 5.4 Fabric 集成详解

#### 组织映射

```go
const (
    OEM_ORG          = "org1"      // config.yaml 中的 key
    MANUFACTURER_ORG = "org2"
    CARRIER_ORG      = "org3"
    PLATFORM_ORG     = "org3"
)
```

#### 获取合约客户端

```go
contract := fabric.GetContract(OEM_ORG)
```

#### 提交交易（写操作）

```go
result, err := contract.SubmitTransaction("MethodName", "arg1", "arg2")
```

#### 查询交易（读操作）

```go
result, err := contract.EvaluateTransaction("MethodName", "arg1")
```

#### 错误处理与重试

系统内置了 MVCC 冲突重试机制：

```go
// 自动重试最多3次，延迟指数递增
func submitWithRetry(contract *client.Contract, function string, args ...string) ([]byte, error) {
    for i := 0; i < maxRetries; i++ {
        result, err := contract.SubmitTransaction(function, args...)
        if err == nil {
            return result, nil
        }
        if isMVCCConflict(fabric.ExtractErrorMessage(err)) {
            time.Sleep(retryDelay * time.Duration(i+1))
            continue
        }
        return nil, err
    }
    return nil, lastErr
}
```

### 5.5 区块监听器

#### 功能说明

区块监听器自动订阅所有组织的区块事件，并将区块元数据保存到 BoltDB。

#### 启动流程

1. 服务启动时在 `InitFabric()` 中初始化监听器
2. 为每个组织创建独立的监听 goroutine
3. 从上次保存的区块号继续监听
4. 出现中断时自动重连（30秒间隔）

#### 存储结构

```go
type BlockData struct {
    BlockNum  uint64    `json:"block_num"`   // 区块号
    BlockHash string    `json:"block_hash"`  // 区块哈希
    DataHash  string    `json:"data_hash"`   // 数据哈希
    PrevHash  string    `json:"prev_hash"`   // 前一区块哈希
    TxCount   int       `json:"tx_count"`    // 交易数量
    SaveTime  time.Time `json:"save_time"`   // 保存时间
}
```

#### 查询接口

```go
// 查询单个区块
GetBlockByNumber(orgName string, blockNum uint64) (*BlockData, error)

// 分页查询区块列表
GetBlocksByOrg(orgName string, pageSize, pageNum int) (*BlockQueryResult, error)
```

### 5.6 本地运行

```bash
cd application/server

# 安装依赖
go mod download

# 运行服务
go run main.go
```

服务将在 http://localhost:8888 启动

---

## 6. 前端开发指南

### 6.1 项目结构

```
application/web/src/
├── views/                  # 页面组件
│   ├── Home.vue           # 角色选择页
│   ├── OEM.vue            # 主机厂页面
│   ├── Manufacturer.vue    # 厂商页面
│   ├── Carrier.vue        # 承运商页面
│   └── Platform.vue       # 平台页面
├── api/                    # API 调用
│   └── index.ts           # 供应链 API 封装
├── types/                  # TypeScript 类型
│   └── index.ts           # 类型定义
├── utils/                  # 工具函数
│   └── request.ts         # Axios 封装
├── router/                 # 路由配置
│   └── index.ts
└── main.ts                # 应用入口
```

### 6.2 类型定义

```typescript
// API 统一响应结构
export interface ApiResponse<T = any> {
  code: number;
  message: string;
  data?: T;
}

// 订单项
export interface OrderItem {
  name: string;
  quantity: number;
  price: number;
}

// 订单状态
export type OrderStatus = 'CREATED' | 'ACCEPTED' | 'PRODUCING' | 'PRODUCED' | 'READY' | 'SHIPPED' | 'DELIVERED' | 'RECEIVED';

// 订单
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
}

// 物流单
export interface Shipment {
  id: string;
  orderId: string;
  carrierId: string;
  location: string;
  status: string;
  updateTime: string;
}

// 分页结果
export interface SupplyChainPageResult<T> {
  records: T[];
  bookmark: string;
  recordsCount: number;
  fetchedRecordsCount: number;
}
```

### 6.3 API 调用封装

#### Request 工具

```typescript
// src/utils/request.ts
import axios from 'axios';
import type { ApiResponse } from '../types';

const request = axios.create({
  baseURL: '/api',  // 通过 Vite 代理到后端
  timeout: 10000,
});

// 响应拦截器
request.interceptors.response.use(
  (response) => {
    const res = response.data as ApiResponse<any>;
    if (res.code === 200) {
      return res.data;  // 直接返回 data 字段
    }
    return Promise.reject(new Error(res.message || '请求失败'));
  },
  (error) => {
    // 错误处理...
    return Promise.reject(error);
  }
);
```

#### API 方法

```typescript
// src/api/index.ts
export const supplyChainApi = {
  // 主机厂
  createOrder: (data: { id: string; manufacturerId: string; items: OrderItem[] }) =>
    request.post<never, void>('/oem/order/create', data),

  receiveOrder: (id: string) =>
    request.put<never, void>(`/oem/order/${id}/receive`),

  // 零部件厂商
  acceptOrder: (id: string) =>
    request.put<never, void>(`/manufacturer/order/${id}/accept`),

  updateOrderStatus: (id: string, status: string) =>
    request.put<never, void>(`/manufacturer/order/${id}/status`, { status }),

  // 承运商
  pickupGoods: (data: { orderId: string; shipmentId: string }) =>
    request.post<never, void>('/carrier/shipment/pickup', data),

  updateLocation: (id: string, location: string) =>
    request.put<never, void>(`/carrier/shipment/${id}/location`, { location }),

  // 查询
  getOrder: (id: string) =>
    request.get<never, Order>(`/oem/order/${id}`),

  getOrderList: (params: { pageSize: number; bookmark: string }, role: string) =>
    request.get<never, SupplyChainPageResult<Order>>(`/${role.toLowerCase()}/order/list`, { params }),

  getShipment: (id: string) =>
    request.get<never, Shipment>(`/carrier/shipment/${id}`),

  getOrderHistory: (id: string) =>
    request.get<never, any[]>(`/oem/order/${id}/history`),
};
```

### 6.4 页面组件开发规范

#### 组件模板结构

```vue
<template>
  <div class="role-page">
    <!-- 页面头部 -->
    <a-page-header
      title="角色名称"
      sub-title="角色描述"
      @back="() => $router.push('/')"
    />

    <!-- 内容区域 -->
    <div class="content">
      <!-- 业务内容 -->
    </div>

    <!-- 弹窗/对话框 -->
    <a-modal
      :visible="showModal"
      title="标题"
      @ok="handleSubmit"
      @cancel="showModal = false"
    >
      <!-- 表单内容 -->
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { message } from 'ant-design-vue';

// 响应式数据
const loading = ref(false);
const showModal = ref(false);

// 方法定义
const handleSubmit = async () => {
  try {
    // 调用 API
    await supplyChainApi.someMethod();
    message.success('操作成功');
  } catch (error: any) {
    message.error('操作失败: ' + error.message);
  }
};

// 生命周期
onMounted(() => {
  // 初始化逻辑
});
</script>

<style scoped>
.role-page {
  min-height: 100vh;
  background-color: #f0f2f5;
}

.content {
  padding: 24px;
}
</style>
```

#### 状态映射

```typescript
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
  };
  return textMap[status] || status;
};
```

### 6.5 本地运行

```bash
cd application/web

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

访问 http://localhost:5173

### 6.6 常见 UI 组件使用

#### 表格

```vue
<a-table
  :columns="columns"
  :data-source="orders"
  :pagination="false"
  row-key="id"
>
  <template #bodyCell="{ column, record }">
    <template v-if="column.key === 'status'">
      <a-tag :color="getStatusColor(record.status)">
        {{ getStatusText(record.status) }}
      </a-tag>
    </template>
    <template v-else-if="column.key === 'action'">
      <a-button size="small" @click="handleAction(record)">操作</a-button>
    </template>
  </template>
</a-table>
```

#### 表单

```vue
<a-form :model="form" layout="vertical">
  <a-form-item label="字段名" required>
    <a-input v-model:value="form.field" placeholder="请输入" />
  </a-form-item>
</a-form>
```

#### 弹窗

```vue
<a-modal
  :visible="showModal"
  title="标题"
  @ok="handleSubmit"
  @cancel="showModal = false"
>
  <a-form :model="modalForm">
    <!-- 表单内容 -->
  </a-form>
</a-modal>
```

---

## 7. API 接口文档

### 7.1 响应格式

所有接口统一使用以下响应格式：

```json
{
  "code": 200,
  "message": "成功",
  "data": {}
}
```

### 7.2 主机厂接口 (OEM)

#### 7.2.1 创建订单

```http
POST /api/oem/order/create
Content-Type: application/json

{
  "id": "ORDER-001",
  "manufacturerId": "Org2MSP",
  "items": [
    {
      "name": "发动机",
      "quantity": 10,
      "price": 5000.00
    }
  ]
}
```

**响应**：
```json
{
  "code": 200,
  "message": "订单已发布",
  "data": null
}
```

#### 7.2.2 确认收货

```http
PUT /api/oem/order/{id}/receive
```

#### 7.2.3 查询订单详情

```http
GET /api/oem/order/{id}
```

#### 7.2.4 查询订单历史

```http
GET /api/oem/order/{id}/history
```

#### 7.2.5 查询订单列表

```http
GET /api/oem/order/list?pageSize=10&bookmark=xxx
```

### 7.3 零部件厂商接口 (Manufacturer)

#### 7.3.1 接受订单

```http
PUT /api/manufacturer/order/{id}/accept
```

#### 7.3.2 更新生产状态

```http
PUT /api/manufacturer/order/{id}/status
Content-Type: application/json

{
  "status": "PRODUCING"
}
```

#### 7.3.3 查询订单列表

```http
GET /api/manufacturer/order/list?pageSize=10&bookmark=xxx
```

### 7.4 承运商接口 (Carrier)

#### 7.4.1 取货

```http
POST /api/carrier/shipment/pickup
Content-Type: application/json

{
  "orderId": "ORDER-001",
  "shipmentId": "SHIPMENT-001"
}
```

#### 7.4.2 更新位置

```http
PUT /api/carrier/shipment/{id}/location
Content-Type: application/json

{
  "location": "上海市浦东新区"
}
```

#### 7.4.3 查询物流详情

```http
GET /api/carrier/shipment/{id}
```

#### 7.4.4 查询物流历史

```http
GET /api/carrier/shipment/{id}/history
```

#### 7.4.5 查询订单列表

```http
GET /api/carrier/order/list?pageSize=10&bookmark=xxx
```

### 7.5 平台接口 (Platform)

#### 7.5.1 查询全部订单

```http
GET /api/platform/order/list?pageSize=10&bookmark=xxx
```

---

## 8. 数据模型

### 8.1 链上数据模型

#### Order

| 字段 | 类型 | 说明 |
|-----|------|------|
| ID | string | 订单唯一标识 |
| ObjectType | string | 固定值 "ORDER" |
| OEMID | string | 主机厂 MSP ID |
| ManufacturerID | string | 零部件厂 MSP ID |
| Items | OrderItem[] | 零件清单数组 |
| Status | OrderStatus | 订单状态 |
| TotalPrice | float64 | 总价（自动计算） |
| ShipmentID | string | 关联的物流单ID |
| CreateTime | time.Time | 创建时间 |
| UpdateTime | time.Time | 更新时间 |

#### Shipment

| 字段 | 类型 | 说明 |
|-----|------|------|
| ID | string | 物流单唯一标识 |
| ObjectType | string | 固定值 "SHIPMENT" |
| OrderID | string | 关联订单ID |
| CarrierID | string | 承运商 MSP ID |
| Location | string | 当前位置 |
| Status | string | 运输状态 |
| UpdateTime | time.Time | 更新时间 |

### 8.2 本地存储模型

#### BlockData（区块元数据）

| 字段 | 类型 | 说明 |
|-----|------|------|
| BlockNum | uint64 | 区块号 |
| BlockHash | string | 区块哈希（SHA256） |
| DataHash | string | 数据哈希 |
| PrevHash | string | 前一区块哈希 |
| TxCount | int | 交易数量 |
| SaveTime | time.Time | 保存时间 |

---

## 9. 部署指南

### 9.1 快速部署（使用预构建镜像）

```bash
# 1. 设置脚本权限
chmod +x *.sh network/*.sh

# 2. 一键部署
./install.sh
```

部署完成后访问：
- 前端：http://localhost:8000
- 后端API：http://localhost:8080
- Swagger文档：http://localhost:8080/swagger/index.html

### 9.2 本地开发部署

#### 启动 Fabric 网络

```bash
cd network
./install.sh
```

#### 启动后端服务

```bash
cd application/server
go run main.go
```

#### 启动前端服务

```bash
cd application/web
npm install
npm run dev
```

### 9.3 重新构建镜像

如果修改了代码，需要重新构建镜像：

#### 构建后端镜像

```bash
cd application/server
docker build -t togettoyou/fabric-realty.server:latest .
```

#### 构建前端镜像

```bash
cd application/web
docker build -t togettoyou/fabric-realty.web:latest .
```

### 9.4 清理部署

```bash
./uninstall.sh
```

### 9.5 网络配置说明

#### 组织与节点

| 组织 | MSP ID | Peer 节点 | 端口 |
|-----|--------|----------|------|
| Org1 | Org1MSP | peer0.org1.togettoyou.com | 7051 |
| | | peer1.org1.togettoyou.com | 9051 |
| Org2 | Org2MSP | peer0.org2.togettoyou.com | 27051 |
| | | peer1.org2.togettoyou.com | 37051 |
| Org3 | Org3MSP | peer0.org3.togettoyou.com | 47051 |
| | | peer1.org3.togettoyou.com | 57051 |

#### Orderer 节点（Raft 集群）

| 节点 | 域名 | 端口 |
|-----|------|------|
| Orderer1 | orderer1.togettoyou.com | 7050 |
| Orderer2 | orderer2.togettoyou.com | 8050 |
| Orderer3 | orderer3.togettoyou.com | 9050 |

---

## 10. 常见问题与调试

### 10.1 常见问题

#### 1. 连接 Fabric 失败

**症状**：启动后端时出现 "初始化Fabric客户端失败"

**排查步骤**：
1. 确认 Fabric 网络已启动：`docker ps | grep peer`
2. 检查证书路径是否正确
3. 确认证书文件存在且可读
4. 检查 Peer 节点端口是否正常监听

#### 2. MVCC_READ_CONFLICT 错误

**症状**：提交交易时出现 "MVCC_READ_CONFLICT"

**说明**：并发修改同一键导致的冲突

**解决方案**：系统已内置重试机制，会自动重试最多3次

#### 3. 前端无法访问后端 API

**症状**：浏览器控制台出现 404 或 Network Error

**排查步骤**：
1. 确认后端服务已启动
2. 检查 Vite 配置中的代理设置
3. 查看浏览器开发者工具中的 Network 请求
4. 确认后端 CORS 配置（当前未设置，通过代理解决）

#### 4. 智能合约更新不生效

**症状**：修改链码后，调用仍使用旧逻辑

**解决方法**：
```bash
# 方法1：重新部署网络
cd network
./install.sh

# 方法2：升级链码（需要手动操作）
docker exec cli peer lifecycle chaincode upgrade ...
```

### 10.2 调试技巧

#### 后端调试

1. **查看日志**：后端日志直接输出到控制台
2. **开启 Debug 日志**：在代码中添加 `log.Printf()` 语句
3. **测试链码**：使用 Fabric CLI 容器测试链码

#### 前端调试

1. **浏览器开发者工具**：F12 打开 Console、Network
2. **Vue DevTools**：安装浏览器插件
3. **网络请求**：查看 Network 标签页中的请求详情

#### 区块链调试

1. **查看容器日志**：
```bash
docker logs peer0.org1.togettoyou.com
docker logs orderer1.togettoyou.com
```

2. **进入容器执行命令**：
```bash
docker exec -it cli bash
```

3. **查询链码**：
```bash
peer chaincode query -C mychannel -n mychaincode -c '{"Args":["QueryOrder","ORDER-001"]}'
```

### 10.3 日志级别

系统当前使用标准库 `log` 包，日志直接输出到 stdout。

建议在开发环境添加日志级别控制：
```go
import "log"

// Debug 级别
log.Printf("DEBUG: %v", data)

// Error 级别
log.Printf("ERROR: %v", err)
```

### 10.4 性能优化建议

#### 后端
1. 使用连接池管理 gRPC 连接
2. 添加 API 响应缓存（读操作）
3. 实现请求限流
4. 添加 Prometheus 指标监控

#### 前端
1. 实现列表虚拟滚动（大量数据）
2. 添加请求缓存
3. 使用骨架屏提升加载体验
4. 图片/资源懒加载

#### 区块链
1. 使用 CouchDB 替代 LevelDB（复杂查询）
2. 优化链码查询逻辑
3. 使用私数据集（Private Data Collections）保护敏感数据
4. 考虑通道分区（Channel Partitioning）

---

## 附录

### A. 相关链接

- Hyperledger Fabric 官方文档：https://hyperledger-fabric.readthedocs.io/
- Fabric Gateway SDK：https://hyperledger.github.io/fabric-gateway/
- Go Gin 文档：https://gin-gonic.com/docs/
- Vue 3 文档：https://cn.vuejs.org/
- Ant Design Vue：https://antdv.com/

### B. 端口映射

| 服务 | 宿主机端口 | 容器端口 |
|-----|----------|---------|
| 后端 API | 8080 (Docker) / 8888 (本地) | 8080 |
| 前端 | 8000 | 80 |
| Peer0.Org1 | 7051 | 7051 |
| Peer0.Org2 | 27051 | 27051 |
| Peer0.Org3 | 47051 | 47051 |
| Orderer1 | 7050 | 7050 |

### C. 配置文件对照

| 文件 | 用途 | 环境 |
|-----|------|------|
| config.yaml | 后端配置 | 本地开发 |
| config-docker.yaml | 后端配置 | Docker |
| vite.config.ts | 前端配置 | 本地开发 |
| configtx.yaml | 通道配置 | Fabric 网络 |
| crypto-config.yaml | 证书配置 | Fabric 网络 |

### D. 命令速查

```bash
# 启动 Fabric 网络
cd network && ./install.sh

# 停止 Fabric 网络
cd network && ./uninstall.sh

# 启动后端（本地）
cd application/server && go run main.go

# 启动前端（本地）
cd application/web && npm run dev

# 构建后端镜像
cd application/server && docker build -t togettoyou/fabric-realty.server:latest .

# 构建前端镜像
cd application/web && docker build -t togettoyou/fabric-realty.web:latest .

# 查看容器日志
docker logs peer0.org1.togettoyou.com

# 进入 CLI 容器
docker exec -it cli bash

# 查询订单（CLI）
peer chaincode query -C mychannel -n mychaincode -c '{"Args":["QueryOrder","ORDER-001"]}'
```

---

**文档结束**
