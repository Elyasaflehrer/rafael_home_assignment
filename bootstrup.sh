#! /bin/bash
set -e   # Exit immediately if a command exits with non-zero status

CLUSTER_NAME="kind"
ARGOCD="true"
INSTALL_KIND_CLI="false"
KIND_CLI_PATH="/usr/local/bin"

parse_args(){
  while [[ $# -gt 0 ]]; do
      arg="$1"
      if [[ ! "$arg" == *"="* ]]; then
        shift 1
        continue
      fi
      case "${arg%%=*}" in
           --install-kind-cli)
              INSTALL_KIND_CLI="${arg#*=}"
              shift 1
              ;;
           --kind-cli-path)
              KIND_CLI_PATH="${arg#*=}"
              shift 1
              ;;
          --cluster-name)
              CLUSTER_NAME="${arg#*=}"
              shift 1
              ;;
          --argocd)
              ARGOCD="${arg#*=}"
              shift 1
              ;;
          -h|--help)
              show_help
              exit 0
              ;;
          *)
              shift 1
              ;;
      esac
  done
}

# Function to display help
function show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --install-kind-cli <value>   installe kind cli (Default false, only true install)"
    echo "  --cluster-name <name>        Specify the cluster name (Default kind)"
    echo "  --argocd <value>             installe ArgoCD (Default true, type false to uninstall)"
    echo "  -h, --help                   Show this help message"
    echo
}

function install_kind_cli(){
  if ! command -v kind >/dev/null 2>&1; then
    echo "Installing kind"
    arch=$(uname -m)

    case "$arch" in
      x86_64)
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
        ;;
      aarch64)
        [ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
        ;;
      *)
        echo "Unknown architecture: $arch"
        ;;
    esac
    chmod +x ./kind
    sudo mv ./kind $KIND_CLI_PATH
  fi

}

function install_kind_cluster() {

  # List existing clusters and check if the desired name exists
  if kind get clusters | grep -qw "$CLUSTER_NAME"; then
      echo "Kind cluster '$CLUSTER_NAME' already exists."
      echo "Remove the cluster 'kind delete cluster --name kind' to start the process"
      exit 0  # or 1 if you want to indicate "already exists" as an error
  else
      echo "Installing kind cluster"
      kind create cluster --config assets/kind.yaml --name $CLUSTER_NAME
  fi
}

function install_argocd(){
  ARGOCD_NAMESPACE="argocd"
  
  kubectl create namespace $ARGOCD_NAMESPACE
  kubectl apply -n $ARGOCD_NAMESPACE --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.0-rc4/manifests/install.yaml


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
      echo "Waiting for argocd (sleep 5)"
      sleep 5
  fi
  done
}

function install_argocd_application(){
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
}

parse_args "$@"

echo "Deployment starting..."
echo "Cluster Name: $CLUSTER_NAME"
echo "ArgoCD: $ARGOCD"

if [[ "$INSTALL_KIND_CLI" == "true" ]]; then
  install_kind_cli
fi
install_kind_cluster

if [[ "$ARGOCD" == "true" ]]; then
  echo "installing Argocd"
  install_argocd
  install_argocd_application
else
  echo "Skip argocd installation"
fi


