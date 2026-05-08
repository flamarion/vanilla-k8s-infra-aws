# Self-Managed Kubernetes on AWS

Production-grade, self-managed Kubernetes cluster on AWS EC2, fully automated
with Terraform and Ansible. The whole stack is generic and portable — no
vendor- or app-specific assumptions baked in.

- [Architecture](#architecture)
- [Traffic flow](#traffic-flow)
- [What gets deployed](#what-gets-deployed)
  - [Infrastructure (Terraform)](#infrastructure-terraform)
  - [Cluster (Ansible)](#cluster-ansible)
- [Prerequisites](#prerequisites)
- [Generate SSH keys](#generate-ssh-keys)
- [Project structure](#project-structure)
- [Step-by-step deployment](#step-by-step-deployment)
- [Sizing the cluster (single or multi-controller)](#sizing-the-cluster-single-or-multi-controller)
- [SSH access](#ssh-access)
- [Common operations](#common-operations)
- [MySQL: post-install customization](#mysql-post-install-customization)
- [Ingress and SSL configuration](#ingress-and-ssl-configuration)
- [Upgrading Kubernetes](#upgrading-kubernetes)
- [Tearing down](#tearing-down)
- [Further reading](#further-reading)

## Architecture

```
                  ┌────────────────────────────────────────────────────┐
                  │                        VPC                         │
                  │                                                    │
  ┌──────────┐    │  ┌─ Public subnets (3 AZs) ─────────────────────┐  │
  │ Internet │────┼─▶│  ┌─────────────┐            ┌─────────┐      │  │
  └──────────┘    │  │  │     NLB     │            │ Bastion │      │  │
                  │  │  │ TCP 80/443  │            │  (SSH)  │      │  │
                  │  │  │ TCP 6443    │            └────┬────┘      │  │
                  │  │  └──────┬──────┘                 │           │  │
                  │  └─────────┼────────────────────────┼───────────┘  │
                  │            │                        │ SSH jump     │
                  │            ▼                        ▼              │
                  │  ┌─ Private subnets (3 AZs) ────────────────────┐  │
                  │  │                                              │  │
                  │  │  ┌────────┐   ┌────────┐   ┌────────┐        │  │
                  │  │  │ ctrl-1 │   │ ctrl-2 │   │ ctrl-3 │        │  │
                  │  │  │  AZ-a  │   │  AZ-b  │   │  AZ-c  │        │  │
                  │  │  └───┬────┘   └───┬────┘   └───┬────┘        │  │
                  │  │      └─────┬──────┴──────┬─────┘             │  │
                  │  │            ▼             ▼                   │  │
                  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐      │  │
                  │  │  │ worker-1 │ │ worker-2 │ │ worker-3 │      │  │
                  │  │  │   AZ-a   │ │   AZ-b   │ │   AZ-c   │      │  │
                  │  │  └────┬─────┘ └────┬─────┘ └────┬─────┘      │  │
                  │  │       └──────┬─────┴──────┬─────┘            │  │
                  │  │              ▼            ▼                  │  │
                  │  │       ┌──────────┐  ┌───────────┐            │  │
                  │  │       │    DB    │  │ S3 Bucket │            │  │
                  │  │       │ (MySQL)  │  │  (data)   │            │  │
                  │  │       └──────────┘  └───────────┘            │  │
                  │  │                                              │  │
                  │  └──────────────────────────────────────────────┘  │
                  └────────────────────────────────────────────────────┘
```

The diagram shows a 3-controller HA topology, but the project supports any
number of controllers (1 for dev, 3+ for HA). See
[Sizing the cluster](#sizing-the-cluster-single-or-multi-controller).

## Traffic flow

```
User request (HTTPS)
  │
  ▼
NLB (TCP passthrough, port 443)
  │
  ▼
Cilium Envoy (NodePort 30443, terminates SSL with Let's Encrypt cert)
  │
  ▼
K8s Service → Application Pod
```

## What gets deployed

### Infrastructure (Terraform)

| Resource        | Details                                                                     |
| --------------- | --------------------------------------------------------------------------- |
| VPC             | 3 AZs, public + private subnets, 1 NAT gateway per AZ                       |
| NLB             | Internet-facing, TCP passthrough on 80, 443, and 6443                       |
| EC2             | Configurable instances via a single map (controllers, workers, DB, bastion) |
| S3              | Optional buckets with versioning, lifecycle, CORS                           |
| IAM             | K8s node role with EBS CSI, S3, and cert-manager DNS policies               |
| Security Groups | Bastion, K8s nodes, DB — least-privilege rules                              |
| Route53         | DNS records for NLB, bastion, and all instances                             |
| Key Pair        | EC2 key pair from your SSH public key                                       |

### Cluster (Ansible)

| Component      | Version | Purpose                                                      |
| -------------- | ------- | ------------------------------------------------------------ |
| Kubernetes     | 1.35.x  | HA control plane (1 or N controllers) via kubeadm            |
| Cilium         | 1.17.x  | CNI, kube-proxy replacement, ingress controller, Gateway API |
| cert-manager   | latest  | SSL certificates via Let's Encrypt (DNS-01 challenge)        |
| EBS CSI        | 2.56.x  | Persistent volumes with gp3 encrypted StorageClass           |
| Metrics Server | latest  | Node/pod metrics for HPA and `kubectl top`                   |
| MySQL          | 8.x     | Optional vanilla MySQL server on the `db` node (no databases or users created by default) |

## Prerequisites

- AWS account with CLI configured (`aws configure` or SSO)
- A Route53 public hosted zone for your domain (used by cert-manager DNS-01)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- Python 3.10+ with a virtualenv for Ansible
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) >= 2.15
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster access
- An SSH key pair (see below)

## Generate SSH keys

**Do not commit private keys to Git.** Generate a dedicated key pair for this
project:

```bash
# Ed25519 key pair, no passphrase (for automation)
ssh-keygen -t ed25519 -f deployment -C "k8s-deployer" -N ""
```

This creates two files:

- `deployment` — private key (keep secret, never commit)
- `deployment.pub` — public key (safe to commit)

Add the **public key** to your `terraform.tfvars`:

```hcl
ssh_public_key = "ssh-ed25519 AAAA... k8s-deployer"
# or
ssh_public_key = file("../../../deployment.pub")
```

The Ansible inventory script auto-discovers the **private key** in this order:

1. `SSH_KEY_PATH` environment variable
2. `ANSIBLE_PRIVATE_KEY_FILE` environment variable
3. `./deployment` (default — relative to the repo root)

```bash
# Example: point Ansible at a key in another location
export SSH_KEY_PATH=~/.ssh/k8s-deployer
```

## Project structure

```
.
├── README.md                  ← You are here
├── CLAUDE.md                  Instructions for Claude Code (assistant)
├── setup/
│   └── test-cluster.yaml      End-to-end cluster validation manifest
├── terraform/                 Infrastructure as Code
│   ├── modules/               Generic, reusable modules
│   │   ├── compute/           EC2 instances
│   │   ├── nlb/               Network Load Balancer
│   │   ├── s3/                S3 buckets
│   │   ├── iam/               IAM roles + policies
│   │   ├── dns/               Route53 records
│   │   └── security-group/    Security groups
│   ├── environments/
│   │   └── lab/               Example environment (rename or copy for yours)
│   ├── main.tf                Module composition
│   ├── variables.tf           Module interface
│   └── README.md              Terraform module documentation
└── ansible/                   Cluster configuration
    ├── ansible.cfg
    ├── requirements.yml
    ├── inventory/
    │   ├── terraform_inventory.py     Dynamic inventory from `terraform output`
    │   └── group_vars/
    │       ├── all.yml                Global vars (K8s version, domain, ports)
    │       ├── controllers.yml
    │       ├── workers.yml
    │       └── databases.yml          MySQL config (optional)
    ├── roles/                         common, containerd, k8s_*, cilium, ebs_csi, mysql, ...
    ├── playbooks/
    │   ├── site.yml                   Full deployment
    │   ├── k8s_cluster.yml            K8s only (no MySQL)
    │   └── mysql.yml                  MySQL only
    └── README.md                      Ansible documentation
```

## Step-by-step deployment

### 1. Provision infrastructure

```bash
cd terraform/environments/lab

# Bootstrap your config
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars      # set namespace, region, domain, instances, etc.

terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Prepare Ansible

```bash
cd ../../../ansible

source ~/.virtualenvs/ansible/bin/activate
ansible-galaxy collection install -r requirements.yml   # first time only

# Make sure `domain_name` in inventory/group_vars/all.yml matches the value
# in terraform.tfvars — it's referenced by kubeadm certSANs and cert-manager.

ansible all -m ping                                      # connectivity check
```

### 3. Deploy the cluster

```bash
ansible-playbook playbooks/site.yml
```

### 4. Access the cluster

The kubeconfig is written to `ansible/kubeconfig` by the
`k8s_controller_init` role; it points at the NLB endpoint
(`k8scontroller.<domain>:6443`) so it works from anywhere.

```bash
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes
kubectl get pods -A
```

### 5. Validate

```bash
# Edit setup/test-cluster.yaml first and replace `app.example.com` with one
# of your `application_subdomains` from terraform.tfvars.

kubectl apply -f ../setup/test-cluster.yaml
kubectl get pods,pvc,certificate -n cluster-validation

# Should respond with HTTP/2 200 and a Let's Encrypt certificate
curl -sI https://<your-subdomain>.<your-domain>

kubectl delete -f ../setup/test-cluster.yaml
```

## Sizing the cluster (single or multi-controller)

The `instances` map in `terraform.tfvars` is the only source of truth for
cluster shape. Add or remove entries as needed; roles drive everything else.

### Minimal single-controller dev cluster

```hcl
instances = {
  bastion      = { role = "bastion",    instance_type = "t3.micro",  volume_size = 20,  subnet_type = "public"  }
  controller-1 = { role = "controller", instance_type = "m5.xlarge", volume_size = 100, subnet_type = "private" }
  worker-1     = { role = "worker",     instance_type = "m5.large",  volume_size = 100, subnet_type = "private" }
}
```

A single-controller deployment is fully supported:

- `playbooks/site.yml` joins extra controllers via `controllers[1:]` — an
  empty slice when there's only one, so the join step is a no-op.
- The control-plane taint is left **off** when there are no workers, so the
  controller can also schedule application pods (single-node deployments).
- The `db` node and the `bastion` are both optional — drop them if you don't
  need MySQL or external SSH.

### HA cluster

For production, run an odd number of controllers (3 or 5) for etcd quorum
and place each in a separate AZ. Workers can be sized and scaled
independently.

To add a node, append to the `instances` map and re-run `terraform apply`
followed by `ansible-playbook playbooks/site.yml` — Ansible is idempotent,
only new nodes get configured.

## SSH access

All instances are in private subnets except the bastion. Use the bastion as a
jump host:

```bash
# Bastion
ssh -i deployment ubuntu@$(cd terraform/environments/lab && terraform output -raw bastion_ip)

# Any private node via the bastion
ssh -o ProxyJump=ubuntu@$(cd terraform/environments/lab && terraform output -raw bastion_ip) \
    -i deployment ubuntu@<private-ip>
```

## Common operations

### Add a worker node

Edit `terraform/environments/lab/terraform.tfvars`:

```hcl
instances = {
  # ... existing entries ...
  worker-4 = {
    role          = "worker"
    instance_type = "m5.xlarge"
    volume_size   = 100
    subnet_type   = "private"
  }
}
```

```bash
cd terraform/environments/lab && terraform apply -auto-approve
cd ../../../ansible && ansible-playbook playbooks/site.yml
```

### Add a controller node

Same as above with `role = "controller"`. Controllers run etcd, so keep the
total count at 1 (dev) or an odd number ≥ 3 (HA).

### Add a DNS record for an application

Append the subdomain to `application_subdomains` in `terraform.tfvars`:

```hcl
application_subdomains = ["app", "grafana", "argocd"]
```

```bash
cd terraform/environments/lab && terraform apply -auto-approve
```

This creates CNAMEs pointing to the NLB. Then expose your service via an
Ingress (see [Ingress and SSL configuration](#ingress-and-ssl-configuration)).

### Add an S3 bucket

```hcl
s3_buckets = {
  data    = { manage_versioning = true, versioning_status = "Suspended" }
  backups = { manage_versioning = true, versioning_status = "Enabled", lifecycle_enabled = true }
}
```

The Kubernetes node IAM role automatically gets full access to all buckets
managed by the module.

### Change instance size

Editing `instance_type` replaces the instance. After `terraform apply`, re-run
`ansible-playbook playbooks/site.yml` to rejoin the node.

## MySQL: post-install customization

The `db` node is **optional**. If your `instances` map contains no entries
with `role = "db"`, MySQL is never installed.

When present, the `mysql` role installs a vanilla MySQL 8.0 server, sets the
root password, and exposes it on the private network. By default, **no
databases or users are created** — bring your own.

### Customize via Ansible group_vars

Edit `ansible/inventory/group_vars/databases.yml`:

```yaml
mysql_root_password: "ChangeMeNow!"
mysql_bind_address: "0.0.0.0"

# Optional server tuning. Each key/value becomes `key = value` under [mysqld]
# in /etc/mysql/mysql.conf.d/tuning.cnf and triggers a MySQL restart.
mysql_server_config:
  max_connections: "500"
  innodb_buffer_pool_size: "4G"

# Optional databases to create
mysql_databases:
  - name: appdb
    encoding: utf8mb4
    collation: utf8mb4_general_ci

# Optional application users
mysql_users:
  - name: appuser
    password: "ChangeMeNow!"
    host: "%"
    priv: "appdb.*:ALL"
```

Then re-run only the MySQL playbook:

```bash
ansible-playbook playbooks/mysql.yml
```

### Customize manually on the host

```bash
# SSH to the DB node
ssh -o ProxyJump=ubuntu@<bastion-ip> -i deployment ubuntu@<db-private-ip>

# Local root login uses /root/.my.cnf (passwordless)
sudo mysql

# Create whatever you need
CREATE DATABASE myapp CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'myapp'@'%' IDENTIFIED BY 'StrongPasswordHere';
GRANT ALL ON myapp.* TO 'myapp'@'%';
FLUSH PRIVILEGES;
```

Server tuning files live in `/etc/mysql/mysql.conf.d/`. Restart with
`sudo systemctl restart mysql` after editing.

## Ingress and SSL configuration

Cilium is the ingress controller. Every Ingress resource needs the `cilium`
ingress class, a cert-manager annotation, and a TLS block.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    ingress.cilium.io/force-https: "true"
    ingress.cilium.io/x-forwarded-for: "true"
spec:
  ingressClassName: cilium
  tls:
    - hosts:
        - my-app.example.com
      secretName: my-app-tls           # cert-manager creates this Secret
  rules:
    - host: my-app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-svc
                port:
                  number: 8080
```

What happens automatically:

1. cert-manager sees the annotation and creates a `Certificate` resource.
2. cert-manager uses the DNS-01 challenge (Route53 TXT records) to validate.
3. Let's Encrypt issues the cert and stores it in the named Secret.
4. Cilium Envoy picks up the cert and terminates TLS on NodePort 30443.
5. HTTP requests on NodePort 30080 get a 301 redirect to HTTPS.

### Gateway API (alternative)

The cluster also installs Gateway API CRDs. To use a `Gateway` + `HTTPRoute`
setup instead of Ingress, point your Gateway at `gatewayClassName: cilium`
and reference it from `HTTPRoute.parentRefs`.

### Cilium Ingress annotations (reference)

| Annotation                          | Values                                    | Purpose                                |
| ----------------------------------- | ----------------------------------------- | -------------------------------------- |
| `cert-manager.io/cluster-issuer`    | `letsencrypt-prod`, `letsencrypt-staging` | Which CA issues the cert               |
| `ingress.cilium.io/force-https`     | `"true"`                                  | 301 redirect HTTP to HTTPS             |
| `ingress.cilium.io/x-forwarded-for` | `"true"`                                  | Add X-Forwarded-For/Proto/Host headers |
| `ingress.cilium.io/websocket`       | `"true"`                                  | Enable WebSocket support               |
| `ingress.cilium.io/request-timeout` | `"60s"`                                   | Upstream request timeout               |

### Debugging SSL issues

```bash
kubectl get certificate -A
kubectl get certificaterequest -A
kubectl get challenges -A
kubectl logs -n cert-manager -l app=cert-manager --tail=50
curl -svk https://my-app.example.com 2>&1 | grep -E 'subject:|issuer:|expire'
```

## Upgrading Kubernetes

Kubernetes upgrades happen one minor version at a time (e.g. 1.35 → 1.36) and
are run **manually**, then pinned in Ansible.

### Step 1: Upgrade controllers (one at a time)

```bash
# On each controller:
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt update
sudo apt install -y kubeadm=1.36.* kubelet=1.36.* kubectl=1.36.*
sudo apt-mark hold kubeadm kubelet kubectl
```

On the **first controller only**:

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.x
```

On every other controller:

```bash
sudo kubeadm upgrade node
```

Then restart kubelet on all controllers:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Step 2: Upgrade workers (one at a time)

```bash
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data

# SSH to the worker
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt update
sudo apt install -y kubeadm=1.36.* kubelet=1.36.* kubectl=1.36.*
sudo apt-mark hold kubeadm kubelet kubectl
sudo kubeadm upgrade node
sudo systemctl daemon-reload
sudo systemctl restart kubelet

kubectl uncordon worker-1
```

### Step 3: Pin the new version

Update `ansible/inventory/group_vars/all.yml`:

```yaml
k8s_version: "1.36"
k8s_package_version: "1.36.*"
```

Future Ansible runs and new node additions will then use 1.36.

## Tearing down

```bash
# Delete cluster-side test resources first
kubectl delete -f setup/test-cluster.yaml

cd terraform/environments/lab
terraform destroy -auto-approve
```

### Rebuilding from scratch

```bash
cd terraform/environments/lab
terraform destroy -auto-approve
terraform apply -auto-approve

cd ../../../ansible
rm -rf .ansible_fact_cache
ansible-playbook playbooks/site.yml
```

## Further reading

- [Terraform module documentation](terraform/README.md)
- [Ansible playbook documentation](ansible/README.md)
- [Terraform environments guide](terraform/environments/README.md)
