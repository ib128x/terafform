# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "09b1e9fd-5636-43ca-81d4-b82a0e132c44"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "terraformgroup" {
    name     = "RG-CentralUS"
    location = "centralus"

    tags = {
        environment = "ngeag"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "terraformnetwork" {
    name                = "NGEAG-VN-CentralUS"
    address_space       = ["10.0.0.0/16"]
    location            = "centralus"
    resource_group_name = "${azurerm_resource_group.terraformgroup.name}"

    tags = {
        environment = "ngeag"
    }
}

# Create subnet
resource "azurerm_subnet" "terraformsubnet" {
    name                 = "NGEAG-Subnet"
    resource_group_name  = "${azurerm_resource_group.terraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.terraformnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
#resource "azurerm_public_ip" "myterraformpublicip" {
#    name                         = "myPublicIP"
#    location                     = "eastus"
#    resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
#    allocation_method            = "Dynamic"
#
#    tags = {
#        environment = "Terraform Demo"
#    }
#}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraformnsg" {
    name                = "NGEAG-NetworkSecurityGroup"
    location            = "centralus"
    resource_group_name = "${azurerm_resource_group.terraformgroup.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "144.160.0.0/16"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "ngeag"
    }
}

# Create network interface
resource "azurerm_network_interface" "terraformnic" {
    name                      = "NGEAG-NIC"
    location                  = "centralus"
    resource_group_name       = "${azurerm_resource_group.terraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "NGEAG-NicConfiguration"
        subnet_id                     = "${azurerm_subnet.terraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
        # public_ip_address_id          = "${azurerm_public_ip.terraformpublicip.id}"
    }

    tags = {
        environment = "ngeag"
    }
}







