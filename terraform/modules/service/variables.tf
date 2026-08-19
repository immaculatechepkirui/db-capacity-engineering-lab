variable "service_name" {
  type = string
  validation {
    condition     = length(trimspace(var.service_name)) > 0
    error_message = "service_name must not be empty."
  }
}

variable "app_ami_id" {
  type = string
  validation {
    condition     = length(trimspace(var.app_ami_id)) > 0
    error_message = "app_ami_id must be set from the pipeline output."
  }
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "secret_arn" {
  type = string
  validation {
    condition     = startswith(var.secret_arn, "arn:aws:secretsmanager:")
    error_message = "secret_arn must be a valid Secrets Manager ARN."
  }
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type    = string
  default = "defaultdb"
}

variable "tags" {
  type    = map(string)
  default = {}
}
