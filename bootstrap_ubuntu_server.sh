#! /bin/bash
set -e   # Exit immediately if a command exits with non-zero status

if ! grep -qi "ubuntu" /etc/os-release; then
    echo "This bootstrap supported only Ubuntu distribution"
fi

INSTALL_DIR="/home/${USER}/.local/bin"
USER_DIR="/home/${USER}"
REGEX_LATEST_VERSION='s/.*"v?([^"]+)".*/\1/'
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Create directory ${INSTALL_DIR}"
    mkdir -p ${INSTALL_DIR}
    echo "Add ${INSTALL_DIR} to ~/.bashrc"
    echo "export PATH='$PATH:$USER_DIR/.local/bin'" >>  $USER_DIR/.bashrc
    source $USER_DIR/.bashrc
fi
ROOT_PASS="${1:?Missing required parameter: root password}"

print_step() {
    echo
    echo "=============================================="
    echo "🚀 $1"
    echo "=============================================="
}


# run as a root
echo $ROOT_PASS | sudo -kS  apt update
# add user to root group required to run docker cli
echo -e "Added user \e[3m${USER}\e[0m to root group"
echo $ROOT_PASS | sudo -kS usermod -aG root ${USER}

print_step "Installing Docker"

echo $ROOT_PASS | sudo -kS sh -c '
apt update &&
apt install -y ca-certificates curl &&
install -m 0755 -d /etc/apt/keyrings &&
curl -fL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc &&
chmod a+r /etc/apt/keyrings/docker.asc
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt update
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
'

print_step "Installing Helm"
LATEST_HELM=$(curl -s https://api.github.com/repos/helm/helm/releases/latest \
  | grep '"tag_name":' \
  | sed -E $REGEX_LATEST_VERSION)

TMPDIR=$(mktemp -d)
curl -SL "https://get.helm.sh/helm-v${LATEST_HELM}-linux-amd64.tar.gz" -o $TMPDIR/helm.tar.gz
tar -zxf "$TMPDIR/helm.tar.gz" -C $TMPDIR  > /dev/null
mv "$TMPDIR/linux-amd64/helm" $INSTALL_DIR
rm -rf "$TMPDIR"

print_step "Installing kubectl"
TMPDIR=$(mktemp -d)
curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o $TMPDIR/kubectl
curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" -o $TMPDIR/kubectl.sha256
echo "$(cat $TMPDIR/kubectl.sha256)  $TMPDIR/kubectl" | sha256sum --check
install -m 0755 $TMPDIR/kubectl $INSTALL_DIR
rm -rf "$TMPDIR"

print_step "Installing Justfile"
TMPDIR=$(mktemp -d)
LATEST=$(curl -s https://api.github.com/repos/casey/just/releases/latest \
  | grep '"tag_name":' | sed -E $REGEX_LATEST_VERSION)
echo "Latest version: $LATEST"
curl -L https://github.com/casey/just/releases/download/$LATEST/just-$LATEST-x86_64-unknown-linux-musl.tar.gz -o $TMPDIR/just.tar.gz
tar -zxf "$TMPDIR/just.tar.gz" -C $TMPDIR  > /dev/null
mv $TMPDIR/just $INSTALL_DIR
rm -rf "$TMPDIR"

print_step "Setup git to use vim"
echo $ROOT_PASS | sudo -kS apt install vim
git config --global core.editor "vim"