# Official EKS Module - File Organization

This module wraps the official Terraform AWS modules for EKS deployment.

## File Structure

```
module-official/
├── locals.tf              # Local values and computed variables
├── vpc.tf                 # VPC configuration (networking)
├── eks-cluster.tf         # EKS cluster configuration
├── eks-node-groups.tf     # Node group definitions (on-demand + spot)
├── iam-irsa.tf           # IAM Roles for Service Accounts
├── variables.tf          # Input variables
├── outputs.tf            # Output values
├── main.tf.backup        # Original single-file version (backup)
└── README.md             # This file
```

## File Purposes

### `locals.tf`
- Computed local values
- Currently defines `cluster_name` for use across resources

### `vpc.tf`
- VPC module configuration
- Public and private subnets
- NAT Gateways (HA - one per AZ)
- Internet Gateway
- Route tables
- Required EKS tags

### `eks-cluster.tf`
- EKS cluster module configuration
- Cluster version and networking
- API endpoint access control
- Cluster logging
- Authentication mode
- Add-ons (CoreDNS, kube-proxy, VPC-CNI, EBS CSI)
- IRSA enablement

### `eks-node-groups.tf`
- Node group configurations as locals
- On-demand node group
- Spot node group (conditional)
- Volume encryption
- Labels and taints
- Scaling configuration

### `iam-irsa.tf`
- IAM Roles for Service Accounts
- EBS CSI Driver role
- Template for additional IRSA roles

### `variables.tf`
- All input variables
- Type definitions
- Descriptions

### `outputs.tf`
- Exported values
- VPC outputs
- EKS cluster outputs
- OIDC provider information
- kubectl configuration command

## Why Split Files?

### Benefits:
1. **Better Organization** - Each file has a clear purpose
2. **Easier Navigation** - Find what you need quickly
3. **Team Collaboration** - Multiple people can work on different files
4. **Maintainability** - Changes are isolated to relevant files
5. **Readability** - Smaller files are easier to understand

### Terraform Behavior:
- Terraform reads ALL `.tf` files in the directory
- Order doesn't matter (Terraform builds dependency graph)
- You can split however makes sense for your project

## Common Patterns

### By Resource Type (What we did):
```
vpc.tf          # All VPC resources
eks-cluster.tf  # All EKS cluster resources
iam-irsa.tf     # All IAM resources
```

### By Functionality:
```
networking.tf   # VPC, subnets, routes
compute.tf      # Node groups, launch templates
security.tf     # Security groups, IAM roles
```

### By Environment:
```
dev.tf          # Dev-specific overrides
prod.tf         # Prod-specific overrides
```

## Usage

No changes needed! Use the module exactly as before:

```hcl
module "eks" {
  source = "../module-official"
  
  cluster-name = "my-cluster"
  # ... other variables
}
```

Terraform automatically loads all `.tf` files.

## Adding New Resources

### Example: Add AWS Load Balancer Controller IRSA

Edit `iam-irsa.tf`:

```hcl
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster-name}-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
```

### Example: Add Fargate Profile

Create new file `eks-fargate.tf`:

```hcl
# Fargate profiles for serverless pods
resource "aws_eks_fargate_profile" "app" {
  cluster_name           = module.eks.cluster_name
  fargate_profile_name   = "app-profile"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = module.vpc.private_subnets

  selector {
    namespace = "app"
  }
}
```

## Best Practices

1. **Keep related resources together** - Don't split too much
2. **Use descriptive filenames** - Clear what's inside
3. **Add comments** - Explain complex configurations
4. **Consistent naming** - Follow a pattern across files
5. **One module per file** - Don't mix multiple modules in one file

## Reverting to Single File

If you prefer the single-file approach:

```bash
cd /Users/ademolaadesina/projects/daas/eks/module-official
rm locals.tf vpc.tf eks-cluster.tf eks-node-groups.tf iam-irsa.tf
mv main.tf.backup main.tf
```

## Notes

- The backup file `main.tf.backup` contains the original single-file version
- Both approaches work identically - this is just organization
- Choose what works best for your team
