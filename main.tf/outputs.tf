output "eks_node_private_key" {
  description = "Private key for EKS node SSH access"
  value       = tls_private_key.eks_node_key.private_key_pem
  sensitive   = true
}

output "eks_node_private_key_file_content" {
  description = "Private key content to save to a file"
  value       = tls_private_key.eks_node_key.private_key_pem
  sensitive   = true
}
