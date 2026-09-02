output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the control plane."
  value       = module.eks.cluster_version
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN (IRSA)."
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  description = "Command to merge this cluster into your kubeconfig."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs (nodes, Karpenter, internal LBs)."
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs (NAT, internet-facing LBs)."
  value       = module.vpc.public_subnets
}

output "karpenter_node_role_name" {
  description = "IAM role name to put in EC2NodeClass.spec.role."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN assumed by Karpenter-provisioned nodes."
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_queue_name" {
  description = "SQS queue Karpenter watches for Spot interruption / rebalance."
  value       = module.karpenter.queue_name
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller (Pod Identity + IRSA)."
  value       = module.karpenter.iam_role_arn
}

output "velero_bucket" {
  description = "Primary Velero S3 bucket name."
  value       = aws_s3_bucket.velero.id
}

output "velero_bucket_replica" {
  description = "Replica Velero S3 bucket in the DR region."
  value       = aws_s3_bucket.velero_replica.id
}

output "velero_role_arn" {
  description = "IRSA role ARN to annotate on the velero ServiceAccount."
  value       = aws_iam_role.velero.arn
}

output "vault_unseal_key_id" {
  description = "KMS key id for Vault auto-unseal (Helm: server.ha.config)."
  value       = aws_kms_key.vault.key_id
}

output "vault_role_arn" {
  description = "IRSA role ARN to annotate on the vault ServiceAccount."
  value       = aws_iam_role.vault.arn
}
