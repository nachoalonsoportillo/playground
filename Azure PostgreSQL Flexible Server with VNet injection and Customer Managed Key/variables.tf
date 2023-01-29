variable "resource_group_location" {
  type = string
  validation {
    condition     = contains(["australiacentral", "australiacentral2", "australiaeast", "australiasoutheast", "brazilsouth", "brazilsoutheast", "brazilus", "canadacentral", "canadaeast", "centralindia", "centralus", "centraluseuap", "eastasia", "eastus", "eastus2", "eastus2euap", "francecentral", "francesouth", "germanynorth", "germanywestcentral", "japaneast", "japanwest", "jioindiacentral", "jioindiawest", "koreacentral", "koreasouth", "northcentralus", "northeurope", "norwayeast", "norwaywest", "qatarcentral", "southafricanorth", "southafricawest", "southcentralus", "southeastasia", "southindia", "swedencentral", "swedensouth", "switzerlandnorth", "switzerlandwest", "uaecentral", "uaenorth", "uksouth", "ukwest", "westcentralus", "westeurope", "westindia", "westus", "westus2", "westus3", "austriaeast", "eastusslv", "israelcentral", "italynorth", "malaysiasouth", "mexicocentral", "spaincentral", "taiwannorth", "taiwannorthwest"], var.resource_group_location)
    error_message = "Chosen location is not supported."
  }
  description = "Location of the resource group. For example: australiaeast, eastus, japaneast, or westeurope."
}
