# helm-oci-test-environment
Project for installing the environment for helm oci pull testing:-
Prerequisites : 

Self Signed Certificates

Docker and Docker-compose

Local harbor setup 

Nginx server -> Install and enabled two-way authentication 

-----------------------------------------------------------------------------------------------------------------------------
 Create Self signed certificates
      Step-1 : Generate a Certificate Authority Certificate (Generate a CA certificate private key).

    openssl genrsa -out ca.key 4096

      Step-2 : Generate the CA certificate
    openssl req -x509 -new -nodes -sha512 -days 3650 \
     -subj "/C=IN/ST=Karnataka/L=Bangalore/O=TestOrg/OU=Research and Development/CN=demo.testharbor.com" \
     -key ca.key \
     -out ca.crt

      Step-3 : Generate a Server Certificate (Generate a private key).
    openssl genrsa -out root_server.key 4096
     Step-4 : Generate a certificate signing request (CSR).
    openssl req -sha512 -new \
        -subj "/C=IN/ST=Karnataka/L=Bangalore/O=TestOrg/OU=Research and Development/CN=demo.testharbor.com" \
        -key root_server.key \
        -out root_server.csr

     Step-5 : Generate an x509 server_v3 extension file. (can use vi editor for edit)
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

    Use the server_v3.ext file to generate a certificate for your Harbor host.
    Step-6 : Generate a server certificate
    openssl x509 -req -sha512 -days 3650 \
        -extfile harbor_v3.ext \
        -CA ca.crt -CAkey ca.key -CAcreateserial \
        -in root_server.csr \
        -out root_server.crt

     Step-7 : Generate a client Certificate (Generate a private key).
    openssl genrsa -out root_client.key 4096

    Step-8 : Generate a certificate signing request (CSR).
    openssl req -sha512 -new \
        -subj "/C=IN/ST=Karnataka/L=Bangalore/O=TestOrg/OU=Research and Development/CN=demo.testharbor.com" \
        -key root_client.key \
        -out root_client.csr

     Step-9 : Generate an x509 client_v3 extension file. (can use vi editor)

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

    Use the client_v3.ext file to generate a certificate for your Harbor host.
     Step-10 : Generate client certificate.
    openssl x509 -req -sha512 -days 3650 \
        -extfile harbor_v3.ext \
        -CA ca.crt -CAkey ca.key -CAcreateserial \
        -in root_client.csr \
        -out root_client.crt

Install the Docker and Docker-Compose.
        Docker - https://docs.docker.com/engine/install/ubuntu/
        Docker-Compose - https://www.digitalocean.com/community/tutorials/how-to-install-docker-compose-on-ubuntu-18-04


Setup harbor in Local. 

follow the link for setup harbor locally :-  installation harbor
         
    After Downloading the harbor installer  , follow the below step by step
        - extract it and place the harbor directory in /etc directory,
        - place your self signed certificate (ca.crt, ca.pem , root_server.crt,root_server.key) in certs directory. /et/harbor/certs
    
    Need to change following value in harbor.yml :
    
     hostname: demo.testharbor.com

     # http related config
     #http:
       # port for http, default is 80. If https enabled, this port will redirect to https port
       #port: 80

     # https related config
     https:
       # https port for harbor, default is 443
       port: 443
       # The path of cert and key files for nginx
       certificate: /etc/harbor/certs/root_server.crt
       private_key: /etc/harbor/certs/root_server.key



  Run install.sh
./install sh


After installation completed run the prepare (./prepare) for preparing installation process for docker and it will generate docker-compose file for you.
next time if you want to restart harbor , you can use docker compose to do so.
check the nginx configuration inside common/config/nginx directory , it should be like below .

need to change the ssl port 8443 to 443.

  server {
    listen 443 ssl;
#    server_name harbordomain.com;
    server_tokens off;
    # SSL
    ssl_certificate /etc/cert/server.crt;
    ssl_certificate_key /etc/cert/server.key;

    # Recommendations from https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
    ssl_protocols TLSv1.2;
    ssl_ciphers '!aNULL:kECDH+AESGCM:ECDH+AESGCM:RSA+AESGCM:kECDH+AES:ECDH+AES:RSA+AES:';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;

    # disable any limits to avoid HTTP 413 for large image uploads
    client_max_body_size 0;

    # required to avoid HTTP 411: see Issue #1486 (https://github.com/docker/docker/issues/1486)
    chunked_transfer_encoding on;
.......
}

After doing that check the docker-compose.yml file , there you need to change expose port 80:8080 and 443:443

  proxy:
    image: goharbor/nginx-photon:v2.5.0
    container_name: nginx
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - NET_BIND_SERVICE
    volumes:
      - ./common/config/nginx:/etc/nginx:z
      - /data/secret/cert:/etc/cert:z
      - type: bind
        source: ./common/config/shared/trust-certificates
        target: /harbor_cust_cert
    networks:
      - harbor
    ports:
      - 80:8080
      - 443:443


Restart your harbor again using following command: (go to the directory where docker-compose file is exist then run below code)
for stop the harbor container:
docker-compose down --remove-orphans

for start the harbor container : 
docker-compose up -d (in detached mode)

Next Step to edit network host to forward the ip of harbor nginx to your hostname.
#harbor
172.21.0.10 demo.testharbor.com 

after enabling host try to access the harbor in your browser.
first try it will give you the site exception , for avoiding that you need to import ca.crt file in your browser.

Now you can access it without any exception 😊

Installing nginx server (two-way ssl/tls authentication)

Step -1 : Install Nginx server in your machine . (Make sure nginx is running or not "systemctl status nginx")

Step -2 : Enable the firewall for nginx https/full
          sudo ufw allow 'Nginx Full'
Step -3 : Use the following ssl configuration (create a conf file in sites-available dir /conf.d )

server {
 listen 8181;
 listen 9443 ssl;
 server_name nginx.testharbor.com;

    proxy_ssl_server_name on;
    
    ssl_certificate      /etc/nginx/certs/root_server.crt;
    ssl_certificate_key /etc/nginx/certs/root_server.key;
    ssl_client_certificate /etc/nginx/certs/ca.crt;    

    ssl_verify_client on;
    ssl_verify_depth 2;

    access_log /var/log/nginx/access.log kv;
    error_log /var/log/nginx/error.log debug;

    ssl_prefer_server_ciphers on;
    ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
    #ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:ECDHE-RSA-RC4-SHA:ECDHE-ECDSA-RC4-SHA:RC4-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!3DES:!MD5:!PSK';

    keepalive_timeout 10;
    ssl_session_timeout 5m;

    # If TLS handshake is successful, the request is routed to this block
    
   location / {
     #if ($ssl_client_verify != SUCCESS) { return 401; }
     proxy_pass https://demo.testharbor.com/;
     proxy_pass_request_headers on;
   }

}


Note : if you are creating the conf file inside sites-available directory then you need to use 
       following command to enable the configuration.

 (ln -sf /etc/nginx/sites-available/ssl.conf /etc/nginx/sites-enabled/ssl.conf)

Step -4: Now update your hosts file 
ex :
(10.0.1.19)host_ip_address nginx.testharbor.com

Step -5: Checking configuration use (nginx -t) command 
         reloading the configuration use (nginx -s reload)
         
Step -6: Restart the nginx .

--------------------------------------------------------------------------------------------------------------------------
Example for Test : 
helm login: 

$helm registry login nginx.testharbor.com:9443 -u admin -p Harbor12345

helm pull:

$helm pull oci://nginx.testharbor.com:9443/testrepo/testchart --version 0.1.0

(Note : This will give you the 400-Bad request (in case of nginx) , tls handshake failure (in case of apache))

use PR for testing:

$helm pull oci://nginx.testharbor.com:9443/testrepo/testchart --version 0.1.0 --tls-enabled

Now it will be successfully download your chart.
