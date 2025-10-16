# Arena Bootstrap

**Infrastructure Management for HACKERverse® Arena Controller**

[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20VPC%20%7C%20IAM-orange)](https://aws.amazon.com)
[![Shell](https://img.shields.io/badge/Shell-Bash-green)](https://www.gnu.org/software/bash/)
[![Stage](https://img.shields.io/badge/Stage-Bootstrap-blue)](https://github.com)

## What is This?

**Arena Bootstrap** runs on **your local machine** (Mac/Linux/Windows WSL) to create and destroy the Arena Controller EC2 instance in AWS.

```
Your Laptop/Desktop → AWS → Arena Controller Instance
```

This is the **first step** in setting up a HACKERverse® cybersecurity training arena.

## Quick Start

### 1. Clone This Repository

```bash
git clone https://github.com/PROOFregister/bootstrap.git
cd bootstrap
```

### 2. Launch Arena Controller

```bash
chmod +x arena.bootstrap.launch.bot.sh
./arena.bootstrap.launch.bot.sh
```

Follow the prompts to create your Arena Controller.

### 3. SSH to Controller

```bash
ssh -i ~/.ssh/arena-key.pem ec2-user@<PUBLIC-IP>
```

### 4. Install Stage 0

```bash
# On the Arena Controller
curl -sSL https://raw.githubusercontent.com/YOUR-ORG/arena.control/main/arena.control.install.bot.sh | bash
```

### 5. Destroy When Done

```bash
# Back on your local machine
./arena.bootstrap.destroy.bot.sh
```

## What's in This Repository?

| File | Purpose |
|------|---------|
| `arena.bootstrap.launch.bot.sh` | Creates Arena Controller infrastructure |
| `arena.bootstrap.destroy.bot.sh` | Destroys all resources |
| `arena.bootstrap.prepare-github.bot.sh` | Prepares files for GitHub distribution |
| `README.md` | This file |
| `QUICKSTART.md` | 5-minute setup guide |
| `GUIDE.md` | Complete documentation |

## Prerequisites

- **AWS CLI** installed and configured
  ```bash
  aws --version
  aws configure
  ```

- **AWS Account** with permissions for EC2, VPC, and IAM

- **Operating System**: macOS, Linux, or Windows WSL

## What Gets Created?

The launch script creates:

- ✅ Isolated VPC (10.99.0.0/16)
- ✅ Public subnet (10.99.1.0/24)
- ✅ Internet Gateway
- ✅ Security Group (ports 22, 5000)
- ✅ IAM Role for EC2
- ✅ Arena Controller EC2 instance (t3.medium)
- ✅ SSH key pair

**Cost:** ~$0.043/hour (~$1.03/day, ~$31/month)

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Get running in 5 minutes
- **[GUIDE.md](GUIDE.md)** - Complete step-by-step guide with troubleshooting

## Support

**Issues:** https://github.com/YOUR-ORG/arena.bootstrap/issues

**Questions?** See [GUIDE.md](GUIDE.md) for detailed documentation.

## Next Steps

After launching the Arena Controller:

1. **SSH to the controller** using the provided IP address
2. **Install Stage 0** (Control Plane) from GitHub
3. **Start dashboards** to monitor operations
4. **Build target infrastructure** (Stage 1)
5. **Execute attack campaigns** (Stage 2)

See the [arena.control](https://github.com/YOUR-ORG/arena.control) repository for Stage 0 documentation.

## Safety Warning

⚠️ **FOR ISOLATED TRAINING LAB USE ONLY**

This tool creates AWS infrastructure for cybersecurity training. Only use in:
- Isolated AWS accounts
- Authorized training environments
- With proper security controls

Never use against production systems or without authorization.

## License

Training and educational purposes only. See [LICENSE](LICENSE) for full terms.

---

**Arena Bootstrap** - Infrastructure Management Layer  
Part of the HACKERverse® Cybersecurity Training Platform  
Version 1.0 | October 2025
