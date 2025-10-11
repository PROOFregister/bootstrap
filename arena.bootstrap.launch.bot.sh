#!/bin/bash
# arena.bootstrap.launch.bot.sh - Launch Arena Controller EC2 Instance
# Bootstrap Stage: Runs on your local machine
# Creates isolated VPC and controller instance for Stage 0

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║      HACKERverse® Arena Controller - Bootstrap Launch     ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check Prerequisites
echo "Step 1: Checking Prerequisites"
echo "────────────────────────────────────────────────────────────"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}[✗] AWS CLI not found${NC}"
    exit 1
fi
echo -e "${GREEN}[✓]${NC} AWS CLI found: $(aws --version | cut -d' ' -f1)"

# Check AWS credentials
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT" ]; then
    echo -e "${RED}[✗] AWS credentials not configured${NC}"
    exit 1
fi
echo -e "${GREEN}[✓]${NC} AWS Account: $AWS_ACCOUNT"

# Get region
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo -e "${GREEN}[✓]${NC} Region: $AWS_REGION"

echo ""

# Step 2: Configuration
echo "Step 2: Configuration"
echo "────────────────────────────────────────────────────────────"

# Prompt for configuration
read -p "Stack name [arena-controller]: " STACK_NAME
STACK_NAME=${STACK_NAME:-arena-controller}

read -p "Key pair name [arena-key]: " KEY_NAME
KEY_NAME=${KEY_NAME:-arena-key}

read -p "Instance type [t3.medium]: " INSTANCE_TYPE
INSTANCE_TYPE=${INSTANCE_TYPE:-t3.medium}

read -p "AWS Region [$AWS_REGION]: " REGION_INPUT
AWS_REGION=${REGION_INPUT:-$AWS_REGION}

# Get latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region $AWS_REGION)

echo ""
echo -e "${CYAN}[ℹ]${NC} Stack Name: $STACK_NAME"
echo -e "${CYAN}[ℹ]${NC} Key Pair: $KEY_NAME"
echo -e "${CYAN}[ℹ]${NC} Instance Type: $INSTANCE_TYPE"
echo -e "${CYAN}[ℹ]${NC} Region: $AWS_REGION"
echo -e "${CYAN}[ℹ]${NC} AMI: $AMI_ID"
echo -e "${YELLOW}[⚠]${NC} VPC CIDR: 10.99.0.0/16 (NEW ISOLATED VPC)"
echo -e "${CYAN}[ℹ]${NC} Public Subnet: 10.99.1.0/24"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""

# Step 3: SSH Key Pair
echo "Step 3: SSH Key Pair"
echo "────────────────────────────────────────────────────────────"

KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"

# Check if key already exists
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $AWS_REGION &>/dev/null; then
    echo -e "${YELLOW}[!]${NC} Key pair $KEY_NAME already exists"
    if [ ! -f "$KEY_FILE" ]; then
        echo -e "${RED}[✗]${NC} Key file not found at $KEY_FILE"
        echo -e "${YELLOW}[!]${NC} Please delete the key pair in AWS console or use a different name"
        exit 1
    fi
else
    echo -e "${CYAN}[ℹ]${NC} Creating new key pair: $KEY_NAME"
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text \
        --region $AWS_REGION > "$KEY_FILE"
    chmod 400 "$KEY_FILE"
    echo -e "${GREEN}[✓]${NC} Key pair created: $KEY_FILE"
fi

echo ""

# Step 4: Create VPC
echo "Step 4: Creating Isolated Arena VPC"
echo "────────────────────────────────────────────────────────────"

echo -e "${CYAN}[ℹ]${NC} Creating new VPC: 10.99.0.0/16"
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.99.0.0/16 \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${STACK_NAME}-vpc},{Key=arena,Value=true}]" \
    --query 'Vpc.VpcId' \
    --output text \
    --region $AWS_REGION)
echo -e "${GREEN}[✓]${NC} VPC created: $VPC_ID"

echo -e "${CYAN}[ℹ]${NC} Enabling DNS hostnames..."
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames \
    --region $AWS_REGION
echo -e "${GREEN}[✓]${NC} DNS hostnames enabled"

echo ""

# Step 5: Internet Gateway
echo "Step 5: Creating Internet Gateway"
echo "────────────────────────────────────────────────────────────"

echo -e "${CYAN}[ℹ]${NC} Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${STACK_NAME}-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text \
    --region $AWS_REGION)
echo -e "${GREEN}[✓]${NC} Internet Gateway created: $IGW_ID"

echo -e "${CYAN}[ℹ]${NC} Attaching to VPC..."
aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID \
    --region $AWS_REGION
echo -e "${GREEN}[✓]${NC} Internet Gateway attached"

echo ""

# Step 6: Public Subnet
echo "Step 6: Creating Public Subnet"
echo "────────────────────────────────────────────────────────────"

echo -e "${CYAN}[ℹ]${NC} Creating public subnet: 10.99.1.0/24"
SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.99.1.0/24 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${STACK_NAME}-public-subnet}]" \
    --query 'Subnet.SubnetId' \
    --output text \
    --region $AWS_REGION)
echo -e "${GREEN}[✓]${NC} Public subnet created: $SUBNET_ID"

echo -e "${CYAN}[ℹ]${NC} Enabling auto-assign public IP..."
aws ec2 modify-subnet-attribute \
    --subnet-id $SUBNET_ID \
    --map-public-ip-on-launch \
    --region $AWS_REGION
echo -e "${GREEN}[✓]${NC} Auto-assign public IP enabled"

echo ""

# Step 7: Route Table
echo "Step 7: Configuring Route Table"
echo "────────────────────────────────────────────────────────────"

echo -e "${CYAN}[ℹ]${NC} Creating route table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${STACK_NAME}-public-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text \
    --region $AWS_REGION)
echo -e "${GREEN}[✓]${NC} Route table created: $ROUTE_TABLE_ID"

echo -e "${CYAN}[ℹ]${NC} Adding route to Internet Gateway..."
aws ec2 create-route \
    --route-table-id $ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --region $AWS_REGION > /dev/null
echo -e "${GREEN}[✓]${NC} Route to Internet Gateway added"

echo -e "${CYAN}[ℹ]${NC} Associating route table with public subnet..."
aws ec2 associate-route-table \
    --subnet-id $SUBNET_ID \
    --route-table-id $ROUTE_TABLE_ID \
    --region $AWS_REGION > /dev/null
echo -e "${GREEN}[✓]${NC} Route table associated"

echo ""

# Step 8: Security Group
echo "Step 8: Creating Security Group"
echo "────────────────────────────────────────────────────────────"

echo -e "${CYAN}[ℹ]${NC} Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name "${STACK_NAME}-sg" \
    --description "Security group for arena controller" \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${STACK_NAME}-sg}]" \
    --query 'GroupId' \
    --output text \
    --region $AWS_REGION)
echo -e "${GREEN}[✓]${NC} Security group created: $SG_ID"

echo -e "${CYAN}[ℹ]${NC} Adding SSH rule (port 22)..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION > /dev/null
echo -e "${GREEN}[✓]${NC} SSH access enabled"

echo -e "${CYAN}[ℹ]${NC} Adding HTTP rule (port 5000 - dashboard)..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 5000 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION > /dev/null
echo -e "${GREEN}[✓]${NC} Dashboard access enabled"

echo ""

# Step 9: IAM Role
echo "Step 9: Creating IAM Role"
echo "────────────────────────────────────────────────────────────"

ROLE_NAME="${STACK_NAME}-role"
INSTANCE_PROFILE_NAME="${STACK_NAME}-profile"

# Create trust policy
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

echo -e "${CYAN}[ℹ]${NC} Creating IAM role..."
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --region $AWS_REGION > /dev/null 2>&1 || echo -e "${YELLOW}[!]${NC} Role may already exist"
echo -e "${GREEN}[✓]${NC} IAM role created: $ROLE_NAME"

echo -e "${CYAN}[ℹ]${NC} Attaching EC2 policy..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess \
    --region $AWS_REGION 2>/dev/null || true

echo -e "${CYAN}[ℹ]${NC} Attaching SSM policy..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
    --region $AWS_REGION 2>/dev/null || true

echo -e "${CYAN}[ℹ]${NC} Attaching CloudFormation policy..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AWSCloudFormationFullAccess \
    --region $AWS_REGION 2>/dev/null || true
echo -e "${GREEN}[✓]${NC} Policies attached"

echo -e "${CYAN}[ℹ]${NC} Creating instance profile..."
aws iam create-instance-profile \
    --instance-profile-name $INSTANCE_PROFILE_NAME \
    --region $AWS_REGION > /dev/null 2>&1 || echo -e "${YELLOW}[!]${NC} Profile may already exist"

echo -e "${CYAN}[ℹ]${NC} Adding role to instance profile..."
aws iam add-role-to-instance-profile \
    --instance-profile-name $INSTANCE_PROFILE_NAME \
    --role-name $ROLE_NAME \
    --region $AWS_REGION 2>/dev/null || true
echo -e "${GREEN}[✓]${NC} Instance profile created"

# Wait for instance profile to propagate
echo -e "${CYAN}[ℹ]${NC} Waiting for IAM to propagate (10 seconds)..."
sleep 10

echo ""

# Step 10: Launch Instance
echo "Step 10: Launching Arena Controller Instance"
echo "────────────────────────────────────────────────────────────"

echo -e "${CYAN}[ℹ]${NC} Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --iam-instance-profile Name=$INSTANCE_PROFILE_NAME \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${STACK_NAME}},{Key=arena,Value=true},{Key=role,Value=controller}]" \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $AWS_REGION)
echo -e "${GREEN}[✓]${NC} Instance launched: $INSTANCE_ID"

echo -e "${CYAN}[ℹ]${NC} Waiting for instance to be running..."
aws ec2 wait instance-running \
    --instance-ids $INSTANCE_ID \
    --region $AWS_REGION

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region $AWS_REGION)
echo -e "${GREEN}[✓]${NC} Instance running: $PUBLIC_IP"

echo ""

# Save configuration
CONFIG_FILE="$HOME/.arena-${STACK_NAME}.conf"
cat > $CONFIG_FILE << EOF
STACK_NAME=$STACK_NAME
VPC_ID=$VPC_ID
SUBNET_ID=$SUBNET_ID
IGW_ID=$IGW_ID
ROUTE_TABLE_ID=$ROUTE_TABLE_ID
SG_ID=$SG_ID
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
KEY_FILE=$KEY_FILE
AWS_REGION=$AWS_REGION
ROLE_NAME=$ROLE_NAME
INSTANCE_PROFILE_NAME=$INSTANCE_PROFILE_NAME
EOF

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║                   LAUNCH COMPLETE!                         ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✓${NC} Arena Controller is running!"
echo ""
echo "Details:"
echo "  Instance ID:  $INSTANCE_ID"
echo "  Public IP:    $PUBLIC_IP"
echo "  SSH Key:      $KEY_FILE"
echo "  VPC:          $VPC_ID (10.99.0.0/16)"
echo "  Region:       $AWS_REGION"
echo ""
echo "Next Steps:"
echo ""
echo "1. SSH to controller:"
echo -e "   ${CYAN}ssh -i $KEY_FILE ec2-user@$PUBLIC_IP${NC}"
echo ""
echo "2. Install Stage 0:"
echo -e "   ${CYAN}curl -sSL https://raw.githubusercontent.com/YOUR-ORG/arena.control/main/arena.control.install.bot.sh | bash${NC}"
echo ""
echo "3. Start UIs:"
echo -e "   ${CYAN}cd /arena/bots && ./arena.control.ui-launch.bot.sh${NC}"
echo ""
echo "4. Access dashboard:"
echo -e "   ${CYAN}http://$PUBLIC_IP:5000${NC}"
echo ""
echo "Configuration saved to: $CONFIG_FILE"
echo ""
