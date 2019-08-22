# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "09b1e9fd-5636-43ca-81d4-b82a0e132c44"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "terraformgroup" {
    name     = "132c44-network-eastus2"
    location = "eastus2"

    tags = {
        environment = "ngeag"
    }
}

## Create virtual network
#resource "azurerm_virtual_network" "terraformnetwork" {
#    name                = "132c44-vnet-eastus2"
#    address_space       = ["10.253.12.0/22"]
#    location            = "eastus2"
#    resource_group_name = "${azurerm_resource_group.terraformgroup.name}"
#
#    tags = {
#        environment = "ngeag"
#    }
#}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraformnsg" {
    name                = "132c44-NSG"
    location            = "eastus2"
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

	    security_rule {
        name                       = "dashboard"
        priority                   = 2001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8000"
        source_address_prefix      = "144.160.0.0/16"
        destination_address_prefix = "*"
    }
	
	    security_rule {
        name                       = "http"
        priority                   = 3001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "144.160.0.0/16"
        destination_address_prefix = "*"
    }
	
	    security_rule {
        name                       = "https"
        priority                   = 4001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "144.160.0.0/16"
        destination_address_prefix = "*"
    }
	

    tags = {
        environment = "ngeag"
    }
}

# Retrieving the subnet_id from Azure
data "azurerm_subnet" "subid" {
  name                 = "internal-eastus2"
  virtual_network_name = "132c44-vnet-eastus2"
  resource_group_name  = "${azurerm_resource_group.terraformgroup.name}"
}

output "subnet_id" {
  value = "${data.azurerm_subnet.subid.id}"
}


# Create network interface
resource "azurerm_network_interface" "terraformnicm1" {
    name                      = "NGEAG-NIC-MASTER1"
    location                  = "eastus2"
    resource_group_name       = "${azurerm_resource_group.terraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "NGEAG-NicConfiguration"
        subnet_id                     = "${data.azurerm_subnet.subid.id}"
        private_ip_address_allocation = "Dynamic"        
    }

    tags = {
        environment = "ngeag"
    }
}

# Create network interface
resource "azurerm_network_interface" "terraformnicm2" {
    name                      = "NGEAG-NIC-MASTER2"
    location                  = "eastus2"
    resource_group_name       = "${azurerm_resource_group.terraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "NGEAG-NicConfiguration"
        subnet_id                     = "${data.azurerm_subnet.subid.id}"
        private_ip_address_allocation = "Dynamic"        
    }

    tags = {
        environment = "ngeag"
    }
}

# Create network interface
resource "azurerm_network_interface" "terraformnicm3" {
    name                      = "NGEAG-NIC-MASTER3"
    location                  = "eastus2"
    resource_group_name       = "${azurerm_resource_group.terraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "NGEAG-NicConfiguration"
        subnet_id                     = "${data.azurerm_subnet.subid.id}"
        private_ip_address_allocation = "Dynamic"        
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
    location                    = "eastus2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "ngeag"
    }
}

# Create virtual machine - master1
resource "azurerm_virtual_machine" "terraformvm1" {
    name                  = "ngeagMaster1"
    location              = "eastus2"
    resource_group_name   = "${azurerm_resource_group.terraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.terraformnicm1.id}"]
    vm_size               = "Standard_DS4_v2"

    storage_os_disk {
        name              = "OsDiskM1"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
		disk_size_gb	  = "512"
    }

    storage_image_reference {
	    id = "/subscriptions/b1af8825-0fde-44a1-9ebf-63d5bd0410e4/resourceGroups/att-golden-images/providers/Microsoft.Compute/galleries/ATT_Shared_Images/images/RHEL-7"
    }

    os_profile {
        computer_name  = "master1"
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
        environment = "ngeag"
    }
}

# Create virtual machine - master2
resource "azurerm_virtual_machine" "terraformvm2" {
    name                  = "ngeagMaster2"
    location              = "eastus2"
    resource_group_name   = "${azurerm_resource_group.terraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.terraformnicm2.id}"]
    vm_size               = "Standard_DS4_v2"

    storage_os_disk {
        name              = "OsDiskM2"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
		disk_size_gb	  = "512"
    }

    storage_image_reference {
	    id = "/subscriptions/b1af8825-0fde-44a1-9ebf-63d5bd0410e4/resourceGroups/att-golden-images/providers/Microsoft.Compute/galleries/ATT_Shared_Images/images/RHEL-7"
    }

    os_profile {
        computer_name  = "master2"
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
        environment = "ngeag"
    }
}

# Create virtual machine - master3
resource "azurerm_virtual_machine" "terraformvm3" {
    name                  = "ngeagMaster3"
    location              = "eastus2"
    resource_group_name   = "${azurerm_resource_group.terraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.terraformnicm3.id}"]
    vm_size               = "Standard_DS4_v2"

    storage_os_disk {
        name              = "OsDiskM3"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
		disk_size_gb	  = "512"
    }

    storage_image_reference {
	    id = "/subscriptions/b1af8825-0fde-44a1-9ebf-63d5bd0410e4/resourceGroups/att-golden-images/providers/Microsoft.Compute/galleries/ATT_Shared_Images/images/RHEL-7"
    }

    os_profile {
        computer_name  = "master3"
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
        environment = "ngeag"
    }
}


## scaleset ##


# Create public IPs
resource "azurerm_public_ip" "vmssterraformpublicip" {
    name                         = "PublicIPVMSS"
    location                     = "eastus2"
    resource_group_name          = "${azurerm_resource_group.terraformgroup.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "ngeag"
    }
}

resource "azurerm_lb" "vmss" {
 name                = "132c44-vmss-lb"
 location            = "eastus2"
 resource_group_name = "${azurerm_resource_group.terraformgroup.name}"

 frontend_ip_configuration {
   name                 = "PublicIPVMSS"
   public_ip_address_id = "${azurerm_public_ip.vmssterraformpublicip.id}"
 }

 tags = {
     environment = "ngeag"
 }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
 resource_group_name = "${azurerm_resource_group.terraformgroup.name}"
 loadbalancer_id     = "${azurerm_lb.vmss.id}"
 name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
 resource_group_name = "${azurerm_resource_group.terraformgroup.name}"
 loadbalancer_id     = "${azurerm_lb.vmss.id}"
 name                = "ssh-running-probe"
 port                = "8082"
}

resource "azurerm_lb_rule" "lbnatrule" {
   resource_group_name            = "${azurerm_resource_group.terraformgroup.name}"
   loadbalancer_id                = "${azurerm_lb.vmss.id}"
   name                           = "http"
   protocol                       = "Tcp"
   frontend_port                  = "8083"
   backend_port                   = "8084"
   backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bpepool.id}"
   frontend_ip_configuration_name = "PublicIPVMSS"
   probe_id                       = "${azurerm_lb_probe.vmss.id}"
}

resource "azurerm_virtual_machine_scale_set" "vmss" {
 name                = "vmscaleset"
 location            = "eastus2"
 resource_group_name = "${azurerm_resource_group.terraformgroup.name}"
 upgrade_policy_mode = "Manual"

 sku {
   name     = "Standard_DS4_v2"
   tier     = "Standard"
   capacity = 6
 }
 
  storage_profile_image_reference {
      id = "/subscriptions/b1af8825-0fde-44a1-9ebf-63d5bd0410e4/resourceGroups/att-golden-images/providers/Microsoft.Compute/galleries/ATT_Shared_Images/images/RHEL-7"
 }

 storage_profile_os_disk {
   name              = ""
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }


 storage_profile_data_disk {
   lun          = 0
   caching        = "ReadWrite"
   create_option  = "Empty"
   disk_size_gb   = 512
 }

 os_profile {
   computer_name_prefix = "vmlab"
   admin_username       = "ngeag"
   admin_password       = "ngeagAa1234%^!"
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 network_profile {
   name    = "terraformnetworkprofile"
   primary = true

   ip_configuration {
     name                                   = "IPConfiguration"
     subnet_id                              = "${data.azurerm_subnet.subid.id}"
     load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
     primary = true
   }
 }

 tags = {
     environment = "ngeag"
 }
}






