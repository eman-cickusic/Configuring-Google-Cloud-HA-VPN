# Google Cloud HA VPN Configuration Variables
# Copy this file and customize the values for your environment

# Project Configuration
export PROJECT_ID="your-project-id-here"

# Regional Configuration
export REGION_1="us-central1"
export REGION_2="us-west1"

# Zone Configuration
export ZONE_1="us-central1-a"
export ZONE_2="us-west1-a"

# VPN Configuration
export SHARED_SECRET="your-secure-shared-secret-here"

# Network CIDR Ranges
export VPC_DEMO_SUBNET1_CIDR="10.1.1.0/24"
export VPC_DEMO_SUBNET2_CIDR="10.2.1.0/24"
export ON_PREM_SUBNET1_CIDR="192.168.1.0/24"

# BGP Configuration
export VPC_DEMO_ASN="65001"
export ON_PREM_ASN="65002"

# BGP IP Addresses for Tunnel Interfaces
export VPC_DEMO_TUNNEL0_IP="169.254.0.1"
export ON_PREM_TUNNEL0_IP="169.254.0.2"
export VPC_DEMO_TUNNEL1_IP="169.254.1.1"
export ON_PREM_TUNNEL1_IP="169.254.1.2"

# Instance Configuration
export INSTANCE_MACHINE_TYPE="e2-medium"

# Networking Configuration
export BGP_ROUTING_MODE="GLOBAL"

# Security Configuration
# NOTE: In production, use a strong, randomly generated shared secret
# Example: openssl rand -base64 32
# export SHARED_SECRET=$(openssl rand -base64 32)
