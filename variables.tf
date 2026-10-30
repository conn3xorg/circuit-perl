variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file, jump_hosts or os."

  validation {
    condition     = alltrue([for h in var.hosts : contains(["debian", "ubuntu", "rocky", "almalinux", "rhel", "centos", "fedora"], try(h.os, "debian"))])
    error_message = "A host object's os must be one of debian, ubuntu, rocky, almalinux, rhel, centos or fedora."
  }
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "distro_modules" {
  type = object({
    debian = optional(list(string), [])
    redhat = optional(list(string), [])
  })
  default     = {}
  description = "Perl modules to install from the distribution's packages, as package names for each family, such as { debian = [\"libtry-tiny-perl\"], redhat = [\"perl-Try-Tiny\"] }."
}

variable "cpan_modules" {
  type        = map(string)
  default     = {}
  description = "Perl modules to install from CPAN with cpanm, by name, each at an exact version, such as { \"Text::Trim\" = \"1.04\" }. Installs a compiler and make too."

  validation {
    condition     = alltrue([for name in keys(var.cpan_modules) : can(regex("^[A-Za-z_][A-Za-z0-9_]*(::[A-Za-z0-9_]+)*$", name))])
    error_message = "Each key of cpan_modules must be a Perl module name, such as \"Text::Trim\"."
  }

  validation {
    condition     = alltrue([for v in values(var.cpan_modules) : can(regex("^v?[0-9]+(\\.[0-9_]+)*$", v))])
    error_message = "Each version in cpan_modules must be exact, such as \"1.04\", not a range."
  }
}
