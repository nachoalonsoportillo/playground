# Get current public IP.
data "http" "current_public_ip" {
  url = "http://ipinfo.io/json"
  request_headers = {
    Accept = "application/json"
  }
}

# Helper to figure out whether we're running on Windows or Linux.
data "external" "os" {
  working_dir = path.module
  program     = ["printf", "{\"os\": \"linux\"}"]
}

# Used to get the public IP once the NIC is attached to the virtual machine. Note: this is because the Public IP resource in Azure doesn't have an address assigned unless the NIC to which it is linked is attached to one VM.
data "azurerm_public_ip" "vmpip" {
  name                = azurerm_public_ip.vmpip.name
  resource_group_name = azurerm_public_ip.vmpip.resource_group_name
}