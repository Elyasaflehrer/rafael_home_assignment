
set shell := ["/bin/bash", "-c"]

CLUSTER_NAME := "kind"

default:
    just --list

install-kind-cli:
  tmpdir=`mktemp -d` && \
  echo "Working in temporary directory: $tmpdir" && \
  install_dir="$HOME/.local/bin" && \
  version=`curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest \
  | grep '"tag_name":' \
  | sed -E 's/.*"v?([^"]+)".*/\1/'` && \
  curl -Lo $tmpdir/kind https://kind.sigs.k8s.io/dl/v$version/kind-linux-amd64 && \
  chmod +x $tmpdir/kind && \
  mv $tmpdir/kind  $install_dir && \
  rm -rf $tmpdir

create-kind-cluster CLUSTER_NAME="kind":
  # Check if cluster exists
  if kind get clusters | grep -qw "{{CLUSTER_NAME}}"; then \
      echo "Kind cluster '{{CLUSTER_NAME}}' already exists."; \
      echo "Remove the cluster 'kind delete cluster --name {{CLUSTER_NAME}}'"; \
      echo "or pass the cluster name as a pramater 'CLUSTER_NAME=<cluster_name>'"; \
      exit 0; \
  else \
      echo "Installing kind cluster"; \
      kind create cluster --config assets/kind.yaml --name {{CLUSTER_NAME}}; \
  fi

install_argocd ARGOCD_NAMESPACE="argocd":
  kubectl create namespace {{ARGOCD_NAMESPACE}}
  kubectl apply -n {{ARGOCD_NAMESPACE}} --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.0-rc4/manifests/install.yaml

  while true; do \
    not_running="$(kubectl -n {{ARGOCD_NAMESPACE}} get po --no-headers | awk '{print $3}' | grep -v '^Running$' | wc -l)" ;\
    if [[ "$not_running" -eq 0 ]]; then \
      echo "Finished setting up Argocd" ;\
      echo "Admin password: \
           $(kubectl -n {{ARGOCD_NAMESPACE}} get secret argocd-initial-admin-secret \
          -o go-template='{{"{{.data.password}}"}}' | base64 --decode)" ;\
      echo "Run: \
            kubectl port-forward -n {{ARGOCD_NAMESPACE}} svc/argocd-server <port>:80 \
            Then open: http://localhost:<port>" ;\
      break ;\
    else \
      echo "⏳ Waiting for Argocd — $not_running pods not running yet (sleep 5)";\
      sleep 5 ;\
    fi ;\
  done

create-local-registry REGISTRY_PORT="5001" REG_NAME="local-registry":
  reg_dir="/etc/containerd/certs.d/localhost:{{REGISTRY_PORT}}"
  # Check if registry is already running
  if [[ "$(docker inspect -f '{{ "{{.State.Running}}" }}' {{REG_NAME}} 2>/dev/null || true)" = 'true' ]]; then \
    echo "✅ Registry {{REG_NAME}} is already running on port {{REGISTRY_PORT}}" ;\
    echo "Skipping registry creation." ;\
  else \
    echo "🚀 Starting local registry {{REG_NAME}} on port {{REGISTRY_PORT}}..." ;\
    docker run -d --restart=always -p "127.0.0.1:{{REGISTRY_PORT}}:5000" --network bridge --name {{REG_NAME}} registry:2 ;\
    just connect-to-local-registry ;\
  fi

connect-to-local-registry REGISTRY_PORT="5001" REG_NAME="local-registry":
    for node in $(kind get nodes); do \
      echo "🔧 Configuring node $node for local registry..." ;\
      docker exec "${node}" mkdir -p "/etc/containerd/certs.d/localhost:{{REGISTRY_PORT}}" ;\
      docker exec -i "$node" sh -c 'echo "[host.\"http://{{REG_NAME}}:5000\"]" > /etc/containerd/certs.d/localhost:{{REGISTRY_PORT}}/hosts.toml' ;\
    done ;\
    REGISTRY_PORT="{{REGISTRY_PORT}}" ;\
    echo "apiVersion: v1; kind: ConfigMap; metadata: {name: local-registry-hosting, namespace: kube-public}; data: {localRegistryHosting.v1: \"host: localhost:${REGISTRY_PORT}\"}" | sed 's/; /\n/g' | kubectl apply -f - ;\
    if [ "$(docker inspect -f='{{ "{{json .NetworkSettings.Networks.kind}}" }}' "{{REG_NAME}}")" = 'null' ]; then \
      docker network connect "kind" "{{REG_NAME}}" ;\
    fi

docker-build REGISTRY_PORT="5001" LOCAL="localhost":
  docker build -t ask_docs -f ask_docs/Dockerfile ask_docs
  docker tag ask_docs:latest {{LOCAL}}:{{REGISTRY_PORT}}/ask_docs:latest
  docker push {{LOCAL}}:{{REGISTRY_PORT}}/ask_docs:latest
