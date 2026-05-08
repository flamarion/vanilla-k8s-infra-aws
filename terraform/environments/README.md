# Environments

Each subdirectory is an independent Terraform workspace that calls the root
module (`../../`) with environment-specific configuration.

## Existing environments

| Directory | Purpose                                    |
|-----------|--------------------------------------------|
| `lab/`    | K8s reproduction lab (eu-central-1)        |

## Creating a new environment

```bash
# 1. Create the directory
mkdir environments/my-env
cd environments/my-env

# 2. Bootstrap from an existing environment
cp ../lab/providers.tf .
cp ../lab/main.tf .
cp ../lab/variables.tf .
cp ../lab/outputs.tf .
cp ../lab/terraform.tfvars terraform.tfvars

# 3. Edit terraform.tfvars with your values
#    At minimum change: namespace, aws_region, aws_profile

# 4. Deploy
terraform init
terraform plan
terraform apply
```

## Key points

- **Provider config lives here**, not in the root module. Each environment sets
  its own region, profile, and default tags. **Do not** set `required_providers`
  or version constraints in the environment -- the root module's `versions.tf`
  owns those to prevent incompatible provider versions.
- **State is per-environment**. Each directory has its own `.terraform/` and
  state file. Environments are completely independent.
- **The root module has sensible defaults** for optional variables. An
  environment only needs to set `namespace`, `instances`, and `ssh_public_key`
  at minimum — everything else falls back to defaults.
- **Ansible outputs are per-environment**. Run
  `terraform output -json ansible_inventory > inventory.json` from inside the
  environment directory.

## Naming convention

Use short, descriptive names: `lab`, `staging`, `production`, `customer-acme`,
`perf-test`. The `namespace` variable inside `terraform.tfvars` is what
prefixes AWS resources — keep the directory name and namespace aligned.
