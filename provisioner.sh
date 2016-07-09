set -x
curl -L https://github.com/docker/compose/releases/download/1.8.0-rc2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

useradd -d /home/wekan -m -s /bin/bash wekan
usermod -aG docker wekan

apt-get -y update
apt-get -y install apache2 libapache2-mod-proxy-html libxml2-dev

a2enmod proxy proxy_http proxy_wstunnel

cat << EOF > /home/wekan/docker-compose.yml
wekan:
  image: mquandalle/wekan
  restart: always
  links:
    - wekandb
  environment:
    - MONGO_URL=mongodb://wekandb/wekan
    - ROOT_URL=http://${DOMAIN}
  ports:
    - 8081:80

wekandb:
   image: mongo
   volumes:
     - /home/wekan/data:/data/db
EOF

cat << EOF > /etc/apache2/sites-enabled/$DOMAIN.conf
<VirtualHost *:80>
        ServerName ${DOMAIN}
        ServerAdmin webmaster@${DOMAIN}

        DocumentRoot /var/www-vhosts/${DOMAIN}
        <Directory />
                Options FollowSymLinks
                AllowOverride AuthConfig FileInfo Indexes Options=MultiViews
        </Directory>

        <Directory /var/www-vhosts/${DOMAIN}>
                Options -Indexes +FollowSymLinks +MultiViews
                AllowOverride AuthConfig FileInfo Indexes Options=MultiViews
                Require all granted
        </Directory>

        ErrorLog /var/log/apache2/${DOMAIN}-error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog /var/log/apache2/${DOMAIN}-access.log combined
        ServerSignature Off
        
        ProxyPassMatch   "^/(sockjs\/.*\/websocket)$" "ws://127.0.0.1:8081/$1"
        ProxyPass        "/" "http://127.0.0.1:8081/"
        ProxyPassReverse "/" "http://127.0.0.1:8081/"
</VirtualHost>
EOF


sudo -u wekan docker-compose rm -f
sudo -u wekan docker-compose pull
sudo -u wekan docker-compose build
sudo -u wekan docker-compose up -d

apache2ctl restart
