variable "location" {
  description = "The location of created resources."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default = {
    module  = "acr"
    example = "advanced"
    usage   = "demo"
  }
}

variable "resource_prefix" {
  description = "A prefix for the name of the resource, used to generate the resource names."
  type        = string
  default     = "tfm-ex-adv-acr"
}
