variable "port" {
  type    = number
  default = 2310
}

module "perl" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  distro_modules = {
    debian = ["libtry-tiny-perl"]
    redhat = ["perl-Try-Tiny"]
  }
  cpan_modules = { "Text::Trim" = "1.04" }
}

output "perl" {
  value = module.perl.perl
}
