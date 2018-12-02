provider "google" {
    credentials = "${file("account.json")}"
    project     = "gdg-cloud-lviv"
    region      = "us-central1"
}
resource "google_compute_address" "workshop-static-ip" {
  name = "workshop-static-ip"
  network_tier = "STANDARD"
  address_type = "EXTERNAL"
}

resource "google_compute_address" "workshop-server" {
  name         = "workshop-server"
  machine_type = "f1-micro"
  zone         = "us-central1-a"
  description  = "Server for GDG Cloud Lviv workshop!"

  tags = ["api"]

  boot_disk {
    initialize_params {
      image = "family/coreos-stable"
      size = 30
      type = "pd-standard"
    }
  }

  network_interface {
    network = "default"

    access_config {
        network_tier = "STANDARD"
        nat_ip = "${google_compute_address.workshop-static-ip.address}"
    }
  }

  metadata {
    sshKeys   = "gdglviv:${file("~/.ssh/id_rsa.pub")}"
    user-data = "${file("cloud-config.yml")}"
  }
}

resource "google_compute_firewall" "api" {
  name    = "traefik"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_tags = ["api"]
}

resource "google_compute_firewall" "traefik" {
  name    = "traefik"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["<MY PUBLIC IP>/32"]
}