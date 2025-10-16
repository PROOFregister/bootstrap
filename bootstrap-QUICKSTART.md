# Arena Bootstrap - Quick Start

**Get your Arena Controller running in 5 minutes**

## Prerequisites Check

Before starting, verify you have:

```bash
# AWS CLI installed?
aws --version

# AWS credentials configured?
aws sts get-caller-identity

# jq installed? (JSON processor)
jq --version
```

If any command fails, see [GUIDE.md](GUIDE.md) for installation instructions.

## Step 1: Clone Repository

```bash
git clone https://github.com/YOUR-ORG/arena.bootstrap.git
cd arena.bootstrap
```

## Step 2: Launch Arena Controller

```bash
chmod +x arena.bootstrap.launch.bot.sh
./arena.bootstrap.launch.bot.sh
```

### Interactive Prompts

```
Enter stack name [arena-controller]: ↵
Enter key pair name [arena-key]: ↵
Enter instance type [t3.medium]: ↵
```

**Tip:** Press Enter to accept defaults, or type custom values.

### What Happens Next

The script will:
1. ✓ Find the latest Amazon Linux 2023 AMI
2. ✓ Create or verify SSH key pair
3. ✓ Create isolated VPC and subnet
4. ✓ Create Internet Gateway
5. ✓ Create security group
6. ✓ Create IAM role for EC2
7. ✓ Launch EC2 instance
8. ✓ Save configuration

**Time:** ~2-3 minutes

### Expected Output

```
╔════════════════════════════════════════════════════════════╗
║                   LAUNCH COMPLETE!                         ║
╚════════════════════════════════════════════════════════════╝

✓ Arena Controller Created Successfully!

Connection Details:
  Instance ID:  i-0abc123def456789
  Public IP:    54.123.45.67
  SSH Command:  ssh -i ~/.ssh/arena-key.pem ec2-user@54.123.45.67
  Dashboard:    http://54.123.45.67:5000
  
Configuration saved to: ~/.arena-arena-controller.conf

Next Steps:
  1. SSH to controller
  2. Install Stage 0 from GitHub
  3. Start dashboards
```

## Step 3: SSH to Controller

```bash
# Copy the SSH command from output above
ssh -i ~/.ssh/arena-key.pem ec2-user@54.123.45.67
```

**Note:** Replace `54.123.45.67` with your actual IP address.

### First Time SSH?

You may see:
```
The authenticity of host '54.123.45.67' can't be established.
Are you sure you want to continue connecting (yes/no)? 
```

Type `yes` and press Enter.

## Step 4: Install Stage 0 (Control Plane)

Now you're on the Arena Controller. Install the control plane:

```bash
curl -sSL https://raw.githubusercontent.com/YOUR-ORG/arena.control/main/arena.control.install.bot.sh | bash
```

**Time:** ~1 minute

**What gets installed:**
- `/arena/bots/` - Control plane scripts
- `/arena/logs/` - Log files
- `/arena/config/` - Configuration files

## Step 5: Start Dashboards

```bash
cd /arena/bots
./arena.control.ui-launch.bot.sh
```

**Opens two dashboards:**
- Port 5000: Main dashboard
- Port 5001: CLI monitor

## Step 6: Access Dashboard

Open your browser:
```
http://54.123.45.67:5000
```

You should see the HACKERverse® dashboard!

## Step 7: Build Infrastructure (Optional)

To continue with the full arena setup:

```bash
# On the controller
cd /arena/bots

# Generate campaign
./arena.control.campaign-generate.bot.sh

# Deploy infrastructure
./arena.control.infrastructure-deploy.bot.sh

# Discover targets
./arena.control.targets-discover.bot.sh
```

## Step 8: Cleanup When Done

**IMPORTANT:** Destroy resources to stop charges!

```bash
# Exit from controller
exit

# Back on your local machine
./arena.bootstrap.destroy.bot.sh
```

**Removes:**
- EC2 instance
- VPC and networking
- Security groups
- IAM role

**Keeps:**
- SSH key pair (manual deletion if needed)
- Configuration file (for reference)

---

## Common Issues

### Issue: "aws: command not found"

**Fix:**
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Issue: "Unable to locate credentials"

**Fix:**
```bash
aws configure
```

Enter your AWS Access Key ID and Secret Access Key.

### Issue: "Permission denied (publickey)"

**Fix:**
```bash
# Check key permissions
chmod 400 ~/.ssh/arena-key.pem

# Verify you're using the correct username
ssh -i ~/.ssh/arena-key.pem ec2-user@<PUBLIC-IP>
```

### Issue: "Connection timed out"

**Wait 30 seconds** for instance to fully boot, then try again.

If still failing:
```bash
# Check instance is running
aws ec2 describe-instances --instance-ids <instance-id>
```

### Issue: Key pair already exists

**Option 1:** Use existing key
```bash
# If you have the .pem file, continue
ls ~/.ssh/arena-key.pem
```

**Option 2:** Delete and recreate
```bash
aws ec2 delete-key-pair --key-name arena-key
rm ~/.ssh/arena-key.pem
./arena.bootstrap.launch.bot.sh
```

**Option 3:** Use different name
```bash
./arena.bootstrap.launch.bot.sh
# When prompted: arena-key-2
```

---

## Quick Command Reference

```bash
# Launch controller
./arena.bootstrap.launch.bot.sh

# SSH to controller
ssh -i ~/.ssh/arena-key.pem ec2-user@<PUBLIC-IP>

# Install Stage 0 (on controller)
curl -sSL https://raw.githubusercontent.com/YOUR-ORG/arena.control/main/arena.control.install.bot.sh | bash

# Start dashboards (on controller)
cd /arena/bots && ./arena.control.ui-launch.bot.sh

# Access dashboard
# Browser: http://<PUBLIC-IP>:5000

# Destroy everything (on local machine)
./arena.bootstrap.destroy.bot.sh

# View configuration
cat ~/.arena-arena-controller.conf

# Stop instance (save costs)
aws ec2 stop-instances --instance-ids <instance-id>

# Start instance
aws ec2 start-instances --instance-ids <instance-id>
```

---

## Cost Information

**Hourly:** ~$0.043  
**Daily:** ~$1.03  
**Monthly:** ~$31.00  

**Tip:** Run `./arena.bootstrap.destroy.bot.sh` when not in use to stop all charges.

---

## What's Next?

After completing this quick start:

1. **Learn Stage 0** - See [arena.control](https://github.com/YOUR-ORG/arena.control) repository
2. **Build Targets** - Deploy Windows/Linux target infrastructure
3. **Run Campaigns** - Execute automated attack scenarios
4. **Review Logs** - Analyze security events and detections

For detailed documentation, see [GUIDE.md](GUIDE.md)

---

**Quick Start Complete!** 🎉

You now have a running Arena Controller ready for cybersecurity training.
