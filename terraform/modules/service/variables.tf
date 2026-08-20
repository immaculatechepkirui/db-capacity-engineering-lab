variable "service_name" {
  description = "Base name for resources in this module."
  type        = string
  default     = "regional-health"
}

variable "app_ami_id" {
  description = "LocalStack Docker-backed AMI id, e.g. localstack-ec2/app:ami-<sha12>."
  type        = string
  validation {
    condition     = can(regex("^ami-[0-9a-f]{12}$", var.app_ami_id))
    error_message = "app_ami_id must be ami- followed by exactly 12 lowercase hex chars."
  }
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "app_port" {
  description = "Port the app listens on; nginx proxies to it."
  type        = number
  default     = 3000
}

variable "secret_arn" {
  description = "ARN of the credential secret — the ARN only, never the value."
  type        = string
}

variable "db_endpoint" {
  description = "Aiven MySQL hostname the instance connects to."
  type        = string
}

variable "db_port" {
  description = "Aiven MySQL port (Aiven-assigned high port, not 3306)."
  type        = number
}

variable "db_name" {
  description = "Database name."
  type        = string
  default     = "defaultdb"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
