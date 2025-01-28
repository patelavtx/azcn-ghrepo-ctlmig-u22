/**
 * # Aviatrix Controller Build
 *
 * This module builds and launches the Aviatrix Controller VM instance.
#  PRE-MOD
#  REF points - ADD1  >>  add count + use_existing_vnet to resource blocks
#             - ADD2  >>  update orig ctl EIP data block
#             - ADD3  >>  use_new_eip (to associate orig ctl eip to new ctl) - still new TF import to bring into state
#             - ADD3  >>  update EIP
#             - ADD4  >>  update resource 7. vm with image + os disk name
# UPdate1 - SG lifecycle
# SG - incoming_ssl_cidr  -  modify in 'root' variables.tf  include gw ips

 */

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.54.0"
    }
  }
}

# ADD1 count for resources 1-7 below and 'use_existing_vnet'
# 1. Create an Azure resource group
resource "azurerm_resource_group" "aviatrix_controller_rg" {
  count    = var.use_existing_vnet == false ? 1 : 0
  location = var.location
  name     = "${var.controller_name}-rg"
}

# 2. Create the Virtual Network and Subnet
//  Create the Virtual Network
resource "azurerm_virtual_network" "aviatrix_controller_vnet" {
  count               = var.use_existing_vnet == false ? 1 : 0
  address_space = [var.controller_vnet_cidr]
  location            = var.location
  name                = "${var.controller_name}-vnet"
  resource_group_name = azurerm_resource_group.aviatrix_controller_rg[0].name
}

//  Create the Subnet
resource "azurerm_subnet" "aviatrix_controller_subnet" {
  count               = var.use_existing_vnet == false ? 1 : 0
  name                 = "${var.controller_name}-subnet"
  resource_group_name = azurerm_resource_group.aviatrix_controller_rg[0].name
  virtual_network_name = azurerm_virtual_network.aviatrix_controller_vnet[0].name
  address_prefixes = [var.controller_subnet_cidr]
}

# ADD2 - new_eip  - flip 'use_new_eip'
// 3. Create Public IP Address
resource "azurerm_public_ip" "aviatrix_controller_public_ip" {
  count = var.use_new_eip ? 1 : 0
  allocation_method   = "Static"
  location            = var.location
  name                = "${var.controller_name}-public-ip"
  resource_group_name = var.use_existing_vnet == false ? azurerm_resource_group.aviatrix_controller_rg[0].name : var.resource_group_name
}


# ADD3  -  can add variables here to use in main module
#***************** data to retrieve existing public ip ****************
data "azurerm_public_ip" "origctl" {
  name                = "azCN-ctltest-public-ip"                          # UPDATE with name and RG of original controller ip
  resource_group_name = "azCN-ctltest-rg"
}

output "public_ip_address" {
  value = data.azurerm_public_ip.origctl.ip_address
}
#*****************************************************************

// 4. Create the Security Group
resource "azurerm_network_security_group" "aviatrix_controller_nsg" {
  location            = var.location
  name                = "${var.controller_name}-security-group"
  resource_group_name = var.use_existing_vnet == false ? azurerm_resource_group.aviatrix_controller_rg[0].name : var.resource_group_name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "https"
    priority                   = "200"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.incoming_ssl_cidr  # Update1
    destination_address_prefix = "*"
    description                = "https-for-vm-management"
  }
  lifecycle {
    ignore_changes = [security_rule,tags]              # UPdate1 - SG lifecycle; BEWARE as adding new rules will be ignored, use CSP 
  }
}

# 5. Create the Virtual Network Interface Card
//  associate the public IP address with a VM by assigning it to a nic
resource "azurerm_network_interface" "aviatrix_controller_nic" {
  location            = var.location
  name                = "${var.controller_name}-network-interface-card"
  resource_group_name = var.use_existing_vnet == false ? azurerm_resource_group.aviatrix_controller_rg[0].name : var.resource_group_name
  ip_configuration {
    name                          = "${var.controller_name}-nic"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.use_existing_vnet == false ? azurerm_subnet.aviatrix_controller_subnet[0].id : var.subnet_id
    public_ip_address_id          = var.use_new_eip == true ? azurerm_public_ip.aviatrix_controller_public_ip[0].id : data.azurerm_public_ip.origctl.id
  }
}

# 6. Associate the Security Group to the NIC
resource "azurerm_network_interface_security_group_association" "aviatrix_controller_nic_sg" {
  network_interface_id = azurerm_network_interface.aviatrix_controller_nic.id
  network_security_group_id = azurerm_network_security_group.aviatrix_controller_nsg.id
}

# ADD7
# 7. Create the virtual machine
resource "azurerm_linux_virtual_machine" "aviatrix_controller_vm" {
  admin_username                  = var.controller_virtual_machine_admin_username
  admin_password                  = var.controller_virtual_machine_admin_password
  name                            = "${var.controller_name}-vm"
  disable_password_authentication = false
  location                        = var.location
  network_interface_ids = [
  azurerm_network_interface.aviatrix_controller_nic.id]
  resource_group_name             = var.use_existing_vnet == false ? azurerm_resource_group.aviatrix_controller_rg[0].name : var.resource_group_name
  size                = var.controller_virtual_machine_size
  //disk
  os_disk {
    name                 = "aviatrix2-os-disk-u22"                # disk name unique
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
 # image updated
  source_image_reference {
    publisher = "cbcnetworks"
    offer = "aviatrix-controller"
    sku = "aviatrix-controller-g3"
    version = "latest"
  }

   plan {
    name      = "aviatrix-controller-g3"
    product   = "aviatrix-controller"
    publisher = "cbcnetworks"
  }
}
