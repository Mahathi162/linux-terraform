# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    subscription_id = "c90e3d0d-7080-4628-b93b-0107fa7a76e7"
    features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg" {
    name     = "mm185548-linux-rg"
    location = "eastus"

    tags = {
        environment = "Prep"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "mm185548-Vnet"
    address_space       = ["10.1.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.rg.name

    tags = {
        environment = "Prep"
    }
}

# Create subnet
resource "azurerm_subnet" "subnet" {
    name                 = "mm185548-Subnet"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes       = ["10.1.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "publicip" {
    name                         = "mm185548-PublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.rg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Prep"
    }
}

# Create Network Security Group and rule to allow SSH traffic on TCP port 22
resource "azurerm_network_security_group" "nsg" {
    name                = "mm185548-nsg"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Prep"
    }
}

# Create virtual network interface card (NIC) connects your VM to a given virtual network,
# public IP address, and network security group
resource "azurerm_network_interface" "NIC" {
    name                      = "mm185548-NIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.rg.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.publicip.id
    }

    tags = {
        environment = "Prep"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.NIC.id
    network_security_group_id = azurerm_network_security_group.nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "vmrestore" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        #resource_group = azurerm_resource_group.rg.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.vmrestore.hex}"
    resource_group_name         = azurerm_resource_group.rg.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Prep"
    }
}

# Create (and display) an SSH key
#resource "tls_private_key" "example_ssh" {
 # algorithm = "RSA"
 # rsa_bits = 4096
#}
#output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "Linux_vm" {
    name                  = "mm185548_linux_vm"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.rg.name
    network_interface_ids = [azurerm_network_interface.NIC.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "mm185548-vm"
    admin_username = "azureuser"
    admin_password = "P@ssword123!"
    disable_password_authentication = false

    #admin_ssh_key {
        #username       = "azureuser"
        #public_key     = tls_private_key.example_ssh.public_key_openssh
    #}

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Prep"
    }
}