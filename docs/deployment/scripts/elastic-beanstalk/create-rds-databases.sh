#!/bin/bash
# Script to create RDS databases for Video Tutorials application
# Usage: ./create-rds-databases.sh

set -e

echo "Creating RDS databases for Video Tutorials application..."

# Configuration
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32)}"
VPC_SECURITY_GROUP="${VPC_SECURITY_GROUP}"
DB_SUBNET_GROUP="${DB_SUBNET_GROUP:-ebdb-subnet-group}"

if [ -z "$VPC_SECURITY_GROUP" ]; then
  echo "Error: VPC_SECURITY_GROUP environment variable must be set"
  echo "Usage: VPC_SECURITY_GROUP=sg-xxxxx ./create-rds-databases.sh"
  exit 1
fi

echo "Creating Application Database..."
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-app-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --vpc-security-group-ids "$VPC_SECURITY_GROUP" \
  --db-subnet-group-name "$DB_SUBNET_GROUP" \
  --backup-retention-period 7 \
  --no-publicly-accessible \
  --tags Key=Name,Value=video-tutorials-app-db

echo "Creating Message Store Database..."
aws rds create-db-instance \
  --db-instance-identifier video-tutorials-message-store \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --vpc-security-group-ids "$VPC_SECURITY_GROUP" \
  --db-subnet-group-name "$DB_SUBNET_GROUP" \
  --backup-retention-period 7 \
  --no-publicly-accessible \
  --tags Key=Name,Value=video-tutorials-message-store

echo "Waiting for databases to become available (this takes 10-15 minutes)..."
aws rds wait db-instance-available --db-instance-identifier video-tutorials-app-db
aws rds wait db-instance-available --db-instance-identifier video-tutorials-message-store

echo "Getting database endpoints..."
APP_DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-app-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

MSG_DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier video-tutorials-message-store \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo ""
echo "✅ Databases created successfully!"
echo ""
echo "Application DB Endpoint: $APP_DB_ENDPOINT"
echo "Message Store DB Endpoint: $MSG_DB_ENDPOINT"
echo "Master Password: $DB_PASSWORD"
echo ""
echo "⚠️  IMPORTANT: Save the password above! Store it securely."
echo ""
echo "Connection strings:"
echo "DATABASE_URL=postgresql://postgres:$DB_PASSWORD@$APP_DB_ENDPOINT:5432/postgres"
echo "MESSAGE_STORE_CONNECTION_STRING=postgresql://postgres:$DB_PASSWORD@$MSG_DB_ENDPOINT:5432/postgres"
