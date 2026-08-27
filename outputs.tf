output "public_ip" {
  description = "Public IPv4 of the instance. Billed at $0.005/hour."
  value       = aws_instance.app.public_ip
}

output "web_url" {
  description = "Open this once cloud-init finishes (2-4 minutes after apply)."
  value       = "http://${aws_instance.app.public_ip}"
}

output "ssh" {
  description = "Shell into the box."
  value       = "ssh ubuntu@${aws_instance.app.public_ip}"
}

output "boot_log" {
  description = "Watch the build finish."
  value       = "ssh ubuntu@${aws_instance.app.public_ip} 'sudo tail -f /var/log/cloud-init-output.log'"
}
