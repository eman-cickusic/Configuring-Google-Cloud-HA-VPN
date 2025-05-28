#!/bin/bash

# Google Cloud HA VPN Setup Script
# This script automates the complete setup of HA VPN between two VPC networks

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Source environment variables
if [ -f "variables.env" ]; then
    source variables.env
    print_status "Loaded environment variables from variables.env"
else
    print_warning "variables.env not found, using default values"
    # Default values
    export PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project)}
    export REGION_1=${REGION_1:-"us-central1"}
    export REGION_2=${REGION_2:-"us-west1"}
    export ZONE_1=${ZONE_1:-"us-central1-a"}
    export ZONE_2=${ZONE_2:-"us-west1-a"}
    export SHARED_SECRET=${SHARED_SECRET:-"mysharedsecret123"}
fi

print_status "Starting HA VPN setup for project: $PROJECT_ID"
print_status "Regions: $REGION_1, $REGION_2"
print_status "Zones: $ZONE_1, $ZONE_2"

# Set the project
gcloud config set project $PROJECT_ID

print_status "=== STEP 1: Creating VPC Networks ==="

# Create vpc-demo network
print_status "Creating vpc-demo network..."
gcloud compute networks create vpc-demo --subnet-mode custom

# Create subnets for vpc-demo
print_status "Creating vpc-demo subnets..."
gcloud compute networks subnets create vpc-demo-subnet1 \
  --network vpc-demo \
  --range 10.1.1.0/24 \
  --region $REGION_1

gcloud compute networks subnets create vpc-demo-subnet2 \
  --network vpc-demo \
  --range 10.2.1.0/24 \
  --region $REGION_2

# Create on-prem network
print_status "Creating on-prem network..."
gcloud compute networks create on-prem --subnet-mode custom

# Create subnet for on-prem
print_status "Creating on-prem subnet..."
gcloud compute networks subnets create on-prem-subnet1 \
  --network on-prem \
  --range 192.168.1.0/24 \
  --region $REGION_1

print_status "=== STEP 2: Creating Firewall Rules ==="

# Firewall rules for vpc-demo
print_status "Creating firewall rules for vpc-demo..."
gcloud compute firewall-rules create vpc-demo-allow-custom \
  --network vpc-demo \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --source-ranges 10.0.0.0/8

gcloud compute firewall-rules create vpc-demo-allow-ssh-icmp \
  --network vpc-demo \
  --allow tcp:22,icmp

# Firewall rules for on-prem
print_status "Creating firewall rules for on-prem..."
gcloud compute firewall-rules create on-prem-allow-custom \
  --network on-prem \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --source-ranges 192.168.0.0/16

gcloud compute firewall-rules create on-prem-allow-ssh-icmp \
  --network on-prem \
  --allow tcp:22,icmp

print_status "=== STEP 3: Creating VM Instances ==="

# Create instances in vpc-demo
print_status "Creating vpc-demo instances..."
gcloud compute instances create vpc-demo-instance1 \
  --machine-type=e2-medium \
  --zone $ZONE_1 \
  --subnet vpc-demo-subnet1

gcloud compute instances create vpc-demo-instance2 \
  --machine-type=e2-medium \
  --zone $ZONE_2 \
  --subnet vpc-demo-subnet2

# Create instance in on-prem
print_status "Creating on-prem instance..."
gcloud compute instances create on-prem-instance1 \
  --machine-type=e2-medium \
  --zone $ZONE_1 \
  --subnet on-prem-subnet1

print_status "=== STEP 4: Creating HA VPN Gateways ==="

# Create HA VPN gateways
print_status "Creating HA VPN gateway for vpc-demo..."
gcloud compute vpn-gateways create vpc-demo-vpn-gw1 \
  --network vpc-demo \
  --region $REGION_1

print_status "Creating HA VPN gateway for on-prem..."
gcloud compute vpn-gateways create on-prem-vpn-gw1 \
  --network on-prem \
  --region $REGION_1

# Get gateway details
print_status "VPN Gateway Details:"
gcloud compute vpn-gateways describe vpc-demo-vpn-gw1 --region $REGION_1
gcloud compute vpn-gateways describe on-prem-vpn-gw1 --region $REGION_1

print_status "=== STEP 5: Creating Cloud Routers ==="

# Create cloud routers
print_status "Creating cloud router for vpc-demo..."
gcloud compute routers create vpc-demo-router1 \
  --region $REGION_1 \
  --network vpc-demo \
  --asn 65001

print_status "Creating cloud router for on-prem..."
gcloud compute routers create on-prem-router1 \
  --region $REGION_1 \
  --network on-prem \
  --asn 65002

print_status "=== STEP 6: Creating VPN Tunnels ==="

# Create VPN tunnels for vpc-demo
print_status "Creating VPN tunnels for vpc-demo..."
gcloud compute vpn-tunnels create vpc-demo-tunnel0 \
  --peer-gcp-gateway on-prem-vpn-gw1 \
  --region $REGION_1 \
  --ike-version 2 \
  --shared-secret $SHARED_SECRET \
  --router vpc-demo-router1 \
  --vpn-gateway vpc-demo-vpn-gw1 \
  --interface 0

gcloud compute vpn-tunnels create vpc-demo-tunnel1 \
  --peer-gcp-gateway on-prem-vpn-gw1 \
  --region $REGION_1 \
  --ike-version 2 \
  --shared-secret $SHARED_SECRET \
  --router vpc-demo-router1 \
  --vpn-gateway vpc-demo-vpn-gw1 \
  --interface 1

# Create VPN tunnels for on-prem
print_status "Creating VPN tunnels for on-prem..."
gcloud compute vpn-tunnels create on-prem-tunnel0 \
  --peer-gcp-gateway vpc-demo-vpn-gw1 \
  --region $REGION_1 \
  --ike-version 2 \
  --shared-secret $SHARED_SECRET \
  --router on-prem-router1 \
  --vpn-gateway on-prem-vpn-gw1 \
  --interface 0

gcloud compute vpn-tunnels create on-prem-tunnel1 \
  --peer-gcp-gateway vpc-demo-vpn-gw1 \
  --region $REGION_1 \
  --ike-version 2 \
  --shared-secret $SHARED_SECRET \
  --router on-prem-router1 \
  --vpn-gateway on-prem-vpn-gw1 \
  --interface 1

print_status "=== STEP 7: Configuring BGP Peering ==="

# BGP configuration for vpc-demo
print_status "Configuring BGP for vpc-demo tunnels..."

# Tunnel 0
gcloud compute routers add-interface vpc-demo-router1 \
  --interface-name if-tunnel0-to-on-prem \
  --ip-address 169.254.0.1 \
  --mask-length 30 \
  --vpn-tunnel vpc-demo-tunnel0 \
  --region $REGION_1

gcloud compute routers add-bgp-peer vpc-demo-router1 \
  --peer-name bgp-on-prem-tunnel0 \
  --interface if-tunnel0-to-on-prem \
  --peer-ip-address 169.254.0.2 \
  --peer-asn 65002 \
  --region $REGION_1

# Tunnel 1
gcloud compute routers add-interface vpc-demo-router1 \
  --interface-name if-tunnel1-to-on-prem \
  --ip-address 169.254.1.1 \
  --mask-length 30 \
  --vpn-tunnel vpc-demo-tunnel1 \
  --region $REGION_1

gcloud compute routers add-bgp-peer vpc-demo-router1 \
  --peer-name bgp-on-prem-tunnel1 \
  --interface if-tunnel1-to-on-prem \
  --peer-ip-address 169.254.1.2 \
  --peer-asn 65002 \
  --region $REGION_1

# BGP configuration for on-prem
print_status "Configuring BGP for on-prem tunnels..."

# Tunnel 0
gcloud compute routers add-interface on-prem-router1 \
  --interface-name if-tunnel0-to-vpc-demo \
  --ip-address 169.254.0.2 \
  --mask-length 30 \
  --vpn-tunnel on-prem-tunnel0 \
  --region $REGION_1

gcloud compute routers add-bgp-peer on-prem-router1 \
  --peer-name bgp-vpc-demo-tunnel0 \
  --interface if-tunnel0-to-vpc-demo \
  --peer-ip-address 169.254.0.1 \
  --peer-asn 65001 \
  --region $REGION_1

# Tunnel 1
gcloud compute routers add-interface on-prem-router1 \
  --interface-name if-tunnel1-to-vpc-demo \
  --ip-address 169.254.1.2 \
  --mask-length 30 \
  --vpn-tunnel on-prem-tunnel1 \
  --region $REGION_1

gcloud compute routers add-bgp-peer on-prem-router1 \
  --peer-name bgp-vpc-demo-tunnel1 \
  --interface if-tunnel1-to-vpc-demo \
  --peer-ip-address 169.254.1.1 \
  --peer-asn 65001 \
  --region $REGION_1

print_status "=== STEP 8: Configuring Cross-VPC Firewall Rules ==="

# Allow traffic between VPCs
print_status "Allowing traffic from on-prem to vpc-demo..."
gcloud compute firewall-rules create vpc-demo-allow-subnets-from-on-prem \
  --network vpc-demo \
  --allow tcp,udp,icmp \
  --source-ranges 192.168.1.0/24

print_status "Allowing traffic from vpc-demo to on-prem..."
gcloud compute firewall-rules create on-prem-allow-subnets-from-vpc-demo \
  --network on-prem \
  --allow tcp,udp,icmp \
  --source-ranges 10.1.1.0/24,10.2.1.0/24

print_status "=== STEP 9: Enabling Global Routing ==="

# Enable global routing for vpc-demo
print_status "Enabling global routing for vpc-demo..."
gcloud compute networks update vpc-demo --bgp-routing-mode GLOBAL

print_status "=== STEP 10: Verifying Configuration ==="

# Wait for tunnels to establish
print_status "Waiting for tunnels to establish (this may take a few minutes)..."
sleep 60

# Check tunnel status
print_status "Checking tunnel status..."
gcloud compute vpn-tunnels list

print_status "Checking vpc-demo-tunnel0 status..."
gcloud compute vpn-tunnels describe vpc-demo-tunnel0 --region $REGION_1 | grep detailedStatus

print_status "Checking vpc-demo-tunnel1 status..."
gcloud compute vpn-tunnels describe vpc-demo-tunnel1 --region $REGION_1 | grep detailedStatus

print_status "Checking on-prem-tunnel0 status..."
gcloud compute vpn-tunnels describe on-prem-tunnel0 --region $REGION_1 | grep detailedStatus

print_status "Checking on-prem-tunnel1 status..."
gcloud compute vpn-tunnels describe on-prem-tunnel1 --region $REGION_1 | grep detailedStatus

print_status "=== SETUP COMPLETE ==="
print_status "HA VPN setup completed successfully!"
print_status ""
print_status "Next steps:"
print_status "1. Test connectivity by running: ./test-connectivity.sh"
print_status "2. SSH into on-prem-instance1 and ping 10.1.1.2 to test VPN"
print_status "3. Test high availability by bringing down one tunnel"
print_status ""
print_status "Resources created:"
print_status "- 2 VPC networks (vpc-demo, on-prem)"
print_status "- 3 subnets (2 in vpc-demo, 1 in on-prem)"
print_status "- 3 VM instances"
print_status "- 2 HA VPN gateways"
print_status "- 2 Cloud routers"
print_status "- 4 VPN tunnels"
print_status "- 8 firewall rules"
print_status ""
print_status "To clean up all resources, run: ./cleanup.sh"
