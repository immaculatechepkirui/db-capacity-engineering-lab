variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_username" {
  type    = string
  default = "avnadmin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "defaultdb"
}

variable "app_ami_id" {
  description = "AMI ID from pipeline. Format: localstack-ec2/app:ami-<sha12>."
  type        = string
  default     = "ami-000000000000"
}
