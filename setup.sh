#!/bin/bash
#check if nginx is installed
if [ -z $(which nginx) ]; then
	echo "nginx not installed"
	exit 1
fi
systemctl enable nginx
systemctl start nginx
#get domain name
while [ "$domain" = "" ]
do
	read -p "What is your domain-name? " domain
done
#www prefix for domainname
while [ "$prefix" = "" ]
do
	read -p 'Does this domain have a www prefix?(yn) ' prefix
done
www=""
case $prefix in [yY]* )
	www="www.$domain"
esac
#folder name
while [ "$folder" = "" ]
do
	read -p 'What would you like to call folders? ' folder
done
#where the website goes
read -p "Location of your server-block (leave empty for default(/var/www/$folder))(Any existing data in this folder will be overritten!!!)" location
if [ "location" = "" ]; then
	location="/var/www/$folder"
fi
#adding html content
chmod -R 755 /var/www
mkdir -p "$location/content/html"
echo "welcome to $domain" > "$location/content/html/index.html"
# remove existing entires
rm /etc/nginx/sites-available/$folder
rm /etc/nginx/sites-enabled/$folder
echo "
server {
	listen 80;
	listen [::]:80;
	server_name $use $domain;
	location / {
		root $location/content/html;
		index index.html index.htm index.php;
	}
}
" > /etc/nginx/sites-available/$folder
#generating certificate
read -p 'Do you wish to generate a new certificate?(yn) ' cert
case $cert in [yY]* )
	if [ -z $(which certbot) ]; then
		echo "certbot is not installed"
		exit 1
	fi
	certbot="certbot certonly --standalone -d $domain"
	read -p "What's your mail address? (If you have allready typed it in the past you can leave it empty): " mail
	if [ "$www" != "" ]; then
		certbot="$certbot -d $www"
	fi
	if [ "$mail" != "" ]; then
		certbot="$certbot --non-interactive --agree-tos -m $mail"
	fi
	systemctl stop nginx
	$certbot
esac
#create conf file and linking it
read -p 'Do you want to use ssl?(yn) ' ssl
case $ssl in [yY]* )
        echo "
        server {
		listen 443 ssl http2;
		listen [::]:443 ssl http2;
		server_name $use $domain;
		ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
		ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
		ssl_session_cache    shared:SSL:1m;
		ssl_session_timeout  5m;
		ssl_ciphers  HIGH:!aNULL:!MD5;
		ssl_prefer_server_ciphers  on;
		location / {
			root $location/content/html;
			index index.html index.htm index.php;
		}
	}
	server {
		listen 80;
		listen [::]:80;
		server_name $use $domain;
		"'return 301 https://$host$request_uri;
	}' > /etc/nginx/sites-available/$folder
esac
ln -s /etc/nginx/sites-available/$folder /etc/nginx/sites-enabled/$folder
systemctl restart nginx
echo 'All done!'
