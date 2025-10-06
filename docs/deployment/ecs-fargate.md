# AWS ECS Fargate Deployment Guide

Complete guide for deploying the Video Tutorials microservices application to AWS ECS Fargate with production-ready containerized architecture.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Advanced Configuration](#advanced-configuration)
- [Monitoring & Observability](#monitoring--observability)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## Overview

AWS ECS (Elastic Container Service) with Fargate is a serverless container orchestration platform. It provides the best demonstration of AWS Solutions Architect skills and is ideal for production microservices.

### Why ECS Fargate?

✅ **Best AWS portfolio showcase** - Demonstrates advanced architecture skills
✅ **True microservices** - Container orchestration and service mesh ready
✅ **Serverless containers** - No EC2 management required
✅ **Fine-grained control** - Precise resource allocation
✅ **Cost optimization** - Fargate Spot for 70% savings
✅ **Enterprise-ready** - Blue/green deployments, service discovery

### Time Estimate
- **First deployment:** 20-30 hours (including learning)
- **Subsequent deploys:** 2-5 minutes (with CI/CD)

### Monthly Cost Estimate
- **Development:** ~$75-85/month
- **Production:** ~$150-225/month
- **Production with Spot:** ~$100-150/month

## Prerequisites

### Required Tools

```bash
# Check versions
aws --version          # AWS CLI 2.x+
docker --version       # Docker 20.x+
node --version         # Node.js 20.11.0+

# Optional but recommended
terraform --version    # Terraform 1.x+ (for IaC)
jq --version          # jq 1.6+ (for JSON parsing)
```

### Install Docker (if needed)

**Linux:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

**macOS:**
```bash
brew install --cask docker
```

**Windows:**
Download from: https://www.docker.com/products/docker-desktop

### AWS Knowledge Requirements

This guide assumes you understand:
- VPC, subnets, security groups
- IAM roles and policies
- Container basics (Docker)
- Load balancers (ALB)

If new to these, start with [Elastic Beanstalk guide](./elastic-beanstalk.md) first.

## Architecture

### Production Architecture Diagram

```mermaid
graph TB
    subgraph "Public Subnets"
        ALB[Application Load Balancer<br/>Port 443 HTTPS<br/>SSL Termination<br/>Target Groups]
    end

    subgraph "Private Subnet - AZ us-east-1a"
        subgraph "ECS Fargate Service"
            Task1[Fargate Task 1<br/>1 vCPU, 2GB RAM<br/><br/>App Container<br/>- Express Server<br/>- Aggregators<br/>- Components]
        end
    end

    subgraph "Private Subnet - AZ us-east-1b"
        subgraph "ECS Fargate Service"
            Task2[Fargate Task 2<br/>1 vCPU, 2GB RAM<br/><br/>App Container<br/>- Express Server<br/>- Aggregators<br/>- Components]
        end
    end

    subgraph "Private Database Subnets"
        RDS_APP[(RDS PostgreSQL 16<br/>db.t3.small<br/>Multi-AZ<br/>Application DB<br/>50GB Storage<br/>Automated Backups)]

        RDS_MSG[(RDS PostgreSQL 16<br/>db.t3.small<br/>Multi-AZ<br/>Message Store<br/>50GB Storage<br/>Automated Backups)]
    end

    subgraph "Shared Storage & Registry"
        EFS[Amazon EFS<br/>Encrypted<br/>Multi-AZ<br/>Email Directory<br/>Mounted to Tasks]

        ECR[Elastic Container Registry<br/>Docker Images<br/>Vulnerability Scanning<br/>Lifecycle Policies]
    end

    subgraph "Networking & Security"
        NAT[NAT Gateway<br/>Multi-AZ<br/>Outbound Internet]

        SG_ALB[Security Group: ALB<br/>Inbound: 443 from 0.0.0.0/0<br/>Outbound: All to App SG]

        SG_APP[Security Group: App<br/>Inbound: From ALB only<br/>Outbound: To RDS, EFS, NAT]

        SG_RDS[Security Group: RDS<br/>Inbound: 5432 from App SG<br/>Outbound: None]

        SG_EFS[Security Group: EFS<br/>Inbound: 2049 from App SG<br/>Outbound: None]
    end

    subgraph "Monitoring & Observability"
        CW[CloudWatch<br/>Container Insights<br/>Custom Metrics<br/>Log Aggregation]

        XRay[AWS X-Ray<br/>Distributed Tracing<br/>Service Map<br/>Performance Insights]

        Alarms[CloudWatch Alarms<br/>High CPU<br/>Memory Usage<br/>5xx Errors<br/>SNS Notifications]
    end

    subgraph "CI/CD Pipeline"
        CodePipeline[AWS CodePipeline<br/>GitHub Source<br/>Build Stage<br/>Deploy Stage]

        CodeBuild[AWS CodeBuild<br/>Docker Build<br/>Push to ECR<br/>Run Tests]
    end

    subgraph "Service Discovery"
        CloudMap[AWS Cloud Map<br/>Service Registry<br/>DNS-based Discovery]
    end

    Internet[Internet] -->|HTTPS| ALB
    ALB -->|HTTP 8080| Task1
    ALB -->|HTTP 8080| Task2

    Task1 -->|Pull Image| ECR
    Task2 -->|Pull Image| ECR

    Task1 -->|TCP 5432| RDS_APP
    Task1 -->|TCP 5432| RDS_MSG
    Task2 -->|TCP 5432| RDS_APP
    Task2 -->|TCP 5432| RDS_MSG

    Task1 -.->|NFS Mount| EFS
    Task2 -.->|NFS Mount| EFS

    Task1 -->|Outbound| NAT
    Task2 -->|Outbound| NAT
    NAT --> Internet

    Task1 -.->|Logs & Metrics| CW
    Task2 -.->|Logs & Metrics| CW
    Task1 -.->|Traces| XRay
    Task2 -.->|Traces| XRay

    CW -.->|Trigger| Alarms

    CodePipeline -->|Trigger| CodeBuild
    CodeBuild -->|Push Image| ECR
    CodePipeline -->|Deploy| Task1
    CodePipeline -->|Deploy| Task2

    Task1 -.->|Register| CloudMap
    Task2 -.->|Register| CloudMap

    style ALB fill:#ff9900
    style Task1 fill:#ff9900
    style Task2 fill:#ff9900
    style RDS_APP fill:#3b48cc
    style RDS_MSG fill:#3b48cc
    style EFS fill:#8c4fff
    style ECR fill:#ff9900
    style CW fill:#d63384
    style XRay fill:#d63384
```

### Container Architecture

```mermaid
graph LR
    subgraph "Docker Image"
        subgraph "Application Layer"
            Express[Express.js Server<br/>Port 8080]
            Routes[Route Handlers]
        end

        subgraph "Business Logic"
            Aggregators[Aggregators<br/>- Home Page<br/>- User Credentials<br/>- Video Operations]
            Components[Components<br/>- Identity<br/>- Send Email<br/>- Video Publishing]
        end

        subgraph "Data Layer"
            MessageStore[Message Store Client<br/>Event Sourcing]
            Knex[Knex DB Client<br/>Query Builder]
        end

        subgraph "Dependencies"
            NodeModules[node_modules]
            Config[Configuration<br/>Environment Variables]
        end
    end

    Express --> Routes
    Routes --> Aggregators
    Routes --> Components
    Aggregators --> MessageStore
    Aggregators --> Knex
    Components --> MessageStore
    MessageStore --> Config
    Knex --> Config

    style Express fill:#90EE90
    style MessageStore fill:#FFD700
    style Knex fill:#FFD700
```

### Deployment Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as GitHub
    participant CP as CodePipeline
    participant CB as CodeBuild
    participant ECR as ECR Registry
    participant ECS as ECS Service
    participant Task as Fargate Task
    participant ALB as Load Balancer

    Dev->>Git: git push main
    Git->>CP: Webhook Trigger
    CP->>CB: Start Build
    CB->>CB: npm install
    CB->>CB: npm test
    CB->>CB: docker build
    CB->>ECR: docker push
    CP->>ECS: Update Service
    ECS->>Task: Stop Old Task
    ECS->>ECR: Pull New Image
    ECS->>Task: Start New Task
    Task->>Task: Health Check
    Task->>ALB: Register Target
    ALB->>Task: Route Traffic
    ECS->>Task: Stop Old Task (graceful)
```

## Step-by-Step Deployment

### Phase 1: Containerize Application

#### 1. Create Dockerfile

Create `Dockerfile` in project root:

```dockerfile
# Use official Node.js 20 Alpine image (smaller size)
FROM node:20.11.0-alpine AS base

# Set working directory
WORKDIR /app

# Install system dependencies for native modules
RUN apk add --no-cache \
    postgresql-client \
    python3 \
    make \
    g++

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })"

# Start application
CMD ["npm", "start"]
```

#### 2. Create .dockerignore

Create `.dockerignore`:

```
node_modules
npm-debug.log
.env
.env.*
.git
.gitignore
README.md
docs/
test/
*.test.js
coverage/
.DS_Store
.vscode
.idea
dist/
build/
```

#### 3. Add Health Check Endpoint

Update `src/app/express/index.js` to add health check **inside** the `createExpressApp` function:

```javascript
function createExpressApp({ config, env }) {
    const app = express();

    mountMiddleware(app, env);
    mountRoutes(app, config);

    // Health check endpoint for ECS
    app.get('/health', (req, res) => {
      res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
      })
    })

    return app;
}
```

**Note:** For production, you could add database connectivity checks, but a simple health check is sufficient for container health monitoring.

#### 4. Test Docker Build Locally

```bash
# Build image
docker build -t video-tutorials:local .

# Run container locally
docker run -d \
  --name video-tutorials-test \
  -p 8080:8080 \
  -e DATABASE_URL=postgresql://user:pass@host.docker.internal:5432/video_tutorials \
  -e MESSAGE_STORE_CONNECTION_STRING=postgresql://user:pass@host.docker.internal:5432/message_store \
  -e APP_NAME=video-tutorials \
  -e NODE_ENV=development \
  -e PORT=8080 \
  -e COOKIE_SECRET=test-secret \
  -e EMAIL_DIRECTORY=/tmp/emails \
  -e SYSTEM_SENDER_EMAIL_ADDRESS=test@example.com \
  video-tutorials:local

# Check logs
docker logs -f video-tutorials-test

# Test health endpoint
curl http://localhost:8080/health

# Cleanup
docker stop video-tutorials-test
docker rm video-tutorials-test
```

### Phase 2: Set Up AWS Infrastructure

Infrastructure can be created using automated scripts or manually via AWS CLI. The automated approach is recommended for consistency and speed.

#### Automated Setup (Recommended)

For complete automated infrastructure setup, run the provided scripts in sequence:

```bash
cd docs/deployment/scripts/ecs-fargate

# 1. Create VPC and networking (~5 min)
./setup-vpc.sh us-east-1
source vpc-config.env

# 2. Create security groups (~1 min)
./setup-security-groups.sh
source security-groups.env

# 3. Create RDS databases (~15 min)
./create-rds-databases.sh
source rds-config.env
```

**Total time:** ~25 minutes

See [scripts documentation](../scripts/README.md) for detailed information about what each script does.

**To skip automation and configure manually,** follow the detailed steps below.

---

#### Manual Setup

#### 1. Create VPC (or use existing)

```bash
# Create VPC with public and private subnets
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=video-tutorials-vpc}]'

# Note the VpcId from output
VPC_ID=vpc-xxxxx

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=video-tutorials-igw}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

# Attach to VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

# Create subnets
# Public subnet 1 (for ALB and NAT Gateway)
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=video-tutorials-public-1a}]' \
  --query 'Subnet.SubnetId' \
  --output text)

# Public subnet 2
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=video-tutorials-public-1b}]' \
  --query 'Subnet.SubnetId' \
  --output text)

# Private subnet 1 (for Fargate tasks)
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.10.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=video-tutorials-private-1a}]' \
  --query 'Subnet.SubnetId' \
  --output text)

# Private subnet 2
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.11.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=video-tutorials-private-1b}]' \
  --query 'Subnet.SubnetId' \
  --output text)

# Create NAT Gateway for private subnets
EIP_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' \
  --output text)

NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_1 \
  --allocation-id $EIP_ID \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=video-tutorials-nat}]' \
  --query 'NatGateway.NatGatewayId' \
  --output text)

# Wait for NAT Gateway to be available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID

# Create route tables
PUBLIC_RT=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=video-tutorials-public-rt}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

PRIVATE_RT=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=video-tutorials-private-rt}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add routes
aws ec2 create-route \
  --route-table-id $PUBLIC_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 create-route \
  --route-table-id $PRIVATE_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID

# Associate subnets with route tables
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1 --route-table-id $PUBLIC_RT
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2 --route-table-id $PUBLIC_RT
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_1 --route-table-id $PRIVATE_RT
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_2 --route-table-id $PRIVATE_RT
```

**Save these IDs!** You'll need them throughout the setup.

#### 2. Create Security Groups

```bash
# Security Group for ALB
SG_ALB=$(aws ec2 create-security-group \
  --group-name video-tutorials-alb-sg \
  --description "Security group for ALB" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow HTTPS from internet
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ALB \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Allow HTTP from internet (for redirect)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ALB \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Security Group for Fargate tasks
SG_APP=$(aws ec2 create-security-group \
  --group-name video-tutorials-app-sg \
  --description "Security group for Fargate tasks" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress \
  --group-id $SG_APP \
  --protocol tcp \
  --port 8080 \
  --source-group $SG_ALB

# Security Group for RDS
SG_RDS=$(aws ec2 create-security-group \
  --group-name video-tutorials-rds-sg \
  --description "Security group for RDS" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow PostgreSQL from app
aws ec2 authorize-security-group-ingress \
  --group-id $SG_RDS \
  --protocol tcp \
  --port 5432 \
  --source-group $SG_APP

# Security Group for EFS
SG_EFS=$(aws ec2 create-security-group \
  --group-name video-tutorials-efs-sg \
  --description "Security group for EFS" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow NFS from app
aws ec2 authorize-security-group-ingress \
  --group-id $SG_EFS \
  --protocol tcp \
  --port 2049 \
  --source-group $SG_APP
```

#### 3. Create ECR Repository

```bash
# Create repository
aws ecr create-repository \
  --repository-name video-tutorials \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Get repository URI
ECR_URI=$(aws ecr describe-repositories \
  --repository-names video-tutorials \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository: $ECR_URI"

# Set lifecycle policy to keep only last 10 images
aws ecr put-lifecycle-policy \
  --repository-name video-tutorials \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }]
  }'
```

#### 4. Build and Push Docker Image

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URI

# Build image
docker build -t video-tutorials:latest .

# Tag image
docker tag video-tutorials:latest $ECR_URI:latest
docker tag video-tutorials:latest $ECR_URI:v1.0.0

# Push image
docker push $ECR_URI:latest
docker push $ECR_URI:v1.0.0
```

#### 5. Create RDS Databases

```bash
# Create DB subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name video-tutorials-db-subnet \
  --db-subnet-group-description "Subnet group for RDS" \
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2

# Create Application Database
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-app-db \
  --db-instance-class db.t3.small \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password "$(openssl rand -base64 32)" \
  --allocated-storage 50 \
  --db-subnet-group-name video-tutorials-db-subnet \
  --vpc-security-group-ids $SG_RDS \
  --backup-retention-period 7 \
  --multi-az \
  --no-publicly-accessible \
  --storage-encrypted \
  --enable-cloudwatch-logs-exports '["postgresql"]' \
  --tags Key=Name,Value=video-tutorials-app-db

# Create Message Store Database
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-message-store \
  --db-instance-class db.t3.small \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password "$(openssl rand -base64 32)" \
  --allocated-storage 50 \
  --db-subnet-group-name video-tutorials-db-subnet \
  --vpc-security-group-ids $SG_RDS \
  --backup-retention-period 7 \
  --multi-az \
  --no-publicly-accessible \
  --storage-encrypted \
  --enable-cloudwatch-logs-exports '["postgresql"]' \
  --tags Key=Name,Value=video-tutorials-message-store

# Wait for databases (10-15 minutes)
aws rds wait db-instance-available --db-instance-identifier video-tutorials-app-db
aws rds wait db-instance-available --db-instance-identifier video-tutorials-message-store

# Get endpoints
RDS_APP_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-app-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

RDS_MSG_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-message-store \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "App DB: $RDS_APP_ENDPOINT"
echo "Message Store DB: $RDS_MSG_ENDPOINT"
```

**IMPORTANT:** Save the passwords! Use AWS Secrets Manager in production:

```bash
# Store in Secrets Manager
aws secretsmanager create-secret \
  --name video-tutorials/db/app-password \
  --secret-string "YOUR_APP_DB_PASSWORD"

aws secretsmanager create-secret \
  --name video-tutorials/db/messagestore-password \
  --secret-string "YOUR_MSG_STORE_PASSWORD"
```

#### 6. Create EFS File System

```bash
# Create EFS
EFS_ID=$(aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --encrypted \
  --tags Key=Name,Value=video-tutorials-efs \
  --query 'FileSystemId' \
  --output text)

# Create mount targets in private subnets
aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id $PRIVATE_SUBNET_1 \
  --security-groups $SG_EFS

aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id $PRIVATE_SUBNET_2 \
  --security-groups $SG_EFS

echo "EFS ID: $EFS_ID"
```

### Phase 3: Create ECS Cluster & Service

#### 1. Create ECS Cluster

```bash
# Create cluster
aws ecs create-cluster \
  --cluster-name video-tutorials-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE_SPOT,weight=1 \
    capacityProvider=FARGATE,weight=1,base=1 \
  --settings name=containerInsights,value=enabled
```

#### 2. Create IAM Roles

**Task Execution Role** (for ECS to pull images, write logs):

```bash
# Create trust policy
cat > task-execution-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "ecs-tasks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://task-execution-trust-policy.json

# Attach AWS managed policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Add Secrets Manager access
cat > secrets-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetSecretValue"
    ],
    "Resource": [
      "arn:aws:secretsmanager:us-east-1:*:secret:video-tutorials/*"
    ]
  }]
}
EOF

aws iam put-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name SecretsManagerAccess \
  --policy-document file://secrets-policy.json
```

**Task Role** (for application to access AWS services):

```bash
# Create task role
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document file://task-execution-trust-policy.json

# Add CloudWatch and X-Ray permissions
aws iam attach-role-policy \
  --role-name ecsTaskRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess

aws iam attach-role-policy \
  --role-name ecsTaskRole \
  --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
```

#### 3. Create Task Definition

Create `task-definition.json`:

```json
{
  "family": "video-tutorials",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "video-tutorials-app",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/video-tutorials:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "APP_NAME",
          "value": "video-tutorials-practical-microservices"
        },
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "8080"
        },
        {
          "name": "EMAIL_DIRECTORY",
          "value": "/mnt/efs/emails"
        },
        {
          "name": "SYSTEM_SENDER_EMAIL_ADDRESS",
          "value": "noreply@yourdomain.com"
        }
      ],
      "secrets": [
        {
          "name": "COOKIE_SECRET",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:video-tutorials/cookie-secret"
        },
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:video-tutorials/database-url"
        },
        {
          "name": "MESSAGE_STORE_CONNECTION_STRING",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:video-tutorials/messagestore-url"
        }
      ],
      "mountPoints": [
        {
          "sourceVolume": "efs-emails",
          "containerPath": "/mnt/efs/emails",
          "readOnly": false
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/video-tutorials",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "app"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ],
  "volumes": [
    {
      "name": "efs-emails",
      "efsVolumeConfiguration": {
        "fileSystemId": "fs-xxxxx",
        "transitEncryption": "ENABLED",
        "authorizationConfig": {
          "iam": "ENABLED"
        }
      }
    }
  ]
}
```

**Replace:**
- `ACCOUNT_ID` with your AWS account ID
- `fs-xxxxx` with your EFS ID

Store secrets:

```bash
# Create secrets
aws secretsmanager create-secret \
  --name video-tutorials/cookie-secret \
  --secret-string "$(openssl rand -base64 32)"

aws secretsmanager create-secret \
  --name video-tutorials/database-url \
  --secret-string "postgresql://postgres:PASSWORD@$RDS_APP_ENDPOINT:5432/video_tutorials"

aws secretsmanager create-secret \
  --name video-tutorials/messagestore-url \
  --secret-string "postgresql://postgres:PASSWORD@$RDS_MSG_ENDPOINT:5432/message_store"
```

Create CloudWatch log group:

```bash
aws logs create-log-group --log-group-name /ecs/video-tutorials
aws logs put-retention-policy --log-group-name /ecs/video-tutorials --retention-in-days 7
```

Register task definition:

```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

#### 4. Create Application Load Balancer

```bash
# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name video-tutorials-alb \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $SG_ALB \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --tags Key=Name,Value=video-tutorials-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Create target group
TG_ARN=$(aws elbv2 create-target-group \
  --name video-tutorials-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Create listener (HTTP - will redirect to HTTPS later)
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS: $ALB_DNS"
```

#### 5. Create ECS Service

```bash
aws ecs create-service \
  --cluster video-tutorials-cluster \
  --service-name video-tutorials-service \
  --task-definition video-tutorials \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$SG_APP],assignPublicIp=DISABLED}" \
  --load-balancers targetGroupArn=$TG_ARN,containerName=video-tutorials-app,containerPort=8080 \
  --health-check-grace-period-seconds 60 \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100,deploymentCircuitBreaker={enable=true,rollback=true}" \
  --enable-execute-command
```

This will take 5-10 minutes to stabilize.

#### 6. Verify Deployment

```bash
# Check service status
aws ecs describe-services \
  --cluster video-tutorials-cluster \
  --services video-tutorials-service \
  --query 'services[0].[status,runningCount,desiredCount]'

# Check task status
aws ecs list-tasks \
  --cluster video-tutorials-cluster \
  --service-name video-tutorials-service

# View logs
aws logs tail /ecs/video-tutorials --follow

# Test application
curl http://$ALB_DNS/health
```

### Phase 4: Configure Auto-Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/video-tutorials-cluster/video-tutorials-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create scaling policy - Scale up on high CPU
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/video-tutorials-cluster/video-tutorials-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scale-up \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }'

# Create scaling policy - Scale based on ALB requests
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/video-tutorials-cluster/video-tutorials-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name request-count-scale \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 1000.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "'$(echo $ALB_ARN | cut -d: -f6)'/targetgroup/'$(echo $TG_ARN | cut -d: -f6)'"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }'
```

## Advanced Configuration

### SSL/TLS Certificate

```bash
# Request certificate
CERT_ARN=$(aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names www.yourdomain.com \
  --validation-method DNS \
  --query 'CertificateArn' \
  --output text)

# Get validation records
aws acm describe-certificate \
  --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions'

# Add DNS records to your domain (output from above)
# Wait for validation...

# Add HTTPS listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# Redirect HTTP to HTTPS
HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --query 'Listeners[?Port==`80`].ListenerArn' \
  --output text)

aws elbv2 modify-listener \
  --listener-arn $HTTP_LISTENER_ARN \
  --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}"
```

### CI/CD Pipeline with CodePipeline

Create `buildspec.yml`:

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/video-tutorials
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"video-tutorials-app","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json

artifacts:
  files: imagedefinitions.json
```

Create CodePipeline (via AWS Console or CLI) - this is extensive, see AWS documentation.

### Database Migrations on Deploy

Add init container to task definition:

```json
{
  "name": "migration",
  "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/video-tutorials:latest",
  "essential": false,
  "command": ["npx", "knex", "migrate:latest"],
  "environment": [...],
  "secrets": [...]
}
```

Update `containerDefinitions` order to run migration first.

## Monitoring & Observability

### CloudWatch Container Insights

Already enabled when cluster was created. View dashboards:

```bash
# AWS Console > CloudWatch > Container Insights
```

**Key Metrics:**
- **CPU Utilization**: Target <70%
- **Memory Utilization**: Target <80%
- **Task Count**: Monitor scaling
- **Network I/O**: Database query performance indicator

### AWS X-Ray Tracing

Install X-Ray SDK:

```bash
npm install aws-xray-sdk-core
```

Update application (`src/app/express/index.js`):

```javascript
const AWSXRay = require('aws-xray-sdk-core')
const AWS = AWSXRay.captureAWS(require('aws-sdk'))
const http = AWSXRay.captureHTTPs(require('http'))

// Add X-Ray middleware
app.use(AWSXRay.express.openSegment('video-tutorials'))

// Your routes...

app.use(AWSXRay.express.closeSegment())
```

Add X-Ray daemon sidecar to task definition:

```json
{
  "name": "xray-daemon",
  "image": "amazon/aws-xray-daemon",
  "cpu": 32,
  "memoryReservation": 256,
  "portMappings": [
    {
      "containerPort": 2000,
      "protocol": "udp"
    }
  ]
}
```

### Custom CloudWatch Alarms

```bash
# High 5xx errors
aws cloudwatch put-metric-alarm \
  --alarm-name video-tutorials-high-errors \
  --alarm-description "Alert on high 5xx errors" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d: -f6)

# High memory usage
aws cloudwatch put-metric-alarm \
  --alarm-name video-tutorials-high-memory \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=ServiceName,Value=video-tutorials-service Name=ClusterName,Value=video-tutorials-cluster
```

## Cost Optimization

### Use Fargate Spot (70% Savings)

Already configured in capacity provider strategy. Fargate Spot uses spare capacity at steep discount.

**Current mix:**
- Base capacity: 1 task on Fargate (always available)
- Additional capacity: Fargate Spot (can be interrupted)

### Savings Plans

```bash
# Compute Savings Plan (1 or 3 year)
# Reduces Fargate costs by 50%
# Purchase via AWS Console > AWS Cost Management > Savings Plans
```

**Example:**
- Standard Fargate: $0.04048/hour per vCPU
- With Savings Plan: ~$0.02024/hour (50% off)
- Annual savings: ~$1,200 for 2 tasks running 24/7

### Right-Size Resources

Monitor actual usage:

```bash
# Check CPU usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=video-tutorials-service Name=ClusterName,Value=video-tutorials-cluster \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average

# If consistently <30%, reduce vCPU from 1024 to 512
```

### Use S3 for Static Assets

Instead of serving from EFS:

```bash
# Create S3 bucket
aws s3 mb s3://video-tutorials-assets

# Enable static website hosting
aws s3 website s3://video-tutorials-assets \
  --index-document index.html

# Upload assets
aws s3 sync ./public s3://video-tutorials-assets/public

# Update app to reference S3 URLs
```

### Schedule Dev Environment

Use AWS Lambda to stop/start dev environment during off-hours:

```python
# stop-dev-ecs.py (Lambda)
import boto3

ecs = boto3.client('ecs')

def lambda_handler(event, context):
    ecs.update_service(
        cluster='video-tutorials-cluster',
        service='video-tutorials-dev-service',
        desiredCount=0
    )
```

Schedule with EventBridge (10 PM - 6 AM shutdown = 40% savings on dev).

## Troubleshooting

### Tasks Not Starting

**Symptoms:**
- Service shows 0 running tasks
- Tasks repeatedly stop

**Check:**
```bash
# View stopped tasks
aws ecs list-tasks \
  --cluster video-tutorials-cluster \
  --service-name video-tutorials-service \
  --desired-status STOPPED

# Get task details
aws ecs describe-tasks \
  --cluster video-tutorials-cluster \
  --tasks TASK_ARN

# Check stop reason
```

**Common causes:**
1. **Image pull failure:** Check ECR permissions
2. **Health check failure:** Check `/health` endpoint
3. **Environment variable missing:** Check Secrets Manager
4. **EFS mount failure:** Check security groups

### High Costs

**Diagnose:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  --filter file://filter.json

# filter.json
{
  "Tags": {
    "Key": "Project",
    "Values": ["video-tutorials"]
  }
}
```

**Culprits:**
- **NAT Gateway:** $0.045/hour + data transfer (~$35/month)
  - Solution: Use VPC endpoints for AWS services
- **Multi-AZ RDS:** Doubles cost
  - Solution: Single-AZ for dev
- **Fargate without Spot:** Full price
  - Solution: Enable Fargate Spot

### Connection Timeouts

**Database timeouts:**
```bash
# Verify security group
aws ec2 describe-security-groups --group-ids $SG_RDS

# Should allow inbound 5432 from $SG_APP
```

**Solution:**
```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_RDS \
  --protocol tcp \
  --port 5432 \
  --source-group $SG_APP
```

### Debugging Running Tasks

```bash
# Enable ECS Exec (if not already)
aws ecs update-service \
  --cluster video-tutorials-cluster \
  --service video-tutorials-service \
  --enable-execute-command

# Get task ID
TASK_ID=$(aws ecs list-tasks \
  --cluster video-tutorials-cluster \
  --service-name video-tutorials-service \
  --query 'taskArns[0]' \
  --output text)

# SSH into task
aws ecs execute-command \
  --cluster video-tutorials-cluster \
  --task $TASK_ID \
  --container video-tutorials-app \
  --interactive \
  --command "/bin/sh"
```

## Infrastructure as Code (Terraform)

For production, use Terraform:

Create `main.tf`:

```hcl
# This is a starter - full implementation is extensive

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "video-tutorials-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false  # Multi-AZ for production

  tags = {
    Project = "video-tutorials"
  }
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "video-tutorials-cluster"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 1
        base   = 1
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 4
      }
    }
  }
}

# See full Terraform module for complete implementation
```

## Next Steps

### Portfolio Documentation

**Blog post outline:**
1. **Introduction:** Why ECS Fargate over Elastic Beanstalk
2. **Architecture:** Diagrams (use Mermaid from this guide)
3. **Implementation:** Key decisions and trade-offs
4. **Monitoring:** CloudWatch + X-Ray setup
5. **Cost Analysis:** Actual monthly costs with optimizations
6. **Lessons Learned:** Challenges and solutions

**GitHub README additions:**
- Badge: ![Deployed on AWS ECS](https://img.shields.io/badge/AWS-ECS%20Fargate-orange)
- Architecture diagram
- Link to blog post

### Advanced Enhancements

**Service Mesh (AWS App Mesh):**
- Implement for advanced traffic management
- Blue/green deployments
- Canary releases

**Multi-Region:**
- Deploy to multiple regions
- Route 53 geolocation routing
- Cross-region RDS replication

**Disaster Recovery:**
- Automate RDS snapshots to S3
- Cross-region backup
- Recovery runbook

## Conclusion

You now have a production-grade ECS Fargate deployment with:
- ✅ Containerized microservices
- ✅ Auto-scaling with Fargate Spot (70% savings)
- ✅ Multi-AZ high availability
- ✅ Advanced monitoring (CloudWatch + X-Ray)
- ✅ Blue/green deployment support
- ✅ Infrastructure as Code ready

**Total setup time:** 20-30 hours
**Monthly cost (optimized):** ~$100-150
**Portfolio value:** Very High ⭐⭐⭐ (Best for AWS SAA)

**Ready to simplify?** Check out the [DigitalOcean guide](./digitalocean.md) for a comparison with a simpler PaaS.

**Questions?** File an issue or see the [comparison guide](./comparison.md).
