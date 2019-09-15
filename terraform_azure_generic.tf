
variable subscription_id {}
variable resource_group {}
variable location {}
variable virtual_network {}
variable subnet {}
variable admin_username {}
variable admin_password {}
variable masters_count {}
variable scaleset_vm_count {}

## should start with az login ##


# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = var.subscription_id
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "terraformgroup" {
    name     = var.resource_group
    location = var.location

    tags = {
        environment = "generic"
    }

## wait 30s after RG were created
#	provisioner "local-exec" {
#	  command = "sleep 30"
#	}
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraformnsg" {
    name                = "${var.resource_group}-NSG"
    location            = var.location
    resource_group_name = var.resource_group
    
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
        name                       = "http"
        priority                   = 1101
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
        priority                   = 1201
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "144.160.0.0/16"
        destination_address_prefix = "*"
    }

	    security_rule {
        name                       = "dashboard"
        priority                   = 1301
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8082"
        source_address_prefix      = "144.160.0.0/16"
        destination_address_prefix = "*"
    }

	    security_rule {
        name                       = "kibana"
        priority                   = 1401
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "5601"
        source_address_prefix      = "144.160.0.0/16"
        destination_address_prefix = "*"
    }
	
    tags = {
        environment = "generic"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "terraformnetwork" {
    name                = "${var.resource_group}-VN"
    address_space       = [var.virtual_network]
    location            = var.location
    resource_group_name = var.resource_group
}

# Create subnet
resource "azurerm_subnet" "terraformsubnet" {
    name                 = "${var.resource_group}-Subnet"
    resource_group_name  = var.resource_group
    virtual_network_name = "${var.resource_group}-VN"
    address_prefix       = "${var.subnet}"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "PublicIP"
    location                     = var.location
    resource_group_name          = var.resource_group
    allocation_method            = "Dynamic"

    tags = {
        environment = "generic"
    }
}


resource "azurerm_network_interface" "terraformnicPub" {
    name                      = "${var.resource_group}-PUBIP"
    location                  = var.location
    resource_group_name       = var.resource_group
    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "${var.resource_group}-NicConfiguration"
        subnet_id                     = "${azurerm_subnet.terraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags = {
        environment = "generic"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = var.resource_group
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = var.resource_group
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "generic"
    }
}

# Create Jump-Server VM
resource "azurerm_virtual_machine" "terraforJumpSrv" {
    name                  = "${var.resource_group}-JumpSrv"
    location              = var.location
    resource_group_name   = var.resource_group
    network_interface_ids = ["${azurerm_network_interface.terraformnicPub.id}"]
	vm_size               = "Standard_DS4_v2"

    storage_os_disk {
        name              = "${var.resource_group}-JumpSrv-OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "jumpsrv"
        admin_username = "${var.admin_username}"
		admin_password = "${var.admin_password}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.storageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "generic"
    }
}


## Create 3 k8s-masters

# Create network interface
resource "azurerm_network_interface" "terraformnicmater" {
    count                     = "${var.masters_count}"
    name                      = "NIC-${count.index+1}"
    location                  = var.location
    resource_group_name       = var.resource_group
    network_security_group_id = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "ip-${count.index+1}"
        subnet_id                     = "${azurerm_subnet.terraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"        
    }

    tags = {
        environment = "generic"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "terraformvm" {
  count                 = "${var.masters_count}"
  name                  = "master-${count.index+1}"
  location              = var.location
  resource_group_name   = var.resource_group
  #network_interface_ids = ["${element(azurerm_network_interface.terraformnicmater.*.id, count.index+1)}"]
  network_interface_ids = ["${element(concat(azurerm_network_interface.terraformnicmater.*.id, list("")), count.index)}"]  

  # 1 vCPU, 3.5 Gb of RAM
  vm_size = "Standard_DS4_v2"

  storage_os_disk {
    name              = "disk-os-${count.index+1}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }


  storage_image_reference {
    # need to copy worker image to the require location if not eastus2 #
	id = "/subscriptions/09b1e9fd-5636-43ca-81d4-b82a0e132c44/resourceGroups/GENERIC/providers/Microsoft.Compute/images/master-image"
  }

  # delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  os_profile {
    computer_name  = "master-${count.index+1}"
    admin_username = "${var.admin_username}"
	admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
      environment = "generic"
  }
}

## scale-set

resource "azurerm_virtual_machine_scale_set" "vmss" {
 name                = "vm-scaleset-${var.resource_group}"
 location            = var.location
 resource_group_name = var.resource_group
 upgrade_policy_mode = "Manual"

 sku {
   name     = "Standard_DS4_v2"
   tier     = "Standard"
   capacity = var.scaleset_vm_count
 }
 
 storage_profile_image_reference {
   #id = "/subscriptions/09b1e9fd-5636-43ca-81d4-b82a0e132c44/resourceGroups/132c44-network-eastus2/providers/Microsoft.Compute/images/ngeag-worker-image"
   id = "/subscriptions/09b1e9fd-5636-43ca-81d4-b82a0e132c44/resourceGroups/GENERIC/providers/Microsoft.Compute/images/worker-image"
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
   computer_name_prefix = "worker"
   admin_username = "${var.admin_username}"
   admin_password = "${var.admin_password}"
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 network_profile {
   name    = "terraformnetworkprofile"
   primary = true

   ip_configuration {
     name                                   = "IPConfiguration"
     subnet_id                              = "${azurerm_subnet.terraformsubnet.id}"
#     load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
     primary = true
   }
 }

 tags = {
     environment = "generic"
 }
}












