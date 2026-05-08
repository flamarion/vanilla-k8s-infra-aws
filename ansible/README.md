# Ansible — Kubernetes Cluster Bootstrap

Ansible playbooks and roles to bootstrap a production-grade Kubernetes cluster
on the infrastructure provisioned by the Terraform module. Works for
single-controller dev clusters and multi-controller HA clusters alike.

## What gets deployed

| Component      | Version | Description                                                  |
| -------------- | ------- | ------------------------------------------------------------ |
| Kubernetes     | 1.35.x  | HA control plane via kubeadm (1 or N controllers)            |
| Cilium         | 1.17.x  | CNI, kube-proxy replacement, ingress controller, Gateway API |
| Gateway API    | v1.2.1  | CRDs for Cilium Gateway API support                          |
| cert-manager   | latest  | SSL certificates via Let's Encrypt DNS-01 (Route53)          |
| EBS CSI        | 2.56.x  | Persistent volumes with encrypted gp3 default StorageClass   |
| Metrics Server | latest  | Node/pod metrics for HPA and `kubectl top`                   |
| MySQL          | 8.x     | Optional vanilla MySQL — no databases/users created by default |

## Prerequisites

- Terraform infrastructure deployed (`terraform apply` in `../terraform/environments/<env>/`)
- Python virtual environment with Ansible installed
- SSH private key — defaults to `./deployment` at repo root, override with `SSH_KEY_PATH`
- Ansible Galaxy collections installed

## Build the full stack

```bash
cd ansible

# 1. Activate the Ansible virtual environment
source ~/.virtualenvs/ansible/bin/activate

# 2. Install Ansible Galaxy collections (first time only)
ansible-galaxy collection install -r requirements.yml

# 3. Verify connectivity to all hosts through the bastion
ansible all -m ping

# 4. Deploy the full stack (K8s + Cilium + EBS CSI + cert-manager + optional MySQL)
ansible-playbook playbooks/site.yml

# 5. Access the cluster
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes
kubectl get pods -A
```

The SSH private key is auto-discovered in this order:

1. `SSH_KEY_PATH` environment variable
2. `ANSIBLE_PRIVATE_KEY_FILE` environment variable
3. `./deployment` relative to the repo root

## Run individual components

```bash
# K8s cluster only (no MySQL)
ansible-playbook playbooks/k8s_cluster.yml

# MySQL only
ansible-playbook playbooks/mysql.yml

# Dry run (check what would change without executing)
ansible-playbook playbooks/site.yml --check
```

## Playbook execution order

```
1. common               All nodes      Hostname, swap, packages, chrony
2. containerd           K8s nodes      Container runtime with systemd cgroup
3. k8s_prereqs          K8s nodes      Kernel modules, kubeadm/kubelet/kubectl
4. k8s_controller_init  ctrl[0]        kubeadm init, generate join tokens
5. cilium               ctrl[0]        CNI + ingress (NodePort 30080/30443)
6. k8s_controller_join  ctrl[1:]       Join as control plane (serial, no-op
                                       when there is only one controller)
7. k8s_worker_join      workers        Join as worker nodes
7.5 cilium/reconcile    ctrl[0]        Restart cilium-operator so the
                                       Ingress/Gateway reconciler re-probes
                                       Gateway API CRDs against the now-complete
                                       control plane (harmless on single-node)
8. ebs_csi              ctrl[0]        EBS CSI driver + gp3 StorageClass
9. metrics_server       ctrl[0]        Metrics server for HPA
10. cert_manager        ctrl[0]        cert-manager + Let's Encrypt issuers
11. mysql               db (optional)  MySQL server (no DBs/users by default)
```

Cilium installs **before** any node joins. This ensures the first controller
is fully functional with CNI before other nodes are added, preventing API
server instability.

## Project structure

```
ansible/
├── ansible.cfg                       Configuration (inventory, escalation, SSH)
├── requirements.yml                  Galaxy collections
├── inventory/
│   ├── terraform_inventory.py        Dynamic inventory from Terraform output
│   └── group_vars/
│       ├── all.yml                   Global vars (K8s version, domain, ports)
│       ├── controllers.yml           Controller-specific vars
│       ├── workers.yml               Worker-specific vars
│       └── databases.yml             MySQL config (optional)
├── roles/
│   ├── common/                       Base OS config
│   ├── containerd/                   Container runtime
│   ├── k8s_prereqs/                  kubeadm, kubelet, kubectl
│   ├── k8s_controller_init/          kubeadm init on first controller
│   ├── k8s_controller_join/          kubeadm join --control-plane
│   ├── k8s_worker_join/              kubeadm join
│   ├── cilium/                       Cilium CNI + Gateway API + ingress
│   ├── ebs_csi/                      EBS CSI driver + gp3 StorageClass
│   ├── metrics_server/               Metrics server for HPA
│   ├── cert_manager/                 cert-manager + ClusterIssuers
│   └── mysql/                        Vanilla MySQL server
└── playbooks/
    ├── site.yml                      Full deployment
    ├── k8s_cluster.yml               K8s-only deployment
    └── mysql.yml                     MySQL-only deployment
```

## Inventory

The inventory is **dynamic** — it runs `terraform output` automatically on
every Ansible command. There is no generation step.

```bash
# View the inventory
./inventory/terraform_inventory.py --list | jq .

# Tree view
ansible-inventory --graph
```

The inventory script injects a `ProxyCommand` so all non-bastion hosts are
reached via the bastion SSH jump. The SSH key is included in the ProxyCommand
automatically.

```bash
# Use a different Terraform environment
TF_ENV_DIR=../../terraform/environments/staging ansible-playbook playbooks/site.yml

# Use a different SSH key
SSH_KEY_PATH=~/.ssh/my_key ansible-playbook playbooks/site.yml
```

### Host groups

| Group         | Hosts                  | Purpose                                  |
| ------------- | ---------------------- | ---------------------------------------- |
| `bastion`     | bastion (optional)     | SSH jump host (not targeted by playbooks) |
| `controllers` | controller-N           | K8s control plane nodes                  |
| `workers`     | worker-N (optional)    | K8s worker nodes                         |
| `databases`   | db (optional)          | MySQL server                             |
| `k8s`         | controllers + workers  | All Kubernetes nodes                     |

## Configuration

### Kubernetes

Edit `inventory/group_vars/all.yml`:

```yaml
k8s_version: "1.35"
domain_name: "example.com"     # must match terraform.tfvars
control_plane_endpoint: "k8scontroller.{{ domain_name }}:6443"
pod_network_cidr: "10.244.0.0/16"
cilium_version: "1.17.3"
```

### MySQL (optional)

The MySQL role installs a vanilla server only — no app-specific databases or
users are created by default. Edit `inventory/group_vars/databases.yml` to
customize:

```yaml
mysql_root_password: "ChangeMeNow!"
mysql_bind_address: "0.0.0.0"

# Optional: server tuning. Each key/value becomes `key = value` under
# [mysqld] in /etc/mysql/mysql.conf.d/tuning.cnf.
mysql_server_config:
  max_connections: "500"
  innodb_buffer_pool_size: "4G"

# Optional: databases to create
mysql_databases:
  - name: appdb
    encoding: utf8mb4
    collation: utf8mb4_general_ci

# Optional: application users
mysql_users:
  - name: appuser
    password: "ChangeMeNow!"
    host: "10.0.%"
    priv: "appdb.*:ALL"
```

If your `instances` map in `terraform.tfvars` has no `role = "db"` entries,
the MySQL role is skipped entirely.

## Adding nodes

1. Add the instance to `terraform.tfvars` in the `instances` map
2. Run `terraform apply`
3. Run `ansible-playbook playbooks/site.yml` — idempotent, only new nodes
   get configured

## Single-controller deployments

The playbooks fully support a single-controller deployment:

- `controllers[1:]` is an empty slice with one controller, so join steps no-op.
- The `cilium` role uses `inventory_hostname` for taint commands rather than
  a hardcoded `controller-1`, so the controller can be named anything.
- When there are no workers, the control-plane taint is left off so the
  controller can also schedule application pods (single-node clusters).

For HA, use an odd number of controllers (3 or 5) for etcd quorum.

## Rebuilding from scratch

```bash
cd ../terraform/environments/lab
terraform destroy -auto-approve
terraform apply -auto-approve

cd ../../../ansible
rm -rf .ansible_fact_cache
ansible-playbook playbooks/site.yml
```

## Kubeconfig

After deployment, the kubeconfig is saved to `ansible/kubeconfig` with the NLB
endpoint (`k8scontroller.<domain>:6443`). Use it from anywhere:

```bash
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes
```
