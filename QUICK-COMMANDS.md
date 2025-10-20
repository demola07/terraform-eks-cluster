# Quick Command Reference

## 🚀 Deployment Commands

```bash
# Navigate to project
cd /Users/ademolaadesina/projects/daas/eks/eks

# Initialize
terraform init

# Plan
terraform plan -var-file=dev-official.tfvars

# Deploy
terraform apply -var-file=dev-official.tfvars

# Destroy
terraform destroy -var-file=dev-official.tfvars
```

## 🔐 Access Bastion

```bash
# Get instance ID
INSTANCE_ID=$(terraform output -raw bastion_instance_id)

# Connect via SSM (recommended)
aws ssm start-session --target $INSTANCE_ID --region us-east-1

# Or get the full command
terraform output bastion_ssm_command
```

## ☸️ Kubernetes Commands (From Bastion)

```bash
# Get nodes
kubectl get nodes

# Get all pods
kubectl get pods -A

# Get services
kubectl get svc -A

# Launch K9s UI
k9s

# Get cluster info
kubectl cluster-info

# Describe node
kubectl describe node <node-name>
```

## 📊 Check Status

```bash
# Terraform outputs
terraform output

# Bastion status
aws ec2 describe-instances --instance-ids $INSTANCE_ID

# EKS cluster status
aws eks describe-cluster --name dev-daas-eks-cluster

# Node group status
aws eks describe-nodegroup \
  --cluster-name dev-daas-eks-cluster \
  --nodegroup-name dev-daas-eks-cluster-ondemand-nodes
```

## 🛠️ Useful Aliases (Pre-configured on Bastion)

```bash
k       # kubectl
kgp     # kubectl get pods
kgs     # kubectl get svc
kgn     # kubectl get nodes
kga     # kubectl get all
kd      # kubectl describe
kl      # kubectl logs
kex     # kubectl exec -it
```

## 💾 Save Outputs

```bash
# Save all outputs
terraform output > cluster-info.txt

# Save specific output
terraform output bastion_instance_id > bastion-id.txt
terraform output cluster_name > cluster-name.txt
```

## 🔄 Update Cluster

```bash
# After changing tfvars
terraform plan -var-file=dev-official.tfvars
terraform apply -var-file=dev-official.tfvars
```

## 🧹 Cleanup

```bash
# Stop bastion (save money)
aws ec2 stop-instances --instance-ids $INSTANCE_ID

# Start bastion
aws ec2 start-instances --instance-ids $INSTANCE_ID

# Destroy everything
terraform destroy -var-file=dev-official.tfvars
```
