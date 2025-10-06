#!/bin/bash
# Script to create RDS databases for ECS Fargate deployment
# Usage: source vpc-config.env && source security-groups.env && ./create-rds-databases.sh

set -e

if [ -z "$VPC_ID" ] || [ -z "$SG_RDS" ] || [ -z "$PRIVATE_SUBNET_1" ]; then
  echo "Error: Required environment variables not set"
  echo "Usage: source vpc-config.env && source security-groups.env && ./create-rds-databases.sh"
  exit 1
fi

REGION="${AWS_REGION:-us-east-1}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32)}"

echo "Creating RDS infrastructure..."

# Create DB subnet group
echo "Creating DB subnet group..."
aws rds create-db-subnet-group \
  --db-subnet-group-name video-tutorials-db-subnet \
  --db-subnet-group-description "Subnet group for Video Tutorials RDS instances" \
  --subnet-ids "$PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_2" \
  --region "$REGION"

# Create Application Database
echo "Creating Application Database..."
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-app-db \
  --db-instance-class db.t3.small \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 50 \
  --db-subnet-group-name video-tutorials-db-subnet \
  --vpc-security-group-ids "$SG_RDS" \
  --backup-retention-period 7 \
  --multi-az \
  --no-publicly-accessible \
  --storage-encrypted \
  --enable-cloudwatch-logs-exports '["postgresql"]' \
  --region "$REGION" \
  --tags Key=Name,Value=video-tutorials-app-db

# Create Message Store Database
echo "Creating Message Store Database..."
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-message-store \
  --db-instance-class db.t3.small \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 50 \
  --db-subnet-group-name video-tutorials-db-subnet \
  --vpc-security-group-ids "$SG_RDS" \
  --backup-retention-period 7 \
  --multi-az \
  --no-publicly-accessible \
  --storage-encrypted \
  --enable-cloudwatch-logs-exports '["postgresql"]' \
  --region "$REGION" \
  --tags Key=Name,Value=video-tutorials-message-store

echo "Waiting for databases to become available (10-15 minutes)..."
aws rds wait db-instance-available --db-instance-identifier video-tutorials-app-db --region "$REGION"
aws rds wait db-instance-available --db-instance-identifier video-tutorials-message-store --region "$REGION"

# Get endpoints
RDS_APP_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-app-db \
  --region "$REGION" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

RDS_MSG_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-message-store \
  --region "$REGION" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

# Store secrets in AWS Secrets Manager
echo "Storing credentials in AWS Secrets Manager..."
aws secretsmanager create-secret \
  --name video-tutorials/db/app-password \
  --secret-string "$DB_PASSWORD" \
  --region "$REGION" || true

aws secretsmanager create-secret \
  --name video-tutorials/db/messagestore-password \
  --secret-string "$DB_PASSWORD" \
  --region "$REGION" || true

aws secretsmanager create-secret \
  --name video-tutorials/database-url \
  --secret-string "postgresql://postgres:$DB_PASSWORD@$RDS_APP_ENDPOINT:5432/postgres" \
  --region "$REGION" || true

aws secretsmanager create-secret \
  --name video-tutorials/messagestore-url \
  --secret-string "postgresql://postgres:$DB_PASSWORD@$RDS_MSG_ENDPOINT:5432/postgres" \
  --region "$REGION" || true

# Save configuration
cat > rds-config.env <<EOF
# RDS Configuration for Video Tutorials Application
# Generated: $(date)
# Region: $REGION

export RDS_APP_ENDPOINT=$RDS_APP_ENDPOINT
export RDS_MSG_ENDPOINT=$RDS_MSG_ENDPOINT
export DATABASE_URL=postgresql://postgres:$DB_PASSWORD@$RDS_APP_ENDPOINT:5432/postgres
export MESSAGE_STORE_CONNECTION_STRING=postgresql://postgres:$DB_PASSWORD@$RDS_MSG_ENDPOINT:5432/postgres
EOF

echo ""
echo "✅ RDS databases created successfully!"
echo ""
echo "Configuration saved to: rds-config.env"
echo "Credentials stored in AWS Secrets Manager"
echo ""
echo "Summary:"
echo "  App DB Endpoint: $RDS_APP_ENDPOINT"
echo "  Message Store Endpoint: $RDS_MSG_ENDPOINT"
echo "  Master Password: (stored in Secrets Manager)"
echo ""
echo "⚠️  IMPORTANT: Password also saved locally in rds-config.env - handle securely!"
