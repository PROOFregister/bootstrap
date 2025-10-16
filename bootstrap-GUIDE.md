# Arena Bootstrap - Complete Guide

**Comprehensive documentation for managing Arena Controller infrastructure**

## Table of Contents

- [Overview](#overview)
- [What is Bootstrap?](#what-is-bootstrap)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [What Gets Created](#what-gets-created)
- [Configuration](#configuration)
- [Security](#security)
- [Cost Management](#cost-management)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)
- [FAQ](#faq)

## Overview

Arena Bootstrap is the infrastructure management layer for the HACKERverse® training platform. It runs on your local machine and handles:

- Creating the Arena Controller EC2 instance
- Setting up isolated VPC networking
- Configuring security groups and IAM roles
- Managing SSH key pairs
- Destroying all resources when finished

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Local Machine                        │
│                  (macOS/Linux/Windows WSL)                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  arena.bootstrap.launch.bot.sh                               │
│           ↓                                                   │
│      AWS CloudFormation                                       │
│           ↓                                                   │
│  ┌────────────────────────────────────────────────┐          │
│  │            Arena Controller (EC2)              │          │
│  │                                                 │          │
│  │  • VPC: 10.99.0.0/16                           │          │
│  │  • Instance: Amazon Linux 2023                 │          │
│  │  • Role: EC2/IAM/CloudFormation access         │          │
│  │  • Ports: 22 (SSH), 5000 (Dashboard)          │          │
│  │                                                 │          │
│  │  Runs Stage 0: arena.control                   │          │
│  │        ↓                                        │          │
│  │  Deploys Stage 1: Target Infrastructure        │          │
│  │        ↓                                        │          │
│  │  Executes Stage 2: Attack Campaigns            │          │
│  │                                                 │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Stage Hierarchy

- **Bootstrap** (This repo) - Infrastructure management, runs on local machine
- **Stage 0** - Control plane, runs on Arena Controller
- **Stage 1** - Target infrastructure, deployed by controller
- **Stage 2** - Attack campaigns, executed against targets

## What is Bootstrap?

Bootstrap is specifically designed to:

1. **Create Infrastructure** - VPC, subnet, security groups, IAM roles
2. **Launch Controller** - EC2 instance with proper configuration
3. **Manage Keys** - Generate and store SSH key pairs
4. **Save State** - Track all created resources
5. **Destroy Everything** - Complete cleanup when done

**Think of it as:** The "infrastructure-as-code" foundation for your cybersecurity training arena.

## Prerequisites

### Required Software

#### AWS CLI

**Check if installed:**
```bash
aws --version
# Should show: aws-cli/2.x.x or higher
```

**Install on macOS:**
```bash
brew install awscli
```

**Install on Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Install on Windows:**
```bash
# Use Windows Subsystem for Linux (WSL)
# Then follow Linux instructions
```

#### jq (JSON Processor)

**Check if installed:**
```bash
jq --version
```

**Install on macOS:**
```bash
brew install jq
```

**Install on Linux:**
```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install jq

# RHEL/CentOS/Amazon Linux
sudo yum install jq
```

#### Bash Shell

**Version 4.0 or higher required**

**Check version:**
```bash
bash --version
```

Most modern systems have this by default.

### AWS Account Setup

#### 1. Configure AWS Credentials

```bash
aws configure
```

**You'll be prompted for:**
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., us-east-1)
- Default output format (json)

**Verify configuration:**
```bash
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

#### 2. Required IAM Permissions

Your AWS IAM user needs these permissions:

**Minimum Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:CreateKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeKeyPairs",
        "ec2:CreateTags",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:PassRole",
        "iam:GetRole",
        "iam:GetInstanceProfile"
      ],
      "Resource": "*"
    }
  ]
}
```

**Recommended: Use AWS Managed Policies (for training environments):**
```bash
# Attach these policies to your IAM user
aws iam attach-user-policy --user-name your-username --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-user-policy --user-name your-username --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

**Security Note:** These are broad permissions suitable for isolated training accounts. For production or shared accounts, use the minimum policy above.

### Network Requirements

- **Outbound HTTPS (443)** - To AWS API endpoints
- **No inbound requirements** - All managed from your machine

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/YOUR-ORG/arena.bootstrap.git
cd arena.bootstrap
```

### 2. Verify Files

```bash
ls -la
```

**Expected files:**
```
arena.bootstrap.launch.bot.sh
arena.bootstrap.destroy.bot.sh
arena.bootstrap.prepare-github.bot.sh
README.md
QUICKSTART.md
GUIDE.md
```

### 3. Make Scripts Executable

```bash
chmod +x arena.bootstrap.launch.bot.sh
chmod +x arena.bootstrap.destroy.bot.sh
chmod +x arena.bootstrap.prepare-github.bot.sh
```

### 4. Review Scripts (Optional)

```bash
# View launch script
less arena.bootstrap.launch.bot.sh

# View destroy script
less arena.bootstrap.destroy.bot.sh
```

**Security best practice:** Always review scripts before executing them.

## Usage

### Basic Launch

```bash
./arena.bootstrap.launch.bot.sh
```

**Interactive prompts:**
```
Enter stack name [arena-controller]: arena-prod
Enter key pair name [arena-key]: arena-prod-key
Enter instance type [t3.medium]: t3.medium
```

### Launch with Command-Line Arguments

```bash
./arena.bootstrap.launch.bot.sh \
  --stack-name my-arena \
  --key-name my-key \
  --instance-type t3.large \
  --region us-west-2
```

### Available Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `--stack-name` | `arena-controller` | CloudFormation stack identifier |
| `--key-name` | `arena-key` | SSH key pair name |
| `--instance-type` | `t3.medium` | EC2 instance type |
| `--region` | Current region | AWS region to deploy in |

### Instance Type Options

| Type | vCPUs | RAM | Cost/Hour | Use Case |
|------|-------|-----|-----------|----------|
| t3.small | 2 | 2 GB | $0.0208 | Light testing |
| t3.medium | 2 | 4 GB | $0.0416 | Standard (recommended) |
| t3.large | 2 | 8 GB | $0.0832 | Heavy workloads |
| t3.xlarge | 4 | 16 GB | $0.1664 | Large campaigns |

### What Happens During Launch

**Phase 1: Validation (10 seconds)**
1. Check AWS CLI installed
2. Verify AWS credentials
3. Get current region
4. Find latest Amazon Linux 2023 AMI

**Phase 2: Configuration (User input)**
1. Prompt for stack name
2. Prompt for key pair name
3. Prompt for instance type
4. Display configuration summary
5. Wait for user confirmation

**Phase 3: SSH Key Management (5 seconds)**
1. Check if key pair exists in AWS
2. If not, create new key pair
3. Save key to `~/.ssh/<key-name>.pem`
4. Set permissions to 400

**Phase 4: Network Creation (30 seconds)**
1. Create VPC (10.99.0.0/16)
2. Create Internet Gateway
3. Attach gateway to VPC
4. Create public subnet (10.99.1.0/24)
5. Create route table
6. Add route to internet gateway
7. Associate route table with subnet
8. Create security group
9. Add ingress rules (SSH, Dashboard)

**Phase 5: IAM Setup (15 seconds)**
1. Create IAM role for EC2
2. Attach EC2FullAccess policy
3. Attach SSMManagedInstanceCore policy
4. Attach CloudFormationFullAccess policy
5. Create instance profile
6. Add role to instance profile
7. Wait for IAM propagation

**Phase 6: Instance Launch (30 seconds)**
1. Launch EC2 instance with configuration
2. Wait for instance to be running
3. Get public IP address
4. Tag all resources

**Phase 7: Finalization (5 seconds)**
1. Save configuration to file
2. Display connection details
3. Show next steps

**Total Time:** ~2-3 minutes

### Launch Output

**Successful launch shows:**
```
╔════════════════════════════════════════════════════════════╗
║                   LAUNCH COMPLETE!                         ║
╚════════════════════════════════════════════════════════════╝

✓ Arena Controller Created Successfully!

Connection Details:
  Instance ID:  i-0abc123def456789
  Public IP:    54.123.45.67
  Private IP:   10.99.1.100
  SSH Key:      ~/.ssh/arena-prod-key.pem
  VPC:          vpc-0abc123def456789 (10.99.0.0/16)
  Subnet:       subnet-0abc123def456789 (10.99.1.0/24)
  Security:     sg-0abc123def456789
  Region:       us-east-1

SSH Command:
  ssh -i ~/.ssh/arena-prod-key.pem ec2-user@54.123.45.67

Dashboard:
  http://54.123.45.67:5000

Configuration saved to: ~/.arena-arena-prod.conf

Next Steps:
  1. SSH to controller
  2. Install Stage 0: arena.control
  3. Start dashboards
  4. Build target infrastructure

Estimated Cost: $0.0416/hour (~$1.00/day, ~$30/month)
```

### Destroying Resources

```bash
./arena.bootstrap.destroy.bot.sh
```

**The script will:**
1. Read saved configuration from `~/.arena-<stack-name>.conf`
2. Prompt for confirmation
3. Terminate EC2 instance
4. Wait for instance termination
5. Delete IAM instance profile
6. Delete IAM role
7. Delete security group
8. Delete route table
9. Detach and delete internet gateway
10. Delete subnet
11. Delete VPC
12. Display summary

**What does NOT get deleted:**
- SSH key pair in AWS (optional, can be deleted manually)
- Local SSH key file at `~/.ssh/`
- Configuration file at `~/.arena-*.conf`

### Manual Key Deletion

```bash
# Delete from AWS
aws ec2 delete-key-pair --key-name arena-prod-key --region us-east-1

# Delete local file
rm ~/.ssh/arena-prod-key.pem

# Delete configuration
rm ~/.arena-arena-prod.conf
```

## What Gets Created

### VPC and Networking

```
VPC: 10.99.0.0/16
├── Internet Gateway: igw-xxxxx
├── Subnet: 10.99.1.0/24 (Public)
│   └── Arena Controller: 10.99.1.x
├── Route Table: rtb-xxxxx
│   ├── Local Route: 10.99.0.0/16 → local
│   └── Default Route: 0.0.0.0/0 → igw-xxxxx
└── Security Group: sg-xxxxx
    ├── Ingress: TCP 22 from 0.0.0.0/0
    ├── Ingress: TCP 5000 from 0.0.0.0/0
    └── Egress: All traffic to 0.0.0.0/0
```

### EC2 Instance

**Specifications:**
- **AMI:** Latest Amazon Linux 2023
- **Instance Type:** t3.medium (default)
- **Storage:** 8 GB gp3 EBS
- **Network:** Public IP assigned
- **IAM Role:** Attached with necessary permissions
- **Tags:**
  - `Name: arena-controller`
  - `Project: HACKERverse`
  - `Stage: Bootstrap`
  - `ManagedBy: arena.bootstrap`

### IAM Resources

**Role Name:** `arena-controller-role`

**Attached Policies:**
1. `AmazonEC2FullAccess` - Manage target EC2 instances
2. `AmazonSSMManagedInstanceCore` - Systems Manager access
3. `AWSCloudFormationFullAccess` - Deploy target infrastructure

**Instance Profile:** `arena-controller-profile`

### SSH Key Pair

**AWS Key Pair:** Named as specified (default: `arena-key`)

**Local File:**
```
~/.ssh/<key-name>.pem
```

**Permissions:** 400 (read-only for owner)

### Configuration File

**Location:**
```
~/.arena-<stack-name>.conf
```

**Format:**
```bash
STACK_NAME=arena-controller
VPC_ID=vpc-0abc123def456789
SUBNET_ID=subnet-0abc123def456789
IGW_ID=igw-0abc123def456789
ROUTE_TABLE_ID=rtb-0abc123def456789
SG_ID=sg-0abc123def456789
INSTANCE_ID=i-0abc123def456789
PUBLIC_IP=54.123.45.67
PRIVATE_IP=10.99.1.100
KEY_FILE=/Users/username/.ssh/arena-key.pem
AWS_REGION=us-east-1
ROLE_NAME=arena-controller-role
INSTANCE_PROFILE_NAME=arena-controller-profile
```

## Configuration

### Environment Variables

You can override defaults with environment variables:

```bash
# Set AWS profile
export AWS_PROFILE=training-account

# Set region
export AWS_DEFAULT_REGION=us-west-2

# Launch with custom settings
./arena.bootstrap.launch.bot.sh
```

### Multiple Environments

Run multiple arenas simultaneously:

```bash
# Production arena
./arena.bootstrap.launch.bot.sh --stack-name arena-prod --key-name prod-key

# Testing arena
./arena.bootstrap.launch.bot.sh --stack-name arena-test --key-name test-key

# Development arena
./arena.bootstrap.launch.bot.sh --stack-name arena-dev --key-name dev-key
```

Each gets:
- Separate VPC (isolated network)
- Separate EC2 instance
- Separate SSH key
- Separate configuration file
- Complete resource isolation

### Custom VPC CIDR (Advanced)

To change the VPC CIDR range, edit `arena.bootstrap.launch.bot.sh`:

```bash
# Find these lines (around line 50)
VPC_CIDR="10.99.0.0/16"
SUBNET_CIDR="10.99.1.0/24"

# Change to your preferred range
VPC_CIDR="10.100.0.0/16"
SUBNET_CIDR="10.100.1.0/24"
```

**Valid private ranges:**
- 10.0.0.0/8
- 172.16.0.0/12
- 192.168.0.0/16

## Security

### Security Group Rules

**Inbound Rules:**

| Protocol | Port | Source | Purpose |
|----------|------|--------|---------|
| TCP | 22 | 0.0.0.0/0 | SSH access |
| TCP | 5000 | 0.0.0.0/0 | Dashboard |

**Outbound Rules:**

| Protocol | Port | Destination | Purpose |
|----------|------|-------------|---------|
| All | All | 0.0.0.0/0 | Internet access |

### Security Recommendations

#### 1. Restrict SSH Access

**Current (default):** Open to world (0.0.0.0/0)

**Recommended:** Restrict to your IP

```bash
# Get your IP
MY_IP=$(curl -s https://checkip.amazonaws.com)

# Update security group
aws ec2 revoke-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32
```

#### 2. Use SSH Tunnel for Dashboard

Instead of exposing port 5000 to internet:

```bash
# SSH with port forwarding
ssh -i ~/.ssh/arena-key.pem -L 5000:localhost:5000 ec2-user@<public-ip>

# Access dashboard at
# http://localhost:5000
```

#### 3. Enable VPC Flow Logs

```bash
# Create CloudWatch log group
aws logs create-log-group --log-group-name /aws/vpc/arena-controller

# Enable flow logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids <vpc-id> \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/arena-controller
```

#### 4. Enable CloudTrail

```bash
# Create S3 bucket for logs
aws s3 mb s3://arena-cloudtrail-logs-$(date +%s)

# Create trail
aws cloudtrail create-trail \
  --name arena-audit \
  --s3-bucket-name arena-cloudtrail-logs-$(date +%s)

# Start logging
aws cloudtrail start-logging --name arena-audit
```

### IAM Security

**Current Permissions:** Broad (EC2FullAccess, CloudFormationFullAccess)

**Appropriate for:**
- Isolated training accounts
- Non-production environments
- Dedicated security testing

**Not appropriate for:**
- Shared AWS accounts
- Production environments
- Regulated/compliance-sensitive environments

**For production use:** Create custom IAM policy with least-privilege permissions.

### SSH Key Security

**Best Practices:**

1. **Protect key file:**
   ```bash
   chmod 400 ~/.ssh/arena-key.pem
   ```

2. **Never commit to git:**
   ```bash
   # Add to .gitignore
   echo "*.pem" >> ~/.gitignore
   ```

3. **Backup securely:**
   ```bash
   # Encrypt and store
   gpg -c ~/.ssh/arena-key.pem
   # Store arena-key.pem.gpg in secure location
   ```

4. **Rotate regularly:**
   ```bash
   # Delete old key
   aws ec2 delete-key-pair --key-name old-arena-key
   
   # Create new key
   ./arena.bootstrap.launch.bot.sh --key-name new-arena-key
   ```

## Cost Management

### Detailed Cost Breakdown

**EC2 Instance (t3.medium):**
- On-Demand: $0.0416/hour
- Reserved (1-year): $0.027/hour (35% savings)
- Spot: $0.012-0.020/hour (up to 70% savings)

**EBS Storage (8 GB gp3):**
- Storage: $0.08/month
- IOPS: Included (3000 baseline)
- Throughput: Included (125 MB/s baseline)

**Data Transfer:**
- Inbound: Free
- Outbound (first 100 GB): Free
- Outbound (next 9.999 TB): $0.09/GB

**Total Estimated Costs:**

| Period | Cost (On-Demand) |
|--------|------------------|
| Hourly | $0.043 |
| Daily | $1.03 |
| Weekly | $7.22 |
| Monthly | $31.00 |
| Yearly | $377.00 |

### Cost Optimization Strategies

#### 1. Stop When Not In Use

```bash
# Stop instance (no compute charges)
aws ec2 stop-instances --instance-ids <instance-id>

# Storage charges continue (~$0.08/month)
# Start when needed
aws ec2 start-instances --instance-ids <instance-id>
```

**Savings:** ~$1/day when stopped

#### 2. Use Smaller Instance Type

```bash
./arena.bootstrap.launch.bot.sh --instance-type t3.small
```

**Savings:** ~50% on compute costs

#### 3. Use Spot Instances (Advanced)

Spot instances can save up to 70% but may be interrupted.

**Not recommended for:** Production arenas or long-running campaigns

#### 4. Set Billing Alerts

```bash
# Create SNS topic
aws sns create-topic --name arena-cost-alerts

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:arena-cost-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Create billing alarm
aws cloudwatch put-metric-alarm \
  --alarm-name arena-daily-cost \
  --alarm-description "Alert when daily cost exceeds $2" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 2 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

#### 5. Schedule Automatic Shutdown

```bash
# Add to cron (runs at 6 PM daily)
0 18 * * * aws ec2 stop-instances --instance-ids <instance-id>

# Add to cron (starts at 8 AM daily)
0 8 * * * aws ec2 start-instances --instance-ids <instance-id>
```

#### 6. Destroy When Finished

```bash
./arena.bootstrap.destroy.bot.sh
```

**Removes all charges immediately**

### Cost Tracking

**View current month costs:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

**View by service:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## Troubleshooting

### AWS CLI Issues

#### Issue: aws command not found

**Check installation:**
```bash
which aws
```

**Install:**
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### Issue: Unable to locate credentials

**Check configuration:**
```bash
aws configure list
```

**Reconfigure:**
```bash
aws configure
```

**Or use environment variables:**
```bash
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Permission Issues

#### Issue: User is not authorized to perform: ec2:CreateVpc

**Check IAM permissions:**
```bash
aws iam get-user-policy --user-name your-username --policy-name YourPolicyName
```

**Solution:** Contact AWS administrator to add required permissions.

### Key Pair Issues

#### Issue: Key pair already exists

**Check if you have the .pem file:**
```bash
ls -la ~/.ssh/arena-key.pem
```

**If file exists:** Continue using existing key

**If file missing:** Delete key pair and recreate
```bash
aws ec2 delete-key-pair --key-name arena-key
./arena.bootstrap.launch.bot.sh
```

#### Issue: Permission denied (publickey)

**Check key permissions:**
```bash
ls -la ~/.ssh/arena-key.pem
# Should show: -r-------- (400)
```

**Fix permissions:**
```bash
chmod 400 ~/.ssh/arena-key.pem
```

**Verify username:**
```bash
# Amazon Linux 2023 uses 'ec2-user'
ssh -i ~/.ssh/arena-key.pem ec2-user@<public-ip>

# Not 'root' or 'admin'
```

### Connectivity Issues

#### Issue: Connection timed out

**Wait 30-60 seconds** after launch for instance to fully boot.

**Check instance state:**
```bash
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].State.Name'
```

**Check security group:**
```bash
aws ec2 describe-security-groups --group-ids <sg-id>
```

**Verify port 22 is open:**
```bash
aws ec2 describe-security-groups --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'
```

#### Issue: Network error: Connection refused

Instance may not be fully booted. Wait and retry.

**Check system log:**
```bash
aws ec2 get-console-output --instance-id <instance-id>
```

### Resource Limit Issues

#### Issue: VpcLimitExceeded

**Check current VPCs:**
```bash
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]'
```

**Delete unused VPCs** or **request limit increase** from AWS Support.

#### Issue: InstanceLimitExceeded

**Check current instances:**
```bash
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'
```

**Terminate unused instances** or **request limit increase**.

### IAM Issues

#### Issue: Role already exists

This is expected behavior. The script will use the existing role.

**No action needed.**

#### Issue: Cannot pass role to EC2

**Error:** User is not authorized to perform: iam:PassRole

**Solution:** Add PassRole permission to your IAM user:
```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::*:role/arena-controller-role"
}
```

### Destroy Script Issues

#### Issue: Configuration file not found

**Error:** ~/.arena-<stack-name>.conf not found

**Solution:** Manually specify resources or use AWS Console to delete.

#### Issue: Resources still exist after destroy

**Check for dependencies:**
```bash
# List ENIs
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=<vpc-id>"

# List route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"
```

**Manual cleanup:**
```bash
# Delete ENIs first
aws ec2 delete-network-interface --network-interface-id <eni-id>

# Then retry destroy script
./arena.bootstrap.destroy.bot.sh
```

## Advanced Usage

### Using Different AWS Profiles

```bash
# Set profile for session
export AWS_PROFILE=training-account

# Or specify in command
AWS_PROFILE=training-account ./arena.bootstrap.launch.bot.sh
```

### Automating Launch

**Non-interactive mode:**
```bash
# Create wrapper script
cat > auto-launch.sh << 'EOF'
#!/bin/bash
./arena.bootstrap.launch.bot.sh \
  --stack-name auto-arena \
  --key-name auto-key \
  --instance-type t3.medium \
  --region us-east-1 \
  --no-prompt
EOF

chmod +x auto-launch.sh
./auto-launch.sh
```

### Scheduled Cleanup

```bash
# Launch arena for 8 hours, then destroy
./arena.bootstrap.launch.bot.sh &
LAUNCH_PID=$!

# Wait for launch to complete
wait $LAUNCH_PID

# Schedule destruction
(sleep 28800 && ./arena.bootstrap.destroy.bot.sh) &
```

### CI/CD Integration

**GitHub Actions Example:**
```yaml
name: Deploy Arena
on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Launch Arena Controller
        run: |
          chmod +x arena.bootstrap.launch.bot.sh
          ./arena.bootstrap.launch.bot.sh --no-prompt
      
      - name: Save configuration
        uses: actions/upload-artifact@v2
        with:
          name: arena-config
          path: ~/.arena-*.conf
```

### Custom AMI

To use a custom AMI instead of Amazon Linux:

1. Edit `arena.bootstrap.launch.bot.sh`
2. Find the AMI lookup section (around line 100)
3. Replace with your AMI ID:

```bash
# Original (finds latest Amazon Linux 2023)
AMI_ID=$(aws ec2 describe-images ...)

# Custom
AMI_ID="ami-your-custom-ami-id"
```

### Additional Security Groups

To add more security group rules:

```bash
# After launch, add rules
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0
```

## Best Practices

### Before Launch

1. ✅ Review AWS credentials
2. ✅ Verify IAM permissions
3. ✅ Check AWS service limits
4. ✅ Plan naming convention
5. ✅ Decide on instance type
6. ✅ Review security requirements

### During Operation

1. ✅ Monitor AWS costs daily
2. ✅ Review CloudTrail logs
3. ✅ Check security group rules
4. ✅ Backup important data
5. ✅ Tag all resources properly
6. ✅ Document configuration changes

### After Completion

1. ✅ Destroy unused resources
2. ✅ Delete SSH keys if no longer needed
3. ✅ Review final costs
4. ✅ Archive configuration files
5. ✅ Document lessons learned

### Security Best Practices

1. ✅ Use isolated AWS accounts
2. ✅ Enable CloudTrail auditing
3. ✅ Restrict security groups to known IPs
4. ✅ Rotate IAM credentials regularly
5. ✅ Use SSH tunnels for dashboard access
6. ✅ Enable VPC Flow Logs
7. ✅ Never commit SSH keys to git
8. ✅ Use MFA for AWS console access

### Cost Management Best Practices

1. ✅ Set billing alerts
2. ✅ Stop instances when not in use
3. ✅ Destroy resources promptly
4. ✅ Use appropriate instance sizes
5. ✅ Review costs weekly
6. ✅ Tag resources for cost tracking
7. ✅ Schedule automatic shutdowns
8. ✅ Document expected costs

## FAQ

### General Questions

**Q: What is the Arena Controller?**  
A: The EC2 instance that runs the Stage 0 control plane and manages target infrastructure deployment.

**Q: Can I use an existing VPC?**  
A: Not currently supported. The script creates an isolated VPC.

**Q: How long does launch take?**  
A: Typically 2-3 minutes.

**Q: Can I run multiple arenas?**  
A: Yes, use different stack names for each arena.

**Q: What operating systems are supported?**  
A: macOS, Linux, and Windows WSL.

### AWS Questions

**Q: Which regions are supported?**  
A: All standard AWS regions. Specify with `--region` flag.

**Q: What about AWS GovCloud or China regions?**  
A: Not tested, but should work with appropriate credentials.

**Q: Can I use AWS Organizations?**  
A: Yes, recommended for isolated training accounts.

**Q: Does this work with AWS Free Tier?**  
A: Partially. EC2 t3.micro is free tier eligible, but t3.medium is not.

### Cost Questions

**Q: How much does this cost?**  
A: ~$0.043/hour (~$1.03/day, ~$31/month) for default t3.medium.

**Q: Are there any hidden costs?**  
A: Data transfer costs may apply if you transfer large amounts of data.

**Q: How do I reduce costs?**  
A: Stop instances when not in use, use smaller instance types, destroy when finished.

**Q: Can I get cost estimates before launching?**  
A: Yes, use the AWS Simple Monthly Calculator or Pricing Calculator.

### Security Questions

**Q: Is the default configuration secure?**  
A: It's designed for isolated training environments. For production, restrict security groups and use least-privilege IAM.

**Q: Should I open port 5000 to the internet?**  
A: For training, yes. For production, use SSH tunneling instead.

**Q: What about compliance (HIPAA, PCI, etc.)?**  
A: This tool is for training only. Do not use in regulated environments without proper review.

**Q: How do I audit who accessed the controller?**  
A: Enable CloudTrail and review SSH logs on the controller.

### Technical Questions

**Q: What if launch fails?**  
A: Check AWS CloudTrail for error details. Most issues are permission-related.

**Q: Can I change the VPC CIDR?**  
A: Yes, edit the script before launching. See [Configuration](#configuration).

**Q: How do I backup my arena?**  
A: Create an AMI of the controller instance.

**Q: Can I restore from backup?**  
A: Launch new controller and manually configure to match AMI.

**Q: What happens if I lose the SSH key?**  
A: You'll need to use EC2 Instance Connect or create a new instance.

### Troubleshooting Questions

**Q: SSH connection refused?**  
A: Wait 30-60 seconds for instance to boot. Check security group rules.

**Q: Can't find configuration file?**  
A: Should be at `~/.arena-<stack-name>.conf`. Check for typos in stack name.

**Q: Destroy script failed?**  
A: Manually delete resources using AWS Console, or check for resource dependencies.

**Q: Getting permission denied errors?**  
A: Check IAM permissions. See [Prerequisites](#prerequisites).

---

## Additional Resources

### Documentation

- [README.md](README.md) - Repository overview
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup guide
- [arena.control](https://github.com/YOUR-ORG/arena.control) - Stage 0 documentation

### AWS Documentation

- [EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [VPC User Guide](https://docs.aws.amazon.com/vpc/)
- [IAM User Guide](https://docs.aws.amazon.com/iam/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)

### Support

**GitHub Issues:**  
https://github.com/YOUR-ORG/arena.bootstrap/issues

**Questions:**  
Open a discussion in the repository

---

**Arena Bootstrap - Complete Guide**  
Part of the HACKERverse® Cybersecurity Training Platform  
Version 1.0 | October 2025
