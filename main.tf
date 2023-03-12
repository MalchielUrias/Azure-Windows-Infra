terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.45.0"
    }
  }
}

# Declaring Variables
variable "storage_account_name" {
  type = string
  description = "Please enter the storage account name: "  
  default = "tfstrgmalchiel001"
}

# Configure Provider
provider "azurerm" {
  # Configuration options
  subscription_id = var.subscription_id
  client_id = var.client_id
  client_secret = var.client_secret
  tenant_id = var.tenant_id
  features {}
}

# Declaring local variables to be used within main.tf 
locals {
  resource_group = "application_grp"
  location = "North Europe"
}

# Create Resource Group
resource "azurerm_resource_group" "application_grp" {
  name     = local.resource_group
  location = local.location
}

# Datablock: To get information about an existing resource on the Azure platform
data "azurerm_client_config" "current" {}
 
# Create a Virtual Network
resource "azurerm_virtual_network" "app_network" {
  name                = "app_network"
  location            = local.location
  resource_group_name = azurerm_resource_group.application_grp.name
  address_space       = ["10.0.0.0/16"]
}

# Creating Subnet
resource "azurerm_subnet" "subnetA" {
  name                 = "subnetA"
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

# Creating Subnet for Bastion Host
resource "azurerm_subnet" "subnetBastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

# Creating Bastion Host IP
resource "azurerm_public_ip" "bastion_ip" {
  name                = "bastion-ip"
  location            = local.location
  resource_group_name = local.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [
    azurerm_resource_group.application_grp
  ]
}

# Creating Bastion Host
resource "azurerm_bastion_host" "app_bastion" {
  name                = "app-bastion"
  location            = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name                 = "bastion-configuration"
    subnet_id            = azurerm_subnet.subnetBastion.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}

# Creating a Public IP for the VM
# resource "azurerm_public_ip" "app_public_ip" {
#   name                = "app_public_ip"
#   resource_group_name = local.resource_group
#   location            = local.location
#   allocation_method   = "Static"
#   depends_on = [
#     azurerm_resource_group.application_grp
#   ]
# }

#Creating a Network Security Group
resource "azurerm_network_security_group" "app_network_sg" {
  name                = "app-network-sg"
  location            = local.location
  resource_group_name = local.resource_group

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [
    azurerm_resource_group.application_grp
  ]
}

# Creating NSG Association
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id = azurerm_subnet.subnetA.id
  network_security_group_id = azurerm_network_security_group.app_network_sg.id
  depends_on = [
    azurerm_network_security_group.app_network_sg
  ]
}

# Creating an Azure Windows VM network interface
resource "azurerm_network_interface" "app_interface" {
  name                = "app_interface"
  location            = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetA.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.subnetA 
  ]
}

resource "azurerm_network_interface" "app_interface_2" {
  name                = "app-interface-2"
  location            = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetA.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_network_interface.app_interface,
    azurerm_subnet.subnetA 
  ]
}

# Creating a Key Vault for Keys and Parameters
resource "azurerm_key_vault" "app_vault" {
  name                        = "app-vault55818168"
  location                    = local.location
  resource_group_name         = local.resource_group
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set", 
    ]

    storage_permissions = [
      "Get",
    ]
  }
  depends_on = [
    azurerm_resource_group.application_grp
  ]
}

# Secret in the Key Value
resource "azurerm_key_vault_secret" "vmpassword" {
  name = "vmpassword"
  value = "Azure@123"
  key_vault_id = azurerm_key_vault.app_vault.id
  depends_on = [
    azurerm_key_vault.app_vault
  ]  
}

# Creating VM
resource "azurerm_windows_virtual_machine" "app-windows-vm" {
  name                = "app-windows-vm"
  resource_group_name = local.resource_group
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = azurerm_key_vault_secret.vmpassword.value
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface,
    azurerm_availability_set.app_set,
    azurerm_key_vault_secret.vmpassword
  ]
}

# Creating and Attaching an Extra Disk to the VM
resource "azurerm_managed_disk" "data_disk" {
  name                 = "data-disk"
  location             = local.location
  resource_group_name  = local.resource_group
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 16
  depends_on = [
    azurerm_resource_group.application_grp
  ]
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_attach" {
  managed_disk_id    = azurerm_managed_disk.data_disk.id 
  virtual_machine_id = azurerm_windows_virtual_machine.app-windows-vm.id
  lun                = "0"
  caching            = "ReadWrite"
  depends_on = [
    azurerm_windows_virtual_machine.app-windows-vm,
    azurerm_managed_disk.data_disk
  ]
}

# Creating Availability Set
resource "azurerm_availability_set" "app_set" {
  name = "app-set"
  location = local.location
  resource_group_name = local.resource_group
  platform_fault_domain_count = 3
  platform_update_domain_count = 3  
  depends_on = [
    azurerm_resource_group.application_grp
  ]
}

# Create Storage Account Resource
resource "azurerm_storage_account" "storage_account" {
  name                     = var.storage_account_name
  resource_group_name      = local.resource_group
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [
    azurerm_resource_group.application_grp
  ]
}

# Creating Storage Container
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = var.storage_account_name
  container_access_type = "blob"
  depends_on = [
    azurerm_storage_account.storage_account
  ]
}

# Creating a Storage Blob: Where you can upload files to in the container
resource "azurerm_storage_blob" "IIS_config" {
  name                   = "IIS_Config.ps1"
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  source                 = "IIS_Config.ps1"
  depends_on = [
    azurerm_storage_container.data
  ]
}

# Creating a Virtual Machine Extension
resource "azurerm_virtual_machine_extension" "vm_extension" {
  name                 = "app-windows-vm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.app-windows-vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_windows_virtual_machine.app-windows-vm,
    azurerm_storage_container.data,
    azurerm_storage_blob.IIS_config
  ]

  settings = <<SETTINGS
 {
  "fileUris": ["https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/data/IIS_Config.ps1"],
    "commandToExecute": "powershell -ExecutionPolicy Unresticted -file IIS_Config.ps1"
 }
SETTINGS
}


# Azure LoadBalancing Section

# Create Loadbalancer Public IP
resource "azurerm_public_ip" "lb_ip" {
  name                = "lb-ip"
  location            = local.location
  resource_group_name = local.resource_group
  allocation_method   = "Static"
  sku = "Standard"
}

# Create LB
resource "azurerm_lb" "app_lb" {
  name                = "app-lb"
  location            = local.location
  resource_group_name = local.resource_group

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
  sku = "Standard"

  depends_on = [
    azurerm_public_ip.lb_ip
  ]
}

# # LB Backend Pool
# resource "azurerm_lb_backend_address_pool" "PoolA" {
#   loadbalancer_id = azurerm_lb.app_lb.id
#   name            = "BackEndAddressPool"

#   depends_on = [
#     azurerm_lb.app_lb
#   ]
# }

# # LB Backend Pool Addresses
# resource "azurerm_lb_backend_address_pool_address" "appvm1_address" {
#   name                    = "appvm1"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
#   virtual_network_id      = azurerm_virtual_network.app_network.id
#   ip_address              = azurerm_network_interface.app_interface.private_ip_address
#   depends_on = [
#     azurerm_lb_backend_address_pool.PoolA
#   ]
# }

# resource "azurerm_lb_backend_address_pool_address" "appvm2-address" {
#   name                    = "appvm2"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
#   virtual_network_id      = azurerm_virtual_network.app_network.id 
#   ip_address              = azurerm_network_interface.app_interface_2.private_ip_address
#   depends_on = [
#     azurerm_lb_backend_address_pool.PoolA
#   ]
# }

# Scaleset Pool
resource "azurerm_lb_backend_address_pool" "scalesetpool" {
  loadbalancer_id = azurerm_lb.app_lb.id
  name = "scalesetpool"
  depends_on = [
    azurerm_lb.app_lb
  ]  
}

# LB Probe
resource "azurerm_lb_probe" "ProbeA" {
  loadbalancer_id = azurerm_lb.app_lb.id
  name            = "ProbeA"
  port            = 80
  depends_on = [
    azurerm_lb.app_lb
  ]
}

# LB Rule
resource "azurerm_lb_rule" "RuleA" {
  loadbalancer_id                = azurerm_lb.app_lb.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.scalesetpool.id  ] 
  probe_id = azurerm_lb_probe.ProbeA.id
  depends_on = [
    azurerm_lb.app_lb,
    azurerm_lb_probe.ProbeA
  ]
}

# Scaleset
resource "azurerm_windows_virtual_machine_scale_set" "scale_set" {
  name                = "scale-set"
  resource_group_name = local.resource_group
  location            = local.location
  sku                 = "Standard_F2"
  instances           = 2
  admin_password      = "P@55w0rd1234!"
  admin_username      = "vmuser"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-Server-Core"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "scaleset-interface"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnetA.id
      load_balancer_backend_address_pool_ids = [ azurerm_lb_backend_address_pool.scalesetpool.id ]
    }
  }

  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

# Creating a Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "vm_workspace" {
  name                = "vm-workspace"
  location            = local.location
  resource_group_name = local.resource_group
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_virtual_machine_extension" "vm_logagent_extension" {
  name                       = "vm-logagent-extension"
  virtual_machine_id         = azurerm_windows_virtual_machine.app-windows-vm.id 
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
    {
      "workspaceId": "${azurerm_log_analytics_workspace.vm_workspace.workspace_id}"
    }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
    {
      "workspaceKey": "${azurerm_log_analytics_workspace.vm_workspace.primary_shared_key}"
    }
  PROTECTED_SETTINGS
}

resource "azurerm_log_analytics_datasource_windows_event" "collect_events" {
  name                = "collect-events"
  resource_group_name = local.resource_group
  workspace_name      = azurerm_log_analytics_workspace.vm_workspace.name
  event_log_name      = "Application"
  event_types         = ["Error"]
}

# Creating Monitoring Alerts
resource "azurerm_monitor_action_group" "email_alert" {
  name                = "email-alert"
  resource_group_name = local.resource_group
  short_name          = "email-alert"

  email_receiver {
    name                    = "sendtodevops"
    email_address           = "devops.itsm@company.com"
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "Network_Threshold_Alert" {
  name                = "network_threshold_alert"
  resource_group_name = local.resource_group
  scopes              = [azurerm_windows_virtual_machine.app-windows-vm.id]
  description         = "Network Out Bytes greater than 70."

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Network Out Total"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 70
  }

  action {
    action_group_id = azurerm_monitor_action_group.email_alert.id 
  }
  
  depends_on = [
    azurerm_monitor_action_group.email_alert,
    azurerm_windows_virtual_machine.app-windows-vm
  ]
}


# Budget Alert
resource "azurerm_consumption_budget_resource_group" "monthly_budget" {
  name              = "monthly_budget"
  resource_group_id = azurerm_resource_group.application_grp.id

  amount     = 90
  time_grain = "Monthly"

  time_period {
    start_date = "2023-03-01T00:00:00Z"
    end_date   = "2023-04-01T00:00:00Z"   
  }

  notification {
    enabled   = true
    threshold = 70.0
    operator  = "EqualTo"
    threshold_type = "Forecasted"

    contact_groups = [
      azurerm_monitor_action_group.email_alert.id 
    ]
  }
}

