# Generate random resource group name
resource "random_pet" "rg_name" {
  prefix = "rg"
}

# Generate random value for names
resource "random_string" "name" {
  length  = 8
  lower   = true
  numeric = false
  special = false
  upper   = false
}

# Generate random password for PostgreSQL Flexible Server
resource "random_password" "pgsql_pwd" {
  length      = 20
  min_lower   = 4
  min_numeric = 4
  min_special = 4
  min_upper   = 4
}

# Manages the key to connect to VM.
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Saves the key to connect to VM as a local file.
resource "local_file" "key_as_file" {
  filename = "vmkey"
  content  = tls_private_key.key.private_key_pem
}

# Saves the testing script to connect to PostgreSQL from the VM.
resource "local_file" "psql_script" {
  filename = "psqltest.sh"
  content  = local.psql_command
}

# Manages the Resource Group
resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
}

data "azurerm_client_config" "current" {}

# Manages the VNET
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${random_string.name.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Manages the default subnet
resource "azurerm_subnet" "default_subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.0.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
}

# Manages the pgsql subnet
resource "azurerm_subnet" "pgsql_subnet" {
  name                 = "pgsql"
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  delegation {
    name = "dlg-Microsoft.DBforPostgreSQL-flexibleServers"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Manages the Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-default"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Manages the Network Security Rule
resource "azurerm_network_security_rule" "nsr" {
  name                        = "AllowAnySSHInbound"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
  access                      = "Allow"
  description                 = ""
  destination_address_prefix  = "AzureCloud"
  destination_port_range      = "22"
  direction                   = "Inbound"
  priority                    = 100
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  source_port_range           = "*"
}

# Manages the Network Security Group associations to default subnet
resource "azurerm_subnet_network_security_group_association" "security_group_association" {
  network_security_group_id = azurerm_network_security_group.nsg.id
  subnet_id                 = azurerm_subnet.default_subnet.id
}

# Manages the Key Vault
resource "azurerm_key_vault" "akv" {
  name                            = "akv-${random_string.name.result}"
  location                        = azurerm_resource_group.rg.location
  enable_rbac_authorization       = false
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = true
  resource_group_name             = azurerm_resource_group.rg.name
  sku_name                        = "standard"
  soft_delete_retention_days      = 90
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.current_public_ip.response_body).ip
    ]
  }
}

# Manages the Key Vault Access Policy for the principal running this Terraform configuration
resource "azurerm_key_vault_access_policy" "akv_access_policy_terraform_principal" {
  tenant_id    = azurerm_key_vault.akv.tenant_id
  key_vault_id = azurerm_key_vault.akv.id
  object_id    = data.azurerm_client_config.current.object_id
  key_permissions = [
    "Create",
    "Get",
    "Delete"
  ]
}

# Manages the Key Vault Access Policy for the PostgreSQL UAMI
resource "azurerm_key_vault_access_policy" "akv_access_policy_postgresql_principal" {
  tenant_id    = azurerm_key_vault.akv.tenant_id
  key_vault_id = azurerm_key_vault.akv.id
  object_id    = azurerm_user_assigned_identity.pgsql_uami.principal_id
  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]
}

# Manages PostgreSQL Flexible Server User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "pgsql_uami" {
  location            = azurerm_resource_group.rg.location
  name                = "pgsqluami-${random_string.name.result}"
  resource_group_name = azurerm_resource_group.rg.name
}

# Manages PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "pgsql" {
  name                   = "pgsql-${random_string.name.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "13"
  delegated_subnet_id    = azurerm_subnet.pgsql_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.pgsqldnszone.id
  administrator_login    = "adminpostgresql"
  administrator_password = random_password.pgsql_pwd.result
  zone                   = "1"
  storage_mb             = 32768
  sku_name               = "GP_Standard_D2s_v3"
  backup_retention_days  = 7
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pgsql_uami.id]
  }
  customer_managed_key {
    key_vault_key_id                  = azurerm_key_vault_key.key.id
    primary_user_assigned_identity_id = azurerm_user_assigned_identity.pgsql_uami.id
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

#Manages PostgreSQL Flexible Server Database
resource "azurerm_postgresql_flexible_server_database" "database" {
  name      = "sample-database"
  server_id = azurerm_postgresql_flexible_server.pgsql.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Manages PostgreSQL private DNS zone
resource "azurerm_private_dns_zone" "pgsqldnszone" {
  name                = "pgsql-${random_string.name.result}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Manages PostgreSQL private DNS zone link to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "linkpgsqlprivatednszonetovnet"
  private_dns_zone_name = azurerm_private_dns_zone.pgsqldnszone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
}

# Manages the encryption key
resource "azurerm_key_vault_key" "key" {
  name         = "pgsql-key"
  key_vault_id = azurerm_key_vault.akv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [azurerm_key_vault_access_policy.akv_access_policy_terraform_principal]
}

# Manages the Virtual Machine Public IP
resource "azurerm_public_ip" "vmpip" {
  name                = "vmpip-${random_string.name.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

# Manages the Virtual Machine NIC
resource "azurerm_network_interface" "vmnic" {
  name                = "nic-${random_string.name.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.default_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vmpip.id
  }
}

# Manages the Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-${random_string.name.result}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.vmnic.id]

  custom_data = filebase64("customdata.tftpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
/*
  provisioner "local-exec" {
    command = templatefile("${local.host_os}-ssh-script.tftpl", {
      hostname     = self.public_ip_address
      user         = self.admin_username
      identityfile = "${path.module}/vmkey"
    })
    interpreter = local.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }
*/

  connection {
    type        = "ssh"
    user        = self.admin_username
    host        = data.azurerm_public_ip.vmpip.ip_address
    agent       = false
    private_key = tls_private_key.key.private_key_openssh
  }

  provisioner "file" {
    source      = "${path.module}/${local_file.psql_script.filename}"
    destination = "psqltest.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x psqltest.sh"
    ]
  }

  depends_on = [local_file.psql_script, azurerm_subnet_network_security_group_association.security_group_association]
}
