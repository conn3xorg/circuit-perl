# Facts give each host's distribution, which picks the package names.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = try(each.value.os, self.os_id) == self.os_id
      error_message = "Host ${each.key} is ${self.os_id}, not the ${try(each.value.os, "")} its os says."
    }
  }
}

locals {
  # A host object's os stands in for the facts of a host created in the
  # same plan, which can't be read until it exists.
  os     = { for name, h in var.hosts : name => try(h.os, data.conn3x_host.facts[name].os_id) }
  family = { for name, o in local.os : name => contains(["debian", "ubuntu"], o) ? "debian" : "redhat" }

  deb_hosts    = { for name, h in var.hosts : name => h if local.family[name] == "debian" }
  redhat_hosts = { for name, h in var.hosts : name => h if local.family[name] == "redhat" }

  # One cpanm, the same on every distribution: not every one packages it,
  # and Rocky Linux would need EPEL for it.
  cpanm_version = "1.7049"
  cpanm_sha256  = "137e8c5856e09867f6d7631d6d67a5e7778166962e29830c573cbbbab6ed2e21"
}

circuit "perl" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "package" {
    package {
      name = "perl"
    }
  }
}

circuit "deb_modules" {
  hosts = local.deb_hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "module" {
    for_each   = toset(var.distro_modules.debian)
    depends_on = [conn3x_package.perl__package]
    package {
      name = item.value
    }
  }
}

circuit "redhat_modules" {
  hosts = local.redhat_hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "module" {
    for_each   = toset(var.distro_modules.redhat)
    depends_on = [conn3x_package.perl__package]
    package {
      name = item.value
    }
  }
}

# cpanm builds what it installs, and a module with C in it needs a compiler
# and Perl's headers, which the Red Hat family keeps in perl-devel. curl is
# how cpanm reaches MetaCPAN over HTTPS.
circuit "deb_build" {
  hosts = length(var.cpan_modules) > 0 ? local.deb_hosts : {}

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "package" {
    for_each = ["curl", "make", "gcc", "libc6-dev"]
    package {
      name = item.value
    }
  }
}

circuit "redhat_build" {
  hosts = length(var.cpan_modules) > 0 ? local.redhat_hosts : {}

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "package" {
    for_each = ["curl", "make", "gcc", "glibc-devel", "perl-devel"]
    package {
      name = item.value
    }
  }
}

circuit "cpan" {
  hosts = length(var.cpan_modules) > 0 ? var.hosts : {}

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "cpanm" {
    depends_on = [conn3x_package.perl__package, conn3x_package.deb_build__package, conn3x_package.redhat_build__package]
    download {
      url    = "https://raw.githubusercontent.com/miyagawa/cpanminus/${local.cpanm_version}/cpanm"
      sha256 = local.cpanm_sha256
      dest   = "/usr/local/bin/cpanm"
      mode   = "0755"
    }
  }

  # Named by path because sudo's secure_path leaves out /usr/local/bin on
  # the Red Hat family. --notest because a module's own test suite can pull
  # in dozens of test-only dependencies. The check also fails when a Perl
  # upgrade leaves a compiled module unable to load, so it gets rebuilt.
  step "module" {
    for_each = var.cpan_modules
    command {
      command = "/usr/bin/perl /usr/local/bin/cpanm --notest --quiet '${item.key}@${item.value}'"
      unless  = "[ \"$(/usr/bin/perl -M'${item.key}' -e 'print ${item.key}->VERSION' 2>/dev/null)\" = '${item.value}' ]"
    }
  }
}
