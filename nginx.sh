#!/bin/bash
if [ -z echo$(which nginx) ]; then
	echo "nginx not installed"
	exit 1
fi
echo $(systemctl enable nginx)
echo $(systemctl start nginx)
#get domain name and folder name
while [ "$domain" = "" ]
do
	read -p "What is your domain-name? " domain
done
while [ "$prefix" = "" ]
do
	read -p 'Does this domain have a www prefix?(yn) ' prefix
done
use=""
case $prefix in [yY]* )
	www="www.$domain"
esac
while [ "$folder" = "" ]
do
	read -p 'What would you like to call folders? ' folder
done
#adding html content
echo $(chmod -R 755 /var/www)
echo $(mkdir -p /var/www/$folder/html)
echo "welcome to $domain" > /var/www/$folder/html/index.html
# remove existing and default entires
echo $(rm /etc/nginx/sites-available/$folder)
echo $(rm /etc/nginx/sites-enabled/$folder)
echo $(rm -r /var/www/html)
echo $(rm /etc/nginx/sites-available/default)
echo $(rm /etc/nginx/sites-enabled/default)
echo "
server {
	listen 80;
	listen [::]:80;
	server_name $use $domain;
	location / {
		root /var/www/$folder/html;
		index index.html index.htm index.php;
	}
}
" > /etc/nginx/sites-available/$folder
#generating certificate
read -p 'Do you wish to generate a new certificate?(yn) ' cert
case $cert in [yY]* )
	if [ -z echo$(which certbot) ]; then
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
	echo $(systemctl stop nginx)
	echo $($certbot)
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
			root /var/www/$folder/html;
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
echo $(ln -s /etc/nginx/sites-available/$folder /etc/nginx/sites-enabled/$folder)
echo $(systemctl restart nginx)
echo 'All done!'
