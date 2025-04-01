# Seafile Setup with Terraform and Docker Compose

This repository provides a Terraform configuration to automate the deployment of a Seafile server using Docker Compose on a cloud provider (e.g., AWS, GCP, or any Terraform-supported infrastructure). Seafile is an open-source, self-hosted file synchronization and sharing solution, and this setup simplifies its deployment with infrastructure-as-code principles.

## Features

- Automated provisioning of infrastructure (e.g., VM/instance) using Terraform.
- Deployment of Seafile server via Docker Compose.
- Scalable and reproducible setup for private cloud file hosting.
- Customizable configuration for Seafile and infrastructure settings.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1. **Terraform**: [Install Terraform](https://www.terraform.io/downloads.html) (version 0.14 or higher recommended).
2. **Docker**: [Install Docker](https://docs.docker.com/get-docker/) on your local machine or target server.
3. **Docker Compose**: [Install Docker Compose](https://docs.docker.com/compose/install/).
4. **AWS CLI**:  configured with credentials if deploying to the cloud provider.
5. **Git**: To clone this repository.

## Repository Structure

seafile-setup-terraform/
├── main.tf           # Main Terraform configuration
├── variables.tf      # Input variables for customization
├── terraform.tfvars  # Variable definitions (customize this)
├── README.md             # This file
└── .gitignore            # Git ignore file

## Getting Started

Follow these steps to deploy your Seafile server:

### 1. Clone the Repository

```bash
git clone https://github.com/toandinhtruong/seafile-setup-terraform.git
cd seafile-setup-terraform
```

### 2. Initialize Terraform
Initialize the Terraform working directory to download required providers:

```bash
cd terraform
terraform init
terraform plan
terraform apply --auto-approve
```

### 3. Access Seafile
Once the deployment completes, Terraform will output the public IP or domain of your Seafile server (check outputs.tf for details). Open a browser and navigate to:

http://<ec2-public-ip>

Follow the Seafile setup wizard to configure your admin account and initial settings.

### 4. Customize Seafile Configuration (Optional)
Modify the docker-compose.yml file to adjust Seafile settings, such as database credentials, storage options, or port mappings.

## Cleaning Up
To destroy the deployed infrastructure and remove all resources:

```bash
terraform destroy
```
Confirm with yes when prompted.

##Troubleshooting
Terraform Errors: Check the provider credentials and ensure the region/instance type is valid.

Docker Issues: Verify Docker is running on the target machine (systemctl status docker).

Seafile Not Accessible: Ensure security groups/firewalls allow traffic on port 80 (or your configured port).

For additional help, refer to the Seafile Docker documentation or open an issue in this repository.
