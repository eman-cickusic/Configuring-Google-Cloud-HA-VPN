# Configuring Google Cloud HA VPN

This repository contains the complete setup for configuring Google Cloud High Availability (HA) VPN with a 99.99% SLA. The project demonstrates connecting two VPC networks through secure IPsec VPN tunnels with dynamic BGP routing.

## Video

https://youtu.be/iH3iBCfaF2A

## Overview

HA VPN is a high-availability Cloud VPN solution that securely connects your on-premises network to your VPC network through IPsec VPN connections. This implementation creates redundant tunnels across two interfaces to achieve 99.99% service availability.

### Architecture

- **VPC 1 (vpc-demo)**: Simulates a cloud environment with two subnets across different regions
- **VPC 2 (on-prem)**: Simulates an on-premises data center
- **HA VPN Gateways**: Each VPC has an HA VPN gateway with two interfaces
- **Cloud Routers**: Handle dynamic BGP routing between networks
- **VPN Tunnels**: Four tunnels total (two per gateway) for redundancy

## Prerequisites

- Google Cloud Project with billing enabled
- gcloud CLI installed and configured
- Appropriate IAM permissions for VPN and Compute resources

## Quick Start

1. Clone this repository:
   ```bash
   git clone <your-repo-url>
   cd google-cloud-ha-vpn
   ```

2. Set your project variables:
   ```bash
   export PROJECT_ID="your-project-id"
   export REGION_1="us-central1"
   export REGION_2="us-west1"
   export ZONE_1="us-central1-a"
   export ZONE_2="us-west1-a"
   export SHARED_SECRET="your-secure-shared-secret"
   ```

3. Run the complete setup:
   ```bash
   chmod +x setup-ha-vpn.sh
   ./setup-ha-vpn.sh
   ```

## Manual Step-by-Step Setup

If you prefer to run commands manually, follow these steps:

### Step 1: Create VPC Networks

```bash
# Create vpc-demo network
gcloud compute networks create vpc-demo --subnet-mode custom

# Create subnets
gcloud compute networks subnets create vpc-demo-subnet1 \
  --network vpc-demo --range 10.1.1.0/24 --region $REGION_1

gcloud compute networks subnets create vpc-demo-subnet2 \
  --network vpc-demo --range 10.2.1.0/24 --region $REGION_2

# Create on-prem network
gcloud compute networks create on-prem --subnet-mode custom

gcloud compute networks subnets create on-prem-subnet1 \
  --network on-prem --range 192.168.1.0/24 --region $REGION_1
```

### Step 2: Configure Firewall Rules

```bash
# VPC Demo firewall rules
gcloud compute firewall-rules create vpc-demo-allow-custom \
  --network vpc-demo \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --source-ranges 10.0.0.0/8

gcloud compute firewall-rules create vpc-demo-allow-ssh-icmp \
  --network vpc-demo \
  --allow tcp:22,icmp

# On-prem firewall rules
gcloud compute firewall-rules create on-prem-allow-custom \
  --network on-prem \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --source-ranges 192.168.0.0/16

gcloud compute firewall-rules create on-prem-allow-ssh-icmp \
  --network on-prem \
  --allow tcp:22,icmp
```

### Step 3: Create VM Instances

```bash
# Create instances in vpc-demo
gcloud compute instances create vpc-demo-instance1 \
  --machine-type=e2-medium --zone $ZONE_1 --subnet vpc-demo-subnet1

gcloud compute instances create vpc-demo-instance2 \
  --machine-type=e2-medium --zone $ZONE_2 --subnet vpc-demo-subnet2

# Create instance in on-prem
gcloud compute instances create on-prem-instance1 \
  --machine-type=e2-medium --zone $ZONE_1 --subnet on-prem-subnet1
```

### Step 4: Create HA VPN Gateways

```bash
# Create HA VPN gateways
gcloud compute vpn-gateways create vpc-demo-vpn-gw1 \
  --network vpc-demo --region $REGION_1

gcloud compute vpn-gateways create on-prem-vpn-gw1 \
  --network on-prem --region $REGION_1
```

### Step 5: Create Cloud Routers

```bash
# Create cloud routers with different ASNs
gcloud compute routers create vpc-demo-router1 \
  --region $REGION_1 \
  --network vpc-demo \
  --asn 65001

gcloud compute routers create on-prem-router1 \
  --region $REGION_1 \
  --network on-prem \
  --asn 65002
```

### Step 6: Create VPN Tunnels

```bash
# VPC Demo tunnels
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

# On-prem tunnels
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
```

### Step 7: Configure BGP Peering

See the complete BGP configuration commands in the `configure-bgp.sh` script.

## Testing the Configuration

### Basic Connectivity Test

1. SSH into the on-prem instance:
   ```bash
   gcloud compute ssh on-prem-instance1 --zone $ZONE_1
   ```

2. Test connectivity to vpc-demo instances:
   ```bash
   ping -c 4 10.1.1.2  # vpc-demo-instance1
   ping -c 4 10.2.1.2  # vpc-demo-instance2 (after enabling global routing)
   ```

### High Availability Test

Test the HA functionality by deliberately bringing down one tunnel:

```bash
# Delete one tunnel to test failover
gcloud compute vpn-tunnels delete vpc-demo-tunnel0 --region $REGION_1

# Verify connectivity still works through the remaining tunnel
# SSH to on-prem-instance1 and test ping again
```

## Configuration Files

- `setup-ha-vpn.sh`: Complete automated setup script
- `configure-bgp.sh`: BGP peering configuration
- `cleanup.sh`: Clean up all resources
- `test-connectivity.sh`: Automated connectivity testing
- `variables.env`: Environment variables template

## Key Features

- **High Availability**: 99.99% SLA with redundant tunnels
- **Dynamic Routing**: BGP for automatic route advertisement
- **Global Routing**: Access to resources across all regions
- **Security**: IPsec encryption for all traffic
- **Scalability**: Supports multiple tunnels and regions

## Troubleshooting

### Common Issues

1. **Tunnel Status**: Check tunnel status with:
   ```bash
   gcloud compute vpn-tunnels describe TUNNEL_NAME --region REGION
   ```

2. **BGP Status**: Verify BGP peering:
   ```bash
   gcloud compute routers describe ROUTER_NAME --region REGION
   ```

3. **Firewall Rules**: Ensure proper firewall rules are configured for inter-VPC communication

### Verification Commands

```bash
# List all VPN tunnels
gcloud compute vpn-tunnels list

# Check VPN gateway status
gcloud compute vpn-gateways list

# Verify routing mode
gcloud compute networks describe vpc-demo
```

## Cost Considerations

- HA VPN Gateway: ~$36/month per gateway
- VPN Tunnels: ~$36/month per tunnel
- Data Transfer: Varies by usage
- VM Instances: Based on machine type and usage

## Security Best Practices

1. Use strong shared secrets for tunnel authentication
2. Regularly rotate shared secrets
3. Monitor VPN tunnel status and connectivity
4. Implement proper firewall rules
5. Use least privilege access for BGP configuration

## Cleanup

To avoid ongoing charges, run the cleanup script:

```bash
./cleanup.sh
```

Or manually delete resources in reverse order of creation.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Resources

- [Google Cloud HA VPN Documentation](https://cloud.google.com/network-connectivity/docs/vpn/concepts/overview)
- [Cloud Router Documentation](https://cloud.google.com/network-connectivity/docs/router)
- [BGP Configuration Guide](https://cloud.google.com/network-connectivity/docs/router/how-to/configuring-bgp)

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Google Cloud documentation
3. Open an issue in this repository
