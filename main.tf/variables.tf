variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins. Change if not free-tier eligible in your region."
  type        = string
  default     = "t3.micro"
}
