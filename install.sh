#!/usr/bin/env bash

# curl -O https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/install.sh
# chmod +x install.sh
# ./install.sh www.mydomain.net username@gmail.com

# exit when any command fails or any unbound variable is accessed
set -eu -o pipefail

# check if parameter is empty
if (( "$#" < 2 ));
  then
    echo "syntax: install.sh <FQDN> <email-for-certbot>"
    echo "example: install.sh www.mydoamin.net username@gmail.com"
    exit 1
fi

fqdn="$1"
email="$2"

# if os is not ubuntu or debian, exit
if ! grep -q "Ubuntu" /etc/issue && ! grep -q "Debian" /etc/issue;
  then
    echo "This script only works on Ubuntu or Debian"
    exit 1
fi

# install docker
sudo apt-get -y install ca-certificates curl wget gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
# check if ubuntu or debian
if grep -q "Ubuntu" /etc/issue;
then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
else
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
sudo chmod a+r /etc/apt/keyrings/docker.gpg
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url  | grep docker-compose-linux-x86_64 | cut -d '"' -f 4 | wget -qi -
chmod +x docker-compose-linux-x86_64
sudo mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
sudo usermod -aG docker "$USER"
sudo systemctl enable docker
# download docker images
sudo docker pull staticfloat/nginx-certbot
sudo docker pull mcr.microsoft.com/dotnet/samples:aspnetapp

# download /etc/nginx conf files
sudo mkdir /etc/nginx
sudo mkdir /etc/nginx/conf.d
sudo curl -o /etc/nginx/nginx.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/nginx.conf
sudo curl -o /etc/nginx/conf.d/00.default.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/conf.d/00.default.conf
sudo curl -o /etc/nginx/conf.d/01.aspnetcore.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/conf.d/01.aspnetcore.conf
sudo sed -i "s/@fqdn/$fqdn/g" /etc/nginx/conf.d/01.aspnetcore.conf

# copy docker-compose.yml to $HOME/dockers/nginx-certbot
mkdir -p "$HOME/dockers/nginx-certbot"
cd "$HOME/dockers/nginx-certbot"
curl -O https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/dockers/nginx-certbot/docker-compose.yml
sed -i "s/@email/$email/g" docker-compose.yml

# copy docker-compose.yml to $HOME/dockers/aspnetcore
mkdir -p "$HOME/dockers/aspnetcore"
cd "$HOME/dockers/aspnetcore"
curl -O https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/dockers/aspnetcore/docker-compose.yml

# start docker containers
cd "$HOME/dockers/aspnetcore"
sudo docker-compose up -d
cd "$HOME/dockers/nginx-certbot"
sudo docker-compose up -d
