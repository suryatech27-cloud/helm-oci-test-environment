#!/bin/bash
SHELL=/bin/sh
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
# Author : Sunil Kumar
# Copyright (c) testharbor.com
# Script follows here:
root_dir=$(pwd)

while [[ $# > 0 ]]
do
	key="$1"
		case $key in
			--os-name )
			osName="$2"
      if [[ "$osName" = "linux" || "$osName" = "" ]]; then
         printf "Please enter correct operating system name(ubuntu,suse,centos)\n\n"
         exit
      fi
			shift ;;
			*)
			# unknown switch
			;;
		esac
	shift
done
printf "os name : $osName"

printf "\nStep 1: Docker"
#checking docker available on current system or not!
printf "\nChecking docker availability....................................\n"

if [ -x "$(command -v docker)" ]; then
    printf "\nDocker is already installed in your system !!!\n\n"
    echo "[ Docker Version ] :" $(docker --version)
    echo "[ Docker working Directory ] :" $(which docker)
    
  else
    printf "\nDocker installation about to start in few seconds.... !!!\n\n"
    if [ "$osName" = "ubuntu" ]; then
      sudo apt update > /dev/null 2>&1
      sudo apt-get install curl apt-transport-https ca-certificates software-properties-common > /dev/null 2>&1
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo apt update > /dev/null 2>&1
      apt-cache policy docker-ce
      sudo apt install docker-ce > /dev/null 2>&1
      sudo serivce docker start 
      sudo service docker enable
      sudo service docker status
      printf "\nDocker installed successfully on your machine \n\n"
    elif [ "$osName" = "suse" ]; then
      sudo zypper refresh > /dev/null 2>&1
      sudo zypper update -y > /dev/null 2>&1
      #sles_version="$(. /etc/os-release && echo "${VERSION_ID##*.}")" 
      #opensuse_repo="https://download.opensuse.org/repositories/security:SELinux/SLE_15_SP$sles_version/security:SELinux.repo"
      #sudo zypper addrepo $opensuse_repo 
      sudo zypper addrepo https://download.docker.com/linux/sles/docker-ce.repo
      sudo zypper install docker-ce docker-ce-cli containerd.io
      sudo serivce docker start 
      sudo service docker enable
      sudo service docker status
      printf "\nDocker installed successfully on your machine \n\n"
    elif [ "$osName" = "centos" ]; then
      sudo yum check-update > /dev/null 2>&1
      sudo yum install -y yum-utils device-mapper-persistent-data lvm2 > /dev/null 2>&1
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install docker > /dev/null 2>&1
      sudo serivce docker start 
      sudo service docker enable
      sudo service docker status
      printf "\nDocker installed successfully on your machine \n\n"
    else
      printf "\nWe are not able to install docker in your system, please install docker latest version (greater than 17.x ) and try again\n\n"
    fi
fi


printf "\nStep 2 : Docker-Compose\n"
printf "Checking Docker compose availability ........................\n\n"

# Docker Compose
compose_release() {
  curl --silent "https://api.github.com/repos/docker/compose/releases/latest" |
  grep -Po '"tag_name": "\K.*?(?=")'
}
if ! [[ -f /usr/local/bin/docker-compose ]]; then
    printf "\nDocker-Compose installation started ......................\n" 
    curl -L https://github.com/docker/compose/releases/download/$(compose_release)/docker-compose-$(uname -s)-$(uname -m) \
    -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

    printf '\nChecking Docker-compose Info \n'
    echo "[ Docker-Compose Version ] :" $(docker-compose --version)
    echo "[ Docker working Directory ] :" $(which docker-compose)
  else
    printf "\nDocker-Compose is already installed in your system !!!\n\n"  
    echo "[ Docker-Compose Version ] :" $(docker-compose --version)
    echo "[ Docker working Directory ] :" $(which docker-compose)
fi 

printf "Step 3 : Generating Self-Signed certificate \n\n"
mkdir certs
printf "Creating root ca keyfile.\n\n"
cd certs
openssl genrsa -out ca.key 4096
printf "Creating root ca certificate.\n\n"
openssl req -x509 -new -nodes -sha512 -days 3650 \
     -subj "/C=IN/ST=Karnataka/L=Bangalore/O=TestOrg/OU=Research and Development/CN=demo.testharbor.com" \
     -key ca.key \
     -out ca.crt
printf "Generate a Server Certificate (Generate a private key).\n\n"
openssl genrsa -out root_server.key 4096

printf "Generate a certificate signing request (CSR).\n\n"
openssl req -sha512 -new \
        -subj "/C=IN/ST=Karnataka/L=Bangalore/O=TestOrg/OU=Research and Development/CN=demo.testharbor.com" \
        -key root_server.key \
        -out root_server.csr

printf "Generate an x509 server_v3 extension file.\n\n"
cat > server_v3.ext <<-EOF
    authorityKeyIdentifier=keyid,issuer
    basicConstraints=CA:FALSE
    keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = @alt_names

    [alt_names]
    DNS.1=demo.testharbor.com
    DNS.2=nginx.testharbor.com
    DNS.3=apache.testharbor.com
    DNS.4=testharbor.com
    DNS.5=sslharbor.com
    DNS.6=demo.sslharbor.com
    DNS.7=nginx.sslharbor.com
    DNS.8=apache.sslharbor.com
EOF

#Use the server_v3.ext file to generate a certificate for your Harbor host.
printf "Generate a server certificate\n\n"
openssl x509 -req -sha512 -days 3650 \
    -extfile server_v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in root_server.csr \
    -out root_server.crt

printf "Generate a client Certificate (Generate a private key).\n\n"
openssl genrsa -out root_client.key 4096

printf "Generate a certificate signing request (CSR).\n\n"
openssl req -sha512 -new \
    -subj "/C=IN/ST=Karnataka/L=Bangalore/O=TestOrg/OU=Research and Development/CN=demo.testharbor.com" \
    -key root_client.key \
    -out root_client.csr

printf "Generate an x509 client_v3 extension file.\n\n"
cat > client_v3.ext <<-EOF
  authorityKeyIdentifier=keyid,issuer
  basicConstraints=CA:FALSE
  keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
  extendedKeyUsage = clientAuth
  subjectAltName = @alt_names

  [alt_names]
  DNS.1=demo.testharbor.com
  DNS.2=nginx.testharbor.com
  DNS.3=apache.testharbor.com
  DNS.4=testharbor.com
  DNS.5=sslharbor.com
  DNS.6=demo.sslharbor.com
  DNS.7=nginx.sslharbor.com
  DNS.8=apache.sslharbor.com
EOF

#Use the client_v3.ext file to generate a certificate for your Harbor host.
printf "Generate client certificate.\n\n"
openssl x509 -req -sha512 -days 3650 \
    -extfile client_v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in root_client.csr \
    -out root_client.crt

printf "\nAll certificated generated successfully.\n\n"

cd ../

printf "\nStep 4 : Harbor\n"
printf "\nHarbor installation started ......................................\n\n"

#Downloading harbor offline installer
printf "\nDownloading harbor offline installer.\n\n"
if ! [[ -f harbor-offline-installer-v2.5.1.tgz ]]; then
    wget https://github.com/goharbor/harbor/releases/download/v2.5.1/harbor-offline-installer-v2.5.1.tgz
else
  printf "\nharbor installer exist in current directory.\n\n"
fi

#Downloading the corresponding *.asc file to verify that the package is genuine.
printf "\nDownloading the corresponding *.asc file.\n\n"
if ! [[ -f harbor-offline-installer-v2.5.1.tgz.asc ]]; then
    wget https://github.com/goharbor/harbor/releases/download/v2.5.1/harbor-offline-installer-v2.5.1.tgz.asc
else
  printf "harbor installer asc file exist in current directory.\n\n"
fi

if which gpg2 >/dev/null; then 
    printf "\nChecking public key ......\n\n"
    gpg2 --keyserver hkps://keyserver.ubuntu.com --recv-keys 644FF454C0B4115C > /dev/null 2>&1

    #Verify that the package is genuine by running one of the
    printf "\nVerifying the package is genuine ?\n\n"
    gpg2 -v --keyserver hkps://keyserver.ubuntu.com --verify harbor-offline-installer-v2.5.1.tgz.asc > /dev/null 2>&1

    printf "\nExtracting package.......\n\n"
    tar xzvf harbor-offline-installer-v2.5.1.tgz > /dev/null 2>&1
  else
    echo "Installing latest gnupg2..."
    echo "Y" | sudo apt-get install gnupg2 > /dev/null 2>&1 #installation
    
    #Obtain the public key for the *.asc file.
    printf "\nChecking public key ......\n\n"
    gpg2 --keyserver hkps://keyserver.ubuntu.com --recv-keys 644FF454C0B4115C > /dev/null 2>&1

    #Verify that the package is genuine by running one of the
    printf "\nVerifying the package is genuine ?\n\n"
    gpg2 -v --keyserver hkps://keyserver.ubuntu.com --verify harbor-offline-installer-v2.5.1.tgz.asc > /dev/null 2>&1

    printf "\nExtracting package.......\n\n"
    tar xzvf harbor-offline-installer-v2.5.1.tgz > /dev/null 2>&1
fi

cp certs/ -R harbor/certs
rm harbor/harbor.yml.tmpl
cp config/harbor/harbor.yml harbor/
cp harbor/ -R /etc/
rm -rf harbor

cd /etc/harbor
bash $(pwd)/install.sh
bash $(pwd)/prepare
sleep 20
docker-compose down --remove-orphans > /dev/null 2>&1
sed -i 's/8443/443/g' $(pwd)/docker-compose.yml
sed -i 's/8443/443/g' $(pwd)/common/config/nginx/nginx.conf

docker-compose up -d > /dev/null 2>&1
sleep 20
harbor_exposed_ip_address=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nginx)

#echo $root_dir
#echo $harbor_exposed_ip_address

echo "$harbor_exposed_ip_address demo.testharbor.com" >> /etc/hosts

printf "\nYour harbor setup is ready .\n\n".

printf "\nYour Harbor Info: \n\n"
printf "\n|-------------------------------------------------------------------------|\n"
printf "|harbor ip-address|        $harbor_exposed_ip_address                                  |\n"
printf "|-------------------------------------------------------------------------|\n"
printf "|harbor host-name |        demo.testharbor.com                            |\n"
printf "|-------------------------------------------------------------------------|\n"
printf "|harbor root-dir  |        /etc/harbor                                    |\n"
printf "|-------------------------------------------------------------------------|\n\n"

success $"----Harbor Configuration has been changed and started successfully.----"
printf "\nNginx server Setup starting in few seconds , Hold on we are working on that\n\n"

if [ "$osName" = "ubuntu" ]; then
   sudo apt update > /dev/null 2>&1
   sudo apt install nginx > /dev/null 2>&1
   sudo ufw allow 'Nginx Full'

  cp $root_dir/certs /etc/nginx/
  cp $root_dir/conf.d/proxy_ssl.conf /etc/nginx/sites-available/
  ln -sf /etc/nginx/sites-available/proxy_ssl.conf /etc/nginx/sites-enabled/proxy_ssl.conf
  nginx -t 
  nginx -s reload
  service nginx restart
  service nginx status

   printf "\nNginx server Installation completed and started successfully\n\n"
elif ["$osName" = "suse" ]; then
  zypper search nginx  
  sudo zypper update
  sudo zypper install nginx
  sudo ufw allow 'Nginx Full'

  cp $root_dir/certs /etc/nginx/
  cp $root_dir/conf.d/proxy_ssl.conf /etc/nginx/sites-available/
  ln -sf /etc/nginx/sites-available/proxy_ssl.conf /etc/nginx/sites-enabled/proxy_ssl.conf
  nginx -t 
  nginx -s reload
  service nginx restart
  service nginx status

   printf "\nNginx server Installation completed and started successfully\n\n"
elif [ "$osName" = "centos" ]; then
  sudo yum install epel-release
  sudo yum install nginx
  sudo systemctl start nginx
  sudo ufw allow 'Nginx Full'

  cp $root_dir/certs /etc/nginx/
  cp $root_dir/conf.d/proxy_ssl.conf /etc/nginx/sites-available/
  ln -sf /etc/nginx/sites-available/proxy_ssl.conf /etc/nginx/sites-enabled/proxy_ssl.conf
  nginx -t 
  nginx -s reload
  service nginx restart
  service nginx status
  printf "\nNginx server Installation completed and started successfully\n\n"
else
  printf "Sorry we are not able to install nginx manually, \n\n"
fi
