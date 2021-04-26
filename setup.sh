#!/bin/bash
#check if nginx is installed
if [ -z $(which nginx) ]; then
	echo "nginx not installed"
	exit 1
fi
systemctl enable nginx
systemctl start nginx
#get domain name
while [ -z $domain ]; do
	read -p "What is your domain-name? " domain
done
#www prefix for domainname
while [ -z $prefix ]; do
	read -p 'Does this domain have a www prefix?(yn) ' prefix
done
www=""
case $prefix in [yY]* )
	www="www.$domain"
esac

#getting folder name (is also used as server block and conf file name)
while [ -z $folder ]; do
	read -p 'What would you like to call folders (and conf-files)? ' folder
done
# remove existing entires
rm /etc/nginx/sites-available/$folder
rm /etc/nginx/sites-enabled/$folder

#location of website files or reverse proxy
reverse=""
while [ -z $reverse ]; do
	read -p 'Are you setting up a reverse proxy?(yn) ' reverse
done
case $reverse in
[yY])
	#using reverse proxy
	root="proxy_pass"
	#getting proxy address
	location=""
	while [ -z $location ]; do
		read -p 'Web server address with port (eg. http://127.0.0.1:8080): ' location
	done
	;;
*)
	#using server-block
	root="root"
	#server-block path
	read -p "Location of your server-block (leave empty for default(/var/www/$folder/content/html))(Any existing data in this folder will be overritten!!!): " location
	if [ -z $location ]; then
		location="/var/www/$folder/content/html"
	fi
	#adding default site
	mkdir -p "$location"
	echo "welcome to $domain" > "$location/index.html"
	# remove existing entires
	rm /etc/nginx/sites-available/$folder
	rm /etc/nginx/sites-enabled/$folder
	;;
esac
echo "server {
	listen 80;
	listen [::]:80;
	server_name $www $domain;
	location / {
		$root $location;
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
	if [ "$www" != "" ]; then
		certbot="$certbot -d $www"
	fi
	systemctl stop nginx
	$certbot
esac
#.htaccess setup
ht=""
while [ -z $ht ]; do
	read -p 'Do you want to set up password athentication for this website?(yn) ' ht
done
case $ht in
[yY])
	name=""
	while [ -z $name ]; do
		read -p 'Username: ' name
	done
	sh -c "echo -n $name: >> /etc/nginx/.htpasswd"
	sh -c "openssl passwd -apr1 >> /etc/nginx/.htpasswd"
	ht='auth_basic "Restricted Content"; auth_basic_user_file /etc/nginx/.htpasswd'
	;;
*)
	$ht=""
	;;
esac
#create conf file and linking it
read -p 'Do you want to use ssl?(yn) ' ssl
case $ssl in [yY]* )
        echo "server {
		listen 443 ssl http2;
		listen [::]:443 ssl http2;
		server_name $www $domain;
		ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
		ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
		ssl_session_cache    shared:SSL:1m;
		ssl_session_timeout  5m;
		ssl_ciphers  HIGH:!aNULL:!MD5;
		ssl_prefer_server_ciphers  on;
		location / {
			$root $location;
			"${ht[@]}";
			index index.html index.htm index.php;
		}
	}
	server {
		listen 80;
		listen [::]:80;
		server_name $www $domain;
		"'return 301 https://$host$request_uri;
	}' > /etc/nginx/sites-available/$folder
esac
ln -s /etc/nginx/sites-available/$folder /etc/nginx/sites-enabled/$folder
systemctl restart nginx
echo 'All done!'
