output "perl" {
  description = "Path of the Perl interpreter on each host, by host name. It's the same on every supported distribution; the version isn't."
  value       = { for name in keys(var.hosts) : name => "/usr/bin/perl" }
}
