provider "google" {
version = "3.5.0"
credentials = file("C:/Users/cnyaga/Desktop/gcpcloud/infonation-008976ff00ba.json")
project = "infonation"
region = "${var.region}"
zone = "${var.region}-a"
}


resource "google_compute_firewall" "firewall" {
  name    = "gritfy-firewall-externalssh"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["externalssh"]
}
resource "google_compute_firewall" "webserverrule" {
  name    = "gritfy-webserver"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["80","443"]
  }
  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["webserver"]
}
# We create a public IP address for our google compute instance to utilize
resource "google_compute_address" "static" {
  name = "vm-public-address"
  project = var.project
  region = "${var.region}"
  depends_on = [ google_compute_firewall.firewall ]
}
resource "google_compute_disk" "disk" {
    name  = "my-disk"
    image = "centos-cloud/centos-8"
    size  = 50
    type  = "pd-ssd"
    zone  = "us-central1-a"
}
resource "google_compute_instance" "dev" {
  name         = "devserver"
  machine_type = "f1-micro"
  zone         = "${var.region}-a"
  tags         = ["externalssh","webserver"]
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-8"
    }
  }
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.user
      timeout     = "500s"
      private_key = file(var.privatekeypath)
    }
    inline = [
      "sudo yum -y install epel-release",
      "sudo yum -y install nginx",
      "sudo nginx -v",
      "yum install cloud-init",
      "yum install Ansible",
      "sudo cloud-init init",
      "echo 'Challenge: Automation end to end' > /usr/share/nginx/www/index.html",
      "docker run -d -p 80:80 --name automation-end2end -v /usr/share/nginx/www/index.html:/usr/share/nginx/www/index.html --restart=always nginx"
          ]
  }
  # Ensure firewall rule is provisioned before server, so that SSH doesn't fail.
  depends_on = [ google_compute_firewall.firewall, google_compute_firewall.webserverrule ]
  service_account {
    email  = var.email
    scopes = ["compute-ro"]
  }
  metadata = {
    ssh-keys = "${var.user}:${file(var.publickeypath)}"
  }
}