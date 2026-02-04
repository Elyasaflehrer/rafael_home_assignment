# !/bin/bash
echo "Deployment starting"

CLUSTER_NAME="kind"

# List existing clusters and check if the desired name exists
if kind get clusters | grep -qw "$CLUSTER_NAME"; then
    echo "Kind cluster '$CLUSTER_NAME' already exists."
    echo "Remove the cluster 'kind delete cluster --name kind' to start the process"
    exit 0  # or 1 if you want to indicate "already exists" as an error
else
    echo "Installing kind cluster"
    kind create cluster --config assets/kind.yaml --name kind
fi

echo "installing Argocd"
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.0-rc4/manifests/install.yaml

ARGOCD_NAMESPACE="argocd"
argocd_installation_complated=1

while [[ $argocd_installation_complated -eq 1 ]] ; do
mapfile -t pod_statuses < <(kubectl -n ${ARGOCD_NAMESPACE} get po --no-headers | awk '{print $3}' | tr -d '\r')
if [[ $(echo "$pod_statuses" | grep -v '^Running$' | wc -l) -eq 0 ]]; then
    echo "Finsied to setup argocd"
    echo "Admin password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{.data.password}}' | base64 --decode)"
    argocd_installation_complated=0
    echo "${argocd_installation_complated}"
    echo "Run 'kubectl port-forward -n argocd svc/argocd-server <port>:80'"
    echo "Then open your browser localhost:<port>"
else
    echo "Waiting for argocd"
    sleep 3
fi
done

echo "Connected argocd to main repo and apply infra argocd application"
kubectl apply -n "$ARGOCD_NAMESPACE" -f - <<EOF
apiVersion: v1
data:
  project: ZGVmYXVsdA==
  type: Z2l0
  url: aHR0cHM6Ly9naXRodWIuY29tL0VseWFzYWZsZWhyZXIvcmFmYWVsX2hvbWVfYXNzaWdubWVudC5naXQ=
kind: Secret
metadata:
  labels:
    argocd.argoproj.io/secret-type: repository
  name: main-repo
  namespace: argocd
type: Opaque
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infra
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
  project: default
  source:
    path: infra
    repoURL: https://github.com/Elyasaflehrer/rafael_home_assignment.git
    targetRevision: dev/initial
  syncPolicy:
    automated:
      enabled: true
EOF