# AWS Elastic Beanstalk Deployment Guide

Complete guide for deploying the Video Tutorials microservices application to AWS Elastic Beanstalk.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Configuration](#configuration)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## Overview

AWS Elastic Beanstalk is a PaaS (Platform-as-a-Service) that handles deployment, scaling, and monitoring automatically. It's the easiest way to deploy to AWS and serves as a good Heroku alternative.

### Why Elastic Beanstalk?

✅ **Easiest AWS option** - Handles infrastructure automatically
✅ **Heroku-like experience** - Focus on code, not servers
✅ **Auto-scaling built-in** - Handles traffic spikes
✅ **AWS ecosystem integration** - RDS, CloudWatch, etc.
✅ **Portfolio value** - Demonstrates AWS competency

### Time Estimate
- **First deployment:** 4-6 hours
- **Subsequent deploys:** 5-10 minutes

### Monthly Cost Estimate
- **Development:** ~$65-75/month
- **Production:** ~$140-210/month

## Prerequisites

### Required Tools

```bash
# Check if AWS CLI is installed
aws --version
# Expected: aws-cli/2.x.x or higher

# Check if EB CLI is installed
eb --version
# Expected: EB CLI 3.x.x

# Check Node.js version
node --version
# Expected: v20.11.0 or higher
```

### Install AWS CLI (if needed)

**Linux/macOS:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows:**
Download from: https://awscli.amazonaws.com/AWSCLIV2.msi

### Install EB CLI

```bash
# Using pip
pip install --upgrade awsebcli

# Or using homebrew (macOS)
brew install awsebcli
```

### Configure AWS Credentials

```bash
aws configure
# AWS Access Key ID: [Your access key]
# AWS Secret Access Key: [Your secret key]
# Default region name: us-east-1 (or your preferred region)
# Default output format: json
```

**Security Best Practice:** Create an IAM user with appropriate permissions rather than using root credentials.

Required IAM permissions:
- `AWSElasticBeanstalkFullAccess`
- `IAMFullAccess` (for service roles)
- `AmazonRDSFullAccess` (for database)
- `AmazonVPCFullAccess` (for networking)

## Architecture

### Deployment Architecture

```mermaid
graph TB
    subgraph "Internet"
        User[Users/Clients]
    end

    subgraph "Elastic Beanstalk Environment"
        ELB[Elastic Load Balancer<br/>Health Checks<br/>SSL Termination]

        subgraph "Auto Scaling Group"
            subgraph "Availability Zone A"
                EC2_1[EC2 Instance<br/>t3.small<br/>Node.js 20 Platform<br/>Application Code<br/>Aggregators<br/>Components]
            end

            subgraph "Availability Zone B"
                EC2_2[EC2 Instance<br/>t3.small<br/>Node.js 20 Platform<br/>Application Code<br/>Aggregators<br/>Components]
            end
        end
    end

    subgraph "Data Layer - Private Subnets"
        RDS_APP[(RDS PostgreSQL 16<br/>db.t3.micro<br/>Application DB<br/>20GB Storage<br/>Automated Backups)]

        RDS_MSG[(RDS PostgreSQL 16<br/>db.t3.micro<br/>Message Store DB<br/>20GB Storage<br/>Automated Backups)]
    end

    subgraph "Shared Storage"
        EFS[Amazon EFS<br/>Email Directory<br/>Mounted on all instances]
    end

    subgraph "Monitoring"
        CW_Logs[CloudWatch Logs<br/>Application Logs<br/>EB Platform Logs]
        CW_Metrics[CloudWatch Metrics<br/>CPU, Memory, Requests<br/>Custom Metrics]
        CW_Alarms[CloudWatch Alarms<br/>High CPU Alert<br/>Health Check Failures]
    end

    subgraph "Security"
        SG_ELB[Security Group: ELB<br/>Inbound: 80, 443<br/>Outbound: All]
        SG_EC2[Security Group: EC2<br/>Inbound: From ELB only<br/>Outbound: All]
        SG_RDS[Security Group: RDS<br/>Inbound: From EC2 only<br/>Port 5432]
        IAM_ROLE[IAM Instance Profile<br/>CloudWatch Logs<br/>S3 Access<br/>EFS Mount]
    end

    User -->|HTTPS| ELB
    ELB -->|HTTP| EC2_1
    ELB -->|HTTP| EC2_2

    EC2_1 -->|TCP 5432| RDS_APP
    EC2_1 -->|TCP 5432| RDS_MSG
    EC2_2 -->|TCP 5432| RDS_APP
    EC2_2 -->|TCP 5432| RDS_MSG

    EC2_1 -.->|NFS| EFS
    EC2_2 -.->|NFS| EFS

    EC2_1 -.->|Logs| CW_Logs
    EC2_2 -.->|Logs| CW_Logs
    ELB -.->|Metrics| CW_Metrics
    EC2_1 -.->|Metrics| CW_Metrics
    EC2_2 -.->|Metrics| CW_Metrics
    CW_Metrics -.->|Triggers| CW_Alarms

    style ELB fill:#ff9900
    style EC2_1 fill:#ff9900
    style EC2_2 fill:#ff9900
    style RDS_APP fill:#3b48cc
    style RDS_MSG fill:#3b48cc
    style EFS fill:#8c4fff
    style CW_Logs fill:#d63384
    style CW_Metrics fill:#d63384
```

### Request Flow

```mermaid
sequenceDiagram
    participant User
    participant ELB as Load Balancer
    participant EC2 as EC2 Instance
    participant RDS as PostgreSQL RDS
    participant EFS as EFS Storage
    participant CW as CloudWatch

    User->>ELB: HTTPS Request
    ELB->>ELB: SSL Termination
    ELB->>EC2: HTTP Request (Health Check Passed)
    EC2->>RDS: Query Application DB
    RDS-->>EC2: Return Data
    EC2->>RDS: Query Message Store
    RDS-->>EC2: Return Events
    EC2->>EFS: Read/Write Email Files
    EFS-->>EC2: File Contents
    EC2->>CW: Log Request
    EC2-->>ELB: HTTP Response
    ELB-->>User: HTTPS Response
```

## Step-by-Step Deployment

### Phase 1: Prepare Application

#### 1. Create Elastic Beanstalk Configuration

Create `.ebextensions/` directory in project root:

```bash
mkdir -p .ebextensions
```

#### 2. Create Node.js Configuration

Create `.ebextensions/01-nodecommand.config`:

```yaml
option_settings:
  aws:elasticbeanstalk:container:nodejs:
    NodeCommand: "npm start"
    NodeVersion: 20.11.0
  aws:elasticbeanstalk:application:environment:
    NODE_ENV: production
```

#### 3. Create EFS Mount Configuration

Create `.ebextensions/02-efs-mount.config`:

```yaml
##############################################
# EFS Mount Configuration
# This mounts EFS for shared email directory
##############################################

option_settings:
  aws:elasticbeanstalk:application:environment:
    EFS_ID: '`{"Ref" : "FileSystem"}`'
    EMAIL_DIRECTORY: '/mnt/efs/emails'

Resources:
  FileSystem:
    Type: AWS::EFS::FileSystem
    Properties:
      FileSystemTags:
        - Key: Name
          Value: video-tutorials-efs
      PerformanceMode: generalPurpose
      Encrypted: true

  MountTargetA:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: {Ref: FileSystem}
      SubnetId: !Select [0, !GetAtt EBEnvironment.Subnets]
      SecurityGroups:
        - !Ref EFSSecurityGroup

  MountTargetB:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: {Ref: FileSystem}
      SubnetId: !Select [1, !GetAtt EBEnvironment.Subnets]
      SecurityGroups:
        - !Ref EFSSecurityGroup

  EFSSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: EFS Security Group
      VpcId: !GetAtt EBEnvironment.VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 2049
          ToPort: 2049
          SourceSecurityGroupId: !GetAtt EBEnvironment.SecurityGroupId

files:
  "/opt/elasticbeanstalk/hooks/appdeploy/pre/01-mount-efs.sh":
    mode: "000755"
    owner: root
    group: root
    content: |
      #!/bin/bash
      EFS_ID=$(/opt/elasticbeanstalk/bin/get-config environment | jq -r '.EFS_ID')
      EFS_MOUNT_POINT=/mnt/efs/emails

      echo "Mounting EFS filesystem ${EFS_ID} to ${EFS_MOUNT_POINT}"

      mkdir -p ${EFS_MOUNT_POINT}

      # Install NFS client if not present
      yum install -y nfs-utils

      # Mount EFS
      mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
        ${EFS_ID}.efs.${AWS_REGION}.amazonaws.com:/ ${EFS_MOUNT_POINT}

      # Make mount persistent
      echo "${EFS_ID}.efs.${AWS_REGION}.amazonaws.com:/ ${EFS_MOUNT_POINT} nfs4 defaults,_netdev 0 0" >> /etc/fstab

      # Set permissions
      chmod 777 ${EFS_MOUNT_POINT}
```

#### 4. Create CloudWatch Logs Configuration

Create `.ebextensions/03-cloudwatch-logs.config`:

```yaml
files:
  "/opt/elasticbeanstalk/tasks/taillogs.d/nodejs.conf":
    mode: "000755"
    owner: root
    group: root
    content: |
      /var/log/nodejs/nodejs.log

option_settings:
  aws:elasticbeanstalk:cloudwatch:logs:
    StreamLogs: true
    DeleteOnTerminate: false
    RetentionInDays: 7
  aws:elasticbeanstalk:cloudwatch:logs:health:
    HealthStreamingEnabled: true
    DeleteOnTerminate: false
    RetentionInDays: 7
```

#### 5. Create Database Configuration Script

Create `.ebextensions/04-rds-setup.config`:

```yaml
Resources:
  # Application Database
  AppDatabase:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: video-tutorials-app-db
      DBName: video_tutorials
      Engine: postgres
      EngineVersion: "16"
      DBInstanceClass: db.t3.micro
      AllocatedStorage: 20
      MasterUsername: postgres
      MasterUserPassword: !Ref DBPassword
      VPCSecurityGroups:
        - !Ref DBSecurityGroup
      DBSubnetGroupName: !Ref DBSubnetGroup
      PubliclyAccessible: false
      BackupRetentionPeriod: 7
      PreferredBackupWindow: "03:00-04:00"
      PreferredMaintenanceWindow: "sun:04:00-sun:05:00"
      Tags:
        - Key: Name
          Value: video-tutorials-app-db

  # Message Store Database
  MessageStoreDatabase:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: video-tutorials-message-store
      DBName: message_store
      Engine: postgres
      EngineVersion: "16"
      DBInstanceClass: db.t3.micro
      AllocatedStorage: 20
      MasterUsername: postgres
      MasterUserPassword: !Ref DBPassword
      VPCSecurityGroups:
        - !Ref DBSecurityGroup
      DBSubnetGroupName: !Ref DBSubnetGroup
      PubliclyAccessible: false
      BackupRetentionPeriod: 7
      Tags:
        - Key: Name
          Value: video-tutorials-message-store

  DBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: RDS Security Group
      VpcId: !GetAtt EBEnvironment.VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 5432
          ToPort: 5432
          SourceSecurityGroupId: !GetAtt EBEnvironment.SecurityGroupId

  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupDescription: Subnet group for RDS instances
      SubnetIds: !GetAtt EBEnvironment.Subnets

Parameters:
  DBPassword:
    Type: String
    NoEcho: true
    Description: Database master password

Outputs:
  AppDatabaseEndpoint:
    Value: !GetAtt AppDatabase.Endpoint.Address
  MessageStoreDatabaseEndpoint:
    Value: !GetAtt MessageStoreDatabase.Endpoint.Address
```

#### 6. Update package.json

Ensure `package.json` has proper start script:

```json
{
  "scripts": {
    "start": "node src/app/express/index.js",
    "postinstall": "npm run migrate:latest"
  },
  "engines": {
    "node": "20.11.0",
    "npm": "10.x"
  }
}
```

#### 7. Create .ebignore

Create `.ebignore` to exclude unnecessary files:

```
node_modules/
.git/
.env
.env.*
*.log
coverage/
.DS_Store
docs/
test/
*.test.js
```

### Phase 2: Initialize Elastic Beanstalk

#### 1. Initialize EB Application

```bash
# Navigate to project root
cd /path/to/video-tutorials-practical-microservices

# Initialize Elastic Beanstalk
eb init

# Follow prompts:
# Select a default region: (Choose your region, e.g., us-east-1)
# Select an application: [ Create new Application ]
# Application name: video-tutorials-practical-microservices
# Select a platform: Node.js
# Select a platform version: Node.js 20 running on 64bit Amazon Linux 2023
# Do you wish to continue with CodeCommit? n
# Do you want to set up SSH for your instances? y (recommended)
```

This creates `.elasticbeanstalk/config.yml`:

```yaml
branch-defaults:
  main:
    environment: video-tutorials-prod
global:
  application_name: video-tutorials-practical-microservices
  default_ec2_keyname: aws-eb-keypair
  default_platform: Node.js 20 running on 64bit Amazon Linux 2023
  default_region: us-east-1
  sc: git
```

#### 2. Create Environment

```bash
# Create development environment
eb create video-tutorials-dev \
  --instance-type t3.small \
  --envvars APP_NAME=video-tutorials,NODE_ENV=development,PORT=8080 \
  --database.engine postgres \
  --database.version 16 \
  --single

# This will take 10-15 minutes
```

**Options explained:**
- `--instance-type t3.small`: Small instance for dev (2 vCPU, 2GB RAM)
- `--envvars`: Initial environment variables
- `--database`: Creates RDS PostgreSQL (optional - we'll create separately for more control)
- `--single`: Single instance (no load balancer) for dev

### Phase 3: Set Up Databases

The application requires two PostgreSQL databases. These can be created using the automated script or manually.

#### Option A: Automated Setup (Recommended)

Use the provided script to create both databases:

```bash
# Get security group ID from Elastic Beanstalk environment
# AWS Console > Elastic Beanstalk > Environments > Configuration > Instances
export VPC_SECURITY_GROUP=sg-xxxxx

# Run automation script
cd docs/deployment/scripts/elastic-beanstalk
./create-rds-databases.sh
```

**What the script does:**
- Creates both PostgreSQL 16 databases (db.t3.micro)
- Generates secure random password
- Configures automated backups (7-day retention)
- Waits for databases to become available
- Outputs connection strings

**Time:** ~15 minutes

See [scripts documentation](../scripts/README.md) for details.

#### Option B: Manual Setup

If preferring manual creation or needing custom configuration:

**For Application Database:**

```bash
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-app-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password YOUR_SECURE_PASSWORD_HERE \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-xxx \  # Get from EB environment
  --db-subnet-group-name ebdb-subnet-group \  # Created by EB
  --backup-retention-period 7 \
  --no-publicly-accessible \
  --tags Key=Name,Value=video-tutorials-app-db
```

**For Message Store Database:**

```bash
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-message-store \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password YOUR_SECURE_PASSWORD_HERE \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-xxx \
  --db-subnet-group-name ebdb-subnet-group \
  --backup-retention-period 7 \
  --no-publicly-accessible \
  --tags Key=Name,Value=video-tutorials-message-store
```

**Get Database Endpoints:**

```bash
# Wait for databases (5-10 minutes)
aws rds wait db-instance-available --db-instance-identifier video-tutorials-app-db
aws rds wait db-instance-available --db-instance-identifier video-tutorials-message-store

# Get endpoints
aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-app-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-message-store \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

Save the endpoints - they're needed for environment variables.

### Phase 4: Configure Environment Variables

#### 1. Set Environment Variables

```bash
eb setenv \
  APP_NAME=video-tutorials-practical-microservices \
  COOKIE_SECRET=$(openssl rand -base64 32) \
  DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@app-db-endpoint.rds.amazonaws.com:5432/video_tutorials \
  EMAIL_DIRECTORY=/mnt/efs/emails \
  SYSTEM_SENDER_EMAIL_ADDRESS=noreply@yourdomain.com \
  NODE_ENV=production \
  PORT=8080 \
  MESSAGE_STORE_CONNECTION_STRING=postgresql://postgres:YOUR_PASSWORD@message-store-endpoint.rds.amazonaws.com:5432/message_store
```

**Replace:**
- `YOUR_PASSWORD`: Your RDS master password
- `app-db-endpoint.rds.amazonaws.com`: Your actual app DB endpoint
- `message-store-endpoint.rds.amazonaws.com`: Your actual message store endpoint
- `noreply@yourdomain.com`: Your email address

#### 2. Verify Environment Variables

```bash
eb printenv
```

### Phase 5: Run Database Migrations

Since migrations need to run before the app starts:

#### 1. SSH into EB Instance

```bash
eb ssh
```

#### 2. Run Migrations

```bash
# Navigate to app directory
cd /var/app/current

# Run migrations for application database
npx knex migrate:latest --env production

# Exit SSH
exit
```

**Alternative:** Add migration to package.json `postinstall` script (already done above).

### Phase 6: Deploy Application

#### 1. Deploy Code

```bash
# Deploy from git
eb deploy

# This will:
# 1. Bundle your application
# 2. Upload to S3
# 3. Deploy to EB instances
# 4. Run npm install
# 5. Start application
# 6. Run health checks
```

#### 2. Monitor Deployment

```bash
# Watch deployment progress
eb status

# View recent logs
eb logs

# Tail logs in real-time
eb logs --stream
```

#### 3. Open Application

```bash
# Open in browser
eb open
```

### Phase 7: Configure Production Environment

For production, you'll want load balancing and auto-scaling:

#### 1. Create Production Environment

```bash
eb create video-tutorials-prod \
  --instance-type t3.small \
  --scale 2 \
  --envvars APP_NAME=video-tutorials,NODE_ENV=production,PORT=8080 \
  --elb-type application
```

#### 2. Configure Auto-Scaling

```bash
# Set auto-scaling rules
eb config

# In the editor that opens, modify:
```

```yaml
aws:autoscaling:asg:
  MaxSize: '4'
  MinSize: '2'

aws:autoscaling:trigger:
  MeasureName: CPUUtilization
  Statistic: Average
  Unit: Percent
  UpperThreshold: '70'
  LowerThreshold: '20'
  BreachDuration: '5'
  Period: '5'
  EvaluationPeriods: '1'
  UpperBreachScaleIncrement: '1'
  LowerBreachScaleIncrement: '-1'
```

#### 3. Configure Health Checks

```yaml
aws:elasticbeanstalk:application:
  Application Healthcheck URL: /health

aws:elb:healthcheck:
  HealthyThreshold: '2'
  Interval: '30'
  Timeout: '5'
  UnhealthyThreshold: '3'
```

Add health check endpoint **inside** the `createExpressApp` function in `src/app/express/index.js`:

```javascript
function createExpressApp({ config, env }) {
    const app = express();

    mountMiddleware(app, env);
    mountRoutes(app, config);

    // Health check endpoint
    app.get('/health', (req, res) => {
      res.status(200).json({ status: 'healthy' })
    })

    return app;
}
```

## Configuration

### Environment-Specific Configuration

Create `.env.example` for reference:

```bash
# Application
APP_NAME=video-tutorials-practical-microservices
NODE_ENV=production
PORT=8080

# Security
COOKIE_SECRET=generate-with-openssl-rand-base64-32

# Database
DATABASE_URL=postgresql://user:pass@host:5432/video_tutorials
MESSAGE_STORE_CONNECTION_STRING=postgresql://user:pass@host:5432/message_store

# Email
EMAIL_DIRECTORY=/mnt/efs/emails
SYSTEM_SENDER_EMAIL_ADDRESS=noreply@yourdomain.com
```

### Custom Domain Setup

#### 1. Add CNAME Record

In your DNS provider:
```
Type: CNAME
Name: app (or www)
Value: video-tutorials-prod.us-east-1.elasticbeanstalk.com
TTL: 300
```

#### 2. Configure SSL Certificate

```bash
# Request certificate via AWS Certificate Manager
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names www.yourdomain.com \
  --validation-method DNS

# Add certificate to load balancer via EB console
# Environment > Configuration > Load Balancer > Listeners > Add listener
# Port: 443
# Protocol: HTTPS
# SSL Certificate: (select your certificate)
```

## Monitoring & Maintenance

### CloudWatch Monitoring

#### View Metrics

```bash
# Via CLI
eb health

# Via console
# AWS Console > Elastic Beanstalk > Environments > video-tutorials-prod > Monitoring
```

**Key Metrics to Monitor:**
- **Environment Health**: Overall application health
- **Request Count**: Traffic patterns
- **Latency**: Response times (p50, p90, p99)
- **HTTP 5xx**: Server errors
- **CPU Utilization**: Instance performance
- **Database Connections**: RDS connection pool

#### Set Up Alarms

```bash
# Create CloudWatch alarm for high error rate
aws cloudwatch put-metric-alarm \
  --alarm-name video-tutorials-high-5xx \
  --alarm-description "Alert when 5xx errors exceed threshold" \
  --metric-name ApplicationRequests5xx \
  --namespace AWS/ElasticBeanstalk \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:alert-topic
```

### Log Management

#### View Logs

```bash
# Tail logs
eb logs --stream

# Download full logs
eb logs --zip

# View specific log
eb ssh
sudo tail -f /var/log/nodejs/nodejs.log
```

#### Log Rotation

CloudWatch Logs handles rotation automatically. Configure retention:

```bash
aws logs put-retention-policy \
  --log-group-name /aws/elasticbeanstalk/video-tutorials-prod/var/log/nodejs/nodejs.log \
  --retention-in-days 7
```

### Backups

#### RDS Automated Backups

Already configured (7-day retention). To restore:

```bash
# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier video-tutorials-app-db

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier video-tutorials-app-db-restored \
  --db-snapshot-identifier rds:video-tutorials-app-db-2025-01-15-03-00
```

#### Manual Snapshot

```bash
aws rds create-db-snapshot \
  --db-instance-identifier video-tutorials-app-db \
  --db-snapshot-identifier manual-snapshot-before-major-change
```

### Updates & Maintenance

#### Update Application Code

```bash
# Deploy new version
git add .
git commit -m "Update feature X"
eb deploy
```

#### Update Platform Version

```bash
# Check available platform versions
eb platform list

# Update to latest
eb upgrade
```

#### Update Dependencies

```bash
# Update locally
npm update

# Test locally
npm start

# Deploy
git add package*.json
git commit -m "Update dependencies"
eb deploy
```

## Cost Optimization

### Current Costs Breakdown

**Development Environment (~$67/month):**
```
EC2 t3.small (1 instance)         $15/month
RDS db.t3.micro (2 instances)     $30/month
ELB (if used)                     $16/month
EFS (5GB)                         $1.50/month
Data transfer (50GB)              $4.50/month
```

**Production Environment (~$175/month):**
```
EC2 t3.small (2 instances)        $30/month
RDS db.t3.small Multi-AZ (2)      $120/month
ELB                               $16/month
EFS (20GB)                        $6/month
Data transfer (200GB)             $18/month
CloudWatch                        $10/month
```

### Optimization Strategies

#### 1. Use Reserved Instances

```bash
# Purchase 1-year reserved instance (40% savings)
aws ec2 purchase-reserved-instances-offering \
  --reserved-instances-offering-id xxx \
  --instance-count 2
```

**Savings:** ~$144/year per instance

#### 2. Use RDS Reserved Instances

```bash
# Purchase 1-year reserved RDS (35% savings)
aws rds purchase-reserved-db-instances-offering \
  --reserved-db-instances-offering-id xxx \
  --db-instance-count 2
```

**Savings:** ~$252/year for both databases

#### 3. Optimize Storage

```bash
# Use S3 for large files instead of EFS
# S3 Standard: $0.023/GB (vs EFS $0.30/GB)

# Example: Move old emails to S3
aws s3 sync /mnt/efs/emails/archive s3://video-tutorials-emails-archive --storage-class GLACIER
```

#### 4. Scheduled Scaling

For development environments, shut down during off-hours:

Create `.ebextensions/05-scheduled-scaling.config`:

```yaml
Resources:
  ScheduledActionDown:
    Type: AWS::AutoScaling::ScheduledAction
    Properties:
      AutoScalingGroupName: {"Ref": "AWSEBAutoScalingGroup"}
      MinSize: 0
      MaxSize: 0
      DesiredCapacity: 0
      Recurrence: "0 22 * * *"  # 10 PM UTC (after work hours)

  ScheduledActionUp:
    Type: AWS::AutoScaling::ScheduledAction
    Properties:
      AutoScalingGroupName: {"Ref": "AWSEBAutoScalingGroup"}
      MinSize: 1
      MaxSize: 1
      DesiredCapacity: 1
      Recurrence: "0 13 * * *"  # 1 PM UTC (before work hours)
```

**Savings:** ~50% on dev environment (~$33/month)

#### 5. Use Spot Instances (Advanced)

Mix spot instances for cost savings. See [ECS Fargate guide](./ecs-fargate.md) for better spot instance support.

### Monthly Budget Alert

```bash
# Create budget alert
aws budgets create-budget \
  --account-id ACCOUNT_ID \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

`budget.json`:
```json
{
  "BudgetName": "video-tutorials-monthly",
  "BudgetLimit": {
    "Amount": "200",
    "Unit": "USD"
  },
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY"
}
```

## Troubleshooting

### Common Issues

#### Issue: Environment Health is Red

**Symptoms:**
- EB dashboard shows red health status
- Application not responding

**Diagnosis:**
```bash
eb health --refresh
eb logs
```

**Common Causes:**
1. **Application not starting:**
   - Check logs: `eb logs | grep -A 20 "npm start"`
   - Verify `package.json` start script
   - Check environment variables: `eb printenv`

2. **Failed health checks:**
   - Verify `/health` endpoint exists
   - Check security group allows traffic from ELB
   - Increase health check timeout

3. **Database connection failures:**
   - Verify security group allows EC2 → RDS traffic
   - Check DATABASE_URL is correct
   - Test connection: `eb ssh` then `psql $DATABASE_URL`

**Solution:**
```bash
# View detailed health
eb health --view

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxx

# Update health check
eb config  # Increase timeout to 10 seconds
```

#### Issue: Database Connection Timeout

**Symptoms:**
```
Error: connect ETIMEDOUT
```

**Solution:**
```bash
# 1. Get EB security group ID
EB_SG=$(eb describe-configuration-settings --application-name video-tutorials --environment-name video-tutorials-prod | jq -r '.ConfigurationSettings[0].OptionSettings[] | select(.OptionName=="InstanceSecurityGroup") | .Value')

# 2. Get RDS security group ID
RDS_SG=$(aws rds describe-db-instances --db-instance-identifier video-tutorials-app-db --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

# 3. Add rule allowing EB -> RDS
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $EB_SG
```

#### Issue: EFS Mount Fails

**Symptoms:**
```
mount.nfs4: Connection timed out
```

**Solution:**
```bash
# Verify EFS security group allows NFS (port 2049)
aws ec2 describe-security-groups --group-ids sg-efs-xxx

# Add rule if missing
aws ec2 authorize-security-group-ingress \
  --group-id sg-efs-xxx \
  --protocol tcp \
  --port 2049 \
  --source-group $EB_SG
```

#### Issue: Deployments Fail

**Symptoms:**
```
ERROR: ServiceError - Failed to deploy application
```

**Common Causes:**
1. **npm install fails:** Check `package.json` for invalid dependencies
2. **Migrations fail:** Run migrations manually first
3. **Health checks fail:** Application not starting properly

**Solution:**
```bash
# Deploy with verbose logging
eb deploy --debug

# Check deployment logs
eb logs --zip
unzip -p logs.zip var/log/eb-engine.log

# Roll back to previous version
eb deploy --version app-version-label
```

#### Issue: High Costs

**Symptoms:**
- AWS bill higher than expected

**Diagnosis:**
```bash
# Check cost breakdown
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**Common Causes:**
1. **Data transfer costs:** Large file uploads/downloads
2. **Multi-AZ RDS:** Doubles database costs
3. **Oversized instances:** Using larger than needed
4. **ELB idle charges:** Load balancer always running

**Solutions:**
- Implement CloudFront CDN for static assets
- Use Single-AZ for dev/staging
- Right-size instances based on CloudWatch metrics
- Use single instance (no ELB) for dev

### Getting Help

**AWS Support:**
- Basic: Free (AWS forums)
- Developer: $29/month (12-hour response)
- Business: $100/month (1-hour response)

**Useful Resources:**
- [AWS Elastic Beanstalk Documentation](https://docs.aws.amazon.com/elasticbeanstalk/)
- [AWS Knowledge Center](https://aws.amazon.com/premiumsupport/knowledge-center/)
- [Stack Overflow - AWS Elastic Beanstalk](https://stackoverflow.com/questions/tagged/aws-elastic-beanstalk)

## Next Steps

### After Successful Deployment

1. **Set up CI/CD:**
   - Configure GitHub Actions or AWS CodePipeline
   - Automate testing before deploy
   - [Example GitHub Actions workflow](#cicd-example)

2. **Implement monitoring:**
   - Set up CloudWatch dashboards
   - Configure alerting (PagerDuty, Slack)
   - Enable X-Ray tracing

3. **Harden security:**
   - Enable WAF (Web Application Firewall)
   - Implement rate limiting
   - Regular security audits

4. **Consider migration to ECS:**
   - When you need more control
   - Better for microservices
   - Follow [ECS Fargate guide](./ecs-fargate.md)

### Portfolio Documentation

Document this deployment for your portfolio:

**Blog Post Ideas:**
- "Deploying Node.js Microservices to AWS Elastic Beanstalk"
- "From Heroku to AWS: A Cost and Complexity Comparison"
- "Setting up Production-Ready Auto-Scaling on AWS"

**What to Include:**
- Architecture diagrams (use Mermaid from this guide)
- Cost breakdown and optimizations
- Challenges faced and solutions
- Monitoring screenshots
- Performance metrics

### CI/CD Example

`.github/workflows/deploy-eb.yml`:

```yaml
name: Deploy to Elastic Beanstalk

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20.11.0'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Deploy to Elastic Beanstalk
        run: |
          pip install awsebcli
          eb deploy video-tutorials-prod
```

## Conclusion

You now have a production-ready Elastic Beanstalk deployment with:
- ✅ Auto-scaling and load balancing
- ✅ RDS PostgreSQL databases
- ✅ Shared file storage (EFS)
- ✅ CloudWatch monitoring
- ✅ Automated deployments

**Total setup time:** 4-6 hours
**Monthly cost:** ~$175 for production
**Portfolio value:** Medium-High (demonstrates AWS competency)

**Ready for more advanced architecture?** Check out the [ECS Fargate guide](./ecs-fargate.md) for containerized microservices.

---

**Questions or issues?** File an issue in this repository or consult the [comparison guide](./comparison.md).
