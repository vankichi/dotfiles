# install kubectl
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
sleep 5
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
kubectl version --client

# k3d install
wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

# k9s install
curl -sS https://webinstall.dev/k9s | bash
