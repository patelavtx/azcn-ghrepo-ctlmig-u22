# Migrate to G3 Aviatrix Controller in Azure China

## Description

This repo helps build a U22 based Controller only for Azure China.
Initialization of the controller is a manual process see section 4 below.
Assumes that the repo - https://github.com/patelavtx/AzCN-GHrepo.git was used to deploy originally/


## Prerequisites

*** IMPORTANT ***
-  Accept the TERMS for Aviatrix G3 controller
-  Accept the TERMS for the Aviatrix G3 Gateway (needed for Azure China Aviatrix Gateway deployment of G3 images)
 
-  If you don’t ‘accept TERMs for aviatrix-gateway-g3’ and you conduct an image upgrade’ it fails,  BUT also leaves a state where the transit gateway is left deleted in CSP

```shell
#Aviatrix controller
az vm image list --offer aviatrix --all --output table | grep "aviatrix-controller"
az vm image terms accept --urn cbcnetworks:aviatrix-controller:aviatrix-controller-g3:latest

# Aviatrix GWs
az vm image terms accept --urn cbcnetworks:aviatrix-gateway:aviatrix-gateway-g3:latest
```


This repo assumes that an existing Aviatrix Controller has been deployed in Azure China where existing vnet/subnet details will be leveraged to create a new controller VM.

Requirements
As deploying to same RG (existing vnet):

```shell
1. Controller name needs to be unique (as deploying to same RG)
2. Review ./module/main.tf  and update VM 'os-disk name'        see ADD4 in this file for where to modify
# CHANGES made to 'build' module for controller migration purpose  (see for 'ADD' in file)
#
#  REF points - ADD1  >>  add count + use_existing_vnet to resource blocks
#             - ADD2  >>  use_new_eip (to associate orig ctl eip to new ctl) - still new TF import to bring into state  
#             - ADD3  >>   update orig ctl EIP data block         ## UPDATE with 'original controller PIP'
#             - ADD4  >>  update resource 7. vm with image + os disk name             
#
# UPdate1 - SG lifecycle
# SG - incoming_ssl_cidr  -  modify in 'root' variables.tf  to include existing gw pips    

```


## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | ~> 2.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | \>= 3.54.0 |
| <a name="provider_null"></a> [null](#provider\_null) | \>= 2.0 |


## Available Modules

Module  | Description |
| ------- | ----------- |
|[aviatrix_controller_build](modules/aviatrix_controller_build) |Builds the Aviatrix Controller VM on Azure |



## Procedures for Building  a Controller in Azure


### 1. Authenticating to Azure

Set the environment in Azure CLI to Azure China:

```shell
az cloud set -n AzureChinaCloud
```

Login to the Azure CLI using:

```shell
az login --use-device-code
````
*Note: Please refer to the [documentation](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs#authenticating-to-azure-active-directory) for different methods of authentication to Azure, incase above command is not applicable.*

Pick the subscription you want and use it in the command below.

```shell
az account set --subscription <subscription_id>
```

Set environment variables ARM_ENDPOINT and ARM_ENVIRONMENT to use Azure China endpoints:

  ``` shell
  export ARM_ENDPOINT=https://management.chinacloudapi.cn
  export ARM_ENVIRONMENT=china
  ```

If executing this code from a CI/CD pipeline, the following environment variables are required. The service principal used to authenticate the CI/CD tool into Azure must either have subscription owner role or a custom role that has `Microsoft.Authorization/roleAssignments/write` to be able to succesfully create the role assignments required

``` shell
export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
export ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000"
export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
```


### 2. Applying Terraform configuration 

Build the Aviatrix Controller

```hcl
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# controller build
module "aviatrix_controller_build" {
  #source = "./modules/aviatrix_controller_build"
  source = "github.com/patelavtx/aviatrix_controller_azure_china/modules/aviatrix_controller_build"
  controller_name                           = var.controller_name
  location                                  = var.location
  controller_vnet_cidr                      = var.controller_vnet_cidr
  controller_subnet_cidr                    = var.controller_subnet_cidr
  controller_virtual_machine_admin_username = var.controller_virtual_machine_admin_username
  controller_virtual_machine_admin_password = var.controller_virtual_machine_admin_password
  controller_virtual_machine_size           = var.controller_virtual_machine_size
  incoming_ssl_cidr                         = local.allowed_ips
}
```




### 3. Applying Terraform configuration 
Note/.  controller_vnet_cidr and controller_subnet_cidr is not required if deploying to existing vnet


controller_name = "azCN-u22"
#controller_vnet_cidr = "10.190.190.0/24"
#controller_subnet_cidr = "10.190.190.0/24"


# Needed for deploying new controller in existing vnet  
use_existing_vnet = true
vnet_name = "azCN-ctltest-vnet"
subnet_id = "/subscriptions/<subscriptionID>/resourceGroups/azCN-ctltest-rg/providers/Microsoft.Network/virtualNetworks/azCN-ctltest-vnet/subnets/azCN-ctltest-subnet"
subnet_name =  "azCN-ctltest-subnet"
resource_group_name = "azCN-ctltest-rg"

# STEP2  - AFTER restore toggle to false to associate 'original PIP' in TF state
# use_new_eip = "false"                  
eip_name = "azCN-ctltest-public-ip"      #  Will only be used when 'use_new_eip' is toggled to false **UPDATE

# update here with existing gw PIPs
incoming_ssl_cidr = [ "7.7.7.7/32","8.8.8.8/32","11.11.11.11/32"]



### 4. Post New Aviatrix China Controller deployment

Initialization Requirements after new controller is deployed:
```shell
1. Set Password  (temporary as restore will override)
2. Set email
3. Set sw version 7.1.4191  (in this example)
4. Disassociate original PIP from original controller and associate to new controller
5. IP Migration  (then restore)
6. Restore
7. Image upgrade Gateways
```



*Execute*

```shell
terraform init
terraform apply
```
