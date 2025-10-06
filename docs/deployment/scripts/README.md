# Deployment Automation Scripts

This directory contains automation scripts to simplify cloud infrastructure setup for the Video Tutorials application.

## Overview

These scripts automate the manual CLI commands described in the deployment guides. Use them to speed up infrastructure provisioning and reduce human error.

## Prerequisites

Before running any scripts:

1. **Install required tools:**
   ```bash
   aws --version        # AWS CLI 2.x+
   docker --version     # Docker 20+ (for ECS)
   jq --version         # jq 1.6+ (for JSON parsing)
   ```

2. **Configure AWS credentials:**
   ```bash
   aws configure
   # Enter AWS Access Key ID
   # Enter AWS Secret Access Key
   # Default region: us-east-1 (or preferred region)
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x docs/deployment/scripts/**/*.sh
   ```

## AWS Elastic Beanstalk Scripts

### create-rds-databases.sh

Creates two RDS PostgreSQL databases (application DB and message store).

**Usage:**
```bash
cd docs/deployment/scripts/elastic-beanstalk

# Set security group from Elastic Beanstalk environment
export VPC_SECURITY_GROUP=sg-xxxxx  # Get from EB console

# Run script
./create-rds-databases.sh
```

**What it does:**
- Creates two db.t3.micro PostgreSQL 16 instances
- Configures automated backups (7-day retention)
- Generates secure random password
- Outputs connection strings
- Waits for databases to become available

**Output:**
- Prints database endpoints and connection strings
- Save the password securely!

**Time:** ~15 minutes

## AWS ECS Fargate Scripts

These scripts should be run in sequence to build complete ECS infrastructure.

### 1. setup-vpc.sh

Creates VPC with public and private subnets across two availability zones.

**Usage:**
```bash
cd docs/deployment/scripts/ecs-fargate

# Run with default region (us-east-1)
./setup-vpc.sh

# Or specify region
./setup-vpc.sh us-west-2
```

**What it does:**
- Creates VPC (10.0.0.0/16)
- Creates 2 public subnets (for ALB, NAT Gateway)
- Creates 2 private subnets (for Fargate tasks, RDS)
- Creates Internet Gateway
- Creates NAT Gateway for outbound internet access
- Configures route tables
- Saves configuration to `vpc-config.env`

**Output:**
- Creates `vpc-config.env` with all VPC resource IDs
- Exports: VPC_ID, subnet IDs, route table IDs, etc.

**Time:** ~5 minutes

**Next step:** Source the config file
```bash
source vpc-config.env
```

### 2. setup-security-groups.sh

Creates security groups for ALB, application, RDS, and EFS.

**Usage:**
```bash
cd docs/deployment/scripts/ecs-fargate

# Must run after setup-vpc.sh
source vpc-config.env
./setup-security-groups.sh
```

**What it does:**
- Creates ALB security group (allows 80, 443 from internet)
- Creates App security group (allows 8080 from ALB only)
- Creates RDS security group (allows 5432 from App only)
- Creates EFS security group (allows 2049 from App only)
- Saves configuration to `security-groups.env`

**Output:**
- Creates `security-groups.env` with security group IDs
- Follows principle of least privilege

**Time:** ~1 minute

**Next step:** Source the config file
```bash
source security-groups.env
```

### 3. create-rds-databases.sh

Creates RDS databases with Multi-AZ deployment.

**Usage:**
```bash
cd docs/deployment/scripts/ecs-fargate

# Must run after setup-vpc.sh and setup-security-groups.sh
source vpc-config.env
source security-groups.env
./create-rds-databases.sh
```

**What it does:**
- Creates DB subnet group in private subnets
- Creates Application DB (db.t3.small, Multi-AZ, encrypted)
- Creates Message Store DB (db.t3.small, Multi-AZ, encrypted)
- Stores credentials in AWS Secrets Manager
- Saves configuration to `rds-config.env`

**Output:**
- Creates `rds-config.env` with database endpoints
- Stores passwords in AWS Secrets Manager
- Enables CloudWatch Logs for PostgreSQL

**Time:** ~15 minutes

**Next step:** Source the config file
```bash
source rds-config.env
```

## Complete ECS Setup Workflow

Run all ECS scripts in sequence:

```bash
cd docs/deployment/scripts/ecs-fargate

# 1. Create VPC
./setup-vpc.sh
source vpc-config.env

# 2. Create Security Groups
./setup-security-groups.sh
source security-groups.env

# 3. Create RDS Databases
./create-rds-databases.sh
source rds-config.env

# At this point, all environment variables are loaded
echo "VPC ID: $VPC_ID"
echo "App DB: $RDS_APP_ENDPOINT"
echo "Message Store: $RDS_MSG_ENDPOINT"
```

Total time: ~25 minutes

## Environment Variable Files

Each script creates a `.env` file with exported variables:

- **vpc-config.env**: VPC, subnet, and networking resource IDs
- **security-groups.env**: Security group IDs
- **rds-config.env**: Database endpoints and connection strings

**To load all variables:**
```bash
source vpc-config.env
source security-groups.env
source rds-config.env
```

**To persist across sessions:**
Add to your shell profile (~/.bashrc or ~/.zshrc):
```bash
# Add to ~/.bashrc
[ -f ~/path/to/vpc-config.env ] && source ~/path/to/vpc-config.env
[ -f ~/path/to/security-groups.env ] && source ~/path/to/security-groups.env
[ -f ~/path/to/rds-config.env ] && source ~/path/to/rds-config.env
```

## Security Best Practices

1. **Never commit `.env` files to git**
   - Already in `.gitignore`
   - Contains sensitive credentials

2. **Use AWS Secrets Manager for production**
   - Scripts automatically store passwords in Secrets Manager
   - Reference secrets in ECS task definitions

3. **Rotate credentials regularly**
   - Change RDS passwords every 90 days
   - Update Secrets Manager values

4. **Review security group rules**
   - Scripts follow least-privilege principle
   - Audit rules periodically

## Cleanup

To delete all created resources (⚠️ destructive):

```bash
# For ECS resources
aws cloudformation delete-stack --stack-name video-tutorials-ecs

# For RDS (takes ~10 minutes)
aws rds delete-db-instance --db-instance-identifier video-tutorials-app-db --skip-final-snapshot
aws rds delete-db-instance --db-instance-identifier video-tutorials-message-store --skip-final-snapshot

# For VPC (after all resources deleted)
aws ec2 delete-vpc --vpc-id $VPC_ID
```

**Warning:** This permanently deletes data. Take snapshots first!

## Troubleshooting

### Script fails with "command not found"

**Solution:** Install AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### "An error occurred (UnauthorizedOperation)"

**Solution:** Check AWS credentials
```bash
aws sts get-caller-identity  # Verify credentials work
```

Ensure IAM user has required permissions:
- EC2 full access (for VPC, security groups)
- RDS full access (for databases)
- Secrets Manager access (for credential storage)

### "VPC_ID not set"

**Solution:** Source the config file
```bash
source vpc-config.env
echo $VPC_ID  # Should print vpc-xxxxx
```

### Script hangs on "Waiting for..."

**Explanation:** Normal behavior - RDS creation takes 10-15 minutes, NAT Gateway takes 2-5 minutes.

**To run in background:**
```bash
./create-rds-databases.sh > rds-creation.log 2>&1 &
tail -f rds-creation.log  # Monitor progress
```

## Customization

### Change instance sizes

Edit scripts to modify instance types:

**For development:**
```bash
# In create-rds-databases.sh, change:
--db-instance-class db.t3.micro   # Smaller, cheaper
--no-multi-az                      # Single AZ
```

**For production:**
```bash
--db-instance-class db.t3.medium   # More powerful
--multi-az                         # High availability
```

### Change regions

Pass region as argument:
```bash
./setup-vpc.sh us-west-2
```

Or set environment variable:
```bash
export AWS_REGION=eu-west-1
./setup-vpc.sh
```

### Change CIDR blocks

Edit `setup-vpc.sh` to modify IP ranges:
```bash
# Change VPC CIDR
--cidr-block 172.16.0.0/16

# Change subnet CIDRs
--cidr-block 172.16.1.0/24  # Public subnet 1
--cidr-block 172.16.2.0/24  # Public subnet 2
```

## Contributing

To add new automation scripts:

1. Follow existing naming conventions
2. Add error handling (`set -e`)
3. Include usage comments at top
4. Output configuration to `.env` file
5. Update this README with usage instructions

## Support

- For script issues: File an issue in this repository
- For AWS service issues: Consult AWS documentation
- For deployment guide questions: See main deployment guides in parent directory
