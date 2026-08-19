output "secret_arn" {
  description = "Secrets Manager secret ARN."
  value       = module.data.secret_arn
}

output "secret_name" {
  description = "Secrets Manager secret name."
  value       = module.data.secret_name
}

output "alb_dns_name" {
  description = "ALB DNS name."
  value       = module.service.alb_dns_name
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.service.instance_id
}

output "instance_private_ip" {
  description = "EC2 instance private IP."
  value       = module.service.instance_private_ip
}
