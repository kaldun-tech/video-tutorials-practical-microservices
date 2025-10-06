#!/bin/bash
# Script to create VPC infrastructure for ECS Fargate deployment
# Usage: ./setup-vpc.sh [region]

set -e

REGION="${1:-us-east-1}"
VPC_NAME="video-tutorials-vpc"

echo "Creating VPC infrastructure in region: $REGION"

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region "$REGION" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC created: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames \
  --region "$REGION"

# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "$REGION" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$VPC_NAME-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID" \
  --region "$REGION"

# Create subnets
echo "Creating subnets..."
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone "${REGION}a" \
  --region "$REGION" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-public-1a}]" \
  --query 'Subnet.SubnetId' \
  --output text)

PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.2.0/24 \
  --availability-zone "${REGION}b" \
  --region "$REGION" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-public-1b}]" \
  --query 'Subnet.SubnetId' \
  --output text)

PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.10.0/24 \
  --availability-zone "${REGION}a" \
  --region "$REGION" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-private-1a}]" \
  --query 'Subnet.SubnetId' \
  --output text)

PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.11.0/24 \
  --availability-zone "${REGION}b" \
  --region "$REGION" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-private-1b}]" \
  --query 'Subnet.SubnetId' \
  --output text)

# Create NAT Gateway
echo "Creating NAT Gateway (this takes a few minutes)..."
EIP_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --region "$REGION" \
  --query 'AllocationId' \
  --output text)

NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id "$PUBLIC_SUBNET_1" \
  --allocation-id "$EIP_ID" \
  --region "$REGION" \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$VPC_NAME-nat}]" \
  --query 'NatGateway.NatGatewayId' \
  --output text)

aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID" --region "$REGION"

# Create route tables
echo "Creating route tables..."
PUBLIC_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-public-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)

PRIVATE_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-private-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add routes
aws ec2 create-route \
  --route-table-id "$PUBLIC_RT" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" \
  --region "$REGION"

aws ec2 create-route \
  --route-table-id "$PRIVATE_RT" \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id "$NAT_GW_ID" \
  --region "$REGION"

# Associate subnets with route tables
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_1" --route-table-id "$PUBLIC_RT" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_2" --route-table-id "$PUBLIC_RT" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_1" --route-table-id "$PRIVATE_RT" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_2" --route-table-id "$PRIVATE_RT" --region "$REGION"

# Save configuration
cat > vpc-config.env <<EOF
# VPC Configuration for Video Tutorials Application
# Generated: $(date)
# Region: $REGION

export VPC_ID=$VPC_ID
export IGW_ID=$IGW_ID
export PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1
export PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2
export PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1
export PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2
export NAT_GW_ID=$NAT_GW_ID
export PUBLIC_RT=$PUBLIC_RT
export PRIVATE_RT=$PRIVATE_RT
EOF

echo ""
echo "✅ VPC infrastructure created successfully!"
echo ""
echo "Configuration saved to: vpc-config.env"
echo "To use these values: source vpc-config.env"
echo ""
echo "Summary:"
echo "  VPC ID: $VPC_ID"
echo "  Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "  Private Subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
echo "  NAT Gateway: $NAT_GW_ID"
