# Azure-Windows-Infra
Creation of Azure Resources using Terraform IAC (HCL)

# Terraform
This is an open-source tool created by HarshiCorp. It is used to create and provision infrastructure on various cloud platforms. It is cloud-agnostic tool in that it is not created just for a specific cloud platform. It is able to create resources on various cloud platforms using API plugins from these platformers known as providers. Some of these providers include:

AWS Provider ( hashicorp/terraform-provider-aws )
Azure Provider ( hashicorp/terraform-provider-azurerm )
Google Cloud Provider ( hashicorp/terraform-provider-google )
Kubernetes Provider ( hashicorp/terraform-provider-kubernetes ) and lots more...
for this project we used Azure and as such worked with the Azure Provider

# Azure
This is Microsoft Cloud Platform. It was used as the cloud provider for our project.

# Project Description
Our project assumes we are deploying a simple creating resources for a simple web server(IIS) running on a Windows Virtual Machine.

Some of the resources created include:

A Resource Group
A Virtual Network
A Virtual Machine
A Key Vault
A Storage Account
A Storage Container
A VM Extension; to run our Custom Powershell Script

### Please Note: You would be required to input your own Azure Account Credentials as variables.
