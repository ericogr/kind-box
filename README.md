# KindBox

**KindBox** is a lightweight Bash script that sets up a temporary Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/) and creates a fully configured testing environment. It provisions a pod with essential tools and enables shared remote access via [sshx](https://sshx.io/). This project is ideal for experimenting with Kubernetes, testing scripts, or collaborative development in a safe sandbox environment.

## Features

- Creates a multi-node Kubernetes cluster using Kind.
- Sets up a dedicated namespace and service account.
- Provides `kubectl` access both inside and outside the pod.
- Installs useful tools inside a pod (`bash`, `curl`, `kubectl`, `sshx`, etc.).
- Shared SSH access to the pod for collaborative testing or demonstrations.
- Fully ephemeral environment: easy to create and destroy.

## Requirements

- [Docker](https://www.docker.com/) installed and running.
- [Kind](https://kind.sigs.k8s.io/) installed (`v0.29.0` tested).
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed (`v1.27.3` tested).
- Bash shell (Linux/macOS recommended).

## Usage

### Just Run
```bash
wget -qO- https://raw.githubusercontent.com/ericogr/kind-box/main/script.sh | bash
```
### Clone the repository

```bash
git clone https://github.com/yourusername/kindbox.git
cd kindbox
```
### Run the setup script

```bash
chmod +x kindbox.sh
./kindbox.sh
```

### Wait for the pod to be ready.
The script will automatically wait until the pod is fully running.

### Access the shared pod environment

```bash
kubectl --kubeconfig ./kubeconfig-kind.yaml -n sshx-ns logs -f sshx-shell
```
Once you open the link displayed in the logs, you will have access to a shell inside the pod with kubectl pre-configured for the Kind cluster.

### Uninstall

```bash
kind delete clusters kind-sshx
```

## How It Works
- Creates a multi-node Kind cluster (kind-sshx) with a dedicated kubeconfig file.
- Sets up a namespace (sshx-ns) and a service account with cluster-admin permissions.
- Creates a ConfigMap with the kubeconfig file for in-cluster access.
- Deploys a pod (sshx-shell) with:
  - kubectl installed and configured
  - Essential tools: bash, curl, coreutils
  - sshx installed for remote shared access
- Provides instructions to connect to the pod using the link shown in the logs.

## Notes
- The environment is intended for testing, learning, and collaboration, not for production workloads.
- The pod is ephemeral. You can delete the cluster with:

```bash
kind delete cluster --name kind-sshx
```

### Tested on:

- Kind: v0.29.0
- Go: 1.24.2
  Linux/amd64
