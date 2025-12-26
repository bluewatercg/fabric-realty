# 基于 Hyperledger Fabric 的汽配供应链协同系统

本项目是一个基于 Hyperledger Fabric 的汽配供应链协同系统，旨在通过区块链技术解决汽车零部件采购、生产与物流环节中的信息不对称与可追溯性问题。

系统逻辑上由主机厂、零部件厂商、承运商和供应链平台四个角色共同参与，物理上部署于三个 Fabric 组织。

---

## 📚 文档中心

> **重要提示：** 本项目已建立结构化的文档中心，推荐通过以下方式访问技术文档：

### 文档入口

| 文档类型 | 路径 | 说明 |
|----------|------|------|
| **文档中心首页** | [`docs/README.md`](docs/README.md) | 包含 MVP1 业务流图（Mermaid）、目录结构、模块索引 |
| **核心逻辑文档** | [`docs/core/`](docs/core/) | 系统架构、链码实现、服务层逻辑 |
| **开发指南** | [`docs/guide/`](docs/guide/) | 开发指南、API 使用、快速入门 |
| **运维文档** | [`docs/ops/`](docs/ops/) | 部署脚本、诊断手册、Bug 修复 |
| **归档文档** | [`docs/archive/`](docs/archive/) | 历史版本、废弃方案、草稿 |

### 文档命名规范

```
[分类码]-[模块名]-[版本号].[扩展名]

分类码:
  LOG- = Core-Logic 核心逻辑
  GDE- = Guide 开发指南
  OPS- = Operations 运维文档
  SPC- = Specification 规范文档
```

---

## 本地开发

参考：[本地开发指南](dev.md)

推荐首次使用时选择快速部署方式，以便快速体验系统功能。

## 快速部署

### 环境要求

- Docker
- Docker Compose

### 部署步骤

1. 拉取项目（或手动下载）

   ```bash
   git clone --depth 1 https://github.com/togettoyou/fabric-realty.git
   ```

2. 设置脚本权限

   ```bash
   cd fabric-realty
   chmod +x *.sh network/*.sh
   ```

3. 一键部署
   > [!IMPORTANT]
   > 如果您正在进行二次开发并修改了代码，请参考 `redeploy_guide.md` 重新构建镜像。

   ```bash
   ./install.sh
   ```

4. 一键卸载

   ```bash
   ./uninstall.sh
   ```

### 访问服务

http://localhost:8000

## 业务操作流程

系统包含四个逻辑角色，覆盖从订单下达到签收的全生命周期：

### 1. 采购订单下达 (OEM - Org1)
- 主机厂（OEM）录入采购需求（零件名称、数量、价格等）。
- 提交后订单上链，状态变为 `CREATED`。

### 2. 订单接受与生产 (Manufacturer - Org2)
- 零部件厂商接收到新订单，审核后点击“接受订单”。
- 状态流转：`ACCEPTED` -> `PRODUCING` -> `PRODUCED`。

### 3. 物流取货与发货 (Carrier - Org3)
- 承运商（物流公司）前往厂商处取货。
- 确认取货后生成区块链物流单（Shipment），状态变为 `SHIPPED`。
- 承运商可实时更新物流地理位置。

### 4. 签收确认 (OEM - Org1)
- 主机厂收到货物后，在系统内执行“确认收货”。
- 订单状态最终变为 `RECEIVED`，完成闭环。

### 5. 全程监管 (Platform - Org3)
- 供应链平台角色可以实时查看所有订单和物流单的当前状态与流转历史，确保流程透明可控。

## 系统架构

### 网络架构 (Network)

项目在物理上由三个组织（Org1, Org2, Org3）构成：
1. **Org1 (主机厂)**: 维护 peer0.org1 和 peer1.org1。
2. **Org2 (零部件厂)**: 维护 peer0.org2 和 peer1.org2。
3. **Org3 (物流方与平台)**: 承担承运商与监管平台双重角色，维护 peer0.org3 和 peer1.org3。

### 智能合约 (Chaincode)

- **资产模型**: 定义了 `Order`（订单）和 `Shipment`（物流单）。
- **权限控制**: 严格根据调用者的 MSPID 进行鉴权（如：仅限 Org1 签收，仅限 Org3 更新位置）。

### 应用服务器 (Application)

API 路由按角色划分：
- `/api/oem`: 订单创建、签收确认、详情查询。
- `/api/manufacturer`: 接受订单、更新生产状态。
- `/api/carrier`: 物流取货、地理位置更新。
- `/api/platform`: 订单全链路监管查询。

## 技术栈

- **区块链层**: Hyperledger Fabric v2.5.10
- **后端**: Go 1.23 + Gin v1.10.0 + Fabric Gateway SDK
- **前端**: Vue 3 + Vite + TypeScript + Ant Design Vue
