# Hyperledger Fabric 2.5 网络诊断手册：命令行验证账本数据完整性

## 1. 目的

本手册旨在提供一套标准化的命令行操作流程，用于在服务器后端直接与 Hyperledger Fabric 网络进行交互，查询账本上的数据。这使得开发和运维人员可以不依赖前端应用，直接验证数据一致性、诊断问题、追踪交易历史。

---

## 2. 网络关键信息

| 配置项 | 值 | 备注 |
| :--- | :--- | :--- |
| **网络名称** | `fabric_togettoyou_network` | Docker 网络 |
| **通道名称** | `mychannel` | 应用数据通道 |
| **链码名称** | `mychaincode` | 核心链码 |
| **CLI 容器** | `cli.togettoyou.com` | 执行 peer 命令 |
| **Peer 节点 (Org1)** | `peer0.org1.togettoyou.com` | 查询节点 |
| **Orderer 节点** | `orderer1.togettoyou.com:7050` | 排序服务 |

---

## 3. 诊断步骤

### 步骤一：进入 CLI 容器

```bash
docker exec -it cli.togettoyou.com bash
```

---

### 步骤二：设置 Org1 Admin 查询环境变量

```bash
export CORE_PEER_ADDRESS=peer0.org1.togettoyou.com:7051
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH="/etc/hyperledger/crypto-config/peerOrganizations/org1.togettoyou.com/users/Admin@org1.togettoyou.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="/etc/hyperledger/crypto-config/peerOrganizations/org1.togettoyou.com/peers/peer0.org1.togettoyou.com/tls/ca.crt"
export CORE_PEER_TLS_ENABLED=true
```

---

## 4. 常用链码查询命令

### 4.1 查询某个订单的当前状态（World State）

```bash
peer chaincode query -C mychannel -n mychaincode -c '{"Args":["QueryOrder","123"]}'
```

---

### 4.2 查询账本中所有数据

```bash
peer chaincode query -C mychannel -n mychaincode -c '{"Args":["QueryAllLedgerData","10",""]}'
```
> **注意**：根据当前的链码实现，此命令仅返回所有数据的**当前状态 (current state)**，并不会同时返回历史记录。文档中关于返回 `current + history` 的描述是一个功能改进方向。

---

### 4.3 查询某个订单的历史记录（Blockchain）

```bash
peer chaincode query -C mychannel -n mychaincode -c '{"Args":["QueryOrderHistory","123"]}'
```

---

### 4.4 查询通道信息（区块高度 / 当前区块哈希）

Fabric 网络最基础的健康检查命令。因为网络启用了TLS，命令中必须包含 orderer 地址、`--tls` 和 `--cafile` 标志。

```bash
peer channel getinfo -c mychannel -o orderer1.togettoyou.com:7050 --tls --cafile /etc/hyperledger/crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer1.togettoyou.com/msp/tlscacerts/tlsca.togettoyou.com-cert.pem
```

示例返回：

```json
{
  "height": 12,
  "currentBlockHash": "abc123...",
  "previousBlockHash": "def456..."
}
```

字段说明：

| 字段 | 含义 |
|------|------|
| **height** | 当前区块高度 |
| **currentBlockHash** | 最新区块哈希 |
| **previousBlockHash** | 上一个区块哈希 |

> 若 height 不增长，说明网络未出块或 Peer 未同步。

---

### 4.5 切换组织身份进行查询（Org1 → Org2 → Org3）

Fabric 是多组织网络，跨组织查询是排查数据可见性问题的重要手段。

---

#### 切换到 Org2 身份

**注意**：在 `cli` 容器内部访问其他 Peer 时，应始终使用其内部端口 `7051`。

```bash
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_MSPCONFIGPATH="/etc/hyperledger/crypto-config/peerOrganizations/org2.togettoyou.com/users/Admin@org2.togettoyou.com/msp"
export CORE_PEER_ADDRESS=peer0.org2.togettoyou.com:7051
export CORE_PEER_TLS_ROOTCERT_FILE="/etc/hyperledger/crypto-config/peerOrganizations/org2.togettoyou.com/peers/peer0.org2.togettoyou.com/tls/ca.crt"
```

然后执行查询：

```bash
peer chaincode query -C mychannel -n mychaincode -c '{"Args":["QueryOrder","123"]}'
```

---

#### 切换到 Org3 身份

```bash
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_MSPCONFIGPATH="/etc/hyperledger/crypto-config/peerOrganizations/org3.togettoyou.com/users/Admin@org3.togettoyou.com/msp"
export CORE_PEER_ADDRESS=peer0.org3.togettoyou.com:7051
export CORE_PEER_TLS_ROOTCERT_FILE="/etc/hyperledger/crypto-config/peerOrganizations/org3.togettoyou.com/peers/peer0.org3.togettoyou.com/tls/ca.crt"
```

---

#### 跨组织诊断意义

| 诊断目标 | 说明 |
|---------|------|
| 验证数据是否对所有组织可见 | 若某组织查不到数据，说明未加入通道或背书策略不正确 |
| 验证 Peer 是否同步区块 | 若 Org2 的 height 落后，说明同步异常 |
| 验证链码是否在所有组织成功实例化 | 某组织查询报错可能是链码未安装 |

---

## 5. 查看链码容器日志

### 查找链码容器名称

```bash
docker ps --filter "name=dev-peer0.org1" --format "{{.Names}}"
```

### 查看日志

```bash
docker logs -f <CHAINCODE_CONTAINER_NAME>
```