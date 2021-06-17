terraform {
  required_version = "= 0.12.29"
}
provider "azurerm" {
  version = "=2.30.0"
  features {}

  subscription_id = var.subscription_id
  client_id = var.client_id
  client_secret = var.client_secret
  tenant_id = var.tenant_id

}

### VARIABLES
variable "subscription_id" {
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "workload_acronym" {
  type        = string
  description = "(Required) Specifies the name of the Resource Group. Changing this forces a new resource to be created"
}

variable "channel" {
  type = string
  description = "(Optional) Distribution channel to which the associated resource belongs to."
  default     = ""
}

variable "description" {
  type        = string
  description = "(Required) Provide additional context information describing the resource and its purpose."
}

variable "tracking_code" {
  type        = string
  description = "(Required) Allow this resource to be matched against internal inventory systems."
}

variable "sequence_number" {
  type = string
  description = "(Required) Sequence number for resources in WL."
}

variable "akv_sequence_number" {
  type        = string
  description = "(Optional) Key Vault sequence number."
  default     = ""
}

variable "sta_sequence_number" {
  type        = string
  description = "(Optional) Storage Account sequence number."
  default     = ""
}

variable "akv_key_sequence_number" {
  type        = string
  description = "(Optional) AKV Key sequence number which will be used to encrypt the Storage Account."
  default     = ""
}

variable "delete_retention_days" {
  type        = number
  description = "(Optional) Specifies the number of days that the blob should be retained, between 1 and 365 days. Defaults to 7"
  default     = 7
}

variable "sta_tier" {
  type        = string
  description = "(Required) Storage account tier. Possible values: standard."
  default = "standard"
}

variable "sta_replication" {
  type        = string
  description = "(Required) Storage account replication policy. Possible values: LRS, GRS, RAGRS or ZRS "
  default = "LRS"
}

variable "location" {
  type        = string
  description = "(Required) Specifies the supported Azure location where the Resource Group exists. Changing this forces a new resource to be created."
}
variable "cost_center" {
  type        = string
  description = "(Required)This tag will report the cost center of the resource and need to be applied to every resource in the subscription"
}
variable "product" {
  type        = string
  description = "(Required) The product tag will indicate the product to which the associated resource belongs to"
}

variable "cia" {
  type        = string
  description = "(Required) Confidentiality-Integrity-Availability"
}


locals {
  header = "sans1weu"
  rsg_name = "${local.header}rsg${var.workload_acronym}comm${var.sequence_number}"
  sta_name = "${local.header}sta${var.workload_acronym}comm${var.sequence_number}"
  akv_name = "${local.header}sta${var.workload_acronym}comm${var.sequence_number}"
}


## RESOURCES

resource "azurerm_resource_group" "rsg" {
  name     = local.rsg_name
  location = var.location

  tags = {
    cost_center     = var.cost_center
    product         = var.product
    cia             = var.cia
  }
}

resource "azurerm_key_vault" "akv" {
  location = var.location
  name = local.akv_name
  resource_group_name = azurerm_resource_group.rsg.name
  sku_name = "premium"
  tenant_id = var.tenant_id

  tags = {
    cost_center     = azurerm_resource_group.rsg.tags["cost_center"]
    product         = azurerm_resource_group.rsg.tags["product"]
    channel         = var.channel
    description     = var.description
    tracking_code   = var.tracking_code
    cia             = var.cia
  }

  depends_on = [azurerm_resource_group.rsg]
}

resource "azurerm_storage_account" "sta" {
  name                      = local.sta_name
  resource_group_name       = azurerm_resource_group.rsg.name
  location                  = var.location
  account_kind              = "StorageV2"
  account_tier              = "Premium"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true

  blob_properties{
    delete_retention_policy {
      days = var.delete_retention_days
    }
  }

  tags = {
    cost_center     = azurerm_resource_group.rsg.tags["cost_center"]
    product         = azurerm_resource_group.rsg.tags["product"]
    channel       = var.channel
    description   = var.description
    tracking_code = var.tracking_code
    cia           = var.cia
  }

  depends_on = [azurerm_resource_group.rsg]
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = local.sta_name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.sta]
}

## OUTPUTS

output "rsg_name" {
  value = azurerm_resource_group.rsg.name
}

output "rsg_id" {
  value = azurerm_resource_group.rsg.id
}

output "kvt_name"{
  value = azurerm_key_vault.akv.name
}

output "kvt_id"{
  value = azurerm_key_vault.akv.id
}

output "storage_account_id" {
  value = azurerm_storage_account.sta.id
}

output "storage_account_name" {
  value = azurerm_storage_account.sta.name
}

