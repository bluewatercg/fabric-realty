# Hyperledger Fabric Multi-Server Deployment Plan

## Network Architecture Overview

### Server Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Hyperledger Fabric Network                        │
├─────────────────┬─────────────────┬─────────────────┬─────────────────┤
│   Server 1       │   Server 2       │   Server 3       │   Server 4       │
│  (192.168.1.10)  │  (192.168.1.20)  │  (192.168.1.30)  │  (192.168.1.40)  │
├─────────────────┼─────────────────┼─────────────────┼─────────────────┤
│  主机厂 (OEM)   │ 零部件生产厂     │  承运单位       │  平台和监管     │
│                 │  (Manufacturer)  │  (Carrier)      │  (Platform)     │
├─────────────────┼─────────────────┼─────────────────┼─────────────────┤
│  Org1 CA        │  Org2 CA        │  Org3 CA        │  Orderer CA     │
│  peer0.org1     │  peer0.org2     │  peer0.org3     │  orderer1       │
│  peer1.org1     │  peer1.org2     │  peer1.org3     │  orderer2       │
│  OEM Backend    │  Manufacturer   │  Carrier        │  Platform       │
│  OEM Frontend   │  Backend        │  Backend        │  Backend        │
│                 │  Manufacturer   │  Carrier        │  Platform       │
│                 │  Frontend       │  Frontend       │  Frontend       │
│                 │                 │                 │  Monitoring     │
│                 │                 │                 │  Tools          │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

### Network Topology

```mermaid
graph TD
    subgraph Server1[Server 1: 主机厂]
        CA1[Org1 CA]
        Peer0_Org1[peer0.org1]
        Peer1_Org1[peer1.org1]
        Backend1[OEM Backend]
        Frontend1[OEM Frontend]
    end
    
    subgraph Server2[Server 2: 零部件生产厂]
        CA2[Org2 CA]
        Peer0_Org2[peer0.org2]
        Peer1_Org2[peer1.org2]
        Backend2[Manufacturer Backend]
        Frontend2[Manufacturer Frontend]
    end
    
    subgraph Server3[Server 3: 承运单位]
        CA3[Org3 CA]
        Peer0_Org3[peer0.org3]
        Peer1_Org3[peer1.org3]
        Backend3[Carrier Backend]
        Frontend3[Carrier Frontend]
    end
    
    subgraph Server4[Server 4: 平台和监管]
        OrdererCA[Orderer CA]
        Orderer1[orderer1]
        Orderer2[orderer2]
        Orderer3[orderer3]
        Backend4[Platform Backend]
        Frontend4[Platform Frontend]
        Monitor[Monitoring Tools]
    end
    
    %% Cross-server connections
    Peer0_Org1 -->|Anchor| Orderer1
    Peer0_Org2 -->|Anchor| Orderer1
    Peer0_Org3 -->|Anchor| Orderer1
    
    Orderer1 -->|Raft| Orderer2
    Orderer2 -->|Raft| Orderer3
    
    Backend1 -->|gRPC| Peer0_Org1
    Backend2 -->|gRPC| Peer0_Org2
    Backend3 -->|gRPC| Peer0_Org3
    Backend4 -->|gRPC| Peer0_Org1
    Backend4 -->|gRPC| Peer0_Org2
    Backend4 -->|gRPC| Peer0_Org3
```

## Server-Specific Deployment Files

### Server 1: 主机厂 (OEM) - 192.168.1.10

#### Directory Structure
```
/opt/fabric/
├── crypto-config/
│   └── org1.togettoyou.com/
├── data/
│   ├── peer0.org1.togettoyou.com/
│   └── peer1.org1.togettoyou.com/
├── config/
│   ├── core.yaml
│   └── org1-config.yaml
├── docker-compose.yml
├── generate-certs.sh
└── startup.sh
```

#### docker-compose.yml
```yaml
version: '3.8'

networks:
  fabric_network:
    name: fabric_togettoyou_network
    external: true

services:
  # Certificate Authority for Org1
  ca.org1:
    image: hyperledger/fabric-ca:1.5.10
    container_name: ca.org1
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-org1
      - FABRIC_CA_SERVER_PORT=7054
      - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:17054
    ports:
      - "7054:7054"
      - "17054:17054"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ./crypto-config/org1:/etc/hyperledger/fabric-ca-server
    networks:
      - fabric_network

  # Peer 0 for Org1
  peer0.org1:
    image: hyperledger/fabric-peer:2.5.10
    container_name: peer0.org1.togettoyou.com
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer0.org1.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_ADDRESS=peer0.org1.togettoyou.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.togettoyou.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.togettoyou.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org1.togettoyou.com:7051
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/ca.crt
      - CORE_OPERATIONS_LISTENADDRESS=peer0.org1.togettoyou.com:9443
      - CORE_METRICS_PROVIDER=prometheus
    ports:
      - "7051:7051"
      - "7052:7052"
      - "7053:7053"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - ./crypto-config/peerOrganizations/org1.togettoyou.com/peers/peer0.org1.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer0.org1.togettoyou.com:/var/hyperledger/production
    depends_on:
      - ca.org1
    networks:
      - fabric_network

  # Peer 1 for Org1
  peer1.org1:
    image: hyperledger/fabric-peer:2.5.10
    container_name: peer1.org1.togettoyou.com
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer1.org1.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_ADDRESS=peer1.org1.togettoyou.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer1.org1.togettoyou.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org1.togettoyou.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.togettoyou.com:7051
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/ca.crt
      - CORE_OPERATIONS_LISTENADDRESS=peer1.org1.togettoyou.com:9444
      - CORE_METRICS_PROVIDER=prometheus
    ports:
      - "17051:7051"
      - "17052:7052"
      - "17053:7053"
      - "9444:9444"
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - ./crypto-config/peerOrganizations/org1.togettoyou.com/peers/peer1.org1.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer1.org1.togettoyou.com:/var/hyperledger/production
    depends_on:
      - ca.org1
    networks:
      - fabric_network

  # OEM Backend Service
  oem-backend:
    image: togettoyou/fabric-realty.server:latest
    container_name: oem-backend
    volumes:
      - /usr/share/zoneinfo/Asia/Shanghai:/usr/share/zoneinfo/Asia/Shanghai
      - ./crypto-config:/network/crypto-config
      - ./data/application:/app/data
    ports:
      - "8080:8080"
    networks:
      - fabric_network
    environment:
      - TZ=Asia/Shanghai
      - ORG_ROLE=org1
      - ORG_NAME=主机厂
      - FABRIC_GATEWAY_PEER=peer0.org1.togettoyou.com:7051
      - API_BASE_PATH=/api/oem
    depends_on:
      - peer0.org1

  # OEM Frontend Service
  oem-frontend:
    image: togettoyou/fabric-realty.web:latest
    container_name: oem-frontend
    ports:
      - "8000:80"
    networks:
      - fabric_network
    environment:
      - VUE_APP_API_BASE_URL=http://oem-backend:8080
      - VUE_APP_ORG_ROLE=org1
      - VUE_APP_ORG_NAME=主机厂
      - VUE_APP_TITLE=主机厂供应链管理系统
    depends_on:
      - oem-backend
```

#### generate-certs.sh
```bash
#!/bin/bash

echo "Generating certificates for Org1 (主机厂)..."

# Create directory structure
mkdir -p crypto-config/peerOrganizations/org1.togettoyou.com

# Generate crypto material using fabric-ca-client
docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client register --id.name peer0 --id.secret peer0pw --id.type peer -u http://ca.org1:7054

docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client register --id.name peer1 --id.secret peer1pw --id.type peer -u http://ca.org1:7054

docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client register --id.name admin --id.secret adminpw --id.type admin -u http://ca.org1:7054

docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client register --id.name user1 --id.secret user1pw --id.type user -u http://ca.org1:7054

# Enroll identities
docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client enroll -u http://peer0:peer0pw@ca.org1:7054 --csr.names C=CN,ST=Shanghai,L=Shanghai,O=org1.togettoyou.com,OU=peer --mspdir peerOrganizations/org1.togettoyou.com/peers/peer0.org1.togettoyou.com/msp

docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client enroll -u http://peer1:peer1pw@ca.org1:7054 --csr.names C=CN,ST=Shanghai,L=Shanghai,O=org1.togettoyou.com,OU=peer --mspdir peerOrganizations/org1.togettoyou.com/peers/peer1.org1.togettoyou.com/msp

docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client enroll -u http://admin:adminpw@ca.org1:7054 --csr.names C=CN,ST=Shanghai,L=Shanghai,O=org1.togettoyou.com,OU=admin --mspdir peerOrganizations/org1.togettoyou.com/users/Admin@org1.togettoyou.com/msp

docker run --rm -v $(pwd)/crypto-config:/etc/hyperledger/fabric-ca-client 
  -e FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-client 
  hyperledger/fabric-ca:1.5.10 
  fabric-ca-client enroll -u http://user1:user1pw@ca.org1:7054 --csr.names C=CN,ST=Shanghai,L=Shanghai,O=org1.togettoyou.com,OU=user --mspdir peerOrganizations/org1.togettoyou.com/users/User1@org1.togettoyou.com/msp

echo "Org1 certificates generated successfully"
```

### Server 2: 零部件生产厂 (Manufacturer) - 192.168.1.20

#### Directory Structure
```
/opt/fabric/
├── crypto-config/
│   └── org2.togettoyou.com/
├── data/
│   ├── peer0.org2.togettoyou.com/
│   └── peer1.org2.togettoyou.com/
├── config/
│   ├── core.yaml
│   └── org2-config.yaml
├── docker-compose.yml
├── generate-certs.sh
└── startup.sh
```

#### docker-compose.yml
```yaml
version: '3.8'

networks:
  fabric_network:
    name: fabric_togettoyou_network
    external: true

services:
  # Certificate Authority for Org2
  ca.org2:
    image: hyperledger/fabric-ca:1.5.10
    container_name: ca.org2
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-org2
      - FABRIC_CA_SERVER_PORT=7054
      - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:17054
    ports:
      - "7054:7054"
      - "17054:17054"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ./crypto-config/org2:/etc/hyperledger/fabric-ca-server
    networks:
      - fabric_network

  # Peer 0 for Org2
  peer0.org2:
    image: hyperledger/fabric-peer:2.5.10
    container_name: peer0.org2.togettoyou.com
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer0.org2.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org2MSP
      - CORE_PEER_ADDRESS=peer0.org2.togettoyou.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org2.togettoyou.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org2.togettoyou.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org2.togettoyou.com:7051
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/ca.crt
      - CORE_OPERATIONS_LISTENADDRESS=peer0.org2.togettoyou.com:9443
      - CORE_METRICS_PROVIDER=prometheus
    ports:
      - "7051:7051"
      - "7052:7052"
      - "7053:7053"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - ./crypto-config/peerOrganizations/org2.togettoyou.com/peers/peer0.org2.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer0.org2.togettoyou.com:/var/hyperledger/production
    depends_on:
      - ca.org2
    networks:
      - fabric_network

  # Peer 1 for Org2
  peer1.org2:
    image: hyperledger/fabric-peer:2.5.10
    container_name: peer1.org2.togettoyou.com
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer1.org2.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org2MSP
      - CORE_PEER_ADDRESS=peer1.org2.togettoyou.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer1.org2.togettoyou.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org2.togettoyou.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org2.togettoyou.com:7051
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/ca.crt
      - CORE_OPERATIONS_LISTENADDRESS=peer1.org2.togettoyou.com:9444
      - CORE_METRICS_PROVIDER=prometheus
    ports:
      - "17051:7051"
      - "17052:7052"
      - "17053:7053"
      - "9444:9444"
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - ./crypto-config/peerOrganizations/org2.togettoyou.com/peers/peer1.org2.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer1.org2.togettoyou.com:/var/hyperledger/production
    depends_on:
      - ca.org2
    networks:
      - fabric_network

  # Manufacturer Backend Service
  manufacturer-backend:
    image: togettoyou/fabric-realty.server:latest
    container_name: manufacturer-backend
    volumes:
      - /usr/share/zoneinfo/Asia/Shanghai:/usr/share/zoneinfo/Asia/Shanghai
      - ./crypto-config:/network/crypto-config
      - ./data/application:/app/data
    ports:
      - "8080:8080"
    networks:
      - fabric_network
    environment:
      - TZ=Asia/Shanghai
      - ORG_ROLE=org2
      - ORG_NAME=零部件生产厂
      - FABRIC_GATEWAY_PEER=peer0.org2.togettoyou.com:7051
      - API_BASE_PATH=/api/manufacturer
    depends_on:
      - peer0.org2

  # Manufacturer Frontend Service
  manufacturer-frontend:
    image: togettoyou/fabric-realty.web:latest
    container_name: manufacturer-frontend
    ports:
      - "8000:80"
    networks:
      - fabric_network
    environment:
      - VUE_APP_API_BASE_URL=http://manufacturer-backend:8080
      - VUE_APP_ORG_ROLE=org2
      - VUE_APP_ORG_NAME=零部件生产厂
      - VUE_APP_TITLE=零部件生产管理系统
    depends_on:
      - manufacturer-backend
```

### Server 3: 承运单位 (Carrier) - 192.168.1.30

#### Directory Structure
```
/opt/fabric/
├── crypto-config/
│   └── org3.togettoyou.com/
├── data/
│   ├── peer0.org3.togettoyou.com/
│   └── peer1.org3.togettoyou.com/
├── config/
│   ├── core.yaml
│   └── org3-config.yaml
├── docker-compose.yml
├── generate-certs.sh
└── startup.sh
```

#### docker-compose.yml
```yaml
version: '3.8'

networks:
  fabric_network:
    name: fabric_togettoyou_network
    external: true

services:
  # Certificate Authority for Org3
  ca.org3:
    image: hyperledger/fabric-ca:1.5.10
    container_name: ca.org3
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-org3
      - FABRIC_CA_SERVER_PORT=7054
      - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:17054
    ports:
      - "7054:7054"
      - "17054:17054"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ./crypto-config/org3:/etc/hyperledger/fabric-ca-server
    networks:
      - fabric_network

  # Peer 0 for Org3
  peer0.org3:
    image: hyperledger/fabric-peer:2.5.10
    container_name: peer0.org3.togettoyou.com
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer0.org3.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org3MSP
      - CORE_PEER_ADDRESS=peer0.org3.togettoyou.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org3.togettoyou.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org3.togettoyou.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org3.togettoyou.com:7051
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/ca.crt
      - CORE_OPERATIONS_LISTENADDRESS=peer0.org3.togettoyou.com:9443
      - CORE_METRICS_PROVIDER=prometheus
    ports:
      - "7051:7051"
      - "7052:7052"
      - "7053:7053"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - ./crypto-config/peerOrganizations/org3.togettoyou.com/peers/peer0.org3.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer0.org3.togettoyou.com:/var/hyperledger/production
    depends_on:
      - ca.org3
    networks:
      - fabric_network

  # Peer 1 for Org3
  peer1.org3:
    image: hyperledger/fabric-peer:2.5.10
    container_name: peer1.org3.togettoyou.com
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer1.org3.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org3MSP
      - CORE_PEER_ADDRESS=peer1.org3.togettoyou.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer1.org3.togettoyou.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org3.togettoyou.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org3.togettoyou.com:7051
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/ca.crt
      - CORE_OPERATIONS_LISTENADDRESS=peer1.org3.togettoyou.com:9444
      - CORE_METRICS_PROVIDER=prometheus
    ports:
      - "17051:7051"
      - "17052:7052"
      - "17053:7053"
      - "9444:9444"
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - ./crypto-config/peerOrganizations/org3.togettoyou.com/peers/peer1.org3.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer1.org3.togettoyou.com:/var/hyperledger/production
    depends_on:
      - ca.org3
    networks:
      - fabric_network

  # Carrier Backend Service
  carrier-backend:
    image: togettoyou/fabric-realty.server:latest
    container_name: carrier-backend
    volumes:
      - /usr/share/zoneinfo/Asia/Shanghai:/usr/share/zoneinfo/Asia/Shanghai
      - ./crypto-config:/network/crypto-config
      - ./data/application:/app/data
    ports:
      - "8080:8080"
    networks:
      - fabric_network
    environment:
      - TZ=Asia/Shanghai
      - ORG_ROLE=org3
      - ORG_NAME=承运单位
      - FABRIC_GATEWAY_PEER=peer0.org3.togettoyou.com:7051
      - API_BASE_PATH=/api/carrier
    depends_on:
      - peer0.org3

  # Carrier Frontend Service
  carrier-frontend:
    image: togettoyou/fabric-realty.web:latest
    container_name: carrier-frontend
    ports:
      - "8000:80"
    networks:
      - fabric_network
    environment:
      - VUE_APP_API_BASE_URL=http://carrier-backend:8080
      - VUE_APP_ORG_ROLE=org3
      - VUE_APP_ORG_NAME=承运单位
      - VUE_APP_TITLE=物流承运管理系统
    depends_on:
      - carrier-backend
```

### Server 4: 平台和监管 (Platform/Regulator) - 192.168.1.40

#### Directory Structure
```
/opt/fabric/
├── crypto-config/
│   ├── ordererOrganizations/
│   └── org3.togettoyou.com/  # Platform also has Org3 access
├── data/
│   ├── orderer1.togettoyou.com/
│   ├── orderer2.togettoyou.com/
│   ├── orderer3.togettoyou.com/
│   └── application/
├── config/
│   ├── core.yaml
│   ├── orderer-config.yaml
│   └── platform-config.yaml
├── docker-compose.yml
├── generate-certs.sh
├── monitoring/
│   ├── prometheus.yml
│   └── grafana-dashboards/
└── startup.sh
```

#### docker-compose.yml
```yaml
version: '3.8'

networks:
  fabric_network:
    name: fabric_togettoyou_network
    driver: bridge

services:
  # Orderer CA
  ca.orderer:
    image: hyperledger/fabric-ca:1.5.10
    container_name: ca.orderer
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-orderer
      - FABRIC_CA_SERVER_PORT=7054
      - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:17054
    ports:
      - "7054:7054"
      - "17054:17054"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ./crypto-config/orderer:/etc/hyperledger/fabric-ca-server
    networks:
      - fabric_network

  # Orderer 1
  orderer1:
    image: hyperledger/fabric-orderer:2.5.10
    container_name: orderer1.togettoyou.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7050
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/config/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=["/etc/hyperledger/orderer/tls/ca.crt"]
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=["/etc/hyperledger/orderer/tls/ca.crt"]
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=file
      - ORDERER_GENERAL_BOOTSTRAPFILE=/etc/hyperledger/config/genesis.block
      - ORDERER_METRICS_PROVIDER=prometheus
      - ORDERER_OPERATIONS_LISTENADDRESS=orderer1.togettoyou.com:8443
    ports:
      - "7050:7050"
      - "8443:8443"
    volumes:
      - ./config/genesis.block:/etc/hyperledger/config/genesis.block
      - ./crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer1.togettoyou.com:/etc/hyperledger/orderer
      - ./data/orderer1.togettoyou.com:/var/hyperledger/production/orderer
    networks:
      - fabric_network

  # Orderer 2
  orderer2:
    image: hyperledger/fabric-orderer:2.5.10
    container_name: orderer2.togettoyou.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7050
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/config/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=["/etc/hyperledger/orderer/tls/ca.crt"]
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=["/etc/hyperledger/orderer/tls/ca.crt"]
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=file
      - ORDERER_GENERAL_BOOTSTRAPFILE=/etc/hyperledger/config/genesis.block
      - ORDERER_METRICS_PROVIDER=prometheus
      - ORDERER_OPERATIONS_LISTENADDRESS=orderer2.togettoyou.com:8444
    ports:
      - "8050:7050"
      - "8444:8444"
    volumes:
      - ./config/genesis.block:/etc/hyperledger/config/genesis.block
      - ./crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer2.togettoyou.com:/etc/hyperledger/orderer
      - ./data/orderer2.togettoyou.com:/var/hyperledger/production/orderer
    networks:
      - fabric_network

  # Orderer 3
  orderer3:
    image: hyperledger/fabric-orderer:2.5.10
    container_name: orderer3.togettoyou.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7050
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/config/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=["/etc/hyperledger/orderer/tls/ca.crt"]
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=["/etc/hyperledger/orderer/tls/ca.crt"]
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=file
      - ORDERER_GENERAL_BOOTSTRAPFILE=/etc/hyperledger/config/genesis.block
      - ORDERER_METRICS_PROVIDER=prometheus
      - ORDERER_OPERATIONS_LISTENADDRESS=orderer3.togettoyou.com:8445
    ports:
      - "9050:7050"
      - "8445:8445"
    volumes:
      - ./config/genesis.block:/etc/hyperledger/config/genesis.block
      - ./crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer3.togettoyou.com:/etc/hyperledger/orderer
      - ./data/orderer3.togettoyou.com:/var/hyperledger/production/orderer
    networks:
      - fabric_network

  # Platform Backend Service (with access to all organizations)
  platform-backend:
    image: togettoyou/fabric-realty.server:latest
    container_name: platform-backend
    volumes:
      - /usr/share/zoneinfo/Asia/Shanghai:/usr/share/zoneinfo/Asia/Shanghai
      - ./crypto-config:/network/crypto-config
      - ./data/application:/app/data
    ports:
      - "8080:8080"
    networks:
      - fabric_network
    environment:
      - TZ=Asia/Shanghai
      - ORG_ROLE=platform
      - ORG_NAME=平台和监管
      - FABRIC_GATEWAY_PEER=peer0.org1.togettoyou.com:7051,peer0.org2.togettoyou.com:7051,peer0.org3.togettoyou.com:7051
      - API_BASE_PATH=/api/platform
      - PLATFORM_MODE=true
      - ADMIN_ORG=true
    depends_on:
      - orderer1

  # Platform Frontend Service
  platform-frontend:
    image: togettoyou/fabric-realty.web:latest
    container_name: platform-frontend
    ports:
      - "8000:80"
    networks:
      - fabric_network
    environment:
      - VUE_APP_API_BASE_URL=http://platform-backend:8080
      - VUE_APP_ORG_ROLE=platform
      - VUE_APP_ORG_NAME=平台和监管
      - VUE_APP_TITLE=供应链监管平台
      - VUE_APP_ADMIN_MODE=true
    depends_on:
      - platform-backend

  # Prometheus Monitoring
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - fabric_network

  # Grafana Dashboard
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./monitoring/grafana-dashboards:/var/lib/grafana/dashboards
    networks:
      - fabric_network
```

## Client Code Decomposition Strategy

### Current Monolithic Structure
```
application/
├── server/
│   ├── api/
│   │   ├── oem.go
│   │   ├── manufacturer.go
│   │   ├── carrier.go
│   │   └── platform.go
│   ├── service/
│   │   ├── oem_service.go
│   │   ├── manufacturer_service.go
│   │   ├── carrier_service.go
│   │   └── platform_service.go
│   └── main.go
└── web/
    ├── src/
    │   ├── views/
    │   │   ├── OemView.vue
    │   │   ├── ManufacturerView.vue
    │   │   ├── CarrierView.vue
    │   │   └── PlatformView.vue
    │   └── router/
    │       └── index.js
    └── public/
```

### New Organization-Specific Structure

#### Backend Decomposition

**application/server/org1/** (OEM)
```
org1/
├── api/
│   └── oem_routes.go
├── service/
│   └── oem_service.go
├── config/
│   └── org1-config.yaml
├── main.go
└── Dockerfile
```

**application/server/org2/** (Manufacturer)
```
org2/
├── api/
│   └── manufacturer_routes.go
├── service/
│   └── manufacturer_service.go
├── config/
│   └── org2-config.yaml
├── main.go
└── Dockerfile
```

**application/server/org3/** (Carrier)
```
org3/
├── api/
│   └── carrier_routes.go
├── service/
│   └── carrier_service.go
├── config/
│   └── org3-config.yaml
├── main.go
└── Dockerfile
```

**application/server/platform/** (Platform)
```
platform/
├── api/
│   ├── admin_routes.go
│   ├── monitoring_routes.go
│   └── org_management_routes.go
├── service/
│   ├── admin_service.go
│   ├── monitoring_service.go
│   └── org_management_service.go
├── config/
│   └── platform-config.yaml
├── main.go
└── Dockerfile
```

### Frontend Decomposition

**application/web/org1/** (OEM Frontend)
```
org1/
├── src/
│   ├── views/
│   │   ├── OrderCreation.vue
│   │   ├── OrderTracking.vue
│   │   └── Dashboard.vue
│   ├── router/
│   │   └── index.js
│   └── main.js
├── public/
├── package.json
└── Dockerfile
```

**application/web/org2/** (Manufacturer Frontend)
```
org2/
├── src/
│   ├── views/
│   │   ├── ProductionManagement.vue
│   │   ├── OrderFulfillment.vue
│   │   └── Dashboard.vue
│   ├── router/
│   │   └── index.js
│   └── main.js
├── public/
├── package.json
└── Dockerfile
```

**application/web/org3/** (Carrier Frontend)
```
org3/
├── src/
│   ├── views/
│   │   ├── ShipmentManagement.vue
│   │   ├── LocationTracking.vue
│   │   └── Dashboard.vue
│   ├── router/
│   │   └── index.js
│   └── main.js
├── public/
├── package.json
└── Dockerfile
```

**application/web/platform/** (Platform Frontend)
```
platform/
├── src/
│   ├── views/
│   │   ├── SupplyChainMonitoring.vue
│   │   ├── OrganizationManagement.vue
│   │   ├── NewOrgOnboarding.vue
│   │   └── Dashboard.vue
│   ├── router/
│   │   └── index.js
│   └── main.js
├── public/
├── package.json
└── Dockerfile
```

### Shared Components

**application/shared/**
```
shared/
├── fabric/
│   ├── gateway.go
│   ├── contract.go
│   └── utils.go
├── models/
│   ├── order.go
│   ├── shipment.go
│   └── common.go
├── utils/
│   ├── response.go
│   └── validation.go
└── config/
    └── base-config.yaml
```

## Adding New Organizations (Implemented on Platform)

### New Organization Onboarding Process

```mermaid
flowchart TD
    A[平台管理员发起] --> B[填写组织信息]
    B --> C[生成组织配置]
    C --> D[创建CA和证书]
    D --> E[更新configtx.yaml]
    E --> F[生成通道更新]
    F --> G[收集现有组织签名]
    G --> H[提交通道更新]
    H --> I[组织加入通道]
    I --> J[安装链码]
    J --> K[批准链码定义]
    K --> L[提交链码定义]
    L --> M[部署应用组件]
    M --> N[完成]
```

### Platform Implementation for Organization Management

**platform/api/org_management_routes.go**:
```go
package api

import (
    "github.com/gin-gonic/gin"
    "net/http"
    "your-project/platform/service"
)

type OrgManagementHandler struct {
    orgService *service.OrgManagementService
}

func NewOrgManagementHandler(orgService *service.OrgManagementService) *OrgManagementHandler {
    return &OrgManagementHandler{orgService: orgService}
}

func (h *OrgManagementHandler) RegisterRoutes(router *gin.RouterGroup) {
    orgGroup := router.Group("/organizations")
    {
        orgGroup.POST("", h.CreateOrganization)
        orgGroup.GET("/:orgId", h.GetOrganization)
        orgGroup.GET("", h.ListOrganizations)
        orgGroup.POST("/:orgId/approve", h.ApproveOrganization)
        orgGroup.POST("/:orgId/channel-update", h.GenerateChannelUpdate)
        orgGroup.POST("/:orgId/join-channel", h.JoinChannel)
        orgGroup.POST("/:orgId/install-chaincode", h.InstallChaincode)
        orgGroup.POST("/:orgId/approve-chaincode", h.ApproveChaincode)
    }
}

func (h *OrgManagementHandler) CreateOrganization(c *gin.Context) {
    var req service.CreateOrgRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    
    org, err := h.orgService.CreateOrganization(req)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    
    c.JSON(http.StatusCreated, org)
}

func (h *OrgManagementHandler) GenerateChannelUpdate(c *gin.Context) {
    orgId := c.Param("orgId")
    
    updateTx, err := h.orgService.GenerateChannelUpdate(orgId)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    
    c.JSON(http.StatusOK, gin.H{"updateTx": updateTx})
}
```

**platform/service/org_management_service.go**:
```go
package service

import (
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
)

type CreateOrgRequest struct {
    OrgName     string `json:"orgName"`
    OrgType     string `json:"orgType"` // "oem", "manufacturer", "carrier"
    Domain      string `json:"domain"`
    AdminUser   string `json:"adminUser"`
    Description string `json:"description"`
}

type Organization struct {
    ID          string `json:"id"`
    Name        string `json:"name"`
    Type        string `json:"type"`
    Domain      string `json:"domain"`
    Status      string `json:"status"` // "pending", "approved", "active"
    CreatedAt   string `json:"createdAt"`
    UpdatedAt   string `json:"updatedAt"`
}

type OrgManagementService struct {
    configDir string
}

func NewOrgManagementService(configDir string) *OrgManagementService {
    return &OrgManagementService{configDir: configDir}
}

func (s *OrgManagementService) CreateOrganization(req CreateOrgRequest) (*Organization, error) {
    // Generate organization ID
    orgId := fmt.Sprintf("org%d", len(s.listOrganizations())+1)
    
    // Create organization directory
    orgDir := filepath.Join(s.configDir, orgId)
    if err := os.MkdirAll(orgDir, 0755); err != nil {
        return nil, err
    }
    
    // Generate crypto-config.yaml
    cryptoConfig := fmt.Sprintf(`PeerOrgs:
  - Name: %s
    Domain: %s
    EnableNodeOUs: true
    Template:
      Count: 2
    Users:
      Count: 1
`, req.OrgName, req.Domain)
    
    if err := os.WriteFile(filepath.Join(orgDir, "crypto-config.yaml"), []byte(cryptoConfig), 0644); err != nil {
        return nil, err
    }
    
    // Generate configtx snippet
    configtxSnippet := fmt.Sprintf(`  - &%s
    Name: %s
    ID: %sMSP
    MSPDir: crypto-config/peerOrganizations/%s/msp
    AnchorPeers:
      - Host: peer0.%s
        Port: 7051
`, orgId, req.OrgName, orgId, req.Domain, req.Domain)
    
    if err := os.WriteFile(filepath.Join(orgDir, "configtx-snippet.yaml"), []byte(configtxSnippet), 0644); err != nil {
        return nil, err
    }
    
    org := &Organization{
        ID:        orgId,
        Name:      req.OrgName,
        Type:      req.OrgType,
        Domain:    req.Domain,
        Status:    "pending",
    }
    
    return org, nil
}

func (s *OrgManagementService) GenerateChannelUpdate(orgId string) (string, error) {
    // Load organization config
    orgDir := filepath.Join(s.configDir, orgId)
    
    // Generate channel update transaction
    cmd := exec.Command("configtxgen", 
        "-configPath", ".",
        "-profile", "SampleChannel",
        "-outputCreateChannelTx", "channel-update.tx",
        "-channelID", "mychannel")
    cmd.Dir = orgDir
    
    if err := cmd.Run(); err != nil {
        return "", err
    }
    
    // Read the generated transaction
    updateTx, err := os.ReadFile(filepath.Join(orgDir, "channel-update.tx"))
    if err != nil {
        return "", err
    }
    
    return string(updateTx), nil
}

func (s *OrgManagementService) listOrganizations() []Organization {
    // List all organizations in config directory
    // Implementation omitted for brevity
    return []Organization{}
}
```

### Frontend Implementation for Organization Management

**platform/src/views/OrganizationManagement.vue**:
```vue
<template>
  <div class="organization-management">
    <a-card title="组织管理">
      <template #extra>
        <a-button type="primary" @click="showCreateModal">
          <plus-outlined /> 新建组织
        </a-button>
      </template>
      
      <a-table :data-source="organizations" :columns="columns" rowKey="id">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-badge :status="getStatusColor(record.status)" :text="getStatusText(record.status)" />
          </template>
          
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button size="small" @click="viewOrg(record)">查看</a-button>
              <a-button size="small" type="primary" @click="approveOrg(record)" v-if="record.status === 'pending'">
                批准
              </a-button>
              <a-button size="small" type="primary" @click="generateUpdate(record)" v-if="record.status === 'approved'">
                生成更新
              </a-button>
              <a-button size="small" type="primary" @click="joinChannel(record)" v-if="record.status === 'channel_update_ready'">
                加入通道
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>
    
    <!-- Create Organization Modal -->
    <a-modal v-model:visible="createModalVisible" title="创建新组织" @ok="createOrganization">
      <a-form :model="newOrg" layout="vertical">
        <a-form-item label="组织名称" required>
          <a-input v-model:value="newOrg.orgName" placeholder="例如：新主机厂" />
        </a-form-item>
        
        <a-form-item label="组织类型" required>
          <a-select v-model:value="newOrg.orgType">
            <a-select-option value="oem">主机厂</a-select-option>
            <a-select-option value="manufacturer">零部件生产厂</a-select-option>
            <a-select-option value="carrier">承运单位</a-select-option>
          </a-select>
        </a-form-item>
        
        <a-form-item label="域名" required>
          <a-input v-model:value="newOrg.domain" placeholder="例如：org4.togettoyou.com" />
        </a-form-item>
        
        <a-form-item label="管理员用户" required>
          <a-input v-model:value="newOrg.adminUser" placeholder="例如：admin" />
        </a-form-item>
        
        <a-form-item label="描述">
          <a-textarea v-model:value="newOrg.description" placeholder="组织描述" />
        </a-form-item>
      </a-form>
    </a-modal>
    
    <!-- Channel Update Modal -->
    <a-modal v-model:visible="updateModalVisible" title="通道更新" :footer="null">
      <a-steps :current="updateStep">
        <a-step title="生成更新" />
        <a-step title="收集签名" />
        <a-step title="提交更新" />
      </a-steps>
      
      <div v-if="updateStep === 0" class="mt-4">
        <a-alert message="通道更新已生成" type="success" show-icon />
        <a-button type="primary" @click="nextUpdateStep">继续</a-button>
      </div>
      
      <div v-if="updateStep === 1" class="mt-4">
        <a-list :data-source="existingOrgs" item-layout="horizontal">
          <template #renderItem="{ item }">
            <a-list-item>
              <a-list-item-meta :description="item.domain">
                <template #title>
                  {{ item.name }} ({{ item.type }})
                </template>
              </a-list-item-meta>
              <template #actions>
                <a-button type="primary" @click="requestSignature(item)" :disabled="item.signed">
                  {{ item.signed ? '已签名' : '请求签名' }}
                </a-button>
              </template>
            </a-list-item>
          </template>
        </a-list>
        <a-button type="primary" @click="nextUpdateStep" :disabled="!allSigned">继续</a-button>
      </div>
      
      <div v-if="updateStep === 2" class="mt-4">
        <a-alert message="所有签名已收集，准备提交通道更新" type="success" show-icon />
        <a-button type="primary" @click="submitChannelUpdate" :loading="submitting">提交更新</a-button>
      </div>
    </a-modal>
  </div>
</template>

<script>
import { PlusOutlined } from '@ant-design/icons-vue';
import { message } from 'ant-design-vue';

const columns = [
  { title: '组织ID', dataIndex: 'id', key: 'id' },
  { title: '名称', dataIndex: 'name', key: 'name' },
  { title: '类型', dataIndex: 'type', key: 'type' },
  { title: '域名', dataIndex: 'domain', key: 'domain' },
  { title: '状态', dataIndex: 'status', key: 'status' },
  { title: '创建时间', dataIndex: 'createdAt', key: 'createdAt' },
  { title: '操作', key: 'action', scopedSlots: { customRender: 'action' } }
];

export default {
  components: { PlusOutlined },
  data() {
    return {
      columns,
      organizations: [],
      createModalVisible: false,
      updateModalVisible: false,
      updateStep: 0,
      submitting: false,
      newOrg: {
        orgName: '',
        orgType: 'oem',
        domain: '',
        adminUser: 'admin',
        description: ''
      },
      currentOrg: null,
      existingOrgs: []
    };
  },
  created() {
    this.loadOrganizations();
  },
  methods: {
    getStatusColor(status) {
      const colors = {
        pending: 'processing',
        approved: 'warning', 
        channel_update_ready: 'warning',
        active: 'success'
      };
      return colors[status] || 'default';
    },
    
    getStatusText(status) {
      const texts = {
        pending: '待批准',
        approved: '已批准',
        channel_update_ready: '准备加入通道',
        active: '活动'
      };
      return texts[status] || status;
    },
    
    showCreateModal() {
      this.createModalVisible = true;
    },
    
    async createOrganization() {
      try {
        const response = await this.$api.post('/api/platform/organizations', this.newOrg);
        message.success('组织创建成功');
        this.createModalVisible = false;
        this.loadOrganizations();
        this.newOrg = {
          orgName: '',
          orgType: 'oem',
          domain: '',
          adminUser: 'admin',
          description: ''
        };
      } catch (error) {
        message.error('创建组织失败: ' + error.message);
      }
    },
    
    async loadOrganizations() {
      try {
        const response = await this.$api.get('/api/platform/organizations');
        this.organizations = response.data;
      } catch (error) {
        message.error('加载组织列表失败: ' + error.message);
      }
    },
    
    async approveOrg(org) {
      try {
        await this.$api.post(`/api/platform/organizations/${org.id}/approve`);
        message.success('组织批准成功');
        this.loadOrganizations();
      } catch (error) {
        message.error('批准失败: ' + error.message);
      }
    },
    
    async generateUpdate(org) {
      try {
        this.currentOrg = org;
        const response = await this.$api.post(`/api/platform/organizations/${org.id}/channel-update`);
        
        // Load existing organizations for signature collection
        const orgsResponse = await this.$api.get('/api/platform/organizations?status=active');
        this.existingOrgs = orgsResponse.data.map(o => ({ ...o, signed: false }));
        
        this.updateModalVisible = true;
        this.updateStep = 0;
        message.success('通道更新生成成功');
      } catch (error) {
        message.error('生成更新失败: ' + error.message);
      }
    },
    
    nextUpdateStep() {
      this.updateStep++;
    },
    
    async requestSignature(org) {
      try {
        await this.$api.post(`/api/platform/organizations/${this.currentOrg.id}/request-signature`, {
          orgId: org.id
        });
        
        const index = this.existingOrgs.findIndex(o => o.id === org.id);
        if (index !== -1) {
          this.existingOrgs[index].signed = true;
        }
        message.success('签名请求已发送');
      } catch (error) {
        message.error('请求签名失败: ' + error.message);
      }
    },
    
    async submitChannelUpdate() {
      try {
        this.submitting = true;
        await this.$api.post(`/api/platform/organizations/${this.currentOrg.id}/submit-update`);
        message.success('通道更新提交成功');
        this.updateModalVisible = false;
        this.loadOrganizations();
      } catch (error) {
        message.error('提交更新失败: ' + error.message);
      } finally {
        this.submitting = false;
      }
    }
  },
  computed: {
    allSigned() {
      return this.existingOrgs.every(org => org.signed);
    }
  }
};
</script>

<style scoped>
.organization-management {
  padding: 20px;
}
.mt-4 {
  margin-top: 20px;
}
</style>
```

### Deployment Sequence for New Organizations

```mermaid
sequenceDiagram
    participant PlatformAdmin
    participant PlatformBackend
    participant Org1Backend
    participant Org2Backend
    participant Org3Backend
    participant Orderer
    
    PlatformAdmin->>PlatformBackend: 创建新组织 (POST /organizations)
    PlatformBackend->>PlatformBackend: 生成组织配置
    PlatformBackend->>PlatformBackend: 创建CA和证书
    PlatformBackend-->>PlatformAdmin: 返回组织信息
    
    PlatformAdmin->>PlatformBackend: 批准组织 (POST /organizations/{id}/approve)
    PlatformBackend->>PlatformBackend: 更新组织状态
    PlatformBackend-->>PlatformAdmin: 批准成功
    
    PlatformAdmin->>PlatformBackend: 生成通道更新 (POST /organizations/{id}/channel-update)
    PlatformBackend->>PlatformBackend: 更新configtx.yaml
    PlatformBackend->>PlatformBackend: 生成channel-update.tx
    PlatformBackend-->>PlatformAdmin: 返回更新事务
    
    PlatformAdmin->>Org1Backend: 请求签名 (通过平台API)
    Org1Backend->>Org1Backend: 验证更新
    Org1Backend->>Org1Backend: 签名事务
    Org1Backend-->>PlatformAdmin: 返回签名
    
    PlatformAdmin->>Org2Backend: 请求签名
    Org2Backend->>Org2Backend: 验证更新
    Org2Backend->>Org2Backend: 签名事务
    Org2Backend-->>PlatformAdmin: 返回签名
    
    PlatformAdmin->>Org3Backend: 请求签名
    Org3Backend->>Org3Backend: 验证更新
    Org3Backend->>Org3Backend: 签名事务
    Org3Backend-->>PlatformAdmin: 返回签名
    
    PlatformAdmin->>PlatformBackend: 提交通道更新 (POST /organizations/{id}/submit-update)
    PlatformBackend->>Orderer: 提交更新事务
    Orderer->>Orderer: 验证签名
    Orderer->>Orderer: 更新通道配置
    Orderer-->>PlatformBackend: 更新成功
    PlatformBackend-->>PlatformAdmin: 完成
    
    PlatformAdmin->>PlatformBackend: 组织加入通道 (POST /organizations/{id}/join-channel)
    PlatformBackend->>NewOrgPeer: 加入通道
    NewOrgPeer->>Orderer: 获取区块
    Orderer-->>NewOrgPeer: 返回区块
    NewOrgPeer-->>PlatformBackend: 加入成功
    PlatformBackend-->>PlatformAdmin: 完成
    
    PlatformAdmin->>PlatformBackend: 安装链码 (POST /organizations/{id}/install-chaincode)
    PlatformBackend->>NewOrgPeer: 安装链码
    NewOrgPeer-->>PlatformBackend: 安装成功
    PlatformBackend-->>PlatformAdmin: 完成
    
    PlatformAdmin->>PlatformBackend: 批准链码 (POST /organizations/{id}/approve-chaincode)
    PlatformBackend->>NewOrgPeer: 批准链码
    NewOrgPeer-->>PlatformBackend: 批准成功
    PlatformBackend-->>PlatformAdmin: 完成
```

## Configuration Management

### DNS Configuration (All Servers)

**/etc/hosts**:
```
# Orderer Cluster
192.168.1.40 orderer1.togettoyou.com
192.168.1.40 orderer2.togettoyou.com
192.168.1.40 orderer3.togettoyou.com

# Org1 - 主机厂
192.168.1.10 peer0.org1.togettoyou.com
192.168.1.10 peer1.org1.togettoyou.com
192.168.1.10 oem-backend.togettoyou.com

# Org2 - 零部件生产厂
192.168.1.20 peer0.org2.togettoyou.com
192.168.1.20 peer1.org2.togettoyou.com
192.168.1.20 manufacturer-backend.togettoyou.com

# Org3 - 承运单位
192.168.1.30 peer0.org3.togettoyou.com
192.168.1.30 peer1.org3.togettoyou.com
192.168.1.30 carrier-backend.togettoyou.com

# Platform
192.168.1.40 platform-backend.togettoyou.com
192.168.1.40 prometheus.togettoyou.com
192.168.1.40 grafana.togettoyou.com
```

### Firewall Configuration (All Servers)

```bash
# Allow Fabric ports
ufw allow 7050/tcp  # Orderer
ufw allow 7051/tcp  # Peer gossip
ufw allow 7052/tcp  # Peer chaincode
ufw allow 7053/tcp  # Peer events
ufw allow 7054/tcp  # CA
ufw allow 8080/tcp  # Backend API
ufw allow 80/tcp    # Frontend
ufw allow 9090/tcp  # Prometheus
ufw allow 3000/tcp  # Grafana

# Allow from specific network
ufw allow from 192.168.1.0/24 to any port 7050:7054
ufw allow from 192.168.1.0/24 to any port 8080
ufw allow from 192.168.1.0/24 to any port 80

# Enable firewall
ufw enable
```

## Deployment Checklist

### Server 1: 主机厂
- [ ] Install Docker and Docker Compose
- [ ] Configure DNS resolution
- [ ] Set up firewall rules
- [ ] Create directory structure
- [ ] Generate certificates
- [ ] Deploy Docker Compose stack
- [ ] Verify peer connectivity
- [ ] Test backend API
- [ ] Verify frontend access

### Server 2: 零部件生产厂
- [ ] Install Docker and Docker Compose
- [ ] Configure DNS resolution
- [ ] Set up firewall rules
- [ ] Create directory structure
- [ ] Generate certificates
- [ ] Deploy Docker Compose stack
- [ ] Verify peer connectivity
- [ ] Test backend API
- [ ] Verify frontend access

### Server 3: 承运单位
- [ ] Install Docker and Docker Compose
- [ ] Configure DNS resolution
- [ ] Set up firewall rules
- [ ] Create directory structure
- [ ] Generate certificates
- [ ] Deploy Docker Compose stack
- [ ] Verify peer connectivity
- [ ] Test backend API
- [ ] Verify frontend access

### Server 4: 平台和监管
- [ ] Install Docker and Docker Compose
- [ ] Configure DNS resolution
- [ ] Set up firewall rules
- [ ] Create directory structure
- [ ] Generate orderer certificates
- [ ] Deploy orderer cluster
- [ ] Verify Raft consensus
- [ ] Deploy platform backend
- [ ] Deploy monitoring tools
- [ ] Configure Prometheus and Grafana
- [ ] Test platform functionality

## Validation Procedures

### Network Connectivity Test
```bash
# Test orderer connectivity from each server
ping orderer1.togettoyou.com
telnet orderer1.togettoyou.com 7050

# Test cross-organization peer connectivity
ping peer0.org1.togettoyou.com
telnet peer0.org1.togettoyou.com 7051
```

### Fabric Network Test
```bash
# Check peer health
docker exec peer0.org1.togettoyou.com peer channel list

# Test chaincode query
docker exec peer0.org1.togettoyou.com peer chaincode query -C mychannel -n mychaincode -c '{"Args":["Hello"]}'

# Check ledger height consistency
docker exec peer0.org1.togettoyou.com peer channel getinfo -c mychannel
docker exec peer0.org2.togettoyou.com peer channel getinfo -c mychannel
docker exec peer0.org3.togettoyou.com peer channel getinfo -c mychannel
```

### Application Test
```bash
# Test backend APIs
curl http://oem-backend.togettoyou.com:8080/api/oem/health
curl http://manufacturer-backend.togettoyou.com:8080/api/manufacturer/health
curl http://carrier-backend.togettoyou.com:8080/api/carrier/health
curl http://platform-backend.togettoyou.com:8080/api/platform/health

# Test frontend access
curl http://oem-frontend.togettoyou.com:8000
curl http://manufacturer-frontend.togettoyou.com:8000
curl http://carrier-frontend.togettoyou.com:8000
curl http://platform-frontend.togettoyou.com:8000
```

## Conclusion

This deployment plan provides a comprehensive blueprint for distributing the Hyperledger Fabric network across four servers, each serving a specific business role. The architecture ensures:

1. **Operational Independence**: Each organization manages their own infrastructure
2. **Security Isolation**: Separate Certificate Authorities and MSP boundaries
3. **Consortium Unity**: Shared ledger through distributed orderer service
4. **Scalability**: Platform-based organization onboarding process
5. **Monitoring**: Centralized monitoring and management

The implementation follows a phased approach, starting with infrastructure deployment, followed by network configuration, and concluding with application deployment and validation.