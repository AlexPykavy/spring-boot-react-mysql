terraform {
  backend "gcs" {
    bucket      = "tms-dos21-onl"
    prefix      = "terraform/state"
    credentials = "service-account.json"
  }
}

provider "google" {
  project     = var.project
  region      = var.region
  credentials = file("service-account.json")
}

data "google_compute_network" "default" {
  name = "default"
}

resource "random_id" "instance_suffix" {
  byte_length = 4
}

resource "random_password" "mysql_root_password" {
  length = 10
}

resource "google_sql_database_instance" "main" {
  name             = "private-mysql-${random_id.instance_suffix.hex}"
  region           = "us-central1"
  database_version = "MYSQL_8_0"
  root_password    = random_password.mysql_root_password.result

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = data.google_compute_network.default.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
}

resource "google_sql_database" "main" {
  name     = "my-database"
  instance = google_sql_database_instance.main.name
}

resource "google_compute_instance" "main" {
  name         = "my-instance-${random_id.instance_suffix.hex}"
  machine_type = "n2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "bezkoder-backend-1724148900"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-EOT
    sudo tee -a /opt/bezkoder-backend/.env <<-EOF
    DB_HOST=${google_sql_database_instance.main.private_ip_address}
    DB_NAME=${google_sql_database.main.name}
    DB_USER=root
    DB_PASSWORD=${random_password.mysql_root_password.result}
    EOF
EOT
}
