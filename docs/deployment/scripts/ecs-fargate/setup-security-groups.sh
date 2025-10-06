#!/bin/bash
# Script to create security groups for ECS Fargate deployment
# Usage: source vpc-config.env && ./setup-security-groups.sh

set -e

if [ -z "$VPC_ID" ]; then
  echo "Error: VPC_ID not set. Did you source vpc-config.env?"
  echo "Usage: source vpc-config.env && ./setup-security-groups.sh"
  exit 1
fi

REGION="${AWS_REGION:-us-east-1}"

echo "Creating security groups for VPC: $VPC_ID"

# Security Group for ALB
echo "Creating ALB security group..."
SG_ALB=$(aws ec2 create-security-group \
  --group-name video-tutorials-alb-sg \
  --description "Security group for Application Load Balancer" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ALB" \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ALB" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

# Security Group for Fargate tasks
echo "Creating application security group..."
SG_APP=$(aws ec2 create-security-group \
  --group-name video-tutorials-app-sg \
  --description "Security group for Fargate tasks" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_APP" \
  --protocol tcp \
  --port 8080 \
  --source-group "$SG_ALB" \
  --region "$REGION"

# Security Group for RDS
echo "Creating RDS security group..."
SG_RDS=$(aws ec2 create-security-group \
  --group-name video-tutorials-rds-sg \
  --description "Security group for RDS databases" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_RDS" \
  --protocol tcp \
  --port 5432 \
  --source-group "$SG_APP" \
  --region "$REGION"

# Security Group for EFS
echo "Creating EFS security group..."
SG_EFS=$(aws ec2 create-security-group \
  --group-name video-tutorials-efs-sg \
  --description "Security group for EFS file system" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_EFS" \
  --protocol tcp \
  --port 2049 \
  --source-group "$SG_APP" \
  --region "$REGION"

# Save configuration
cat > security-groups.env <<EOF
# Security Groups Configuration for Video Tutorials Application
# Generated: $(date)
# Region: $REGION

export SG_ALB=$SG_ALB
export SG_APP=$SG_APP
export SG_RDS=$SG_RDS
export SG_EFS=$SG_EFS
EOF

echo ""
echo "✅ Security groups created successfully!"
echo ""
echo "Configuration saved to: security-groups.env"
echo "To use these values: source security-groups.env"
echo ""
echo "Summary:"
echo "  ALB Security Group: $SG_ALB (allows 80, 443 from internet)"
echo "  App Security Group: $SG_APP (allows 8080 from ALB)"
echo "  RDS Security Group: $SG_RDS (allows 5432 from App)"
echo "  EFS Security Group: $SG_EFS (allows 2049 from App)"
