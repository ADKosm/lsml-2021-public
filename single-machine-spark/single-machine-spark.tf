provider "azurerm" {
  # Провайдер, с которым будем работать. В данном случае - Azure
  version = "=2.40.0"
  features {}
}

# Группа ресурсов. К ней будут линковаться все осталные ресурсы
resource "azurerm_resource_group" "lsml_rg" {
  name = "lsml-resource-group-spark"
  location = "westus"
}

# Виртуальная сеть внутри облака
resource "azurerm_virtual_network" "lsml_vn" {
  resource_group_name = azurerm_resource_group.lsml_rg.name
  location = azurerm_resource_group.lsml_rg.location

  name = "lsml-vitrual-network-spark"

  address_space = ["10.0.0.0/16"]
  # Пул адресов внутри сети
}

# Виртуальная подсеть внутри облака
resource "azurerm_subnet" "lsml_subnet" {
  resource_group_name = azurerm_resource_group.lsml_rg.name
  virtual_network_name = azurerm_virtual_network.lsml_vn.name

  name = "internal"

  address_prefixes = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "lsml_pub_ip" {
  location = azurerm_resource_group.lsml_rg.location
  resource_group_name = azurerm_resource_group.lsml_rg.name

  name = "lsml-public-ip-spark"

  allocation_method = "Dynamic" # Выдаем динамический ip
  idle_timeout_in_minutes = 30
  domain_name_label = "sparkmachine" # Для удобства можно использовать DNS имя
}

# Сетевой интерфейс для нашей машины
resource "azurerm_network_interface" "lsml_ni" {
  location = azurerm_resource_group.lsml_rg.location
  resource_group_name = azurerm_resource_group.lsml_rg.name

  name = "lsml-nic-spark"

  ip_configuration {
    name = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.lsml_subnet.id
    public_ip_address_id = azurerm_public_ip.lsml_pub_ip.id
  }
}

# Сама виртуальная машина
resource "azurerm_virtual_machine" "lsml_vm" {
  resource_group_name = azurerm_resource_group.lsml_rg.name
  location = azurerm_resource_group.lsml_rg.location

  name = "lsml-machine-spark"

  vm_size = "Standard_E32d_v4" # 32 CPU 256 GB  https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/#edv4-series

  network_interface_ids = [
    azurerm_network_interface.lsml_ni.id,
    # Подключаем к сети
  ]

  storage_image_reference {
    # Используем образ Ubuntu 16.04
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "18.04-LTS"
    version = "latest"
  }

  os_profile {
    computer_name = "hostname"
    admin_username = "azureuser" # Пользователь и его пароль
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
    // ssh_keys {
    //   path = "/home/azureuser/.ssh/authorized_keys"
    //   key_data = file("~/id_rsa.pub") # Можем указать наш ключ, как ключ для авторизации на машине
    // }
  }

  delete_os_disk_on_termination = true
  storage_os_disk {
    name = "main-disk"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb = "300" # Указываем какой использовать основной жесткий диск и его размер
  }

  connection {
    # Указываем, как подключиться к машине. Будем использовать ssh с паролем и доменным именем
    type = "ssh"
    user = "azureuser"
    password = "Password1234!"
    host = "${azurerm_public_ip.lsml_pub_ip.domain_name_label}.${azurerm_resource_group.lsml_rg.location}.cloudapp.azure.com"
  }

  provisioner "remote-exec" { # Запускаем удаленно
    script = "bootstrap.sh" # Указываем, какой скрипт запустить
  }

  provisioner "file" {
    source = "pyspark-example.ipynb"
    destination = "/jupyter/pyspark-example.ipynb"
  }
}


# Сохраним несколько важных значений в output. Их можно будет потом использовать для наших целей

data "azurerm_public_ip" "lsml_public_ip" {
  name = azurerm_public_ip.lsml_pub_ip.name
  resource_group_name = azurerm_virtual_machine.lsml_vm.resource_group_name
}

output "public_domain" {
  # Домен нашего сервера
  value = "${azurerm_public_ip.lsml_pub_ip.domain_name_label}.${azurerm_resource_group.lsml_rg.location}.cloudapp.azure.com"
}

output "public_ip" {
  # Публичный ip нашего сервера
  value = data.azurerm_public_ip.lsml_public_ip.ip_address
}

output "private_ip" {
  # Приватный ip нашего сервера
  value = azurerm_network_interface.lsml_ni.private_ip_address
}

output "jupyter_endpoint" {
  value = "http://${azurerm_network_interface.lsml_ni.private_ip_address}:8888/tree"
}
