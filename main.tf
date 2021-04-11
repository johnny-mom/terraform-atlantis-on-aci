resource "random_id" "rand" {
  byte_length = 5
  prefix      = "atlantis"
}

resource "azurerm_resource_group" "rg" {
  name     = "atlantis"
  location = var.location
}

resource "azurerm_storage_account" "storage_acc" {
  name                     = random_id.rand.dec
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "share" {
  name                 = "atlantis-share"
  storage_account_name = azurerm_storage_account.storage_acc.name
  quota                = 1
}

resource "azurerm_storage_share_file" "cert" {
  name             = "atlantis.crt"
  storage_share_id = azurerm_storage_share.share.id
  source           = var.cert_location
}

resource "azurerm_storage_share_file" "cert_key" {
  name             = "atlantis.key"
  storage_share_id = azurerm_storage_share.share.id
  source           = var.cert_key_location
}

resource "azurerm_storage_share_file" "repo" {
  name             = "repos.yaml"
  storage_share_id = azurerm_storage_share.share.id
  source           = var.repos_config_location
}

resource "azurerm_storage_share_file" "atlantis_config" {
  name             = "atlantis-config.yaml"
  storage_share_id = azurerm_storage_share.share.id
  source           = var.atlantis_config_location
}

resource "azurerm_container_group" "aci" {
  name                = "atlantis-aci-instance"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "public"
  dns_name_label      = "rnatlantis"
  os_type             = "Linux"
  restart_policy      = "OnFailure"

  container {
    name   = "atlantis"
    image  = "runatlantis/atlantis:latest"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 4141
      protocol = "TCP"
    }

    volume {
      name                 = "atlantis-share"
      mount_path           = "/mnt/atlantis"
      storage_account_name = azurerm_storage_account.storage_acc.name
      storage_account_key  = azurerm_storage_account.storage_acc.primary_access_key
      share_name           = azurerm_storage_share.share.name
    }       
 
    commands = [
      "/bin/bash",
      "-c",
      "atlantis server --config /mnt/atlantis/atlantis-config.yaml --repo-config=/mnt/atlantis/repos.yaml"
    ]

    environment_variables = {
      "ARM_USE_MSI" = "true"
    }
  }
}
