# EC2 GPU Deployment Guide for Seed-VC

This guide provides step-by-step instructions for deploying the Seed-VC voice conversion application on AWS EC2 with GPU support using Docker.

## Prerequisites

- AWS Account with appropriate permissions
- Basic familiarity with AWS Console
- SSH client installed on your local machine

## Table of Contents

1. [Launch EC2 GPU Instance](#1-launch-ec2-gpu-instance)
2. [Connect to Your Instance](#2-connect-to-your-instance)
3. [Install Docker and NVIDIA Container Toolkit](#3-install-docker-and-nvidia-container-toolkit)
4. [Deploy the Application](#4-deploy-the-application)
5. [Access the Application](#5-access-the-application)
6. [Troubleshooting](#6-troubleshooting)
7. [Cost Optimization](#7-cost-optimization)

---

## 1. Launch EC2 GPU Instance

### Step 1.1: Navigate to EC2 Dashboard

1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Search for "EC2" in the top search bar
3. Click on **EC2** to open the EC2 Dashboard

### Step 1.2: Launch Instance

1. Click the **Launch Instance** button (orange button in top right)
2. Configure the following settings:

#### Name and Tags
- **Name**: `seed-vc-gpu` (or any name you prefer)

#### Application and OS Images (Amazon Machine Image)
- Click **Browse more AMIs**
- Search for: `Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)`
- Select the latest version (this comes with NVIDIA drivers pre-installed)
- **Alternative**: Use `Ubuntu Server 22.04 LTS` (you'll need to install NVIDIA drivers manually)

#### Instance Type
Choose a GPU instance type based on your budget and performance needs:

| Instance Type | vCPUs | GPU | GPU Memory | RAM | Cost (approx/hr) | Recommended For |
|--------------|-------|-----|------------|-----|------------------|-----------------|
| g4dn.xlarge  | 4     | 1x T4 | 16 GB    | 16 GB | $0.526 | Testing/Development |
| g4dn.2xlarge | 8     | 1x T4 | 16 GB    | 32 GB | $0.752 | Production (Small) |
| g5.xlarge    | 4     | 1x A10G | 24 GB  | 16 GB | $1.006 | Production (Better) |
| g5.2xlarge   | 8     | 1x A10G | 24 GB  | 32 GB | $1.212 | Production (Recommended) |

**Recommendation**: Start with **g4dn.xlarge** for testing, then upgrade to **g5.2xlarge** for production.

#### Key Pair (login)
- Click **Create new key pair**
- **Key pair name**: `seed-vc-key`
- **Key pair type**: RSA
- **Private key file format**: `.pem` (for Mac/Linux) or `.ppk` (for Windows with PuTTY)
- Click **Create key pair** - this will download the key file
- **IMPORTANT**: Save this file securely! You cannot download it again.

#### Network Settings
- Click **Edit** on Network settings
- **Auto-assign public IP**: Enable
- **Firewall (security groups)**: Create security group
  - **Security group name**: `seed-vc-sg`
  - **Description**: Security group for Seed-VC application
  
Configure the following rules:

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| SSH | TCP | 22 | My IP | SSH access |
| Custom TCP | TCP | 7860 | My IP | Gradio Web UI |

**Security Note**: Using "My IP" is more secure. If you need to access from anywhere, use `0.0.0.0/0` but be aware of security implications.

#### Configure Storage
- **Size**: At least **50 GB** (recommended: **100 GB**)
- **Volume Type**: gp3 (General Purpose SSD)
- Models will be downloaded at runtime and can be large

#### Advanced Details (Optional but Recommended)
- Scroll down to **Advanced details**
- **Termination protection**: Enable (prevents accidental termination)

### Step 1.3: Launch

1. Review your configuration in the **Summary** panel on the right
2. Click **Launch instance**
3. Wait for the instance to reach **Running** state (takes 1-2 minutes)

---

## 2. Connect to Your Instance

### Step 2.1: Get Instance Details

1. In EC2 Dashboard, click **Instances** in the left sidebar
2. Select your `seed-vc-gpu` instance
3. Note the **Public IPv4 address** (e.g., `54.123.45.67`)

### Step 2.2: Set Key Permissions (Mac/Linux)

```bash
chmod 400 ~/Downloads/vc.pem
```

### Step 2.3: SSH into Instance

```bash
ssh -i ~/Downloads/vc.pem ubuntu@YOUR_INSTANCE_PUBLIC_IP
```

Type `yes` when prompted to accept the host key.

---

## 3. Install Docker and NVIDIA Container Toolkit

**Quick Setup Option**: You can run the automated setup script instead of following the manual steps below:

```bash
# Download and run the setup script
wget https://raw.githubusercontent.com/patrickquigley102/vc/main/setup-ec2.sh
chmod +x setup-ec2.sh
./setup-ec2.sh
```

After the script completes, skip to [Section 4: Deploy the Application](#4-deploy-the-application).

**Manual Setup Option**: Follow the steps below if you prefer to install components manually.

### Step 3.1: Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Step 3.2: Install Docker

```bash
# Install Docker dependencies
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group (to run docker without sudo)
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker
```

### Step 3.3: Verify Docker Installation

```bash
docker --version
docker compose version
```

### Step 3.4: Install NVIDIA Container Toolkit

**Note**: If you used the Deep Learning AMI, NVIDIA drivers are already installed. Otherwise, install them first.

```bash
# Configure the repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Use the generic deb repository
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install NVIDIA Container Toolkit
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Step 3.5: Verify GPU Access

```bash
# Check NVIDIA driver
nvidia-smi

# Test GPU in Docker
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi
```

You should see your GPU information displayed.

---

## 4. Deploy the Application

### Step 4.1: Clone the Repository

```bash
cd ~
git clone https://github.com/patrickquigley102/vc.git
cd vc
```

### Step 4.2: Build the Docker Image

```bash
docker build -t seed-vc:latest .
```

This will take 10-15 minutes as it downloads and installs all dependencies.

### Step 4.3: Run the Container

**Option A: Using Docker Compose (Recommended)**

```bash
docker compose up -d
```

**Option B: Using Docker Run**

```bash
docker run -d \
  --name seed-vc \
  --gpus all \
  -p 7860:7860 \
  -v $(pwd)/checkpoints:/app/checkpoints \
  -v $(pwd)/examples:/app/examples \
  --shm-size 8g \
  --restart unless-stopped \
  seed-vc:latest
```

### Step 4.4: Check Container Status

```bash
# View running containers
docker ps

# View logs
docker logs -f seed-vc
```

Wait for the message indicating the Gradio server is running. The first run will download model checkpoints (this can take 5-10 minutes depending on your internet speed).

You should see output like:
```
Running on local URL:  http://0.0.0.0:7860
```

---

## 5. Access the Application

### Step 5.1: Open in Browser

Open your web browser and navigate to:
```
http://YOUR_INSTANCE_PUBLIC_IP:7860
```

Replace `YOUR_INSTANCE_PUBLIC_IP` with your EC2 instance's public IP address.

### Step 5.2: Using the Application

1. You'll see the Seed Voice Conversion interface with two tabs:
   - **V1**: Voice & Singing Voice Conversion
   - **V2**: Voice & Style Conversion

2. Upload your audio files:
   - **Source Audio**: The voice you want to convert
   - **Reference Audio**: The target voice to convert to

3. Adjust parameters as needed (defaults work well for most cases)

4. Click **Submit** and wait for the conversion to complete

### Step 5.3: Test with Examples

The application includes example audio files in the `examples/` directory. You can use these to test the system before uploading your own files.

---

## 5A. Command-Line Inference (Alternative to Web UI)

If you prefer to run voice conversion via command line instead of the Gradio web interface, you have two options:

### Option 1: Using the Helper Script (Recommended)

The repository includes `docker-convert.sh` which simplifies running inference:

```bash
# Basic usage
./docker-convert.sh -s source.mp3 -t reference.mp3

# With custom parameters
./docker-convert.sh \
  -s ./audio/source.mp3 \
  -t ./audio/reference.mp3 \
  -o ./output \
  -d 30 \
  --intelligibility 0.75 \
  --similarity 0.75 \
  --top-p 0.9 \
  --temperature 0.9
```

**Available Options:**
- `-s, --source FILE`: Source audio file to convert (required)
- `-t, --target FILE`: Reference audio file (required)
- `-o, --output DIR`: Output directory (default: ./output)
- `-d, --diffusion N`: Diffusion steps (default: 8)
- `-l, --length-adjust N`: Length adjustment (default: 1.0)
- `--intelligibility N`: Intelligibility CFG rate (default: 0.75)
- `--similarity N`: Similarity CFG rate (default: 0.75)
- `--convert-style BOOL`: Convert style/emotion/accent (default: false)
- `--anonymization BOOL`: Anonymization only (default: false)
- `--top-p N`: Top-p sampling (default: 0.9)
- `--temperature N`: Temperature (default: 0.9)
- `--repetition-penalty N`: Repetition penalty (default: 1.1)

### Option 2: Direct Docker Command

Run inference directly using the Docker container:

```bash
# Create directories for your audio files
mkdir -p input output

# Copy your files to the input directory
cp your_source.mp3 input/
cp your_reference.mp3 input/

# Run inference
docker run --rm \
  --gpus all \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  seed-vc:latest \
  python3 inference_v2.py \
    --source /input/your_source.mp3 \
    --target /input/your_reference.mp3 \
    --output /output \
    --diffusion-steps 8 \
    --length-adjust 1.0 \
    --intelligibility-cfg-rate 0.75 \
    --similarity-cfg-rate 0.75 \
    --convert-style false \
    --anonymization-only false \
    --top-p 0.9 \
    --temperature 0.9 \
    --repetition-penalty 1.1
```

### Option 3: Modify Dockerfile for CLI-Only Deployment

If you only need command-line inference and want to skip the Gradio UI entirely, modify the Dockerfile:

```dockerfile
# Change the CMD line at the end of the Dockerfile from:
CMD ["python3", "app.py", "--enable-v1", "--enable-v2"]

# To:
CMD ["tail", "-f", "/dev/null"]
```

Then rebuild and run:

```bash
docker compose down
docker compose build
docker compose up -d

# Now run inference commands
docker exec seed-vc python3 inference_v2.py \
  --source /path/to/source.mp3 \
  --target /path/to/reference.mp3 \
  --output /output \
  --diffusion-steps 8 \
  --length-adjust 1.0 \
  --intelligibility-cfg-rate 0.75 \
  --similarity-cfg-rate 0.75 \
  --convert-style false \
  --anonymization-only false \
  --top-p 0.9 \
  --temperature 0.9 \
  --repetition-penalty 1.1
```

### Using V1 Model (inference.py)

For V1 model inference:

```bash
docker run --rm \
  --gpus all \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  seed-vc:latest \
  python3 inference.py \
    --source /input/source.wav \
    --target /input/reference.wav \
    --output /output \
    --diffusion-steps 25 \
    --length-adjust 1.0 \
    --inference-cfg-rate 0.7 \
    --f0-condition False \
    --auto-f0-adjust False \
    --semi-tone-shift 0 \
    --fp16 True
```

---

## 6. Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker logs seed-vc

# Check if port is already in use
sudo netstat -tulpn | grep 7860

# Restart container
docker restart seed-vc
```

### GPU Not Detected

```bash
# Verify NVIDIA driver
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi

# Restart Docker daemon
sudo systemctl restart docker
```

### Out of Memory Errors

```bash
# Check GPU memory usage
nvidia-smi

# Increase shared memory
docker stop seed-vc
docker rm seed-vc

# Run with more shared memory
docker run -d \
  --name seed-vc \
  --gpus all \
  -p 7860:7860 \
  --shm-size 16g \
  --restart unless-stopped \
  seed-vc:latest
```

### Cannot Access Web UI

1. **Check Security Group**:
   - Go to EC2 Console > Security Groups
   - Select `seed-vc-sg`
   - Verify port 7860 is open to your IP

2. **Check Container Status**:
   ```bash
   docker ps
   docker logs seed-vc
   ```

3. **Test Local Access**:
   ```bash
   curl http://localhost:7860
   ```

### Model Download Issues

If you're in a region with restricted access to Hugging Face:

```bash
# Set Hugging Face mirror
docker stop seed-vc
docker rm seed-vc

docker run -d \
  --name seed-vc \
  --gpus all \
  -p 7860:7860 \
  -e HF_ENDPOINT=https://hf-mirror.com \
  --shm-size 8g \
  --restart unless-stopped \
  seed-vc:latest
```

---

## 7. Cost Optimization

### Stop Instance When Not in Use

```bash
# From your local machine
aws ec2 stop-instances --instance-ids YOUR_INSTANCE_ID
```

Or use the AWS Console:
1. Go to EC2 Dashboard > Instances
2. Select your instance
3. Click **Instance state** > **Stop instance**

**Note**: You only pay for compute when the instance is running, but you still pay for storage.

### Use Spot Instances

For non-critical workloads, consider using Spot Instances to save up to 70%:
1. When launching, expand **Advanced details**
2. **Purchasing option**: Request Spot instances
3. Set your maximum price

**Warning**: Spot instances can be terminated by AWS with 2-minute notice.

### Set Up Auto-Shutdown

Create a cron job to automatically stop the instance at night:

```bash
# Edit crontab
crontab -e

# Add this line to stop instance at 11 PM daily (adjust timezone as needed)
0 23 * * * sudo shutdown -h now
```

### Monitor Costs

1. Go to AWS Console > Billing Dashboard
2. Set up billing alerts for your account
3. Monitor EC2 costs regularly

---

## Additional Commands

### Update Application

```bash
cd ~/vc
git pull
docker compose down
docker compose build
docker compose up -d
```

### View Real-time Logs

```bash
docker logs -f seed-vc
```

### Access Container Shell

```bash
docker exec -it seed-vc bash
```

### Clean Up Everything

```bash
# Stop and remove container
docker compose down

# Remove image
docker rmi seed-vc:latest

# Remove downloaded models (optional)
rm -rf checkpoints/
```

### Backup Model Checkpoints

```bash
# Create backup
tar -czf seed-vc-checkpoints-$(date +%Y%m%d).tar.gz checkpoints/

# Download to local machine (run from local terminal)
scp -i ~/Downloads/seed-vc-key.pem ubuntu@YOUR_INSTANCE_PUBLIC_IP:~/vc/seed-vc-checkpoints-*.tar.gz ~/Downloads/
```

---

## Security Best Practices

1. **Restrict SSH Access**: Only allow SSH from your IP address
2. **Restrict Web UI Access**: Only allow port 7860 from trusted IPs
3. **Use HTTPS**: For production, set up a reverse proxy with SSL (nginx + Let's Encrypt)
4. **Regular Updates**: Keep your system and Docker images updated
5. **Enable CloudWatch**: Monitor instance metrics and set up alarms
6. **Use IAM Roles**: Instead of storing AWS credentials on the instance

---

## Performance Tuning

### For Better Performance

1. **Use Larger Instance**: Upgrade to g5.2xlarge or higher
2. **Enable Compilation**: Modify the CMD in Dockerfile to include `--compile` flag
3. **Adjust Diffusion Steps**: Lower steps = faster inference (but lower quality)

### Modify Default Settings

Edit the Dockerfile and change the CMD line:

```dockerfile
# For V1 only (faster startup)
CMD ["python3", "app.py", "--enable-v1"]

# For V2 with compilation (faster inference)
CMD ["python3", "app.py", "--enable-v2", "--compile"]
```

Then rebuild:
```bash
docker compose down
docker compose build
docker compose up -d
```

---

## Support

- **Project Repository**: https://github.com/patrickquigley102/vc
- **Original Seed-VC**: https://github.com/Plachtaa/seed-vc
- **AWS Documentation**: https://docs.aws.amazon.com/ec2/

---

## Quick Reference

### Essential Commands

```bash
# Start application
docker compose up -d

# Stop application
docker compose down

# View logs
docker logs -f seed-vc

# Restart application
docker restart seed-vc

# Check GPU usage
nvidia-smi

# Check disk space
df -h
```

### Important Ports

- **7860**: Gradio Web UI
- **22**: SSH

### Important Directories

- `/home/ubuntu/vc`: Application directory
- `/home/ubuntu/vc/checkpoints`: Model checkpoints
- `/home/ubuntu/vc/examples`: Example audio files

---

**Congratulations!** You now have Seed-VC running on AWS EC2 with GPU support. Enjoy voice conversion! 🎤
