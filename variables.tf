variable "controller_name" {
  type        = string
  description = "Customized Name for Aviatrix Controller"
}

variable "controller_subnet_cidr" {
  type        = string
  description = "CIDR for controller subnet."
  default     = "10.190.190.0/24"
}

variable "controller_virtual_machine_admin_username" {
  type        = string
  description = "Admin Username for the controller virtual machine."
  default     = "aviatrix"
}

variable "controller_virtual_machine_admin_password" {
  type        = string
  description = "Admin Password for the controller virtual machine."
  default     = "aviatrix1234!"
}

variable "controller_virtual_machine_size" {
  type        = string
  description = "Virtual Machine size for the controller."
  default     = "Standard_B2ms"
}

variable "controller_vnet_cidr" {
  type        = string
  description = "CIDR for controller VNET."
  default     = "10.190.190.0/24"
}

variable "location" {
  type        = string
  description = "Resource Group Location for Aviatrix Controller"
  default     = "China North"
}


variable "incoming_ssl_cidr" {
  type        = list(string)
  description = "Incoming cidr for security group used by controller"
  default = []
}



# probably don't need; especially if INIT node used
locals {
  provisionerIP = [replace(data.http.my_ip.response_body,"\n","/32")]
  allowed_ips = length(var.incoming_ssl_cidr) > 0 ? concat(var.incoming_ssl_cidr,local.provisionerIP) : local.provisionerIP
}


# controller
variable "use_existing_vnet" {
  type        = string
  description = ""
  default     = "true"
}

variable "vnet_name" {
  type        = string
  description = ""
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = ""
  default     = ""
}

variable "subnet_name" {
  type        = string
  description = ""
  default     = ""
}

variable "resource_group_name" {
  type        = string
  description = ""
  default     = ""
}


# migrate original eip after associating original ctl eip to new ctl
variable "use_new_eip" {
  type        = string
  default = "true"
}

variable "eip_name" {
  type        = string
  description = ""
  default     = ""
}