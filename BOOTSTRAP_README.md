# Arena Bootstrap Stage

## 🎯 Purpose

The **Bootstrap Stage** runs on **your local machine** (Mac/Laptop) and manages the Arena Controller infrastructure.

**Bootstrap = Infrastructure Management**
- Creates the Arena Controller EC2 instance
- Destroys the Arena Controller when done
- Prepares files for GitHub distribution

---

## 📂 Bootstrap Files

| File | Purpose |
|------|---------|
| `arena.bootstrap.launch.bot.sh` | Creates Arena Controller EC2 instance |
| `arena.bootstrap.destroy.bot.sh` | Destroys Arena Controller and all resources |
| `arena.bootstrap.prepare-github.bot.sh` | Organizes Stage 0 files for GitHub |

---

## 🚀 Quick Start

### Step 1: Launch Arena Controller

```bash
chmod +x arena.bootstrap.launch.bot.sh
./arena.bootstrap.launch.bot.sh
```

**Prompts:**
- Stack name (default: `arena-controller`)
- Key pair name (default: `arena-key`)
- Instance type (default: `t3.medium`)
- AWS Region (default: `us-east-1`)

**Creates:**
- Isolated VPC: `10.99.0.0/16`
- Public subnet: `10.99.1.0/24`
- Internet Gateway
- Security Group (SSH port 22, Dashboard port 5000)
- IAM Role with EC2/SSM/CloudFormation permissions
- EC2 instance (Amazon Linux 2023)
- SSH key pair: `~/.ssh/<key-name>.pem`

**Output:**
```
╔════════════════════════════════════════════════════════════╗
║                   LAUNCH COMPLETE!                         ║
╚════════════════════════════════════════════════════════════╝

Details:
  Instance ID:  i-1234567890abcdef
  Public IP:    54.123.45.67
  SSH Key:      ~/.ssh/arena-key.pem
  VPC:          vpc-xxxxx (10.99.0.0/16)
  Region:       us-east-1
```

### Step 2: SSH to Controller

```bash
ssh -i ~/.ssh/arena-key.pem ec2-user@54.123.45.67
```

### Step 3: Install Stage 0

```bash
# On the controller
curl -sSL https://raw.githubusercontent.com/YOUR-ORG/arena.control/main/arena.control.install.bot.sh | bash
```

### Step 4: Start Stage 0 UIs

```bash
cd /arena/bots
./arena.control.ui-launch.bot.sh
```

### Step 5: Access Dashboard

```
http://54.123.45.67:5000
```

---

## 🗑️ Cleanup

### Destroy Everything

```bash
chmod +x arena.bootstrap.destroy.bot.sh
./arena.bootstrap.destroy.bot.sh
```

**Removes:**
- EC2 instance
- Security group
- Route table
- Subnet
- Internet Gateway
- VPC
- IAM role and instance profile

**Note:** SSH key pair is NOT deleted (manual deletion required if needed)

---

## 📋 Prerequisites

### Required

- **AWS CLI** installed and configured
  ```bash
  aws --version
  aws configure
  ```
- **AWS Credentials** with permissions for:
  - EC2 (create/delete instances, VPCs, security groups)
  - IAM (create/delete roles, instance profiles)
  - CloudFormation (read stacks)

### Recommended

- **tmux** (for CLI monitor)
  ```bash
  brew install tmux  # macOS
  ```

---

## 🔧 Configuration

### Default Settings

| Setting | Default Value | Customizable |
|---------|---------------|--------------|
| Stack Name | `arena-controller` | Yes (prompt) |
| Key Pair | `arena-key` | Yes (prompt) |
| Instance Type | `t3.medium` | Yes (prompt) |
| Region | `us-east-1` | Yes (prompt) |
| VPC CIDR | `10.99.0.0/16` | No |
| Subnet CIDR | `10.99.1.0/24` | No |
| AMI | Latest Amazon Linux 2023 | No |

### Saved Configuration

Launch script saves configuration to:
```
~/.arena-<stack-name>.conf
```

**Contents:**
```bash
STACK_NAME=arena-controller
VPC_ID=vpc-xxxxx
SUBNET_ID=subnet-xxxxx
IGW_ID=igw-xxxxx
ROUTE_TABLE_ID=rtb-xxxxx
SG_ID=sg-xxxxx
INSTANCE_ID=i-xxxxx
PUBLIC_IP=54.123.45.67
KEY_FILE=/Users/you/.ssh/arena-key.pem
AWS_REGION=us-east-1
ROLE_NAME=arena-controller-role
INSTANCE_PROFILE_NAME=arena-controller-profile
```

**Used by:** `arena.bootstrap.destroy.bot.sh`

---

## 💰 Cost Estimate

### Hourly Costs

| Resource | Type | Cost/Hour |
|----------|------|-----------|
| EC2 Instance | t3.medium | ~$0.0416 |
| EBS Volume | 8 GB gp3 | ~$0.0011 |
| **Total** | | **~$0.043/hour** |

### Daily/Monthly

- **Daily:** ~$1.03
- **Monthly:** ~$31.00

**Note:** Costs vary by region and usage

---

## 🔒 Security

### Ports Opened

| Port | Purpose | Source |
|------|---------|--------|
| 22 | SSH | 0.0.0.0/0 |
| 5000 | Dashboard | 0.0.0.0/0 |

### IAM Permissions

Controller has these managed policies:
- `AmazonEC2FullAccess`
- `AmazonSSMManagedInstanceCore`
- `AWSCloudFormationFullAccess`

**Security Note:** These are broad permissions suitable for isolated training environments. For production, use least-privilege policies.

---

## 🐛 Troubleshooting

### Issue: Key pair already exists

**Error:**
```
Key pair arena-key already exists
Key file not found at ~/.ssh/arena-key.pem
```

**Solution:**
1. Delete existing key in AWS Console, or
2. Use a different key name when prompted

### Issue: IAM role creation fails

**Error:**
```
An error occurred (EntityAlreadyExists) when calling CreateRole
```

**Solution:**
This is normal if role exists. Script continues automatically.

### Issue: Can't SSH to controller

**Check 1:** Security group allows SSH
```bash
aws ec2 describe-security-groups --group-ids <sg-id>
```

**Check 2:** Instance is running
```bash
aws ec2 describe-instances --instance-ids <instance-id>
```

**Check 3:** Key permissions
```bash
chmod 400 ~/.ssh/arena-key.pem
```

### Issue: Region mismatch

**Error:**
```
Could not find image ami-xxxxx in region us-west-2
```

**Solution:**
Ensure you're using the same region throughout. The script auto-detects from `aws configure`.

---

## 📊 What Happens Step-by-Step

1. **Check Prerequisites**
   - Verifies AWS CLI installed
   - Checks AWS credentials
   - Gets current region

2. **Gather Configuration**
   - Prompts for stack name, key pair, instance type
   - Finds latest Amazon Linux 2023 AMI
   - Confirms with user

3. **Create/Verify SSH Key**
   - Creates new key pair if doesn't exist
   - Saves to `~/.ssh/<key-name>.pem`
   - Sets proper permissions (400)

4. **Build Network Infrastructure**
   - Creates isolated VPC (10.99.0.0/16)
   - Creates Internet Gateway
   - Creates public subnet (10.99.1.0/24)
   - Configures route table
   - Creates security group

5. **Create IAM Resources**
   - Creates IAM role for EC2
   - Attaches necessary policies
   - Creates instance profile
   - Waits for IAM propagation

6. **Launch Controller**
   - Launches EC2 instance
   - Waits for instance to be running
   - Gets public IP address

7. **Save Configuration**
   - Writes config to `~/.arena-<stack>.conf`
   - Shows next steps

---

## 🔄 Multiple Environments

Run multiple isolated arenas:

```bash
# Production arena
./arena.bootstrap.launch.bot.sh
# Stack name: arena-prod

# Testing arena
./arena.bootstrap.launch.bot.sh
# Stack name: arena-test

# Development arena
./arena.bootstrap.launch.bot.sh
# Stack name: arena-dev
```

Each creates:
- Separate VPC
- Separate instance
- Separate configuration file
- Separate SSH key

---

## 📝 Next Steps

After bootstrap completes:

1. **SSH to controller**
2. **Install Stage 0** (from GitHub)
3. **Start UIs**
4. **Begin Stage 1** (Build infrastructure)

See [Stage 0 Guide](STAGE_0_GUIDE.md) for details.

---

## ✅ Verification Checklist

After running bootstrap:

- [ ] Controller instance running
- [ ] Can SSH to controller
- [ ] Security group allows ports 22 and 5000
- [ ] IAM role attached to instance
- [ ] Public IP assigned
- [ ] Configuration file saved
- [ ] SSH key file exists and has correct permissions

---

## 🆘 Support

**Common Issues:**
- AWS credentials not configured: Run `aws configure`
- Permission denied: Add EC2/IAM permissions to your AWS user
- Key already exists: Delete old key or use different name
- Can't access dashboard: Check security group rules

**Files:**
- Configuration: `~/.arena-<stack-name>.conf`
- SSH Key: `~/.ssh/<key-name>.pem`
- Launch script: `arena.bootstrap.launch.bot.sh`
- Destroy script: `arena.bootstrap.destroy.bot.sh`

---

**Bootstrap Stage Complete → Continue to Stage 0 (Control Plane)**
