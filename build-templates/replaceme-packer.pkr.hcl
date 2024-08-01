packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "client_id" {
  type    = string
  default = "${env("ARM_CLIENT_ID")}"
}

variable "client_secret" {
  type    = string
  default = "${env("GH_TOKEN")}"
}

variable "subscription_id" {
  type    = string
  default = "${env("ARM_SUBSCRIPTION_ID")}"
}

variable "tenant_id" {
  type    = string
  default = "${env("ARM_TENANT_ID")}"
}

variable "github_source" {
  type    = string
  default = "MBleezy/Ansible-Packer-Lab"
}

variable "git_commit_sha" {
  type    = string
  default = "unknown"
}

variable "image_version" {
  type    = string
  default = "1.0.0"
}

variable "skip_create_image" {
  type    = bool
  default = true
}

variable "STORAGE_ACCOUNT_NAME" {
  type    = string
  default = "replace.me"
}

variable "DOMAIN_USER" {
  type    = string
  default = "${env("DOMAIN_USER")}"
}

variable "DOMAIN_PASS" {
  type    = string
  default = "${env("DOMAIN_PASS")}"
}

source "azure-arm" "packer" {
  client_id                          = var.client_id
  client_secret                      = var.client_secret
  subscription_id                    = var.subscription_id
  tenant_id                          = var.tenant_id
  communicator                       = "winrm"
  image_offer                        = "windows-10"
  image_publisher                    = "MicrosoftWindowsDesktop"
  image_sku                          = "win10-22h2-avd-g2"
  location                           = "East US"
  os_type                            = "Windows"
  vm_size                            = "Standard_D4ds_v5"
  winrm_insecure                     = true
  winrm_timeout                      = "3m"
  winrm_use_ssl                      = true
  winrm_username                     = "packer"
  managed_image_storage_account_type = "Premium_LRS"

  azure_tags = {
    BuildDate = "${formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())}"
    Source    = "https://github.com/${var.github_source}"
    Commit    = var.git_commit_sha
    CreatedBy = "Packer Automation"
    BaseImage = "win10-22h2-avd"
  }

  virtual_network_name                   = "github-runner-vnet"
  virtual_network_subnet_name            = "default"
  virtual_network_resource_group_name    = "mbleezarde-sandbox"

  # Skip image creation for PR check
  skip_create_image = var.skip_create_image
  shared_image_gallery_destination {
    subscription        = "${var.subscription_id}"
    gallery_name        = "mb_gallery"
    image_name          = "W10_AVD"
    replication_regions = ["eastus"]
    resource_group      = "mbleezarde-sandbox"
    image_version       = var.image_version
    specialized         = false
  }
}

build {
  sources = ["source.azure-arm.packer"]

  # Run script to allow Ansible to connect to the VM
  provisioner "powershell" {
    script = "scripts/ConfigureRemotingForAnsible.ps1"
  }

  # Install pywinrm using pipx to allow Ansible to connect to the VM
  provisioner "shell-local" {
    inline_shebang = "/bin/bash -e"
    inline = [
      "pipx inject ansible-core pywinrm",
    ]
  }

  # Run Ansible playbook to configure the VM
  provisioner "ansible" {
    skip_version_check = false
    user               = "packer"
    use_proxy          = false
    playbook_file      = "ansible/replaceme-ansible-playbook.yml"
    ansible_env_vars = [
      "STORAGE_ACCOUNT_NAME=${var.STORAGE_ACCOUNT_NAME}",
      "DOMAIN_USER=${var.DOMAIN_USER}",
      "DOMAIN_PASS=${var.DOMAIN_PASS}"
    ]
    extra_arguments = [
      "-e",
      "ansible_winrm_server_cert_validation=ignore",
      "-e",
      "ansible_winrm_transport=ntlm",
      "-vvv"
    ]
  }
}
