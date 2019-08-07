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
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "PublicIP"
    location                     = "centralus"
    resource_group_name          = "${azurerm_resource_group.terraformgroup.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "ngeag"
    }
}

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
#resource "azurerm_network_interface" "terraformnic" {
#    name                      = "NGEAG-NIC"
#    location                  = "centralus"
#    resource_group_name       = "${azurerm_resource_group.terraformgroup.name}"
#    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"
#
#    ip_configuration {
#        name                          = "NGEAG-NicConfiguration"
#        subnet_id                     = "${azurerm_subnet.terraformsubnet.id}"
#        private_ip_address_allocation = "Dynamic"
#    }
#
#    tags = {
#        environment = "ngeag"
#    }
#}

# Create network interface
resource "azurerm_network_interface" "terraformnic" {
    name                      = "NGEAG-PUB-NIC"
    location                  = "centralus"
    resource_group_name       = "${azurerm_resource_group.terraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "NGEAG-NicConfiguration"
        subnet_id                     = "${azurerm_subnet.terraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags = {
        environment = "ngeag"
    }
}



# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.terraformgroup.name}"
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.terraformgroup.name}"
    location                    = "centralus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "ngeag"
    }
}


# Create Jump-Server VM
resource "azurerm_virtual_machine" "terraformvm" {
    name                  = "ngeagJumpServer"
    location              = "centralus"
    resource_group_name   = "${azurerm_resource_group.terraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.terraformnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "vm"
        admin_username = "ngeag"
		admin_password = "ngeagAa1234%^!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.storageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "centralus"
    }
}


# Create virtual machine
resource "azurerm_virtual_machine" "terraformvm" {
    name                  = "ngeagNode1"
    location              = "centralus"
    resource_group_name   = "${azurerm_resource_group.terraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.terraformnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "vm"
        admin_username = "ngeag"
		admin_password = "ngeagAa1234%^!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.storageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "centralus"
    }
}





