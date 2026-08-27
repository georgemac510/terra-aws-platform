variable "project" {
  description = "Prefix for every resource name and tag."
  type        = string
  default     = "mckurz-platform"
}

variable "region" {
  description = "AWS region. Cheapest is usually us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 size. t3.micro is plenty for three small containers."
  type        = string
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Root EBS volume in GB. Docker images need headroom."
  type        = number
  default     = 20
}

variable "repo_url" {
  description = "Public HTTPS clone URL of the app repo, containing docker-compose.yml and services/."
  type        = string
}

variable "db_password" {
  description = "Postgres password written into .env on the instance."
  type        = string
  sensitive   = true
}

variable "public_key_path" {
  description = "Local SSH public key to install on the instance."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# No default on purpose. Opening SSH to 0.0.0.0/0 gets you scanned within
# minutes, so Terraform will refuse to run until you set this.
variable "ssh_cidr" {
  description = "CIDR allowed to SSH. Use YOUR.IP.HERE/32."
  type        = string
}
