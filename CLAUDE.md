# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Self-managed Kubernetes cluster on AWS EC2, provisioned in two stages:

1. **Terraform** (`terraform/`) — AWS infrastructure (VPC, EC2, NLB, S3, IAM, Route53)
2. **Ansible** (`ansible/`) — Cluster bootstrap (kubeadm, Cilium, cert-manager, EBS CSI, optional MySQL)

The two stages are loosely coupled through a dynamic Ansible inventory that reads `terraform output`. There is no generation step — every Ansible command re-runs Terraform to discover hosts.

The project is generic and portable: no app-specific values are baked in. The `lab/` Terraform environment is just an example — copy or rename it for your own deployment.

## Commands

All commands assume the repo root as the working directory unless stated otherwise.

### Full deploy

```bash
# 1. Provision AWS infrastructure
cd terraform/environments/lab
terraform init
terraform apply -auto-approve

# 2. Bootstrap the cluster
cd ../../../ansible
source ~/.virtualenvs/ansible/bin/activate
ansible-galaxy collection install -r requirements.yml   # first time only
ansible all -m ping                                     # connectivity check
ansible-playbook playbooks/site.yml                     # full stack
```

### Partial / targeted runs

```bash
ansible-playbook playbooks/k8s_cluster.yml      # K8s + add-ons, no MySQL
ansible-playbook playbooks/mysql.yml            # MySQL only
ansible-playbook playbooks/site.yml --check     # dry run
ansible-playbook playbooks/site.yml --tags <role-tag>
ansible-playbook playbooks/site.yml --limit worker-1
```

### Cluster access

```bash
export KUBECONFIG=$PWD/ansible/kubeconfig
kubectl get nodes
```

The kubeconfig is written by the `k8s_controller_init` role and uses the NLB endpoint (`k8scontroller.<domain>:6443`), so it works from any machine that can resolve the domain.

**Claude is pre-authorized to load this KUBECONFIG and run `kubectl`, `helm`, `cilium`, and related read/debug commands against the lab cluster without asking first.** Still confirm before destructive actions (delete, drain, helm uninstall, `kubectl apply` of anything substantial).

### Validation

```bash
# Edit setup/test-cluster.yaml first — replace `app.example.com` with one of
# your `application_subdomains` from terraform.tfvars.
kubectl apply -f setup/test-cluster.yaml
kubectl get pods,pvc,certificate -n cluster-validation
kubectl delete -f setup/test-cluster.yaml
```

### AWS CLI against this environment

The AWS profile and region are in `terraform/environments/lab/terraform.tfvars` (`aws_profile`, `aws_region`). For any `aws ...` call, export them first — the shell doesn't inherit them from Terraform:

```bash
export AWS_PROFILE=$(awk -F'"' '/aws_profile/{print $2}' terraform/environments/lab/terraform.tfvars)
export AWS_REGION=$(awk -F'"'  '/aws_region/ {print $2}' terraform/environments/lab/terraform.tfvars)
```

### Inventory inspection

```bash
cd ansible
./inventory/terraform_inventory.py --list | jq .
ansible-inventory --graph
```

### Teardown

```bash
cd terraform/environments/lab
terraform destroy -auto-approve
```

### Rebuild from scratch

```bash
cd terraform/environments/lab && terraform destroy -auto-approve && terraform apply -auto-approve
cd ../../../ansible && rm -rf .ansible_fact_cache && ansible-playbook playbooks/site.yml
```

## Architecture

### Terraform composition

The root of `terraform/` is a **reusable module**, not an environment. You never run `terraform apply` in `terraform/` — only in `environments/<name>/`, which calls the root module with environment-specific variables.

- `terraform/versions.tf` — **owns provider version constraints**. Environments must NOT set `required_providers` (prevents version conflicts).
- `terraform/environments/<name>/providers.tf` — per-environment region, profile, default tags.
- `terraform/modules/` — generic building blocks (`compute`, `nlb`, `s3`, `iam`, `dns`, `security-group`) that are project-agnostic and usable standalone.
- All EC2 instances come from a single `instances` map keyed by hostname; `role` (`bastion` | `controller` | `worker` | `db`) drives SG, IAM profile, NLB membership, and subnet placement. To add a node, add a map entry and `terraform apply`.

### Cluster sizing — single or HA

The `instances` map is the only source of truth for cluster shape. There is no hard requirement for 3 controllers — the playbooks work with a single controller too:

- `controllers[1:]` is an empty slice when there's only one controller, so the join step is a no-op.
- The `cilium` role uses `inventory_hostname` (not a hardcoded `controller-1`) for taint operations, so any controller name works.
- The control-plane taint is **left off** when there are no workers, so a single controller can also schedule application pods.
- The `db` and `bastion` nodes are optional — drop them from `instances` if you don't need them.

For HA production deployments, use an odd number of controllers (3 or 5) for etcd quorum.

### NLB traffic flow (TCP passthrough)

| Port | Target | Purpose |
|------|--------|---------|
| 80   | NodePort 30080 | HTTP ingress → Cilium Envoy (redirects to HTTPS) |
| 443  | NodePort 30443 | HTTPS ingress → Cilium Envoy terminates TLS |
| 6443 | 6443 (controllers) | kubeadm HA control plane endpoint |

The NLB does no TLS termination — Cilium Envoy on each controller holds the Let's Encrypt certs issued by cert-manager via DNS-01 (Route53).

### Ansible playbook sequencing

The order in `playbooks/site.yml` is load-bearing. Critical ordering:

- **Cilium installs on `controllers[0]` BEFORE any other node joins.** Joining additional controllers or workers before CNI is ready causes API server instability.
- Control-plane joins run `serial: 1` — etcd quorum changes must be one-at-a-time.
- EBS CSI / metrics-server / cert-manager run on `controllers[0]` only (single-invocation Helm installs against the API).
- A `cilium-operator` rollout-restart runs after all nodes have joined to re-probe Gateway API CRDs against the now-complete control plane (skip is harmless on single-controller deployments).

### Inventory is dynamic

`ansible/inventory/terraform_inventory.py` shells out to `terraform output -json ansible_inventory` on every invocation and patches a `ProxyCommand` into `ansible_ssh_common_args` so private hosts are reached through the bastion. The `bastion` host is excluded from the proxy (it IS the proxy) and from all playbooks (see `hosts: all:!bastion` in `site.yml`).

```bash
# Point Ansible at a different environment without editing files
TF_ENV_DIR=../../terraform/environments/staging ansible-playbook playbooks/site.yml

# Use a different SSH key (default is ./deployment relative to the repo root)
SSH_KEY_PATH=~/.ssh/my_key ansible-playbook playbooks/site.yml
```

### Version pinning

All component versions live in `ansible/inventory/group_vars/all.yml` (`k8s_version`, `cilium_version`, `ebs_csi_chart_version`, etc.). Ports (`ssh_port`, `k8s_api_port`, `mysql_port`) are mirrored between Terraform variables and this file — they must match. The `domain_name` is also mirrored — it must match `terraform.tfvars`.

### Kubernetes upgrades are manual-then-pin

Upgrades are **not** done by re-running Ansible with a new version. Run `kubeadm upgrade` on each node manually (see README § "Upgrading Kubernetes"), then bump `k8s_version` / `k8s_package_version` in `group_vars/all.yml` so future runs and new nodes use the upgraded version.

### MySQL is opt-in and minimal

The `mysql` role installs a vanilla MySQL 8.0 server, sets the root password, and configures bind-address. It does **not** create any application databases or users by default. To create them, populate `mysql_databases`, `mysql_users`, and (optionally) `mysql_server_config` in `ansible/inventory/group_vars/databases.yml`. If `instances` contains no `db` node, MySQL is never installed.

## Conventions

- **Secrets are not in Git.** SSH private key defaults to `./deployment` (override with `SSH_KEY_PATH`). MySQL passwords live in `group_vars/databases.yml` (lab values — rotate for any real use). `terraform.tfvars` is gitignored.
- **Adding a DNS record for an app:** append to `application_subdomains` in `terraform.tfvars` → `terraform apply` → create an Ingress with `ingressClassName: cilium` + `cert-manager.io/cluster-issuer: letsencrypt-prod`. cert-manager handles the cert automatically.
- **Adding an S3 bucket:** append to `s3_buckets` map in `terraform.tfvars` → `terraform apply`. The K8s node IAM role gets access to all buckets managed by the module.
- **Changing instance size:** editing `instance_type` replaces the instance. After `terraform apply`, re-run `ansible-playbook playbooks/site.yml` to rejoin the node.
