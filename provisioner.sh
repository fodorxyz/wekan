curl -L https://github.com/docker/compose/releases/download/1.8.0-rc2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

useradd -d /home/wekan -m -s /bin/bash wekan
usermod -aG docker wekan

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
    - ROOT_URL=http://mytodo.org
    - MAIL_URL=smtp://user:pass@mailserver.example.com:25/
    - MAIL_FROM=wekan-admin@example.com
  ports:
    - 8081:80

wekandb:
   image: mongo
   volumes:
     - /home/wekan/data:/data/db
EOF

cat << EOF > /etc/apache2/sites-enabled/$DOMAIN.conf
<VirtualHost *:80>
        ServerName mytodo.org
        ServerAdmin webmaster@mytodo.org

        DocumentRoot /var/www-vhosts/mytodo.org
        <Directory />
                Options FollowSymLinks
                AllowOverride AuthConfig FileInfo Indexes Options=MultiViews
        </Directory>

        <Directory /var/www-vhosts/mytodo.org>
                Options -Indexes +FollowSymLinks +MultiViews
                AllowOverride AuthConfig FileInfo Indexes Options=MultiViews
                Require all granted
        </Directory>

        ErrorLog /var/log/apache2/mytodo.org-error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog /var/log/apache2/mytodo.org-access.log combined
        ServerSignature Off
        
        ProxyPassMatch   "^/(sockjs\/.*\/websocket)$" "ws://127.0.0.1:8081/$1"
        ProxyPass        "/" "http://127.0.0.1:8081/"
        ProxyPassReverse "/" "http://127.0.0.1:8081/"
</VirtualHost>
EOF

cd /home/wekan
sudo -u wekan docker-composer up -d

apache2ctl restart
