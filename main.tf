/**
 * # Aviatrix Controller Build
 *
 * This module builds and launches the Aviatrix Controller VM instance.
#  Chedk ./module/main.tf 
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
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    null = {
      source = "hashicorp/null"
    }    
      http = {
      source = "hashicorp/http"
      version = "3.2.1"
    }
  }
}

data "azurerm_subscription" "current" {
}

data "http" "my_ip" {
#Get public IP address of system running the code to add to allowed IP addresses of Aviatrix Controller NSG
    url = "http://ipv4.icanhazip.com/"
    method = "GET"
}

module "aviatrix_controller_build" {
  source = "./modules/aviatrix_controller_build"
  controller_name                           = var.controller_name
  location                                  = var.location
  controller_vnet_cidr                      = var.controller_vnet_cidr
  controller_subnet_cidr                    = var.controller_subnet_cidr
  controller_virtual_machine_admin_username = var.controller_virtual_machine_admin_username
  controller_virtual_machine_admin_password = var.controller_virtual_machine_admin_password
  controller_virtual_machine_size           = var.controller_virtual_machine_size
  incoming_ssl_cidr                         = local.allowed_ips
  #deploy to existing vnet using variables
  subnet_id = var.subnet_id
  subnet_name = var.subnet_name
  use_existing_vnet = var.use_existing_vnet             # set to true to deploy to existing vnet and add RG-vnet-subnet details
  vnet_name = var.vnet_name
  resource_group_name = var.resource_group_name
  
  # to point new controller to 'original PIP' in TF state
  use_new_eip = var.use_new_eip
  eip_name = var.eip_name
}



