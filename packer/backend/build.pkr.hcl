packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "ssh_username" {
  type = string
}

variable "jar_file" {
  type    = string
  default = "spring-boot-data-jpa-0.0.1-SNAPSHOT.jar"
}

source "googlecompute" "test-image" {
  project_id                  = var.project_id
  zone                        = var.zone
  credentials_json            = file("service-account.json")

  source_image_family         = "debian-12"
  image_description           = "Image for bezkoder's spring-boot-react-mysql backend"
  ssh_username                = var.ssh_username
  tags                        = ["packer"]

  image_name                  = "bezkoder-backend-{{timestamp}}"
  instance_name               = "pkr-bezkoder-backend-{{uuid}}"
}

build {
  sources = ["sources.googlecompute.test-image"]

  provisioner "shell" {
    inline = [
      "sudo apt update",
      "sudo apt install git maven -y",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo useradd -m -d /opt/bezkoder-backend -s /bin/bash backend"
    ]
  }

  provisioner "file" {
    source      = var.jar_file
    destination = "/tmp/${var.jar_file}"
  }

  provisioner "file" {
    source      = "application.properties"
    destination = "/tmp/application.properties"
  }

  provisioner "file" {
    source      = "bezkoder-backend.service"
    destination = "/tmp/bezkoder-backend.service"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/${var.jar_file} /tmp/application.properties /opt/bezkoder-backend",
      "sudo mv /tmp/bezkoder-backend.service /etc/systemd/system/bezkoder-backend.service",
      "sudo systemctl enable bezkoder-backend.service"
    ]
  }
}
