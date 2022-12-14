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

# get administrative privilege
# invoke `sudo' only when running as an unprivileged user (nonzero "$UID")
declare -a a_privilege=()
if (( "$UID" ));
  then
    a_privilege+=( "sudo" )
    echo "This script requires privileges"
    echo "to install packages and write to top-level files / directories."
    echo "Invoking \`${a_privilege[*]}' to acquire the permission:"
    "${a_privilege[@]}" bash -c ":"
fi

# install docker
"${a_privilege[@]}" apt-get -y install ca-certificates curl wget gnupg lsb-release
"${a_privilege[@]}" mkdir -p /etc/apt/keyrings
# check if ubuntu or debian
if grep -q "Ubuntu" /etc/issue;
then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | "${a_privilege[@]}" gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | "${a_privilege[@]}" tee /etc/apt/sources.list.d/docker.list > /dev/null
else
  curl -fsSL https://download.docker.com/linux/debian/gpg | "${a_privilege[@]}" gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | "${a_privilege[@]}" tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
"${a_privilege[@]}" chmod a+r /etc/apt/keyrings/docker.gpg
"${a_privilege[@]}" apt-get update
"${a_privilege[@]}" apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url  | grep docker-compose-linux-x86_64 | cut -d '"' -f 4 | wget -qi -
chmod +x docker-compose-linux-x86_64
"${a_privilege[@]}" mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
"${a_privilege[@]}" usermod -aG docker "$USER"
"${a_privilege[@]}" systemctl enable docker
# download docker images
"${a_privilege[@]}" docker pull staticfloat/nginx-certbot
"${a_privilege[@]}" docker pull mcr.microsoft.com/dotnet/samples:aspnetapp

# download /etc/nginx conf files
"${a_privilege[@]}" mkdir /etc/nginx
"${a_privilege[@]}" mkdir /etc/nginx/conf.d
"${a_privilege[@]}" curl -o /etc/nginx/nginx.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/nginx.conf
"${a_privilege[@]}" curl -o /etc/nginx/conf.d/00.default.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/conf.d/00.default.conf
"${a_privilege[@]}" curl -o /etc/nginx/conf.d/01.aspnetcore.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/conf.d/01.aspnetcore.conf
"${a_privilege[@]}" sed -i "s/@fqdn/$fqdn/g" /etc/nginx/conf.d/01.aspnetcore.conf

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
"${a_privilege[@]}" docker-compose up -d
cd "$HOME/dockers/nginx-certbot"
"${a_privilege[@]}" docker-compose up -d
