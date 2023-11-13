terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.80.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true
  features {}
}

# Naming Convention
variable "resource_group_name" {
  default = "k8s-rg"
}

variable "location" {
  default = "East US"
}

variable "virtual_network_name" {
  default = "k8s-vnet"
}

variable "subnet_name" {
  default = "k8s-subnet"
}

variable "network_interface_name" {
  default = "k8s-nic"
}

variable "virtual_machine_name" {
  default = "k8s-vm"
}

variable "admin_username" {
  default = "k8sadmin"
}

variable "admin_password" {
  default = "StrongPassword123!#"
}

# SSH key pair generation
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

resource "azurerm_resource_group" "k8s" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "k8s" {
  name                = var.virtual_network_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
}

resource "azurerm_subnet" "k8s" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.k8s.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefixes    = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "k8s" {
  name                = "k8s-nsg"
  resource_group_name = azurerm_resource_group.k8s.name
  location            = azurerm_resource_group.k8s.location

  security_rule {
    name                       = "AllowAllTraffic"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "k8s" {
  name                = var.network_interface_name
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "k8s" {
  name                = "k8s-public-ip"
  resource_group_name = azurerm_resource_group.k8s.name
  location            = azurerm_resource_group.k8s.location
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "k8s" {
  name                = var.virtual_machine_name
  resource_group_name = azurerm_resource_group.k8s.name
  location            = azurerm_resource_group.k8s.location
  size                = "Standard_DS1_v2"

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  network_interface_ids = [azurerm_network_interface.k8s.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }
}


output "private_key" {
  value = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}
