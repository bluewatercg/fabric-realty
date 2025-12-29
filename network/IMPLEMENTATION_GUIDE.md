# Hyperledger Fabric Split Deployment Implementation Guide

## Introduction

This guide provides the specific code changes and implementation steps required to transform the current monolithic deployment into a split deployment architecture.

## Step 1: Certificate Authority Separation

### Current Structure
```
network/
  crypto-config.yaml
  install.sh (generates all certs)
```

### New Structure
```
network/
  crypto-config/
    org1/
      crypto-config.yaml
      generate-certs.sh
    org2/
      crypto-config.yaml
      generate-certs.sh
    org3/
      crypto-config.yaml
      generate-certs.sh
    orderer/
      crypto-config.yaml
      generate-certs.sh
  generate-all-certs.sh
```

### Implementation

**network/crypto-config/org1/crypto-config.yaml**:
```yaml
PeerOrgs:
  - Name: Org1
    Domain: org1.togettoyou.com
    EnableNodeOUs: true
    Template:
      Count: 2
    Users:
      Count: 1
```

**network/crypto-config/org1/generate-certs.sh**:
```bash
#!/bin/bash
cryptogen generate --config=crypto-config.yaml --output=../../crypto-config/peerOrganizations/org1.togettoyou.com
```

**network/generate-all-certs.sh**:
```bash
#!/bin/bash

# Generate orderer certificates
cd orderer && ./generate-certs.sh && cd ..

# Generate organization certificates
cd org1 && ./generate-certs.sh && cd ..
cd org2 && ./generate-certs.sh && cd ..
cd org3 && ./generate-certs.sh && cd ..

echo "All certificates generated successfully"
```

## Step 2: Docker Compose Split

### Current Structure
```yaml
# Single docker-compose.yaml with all services
services:
  orderer1.togettoyou.com:
    # orderer config
  peer0.org1.togettoyou.com:
    # org1 peer config
  peer0.org2.togettoyou.com:
    # org2 peer config
  peer0.org3.togettoyou.com:
    # org3 peer config
```

### New Structure

**network/orderer-compose.yaml**:
```yaml
version: '2.1'

networks:
  fabric_network:
    name: fabric_togettoyou_network
    driver: bridge

services:
  orderer1.togettoyou.com:
    extends:
      file: docker-compose-base.yaml
      service: order-base
    container_name: orderer1.togettoyou.com
    ports:
      - "7050:7050"
    volumes:
      - ./config/genesis.block:/etc/hyperledger/config/genesis.block
      - ./crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer1.togettoyou.com/:/etc/hyperledger/orderer
      - ./data/orderer1.togettoyou.com:/var/hyperledger/production/orderer
    networks:
      - fabric_network

  orderer2.togettoyou.com:
    extends:
      file: docker-compose-base.yaml
      service: order-base
    container_name: orderer2.togettoyou.com
    ports:
      - "8050:7050"
    volumes:
      - ./config/genesis.block:/etc/hyperledger/config/genesis.block
      - ./crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer2.togettoyou.com/:/etc/hyperledger/orderer
      - ./data/orderer2.togettoyou.com:/var/hyperledger/production/orderer
    networks:
      - fabric_network

  orderer3.togettoyou.com:
    extends:
      file: docker-compose-base.yaml
      service: order-base
    container_name: orderer3.togettoyou.com
    ports:
      - "9050:7050"
    volumes:
      - ./config/genesis.block:/etc/hyperledger/config/genesis.block
      - ./crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer3.togettoyou.com/:/etc/hyperledger/orderer
      - ./data/orderer3.togettoyou.com:/var/hyperledger/production/orderer
    networks:
      - fabric_network
```

**network/org1-compose.yaml**:
```yaml
version: '2.1'

networks:
  fabric_network:
    name: fabric_togettoyou_network
    external: true

services:
  peer0.org1.togettoyou.com:
    extends:
      file: docker-compose-base.yaml
      service: peer-base
    container_name: peer0.org1.togettoyou.com
    environment:
      - CORE_PEER_ID=peer0.org1.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_ADDRESS=peer0.org1.togettoyou.com:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.togettoyou.com:7052
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org1.togettoyou.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.togettoyou.com:7051
    ports:
      - "7051:7051"
      - "7053:7053"
    volumes:
      - ./crypto-config/peerOrganizations/org1.togettoyou.com/peers/peer0.org1.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer0.org1.togettoyou.com:/var/hyperledger/production
    networks:
      - fabric_network

  peer1.org1.togettoyou.com:
    extends:
      file: docker-compose-base.yaml
      service: peer-base
    container_name: peer1.org1.togettoyou.com
    environment:
      - CORE_PEER_ID=peer1.org1.togettoyou.com
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_ADDRESS=peer1.org1.togettoyou.com:7051
      - CORE_PEER_CHAINCODEADDRESS=peer1.org1.togettoyou.com:7052
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.togettoyou.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org1.togettoyou.com:7051
    ports:
      - "17051:7051"
      - "17053:7053"
    volumes:
      - ./crypto-config/peerOrganizations/org1.togettoyou.com/peers/peer1.org1.togettoyou.com:/etc/hyperledger/peer
      - ./data/peer1.org1.togettoyou.com:/var/hyperledger/production
    networks:
      - fabric_network
```

## Step 3: Application Configuration Updates

### Current Configuration
```yaml
# application/server/config/config-docker.yaml
fabric:
  organizations:
    org1:
      certPath: /network/crypto-config/peerOrganizations/org1.togettoyou.com/users/User1@org1.togettoyou.com/msp/signcerts
      keyPath: /network/crypto-config/peerOrganizations/org1.togettoyou.com/users/User1@org1.togettoyou.com/msp/keystore
      tlsCertPath: /network/crypto-config/peerOrganizations/org1.togettoyou.com/peers/peer0.org1.togettoyou.com/tls/ca.crt
      peerEndpoint: peer0.org1.togettoyou.com:7051
```

### New Configuration Structure

**application/server/config/org1-config.yaml**:
```yaml
server:
  port: 8080

fabric:
  channelName: mychannel
  chaincodeName: mychaincode
  organizations:
    org1:
      mspID: Org1MSP
      certPath: /network/crypto-config/org1/users/User1@org1.togettoyou.com/msp/signcerts
      keyPath: /network/crypto-config/org1/users/User1@org1.togettoyou.com/msp/keystore
      tlsCertPath: /network/crypto-config/org1/peers/peer0.org1.togettoyou.com/tls/ca.crt
      peerEndpoint: peer0.org1.togettoyou.com:7051
      gatewayPeer: peer0.org1.togettoyou.com
```

**application/server/config/org2-config.yaml**:
```yaml
server:
  port: 8080

fabric:
  channelName: mychannel
  chaincodeName: mychaincode
  organizations:
    org2:
      mspID: Org2MSP
      certPath: /network/crypto-config/org2/users/User1@org2.togettoyou.com/msp/signcerts
      keyPath: /network/crypto-config/org2/users/User1@org2.togettoyou.com/msp/keystore
      tlsCertPath: /network/crypto-config/org2/peers/peer0.org2.togettoyou.com/tls/ca.crt
      peerEndpoint: peer0.org2.togettoyou.com:7051
      gatewayPeer: peer0.org2.togettoyou.com
```

## Step 4: Deployment Script Updates

### Current install.sh Analysis

The current `install.sh` performs all operations in sequence:
1. Certificate generation (all orgs)
2. Genesis block creation
3. Channel configuration
4. All node deployment
5. Channel creation and joining
6. Chaincode deployment

### New Deployment Approach

**network/deploy-orderer.sh**:
```bash
#!/bin/bash

echo "Deploying Orderer Cluster..."
docker-compose -f orderer-compose.yaml up -d

# Wait for orderers to start
sleep 10

# Verify orderer health
docker exec orderer1.togettoyou.com orderer version
echo "Orderer cluster deployed successfully"
```

**network/deploy-org1.sh**:
```bash
#!/bin/bash

echo "Deploying Org1 Infrastructure..."

# Generate Org1 certificates
cd crypto-config/org1 && ./generate-certs.sh && cd ../..

# Deploy Org1 peers
docker-compose -f org1-compose.yaml up -d

# Wait for peers to start
sleep 5

# Verify peer health
docker exec peer0.org1.togettoyou.com peer version
echo "Org1 infrastructure deployed successfully"
```

**network/create-channel.sh**:
```bash
#!/bin/bash

echo "Creating Channel..."

# Generate channel configuration
configtxgen -configPath . -profile SampleChannel -outputCreateChannelTx channel.tx -channelID mychannel

# Create channel
docker exec -e "CORE_PEER_ADDRESS=peer0.org1.togettoyou.com:7051" peer0.org1.togettoyou.com \
  peer channel create -o orderer1.togettoyou.com:7050 -c mychannel -f channel.tx \
  --tls --cafile crypto-config/ordererOrganizations/togettoyou.com/orderers/orderer1.togettoyou.com/tls/ca.crt

echo "Channel created successfully"
```

**network/join-channel.sh**:
```bash
#!/bin/bash

echo "Joining Peers to Channel..."

# Org1 peers join
for peer in peer0.org1.togettoyou.com peer1.org1.togettoyou.com; do
  docker exec -e "CORE_PEER_ADDRESS=${peer}:7051" ${peer} \
    peer channel join -b mychannel.block
done

# Org2 peers join
for peer in peer0.org2.togettoyou.com peer1.org2.togettoyou.com; do
  docker exec -e "CORE_PEER_ADDRESS=${peer}:7051" ${peer} \
    peer channel join -b mychannel.block
done

# Org3 peers join
for peer in peer0.org3.togettoyou.com peer1.org3.togettoyou.com; do
  docker exec -e "CORE_PEER_ADDRESS=${peer}:7051" ${peer} \
    peer channel join -b mychannel.block
done

echo "All peers joined channel successfully"
```

## Step 5: Cross-Host Deployment Configuration

### DNS Configuration

**/etc/hosts entries for all hosts**:
```
# Orderer nodes
192.168.1.40 orderer1.togettoyou.com
192.168.1.41 orderer2.togettoyou.com
192.168.1.42 orderer3.togettoyou.com

# Org1 nodes
192.168.1.10 peer0.org1.togettoyou.com
192.168.1.10 peer1.org1.togettoyou.com

# Org2 nodes  
192.168.1.20 peer0.org2.togettoyou.com
192.168.1.20 peer1.org2.togettoyou.com

# Org3 nodes
192.168.1.30 peer0.org3.togettoyou.com
192.168.1.30 peer1.org3.togettoyou.com
```

### Firewall Configuration

**UFW Rules**:
```bash
# Allow Fabric ports
ufw allow 7050/tcp  # Orderer
ufw allow 7051/tcp  # Peer gossip
ufw allow 7052/tcp  # Peer chaincode
ufw allow 7053/tcp  # Peer events
ufw allow 8080/tcp  # Backend API
ufw allow 80/tcp    # Frontend

# Allow from specific hosts
ufw allow from 192.168.1.0/24 to any port 7050:7053
ufw allow from 192.168.1.0/24 to any port 8080

# Enable firewall
ufw enable
```

## Step 6: Application Deployment Updates

### Current Application Structure
```
application/
  docker-compose.yml
  server/
    config/
      config-docker.yaml
```

### New Application Structure
```
application/
  org1/
    docker-compose.yml
    config/
      config.yaml
  org2/
    docker-compose.yml
    config/
      config.yaml
  org3/
    docker-compose.yml
    config/
      config.yaml
  shared/
    docker-compose-base.yml
```

**application/org1/docker-compose.yml**:
```yaml
version: '2.1'

networks:
  fabric_network:
    name: fabric_togettoyou_network
    external: true

services:
  org1-backend:
    image: togettoyou/fabric-realty.server:latest
    container_name: org1-backend
    volumes:
      - /usr/share/zoneinfo/Asia/Shanghai:/usr/share/zoneinfo/Asia/Shanghai
      - ./../../network/crypto-config/org1:/network/crypto-config
      - ./data:/app/data
    ports:
      - "8080:8080"
    networks:
      - fabric_network
    environment:
      - TZ=Asia/Shanghai
      - ORG_ROLE=org1
      - FABRIC_CONFIG_PATH=/app/config/org1-config.yaml

  org1-frontend:
    image: togettoyou/fabric-realty.web:latest
    container_name: org1-frontend
    ports:
      - "8000:80"
    networks:
      - fabric_network
    environment:
      - VUE_APP_API_BASE_URL=http://org1-backend:8080
      - VUE_APP_ORG_ROLE=org1
```

## Step 7: Configuration Management

### Environment Variables Strategy

**application/org1/.env**:
```env
# Organization-specific configuration
ORG_ID=org1
ORG_NAME=OEM
ORG_ROLE=oem

# Fabric connection details
FABRIC_GATEWAY_PEER=peer0.org1.togettoyou.com:7051
FABRIC_MSP_ID=Org1MSP

# API configuration
API_PORT=8080
API_BASE_PATH=/api/oem

# Database configuration
DB_PATH=/app/data/org1.db
```

### Configuration Loading Updates

**application/server/main.go updates**:
```go
// Load organization-specific configuration
orgRole := os.Getenv("ORG_ROLE")
if orgRole == "" {
    orgRole = "org1" // default
}

configPath := fmt.Sprintf("config/%s-config.yaml", orgRole)
config, err := config.LoadConfig(configPath)
if err != nil {
    log.Fatalf("Failed to load configuration: %v", err)
}
```

## Step 8: Monitoring and Logging

### Centralized Logging Configuration

**network/logging-config.yaml**:
```yaml
version: '1'
disable_existing_loggers: False
formatters:
  standard:
    format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    level: DEBUG
    formatter: standard
    stream: ext://sys.stdout
  file:
    class: logging.handlers.RotatingFileHandler
    level: INFO
    formatter: standard
    filename: /var/log/fabric/fabric.log
    maxBytes: 10485760
    backupCount: 5
loggers:
  hyperledger:
    level: INFO
    handlers: [console, file]
    propagate: no
```

### Health Check Endpoints

**Add to application/server/api/health.go**:
```go
func (h *HealthHandler) OrgHealth(c *gin.Context) {
    org := c.Param("org")
    
    // Check Fabric connection
    gateway, err := fabric.GetGateway(org)
    if err != nil {
        c.JSON(http.StatusServiceUnavailable, gin.H{
            "status": "unhealthy",
            "error": err.Error(),
            "component": "fabric-gateway"
        })
        return
    }
    
    // Check database connection
    dbHealth := database.CheckHealth()
    
    c.JSON(http.StatusOK, gin.H{
        "status": "healthy",
        "org": org,
        "fabric": "connected",
        "database": dbHealth,
        "timestamp": time.Now().UTC()
    })
}
```

## Implementation Checklist

- [ ] Create organization-specific crypto-config directories
- [ ] Split docker-compose.yaml into organization-specific files
- [ ] Update application configuration for organization isolation
- [ ] Implement organization-specific backend configurations
- [ ] Configure DNS resolution for cross-host communication
- [ ] Set up firewall rules for Fabric ports
- [ ] Update deployment scripts for phased deployment
- [ ] Implement health monitoring endpoints
- [ ] Configure centralized logging
- [ ] Test cross-organization communication
- [ ] Validate chaincode deployment across split network
- [ ] Test failover scenarios

## Migration Strategy

### Phase 1: Preparation
1. Backup existing network data
2. Document current ledger state
3. Test certificate generation scripts
4. Verify DNS and network connectivity

### Phase 2: Orderer Deployment
1. Deploy orderer cluster on dedicated host
2. Verify Raft consensus establishment
3. Test orderer failover scenarios

### Phase 3: Organization Deployment
1. Deploy Org1 infrastructure
2. Verify peer communication
3. Repeat for Org2 and Org3

### Phase 4: Channel Migration
1. Create new channel with updated configuration
2. Join all peers to new channel
3. Update anchor peer configurations

### Phase 5: Chaincode Migration
1. Package current chaincode version
2. Install on all peers
3. Collect approvals from all organizations
4. Commit chaincode definition

### Phase 6: Application Migration
1. Deploy organization-specific backends
2. Configure role-based access control
3. Deploy frontends with proper API endpoints
4. Test end-to-end functionality

### Phase 7: Validation and Cutover
1. Perform comprehensive testing
2. Validate ledger consistency
3. Test failover scenarios
4. Monitor performance metrics
5. Execute cutover plan

## Rollback Plan

1. **Detection**: Monitor for deployment failures
2. **Containment**: Isolate affected components
3. **Recovery**: Restore from backup
4. **Verification**: Validate system integrity
5. **Communication**: Notify stakeholders

**Rollback Script**:
```bash
#!/bin/bash

echo "Initiating rollback..."

# Stop all containers
docker-compose -f orderer-compose.yaml down
docker-compose -f org1-compose.yaml down
docker-compose -f org2-compose.yaml down
docker-compose -f org3-compose.yaml down

# Restore from backup
cp -r /backup/network-data/* ./data/
cp -r /backup/crypto-config/* ./crypto-config/

# Restart original deployment
docker-compose -f docker-compose-original.yaml up -d

echo "Rollback completed"
```

## Conclusion

This implementation guide provides the specific code changes and deployment strategies required to transform the current monolithic Hyperledger Fabric deployment into a distributed, organization-specific architecture. The approach maintains all existing functionality while enabling independent deployment and management of each organization's infrastructure.

**Key Benefits**:
- Independent organization management
- Enhanced security through MSP isolation
- Improved scalability and fault tolerance
- Operational autonomy for each business entity
- Maintained consortium unity and shared ledger

**Next Steps**:
1. Implement the certificate authority separation
2. Create organization-specific Docker Compose files
3. Update application configuration management
4. Configure cross-host communication
5. Test the deployment sequence
6. Validate end-to-end functionality