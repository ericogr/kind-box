#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="kind-tmate"
KUBECONFIG_FILE="$(pwd)/kubeconfig-kind.yaml"
NAMESPACE="tmate-ns"
POD_NAME="tmate-shell"

echo "Tested on Kind v0.29.0, Go 1.24.2, Linux/amd64"
echo
echo "👉 Creating Kind cluster: $CLUSTER_NAME"
kind create cluster --name "$CLUSTER_NAME" --kubeconfig "$KUBECONFIG_FILE" --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

echo "👉 Creating namespace $NAMESPACE"
kubectl --kubeconfig "$KUBECONFIG_FILE" create namespace "$NAMESPACE"

echo "👉 Creating default ServiceAccount in namespace $NAMESPACE"
kubectl --kubeconfig "$KUBECONFIG_FILE" -n "$NAMESPACE" create serviceaccount default || true

echo "👉 Creating ConfigMap with kubeconfig"
kubectl --kubeconfig "$KUBECONFIG_FILE" -n "$NAMESPACE" create configmap kubeconfig-cm \
  --from-file=kubeconfig.yaml="$KUBECONFIG_FILE" --dry-run=client -o yaml \
  | kubectl --kubeconfig "$KUBECONFIG_FILE" -n "$NAMESPACE" apply -f -

echo "👉 Ensuring admin permissions for the ServiceAccount"
kubectl --kubeconfig "$KUBECONFIG_FILE" create clusterrolebinding tmate-admin \
  --clusterrole=cluster-admin \
  --serviceaccount="$NAMESPACE:default"

echo "👉 Creating in-cluster kubeconfig ConfigMap"
cat <<EOF | kubectl --kubeconfig "$KUBECONFIG_FILE" -n "$NAMESPACE" apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubeconfig-cm
data:
  kubeconfig.yaml: |
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        server: https://kubernetes.default.svc:443
      name: in-cluster
    contexts:
    - context:
        cluster: in-cluster
        user: in-cluster
      name: in-cluster
    current-context: in-cluster
    users:
    - name: in-cluster
      user:
        tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
EOF

echo "👉 Creating Pod with tools installed"
cat <<'EOF' | kubectl --kubeconfig "$KUBECONFIG_FILE" -n "$NAMESPACE" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tmate-shell
spec:
  serviceAccountName: default
  securityContext:
    fsGroup: 1000
  containers:
  - name: shell
    image: ubuntu:24.04
    command: ["/bin/sh", "-c"]
    args:
      - |
        set -eux
        apt-get update && apt-get install -y bash curl openssh-client coreutils
        # apt-get install -y tmate
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt || echo "v1.27.3")
        curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
        chmod +x kubectl && mv kubectl /usr/local/bin/
        mkdir -p /root/.kube
        cp /config/kubeconfig.yaml /root/.kube/config
        # alternativa instalar tmate
        # tmate -F
        curl -sSf https://sshx.io/get | sh
        sshx
    stdin: true
    tty: true
    volumeMounts:
    - name: kubeconfig
      mountPath: /config
    securityContext:
      runAsUser: 0
      runAsGroup: 0
      runAsNonRoot: false
      allowPrivilegeEscalation: false
      privileged: false
      capabilities:
        drop: ["ALL"]
        add: ["SETUID", "SETGID", "CHOWN", "DAC_OVERRIDE", "FOWNER"]
      seccompProfile:
        type: RuntimeDefault
  volumes:
  - name: kubeconfig
    configMap:
      name: kubeconfig-cm
EOF

echo "👉 Waiting for Pod to start..."
kubectl --kubeconfig "$KUBECONFIG_FILE" -n "$NAMESPACE" wait --for=condition=Ready pod/$POD_NAME --timeout=120s

echo
echo "✅ Environment ready!"
echo "Use this command to see the sshx link (SSH/WEB):"
echo "  kubectl --kubeconfig $KUBECONFIG_FILE -n $NAMESPACE logs -f $POD_NAME"
echo
echo "Once you open the sshx link, you will have access to the Pod shell with kubectl configured for the newly created Kind cluster."