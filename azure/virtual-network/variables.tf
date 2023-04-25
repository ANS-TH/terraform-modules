#########
# Global
#########

variable "location" {
  description = "The location of created resources."
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "The name of the resource group this module will use."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = null
}

#########################
# Virtual Network Config
#########################

variable "name" {
  description = "The name of the virtual network."
  type        = string
}

variable "address_space" {
  description = "The address spaces of the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "dns_servers" {
  description = "The DNS servers to use with this virtual network."
  type        = list(string)
  default     = null
}

variable "ddos_protection_plan_id" {
  description = "A DDoS Protection plan ID to assign to the virtual network."
  type        = string
  default     = null
}

variable "bgp_community" {
  description = "The BGP Community for this virtual network."
  type        = string
  default     = null
}

variable "peer_networks" {
  description = "Networks to peer to this virtual network."
  type = list(
    object({
      name                         = string
      id                           = string
      allow_virtual_network_access = optional(bool, true)
      allow_forwarded_traffic      = optional(bool, true)
      allow_gateway_transit        = optional(bool)
      use_remote_gateways          = optional(bool)
    })
  )
  default = []
}

variable "private_dns_zones" {
  description = "Private DNS Zones to link to this virtual network."
  type = list(
    object({
      name                 = string
      resource_group_name  = string
      registration_enabled = optional(bool)
    })
  )
  default = []
}

variable "subnets" {
  description = "Subnets to create in this virtual network."
  type = list(
    object({
      name                                          = string
      prefix                                        = string
      service_endpoints                             = optional(list(string))
      private_endpoint_network_policies_enabled     = optional(bool)
      private_link_service_network_policies_enabled = optional(bool)
      delegations = optional(map(
        object({
          name    = string
          actions = optional(list(string))
        })
      ))
    })
  )
  default = [
    {
      name   = "default"
      prefix = "10.0.0.0/24"
    }
  ]
}

variable "subnet_network_security_group_map" {
  description = "Mapping of subnet names to NSG IDs."
  type        = map(string)
  default     = {}
}

variable "subnet_route_table_map" {
  description = "Mapping of subnet names to Route Table IDs."
  type        = map(string)
  default     = {}
}

variable "subnet_nat_gateway_map" {
  description = "Mapping of subnet names to NAT Gateway IDs."
  type        = map(string)
  default     = {}
}
