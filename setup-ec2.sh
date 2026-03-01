#!/bin/bash

# EC2 Setup Script for Seed-VC with Docker and NVIDIA GPU Support
# This script automates the installation of Docker and NVIDIA Container Toolkit

set -e  # Exit on any error

echo "=========================================="
echo "Seed-VC EC2 Setup Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Step 1: Update System
print_info "Step 1: Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y
print_success "System updated successfully"
echo ""

# Step 2: Install Docker
print_info "Step 2: Installing Docker..."

# Install Docker dependencies
print_info "Installing Docker dependencies..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
print_info "Adding Docker GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
print_info "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
print_info "Installing Docker Engine..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
print_info "Adding user to docker group..."
sudo usermod -aG docker $USER

print_success "Docker installed successfully"
echo ""

# Step 3: Verify Docker Installation
print_info "Step 3: Verifying Docker installation..."
docker --version
docker compose version
print_success "Docker verification complete"
echo ""

# Step 4: Install NVIDIA Container Toolkit
print_info "Step 4: Installing NVIDIA Container Toolkit..."

# Configure the repository
print_info "Configuring NVIDIA Container Toolkit repository..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Use the generic deb repository
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install NVIDIA Container Toolkit
print_info "Installing NVIDIA Container Toolkit..."
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
print_info "Configuring Docker to use NVIDIA runtime..."
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

print_success "NVIDIA Container Toolkit installed successfully"
echo ""

# Step 5: Verify GPU Access
print_info "Step 5: Verifying GPU access..."
echo ""
print_info "Checking NVIDIA driver..."
nvidia-smi
echo ""

print_info "Testing GPU in Docker..."
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi

print_success "GPU verification complete"
echo ""

# Final message
echo "=========================================="
print_success "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Log out and log back in (or run 'newgrp docker') to apply docker group changes"
echo "2. Clone the repository: git clone https://github.com/patrickquigley102/vc.git"
echo "3. Navigate to the directory: cd vc"
echo "4. Build and run: docker compose up -d"
echo ""
print_info "Note: You may need to start a new shell session for docker group changes to take effect"
