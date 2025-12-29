# 域名修改为 aventura.net.cn 的分析与修改方案

> ⚠️ **此文档为草稿，未经充分验证，仅供参考**

> **状态**：草稿未完成，建议暂不执行。
>
> **风险提示**：本方案涉及重新生成 Fabric 网络的所有加密材料和创世区块，属于高风险操作，可能导致数据丢失。

---

#### **1. 核心问题与难度评估**

-   **核心问题**: 在 Hyperledger Fabric 中，组织的域名（例如 `org1.example.com`）是 MSP（成员服务提供者）ID 和节点身份证书的一部分。所有节点的 TLS 证书、签名证书都与创世时配置的域名强绑定。因此，修改域名意味着**必须重新生成整个区块链网络的加密材料、创世区块和通道配置**。这相当于重新部署一个新的网络。
-   **难度评估**: **高**。
    -   **原因**:
        1.  **区块链数据不兼容**: 旧网络的数据无法直接迁移到新域名下的新网络。需要制定复杂的数据迁移策略。
        2.  **涉及文件广**: 从底层网络配置到上层应用配置都需要修改。
        3.  **需要停机**: 整个过程需要停止服务，进行重新部署。
        4.  **外部依赖**: 需要配置新的 DNS 解析和申请新的 SSL 证书。

#### **2. 潜在问题与风险**

1.  **区块链网络中断与数据丢失**: 这是最大的风险。按标准流程修改域名会创建一个**全新的、空的区块链网络**。旧有的所有账本数据（如订单历史）将保留在旧的 Docker 卷中，但无法被新网络直接使用。
2.  **SSL/TLS 证书失效**: 所有为旧域名颁发的证书都将作废，前后端、以及 Fabric 节点间的通信都将因证书错误而失败。
3.  **跨域资源共享 (CORS) 失败**: 如果后端不更新其允许的来源列表，前端 `aventura.net.cn` 的 API 请求将被拒绝。
4.  **服务发现失败**: 应用后端可能硬编码了 Fabric 节点的地址，如果这些地址不更新，将无法连接到新的 Fabric 网络。
5.  **DNS 解析延迟**: 新的 `aventura.net.cn` 域名解析可能需要一段时间才能在全球生效，期间可能导致服务不可用。

---

#### **3. 需要修改的文件与内容**

以下是需要修改的关键文件列表：

##### **A. 区块链网络层 (`network/`)**

这些是最高优先级的修改，因为它们定义了网络的基础。

1.  **`network/crypto-config.yaml`**:
    -   **内容**: 定义组织结构和域名。
    -   **修改**: 将所有 `Domain` 字段从旧域名（例如 `example.com`）修改为 `aventura.net.cn`。
        ```yaml
        # 示例
        PeerOrgs:
          - Name: Org1
            Domain: org1.aventura.net.cn # <- 修改这里
            EnableNodeOUs: true
            Specs:
              - Hostname: peer0
              - Hostname: peer1
        # ... 对 OrdererOrgs 做同样修改
        ```

2.  **`network/configtx.yaml`**:
    -   **内容**: 定义创世区块和通道的配置。
    -   **修改**: 修改 `Organizations` 部分中各个组织的 `MSPDir` 路径（如果路径中包含旧域名），并检查 `AnchorPeers` 的 `Host` 是否需要更新。

3.  **`network/docker-compose.yaml`** (及 `docker-compose-base.yaml`):
    -   **内容**: 定义 Fabric 节点的容器服务。
    -   **修改**:
        -   所有容器的 `container_name` 应更新以反映新域名（例如 `peer0.org1.aventura.net.cn`）。
        -   环境变量 `CORE_PEER_ID` 和 `CORE_PEER_ADDRESS` 需要更新。
        -   `extra_hosts` 或 `networks` 的别名（aliases）也需要更新。

##### **B. 应用层 (`application/`)**

1.  **`application/server/config/config.yaml`** (及 `config-docker.yaml`):
    -   **内容**: 应用后端的配置。
    -   **修改**:
        -   更新 Fabric 连接配置，确保 `peers`, `orderers` 的 URL 指向新的域名。
        -   更新 `cors` 配置中的 `allowed-origins`，加入 `https://aventura.net.cn` 和 `http://aventura.net.cn`。

2.  **`application/web/default.conf`** (Nginx 配置):
    -   **内容**: 前端 Web 服务器的配置。
    -   **修改**:
        -   将 `server_name` 修改为 `aventura.net.cn`。
        -   确保 `ssl_certificate` 和 `ssl_certificate_key` 指向为新域名申请的证书。
        -   检查 `proxy_pass` 指向的后端地址是否正确。

3.  **`application/web/src/utils/request.ts`** 或 **`application/web/vite.config.ts`**:
    -   **内容**: 前端 API 请求的基地址或代理配置。
    -   **修改**: 如果 API 地址被硬编码，需要将其更新为新的后端服务地址。

---

#### **4. 修改实施方案（步骤）**

这是一个高风险操作，请严格按照步骤执行。

**阶段一：准备工作**

1.  **完全备份**:
    -   使用 Git 创建一个新分支: `git checkout -b feature/domain-change`。
    -   备份整个项目目录的物理副本。
    -   如果已有数据很重要，请备份 Docker 卷。

2.  **DNS 和 SSL**:
    -   在您的 DNS 服务商处，将 `aventura.net.cn` (及可能的 `*.org1.aventura.net.cn` 等子域名) 的 A 记录指向您的服务器 IP。
    -   为新域名 `aventura.net.cn` 及其所有相关子域名申请新的 SSL/TLS 证书。

**阶段二：执行修改**

3.  **停止并清理旧网络**:
    -   在 `network/` 目录下，执行 `./uninstall.sh` 或 `docker-compose down -v --rmi all` 彻底清理旧的容器、网络和卷。

4.  **修改网络层配置**:
    -   按照上面的指导，修改 `network/` 目录下的 `crypto-config.yaml`, `configtx.yaml`, 和 `docker-compose.yaml` 文件。

5.  **生成新的区块链身份和配置**:
    -   在 `network/` 目录下，重新执行网络启动脚本，例如 `install.sh` 或 `Step2_Linux_deploy.sh`。这将使用新的配置文件来：
        -   生成新的 MSP 加密材料。
        -   创建新的创世区块。
        -   创建新的通道。
        -   部署和实例化链码。

6.  **修改应用层配置**:
    -   按照上面的指导，修改 `application/` 目录下的所有相关配置文件。

7.  **重新构建并启动应用**:
    -   在项目根目录或 `application/` 目录下，执行 `docker-compose up -d --build`。`--build` 参数会强制重新构建镜像，以确保所有配置更改生效。

**阶段三：验证与数据迁移**

8.  **全面测试**:
    -   访问 `https://aventura.net.cn`，检查网站是否可以访问。
    -   测试所有核心功能（创建订单、确认运单等），确保前后端通信正常，并且能成功与新的区块链网络交互。
    -   检查 `docker logs` 确认所有容器均正常运行，没有证书或连接错误。

9.  **数据迁移（可选但极难）**:
    -   如果需要旧数据，这是一个独立的项目。您需要：
        -   编写一个脚本，在旧网络上查询所有历史数据。
        -   将数据导出为中间格式（如 JSON）。
        -   在新网络启动后，编写一个脚本，将导出的数据作为新交易逐条提交到新网络中。
