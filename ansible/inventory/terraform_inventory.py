#!/usr/bin/env python3
"""
Dynamic Ansible inventory from Terraform output.

Reads the `ansible_inventory` output from a Terraform environment directory
and patches SSH proxy configuration so private hosts are reachable via bastion.

Environment variables:
  TF_ENV_DIR      Path to the Terraform environment directory
                  (default: ../terraform/environments/lab relative to this script)
  SSH_KEY_PATH    Path to the SSH private key for the bastion ProxyCommand
                  (default: ./deployment relative to the ansible directory)
"""

import json
import os
import subprocess
import sys


def get_terraform_output(env_dir: str) -> dict:
    try:
        result = subprocess.run(
            ["terraform", "output", "-json", "ansible_inventory"],
            cwd=env_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running terraform output: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing terraform output: {e}", file=sys.stderr)
        sys.exit(1)


def patch_proxy_args(inventory: dict, ssh_key: str) -> dict:
    """Inject ProxyCommand with explicit identity file for non-bastion hosts."""
    bastion_ip = inventory.get("all", {}).get("vars", {}).get("bastion_host", "")
    if not bastion_ip:
        return inventory

    proxy_cmd = (
        f'-o ProxyCommand="ssh -o StrictHostKeyChecking=no '
        f"-i {ssh_key} -W %h:%p ubuntu@{bastion_ip}\""
    )

    inventory["all"]["vars"]["ansible_ssh_common_args"] = (
        f"-o StrictHostKeyChecking=no {proxy_cmd}"
    )

    # Bastion itself must NOT use the proxy
    if "bastion" in inventory:
        inventory["bastion"].setdefault("vars", {})[
            "ansible_ssh_common_args"
        ] = "-o StrictHostKeyChecking=no"

    for hostvars in inventory.get("_meta", {}).get("hostvars", {}).values():
        if hostvars.get("role") == "bastion":
            hostvars["ansible_ssh_common_args"] = "-o StrictHostKeyChecking=no"

    return inventory


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_env = os.path.normpath(
        os.path.join(script_dir, "..", "..", "terraform", "environments", "lab")
    )
    env_dir = os.environ.get("TF_ENV_DIR", default_env)
    default_ssh_key = os.path.normpath(os.path.join(script_dir, "..", "deployment"))
    ssh_key = os.environ.get("SSH_KEY_PATH", default_ssh_key)

    if "--list" in sys.argv:
        inventory = get_terraform_output(env_dir)
        inventory = patch_proxy_args(inventory, ssh_key)
        print(json.dumps(inventory, indent=2))
    elif "--host" in sys.argv:
        print(json.dumps({}))
    else:
        print(json.dumps({}))


if __name__ == "__main__":
    main()
