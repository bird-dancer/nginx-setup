#!/bin/bash
#
# prints a promt and repeats it if the user gives an invalid input
# $1: text of promt
# $2: allowed answers	leave empty if the input content does not matter
# returns the answer
# example usage answer=$(ask "Some Question" "[yYnN]")
ask() {
	read -p "$1 $2 " answer
	if [ -z $answer ];then
		answer=$(ask "$1" "$2")
	fi
	if [[ "" != $2 ]];then
		if ! [[ $answer =~ $2 ]];then
			answer=$(ask "$1" "$2")
		fi
	fi
	echo $answer
}
check_if_installed() {
	if [ -z $(which $1)]; then
		echo "$1 not installed"
		exit 1
	fi
}
check_firewall_open_ports() {
	if [ -z $(ufw status | grep $1) ]; then
		echo "port $1 is closed"
		exit 1
	fi
}
# check if nginx is installed
check_if_installed nginx
check_firewall_open_ports 80
systemctl --now enable nginx
# get domain name
domain=$(ask "What is your domain name?")
# www prefix for domainname
prefix=$(ask "Does this domain have a www prefix?" "[yYnN]")
www=""
if [[ $prefix =~ [yY] ]];then
	www="www.$domain"
fi

# location of website files or reverse proxy
reverse=$(ask "Are you setting up a reverse proxy?" "[yYnN]")
# creating the nginx config file
if [[ $reverse =~ [yY] ]];then
	# using reverse proxy
	root="proxy_pass"
	# getting proxy address
	content_location=$(ask "Web server address with port (eg. http://127.0.0.1:8080)")
	certtype="standalone"
else
	# using server-block
	root="root"
	# server-block path
	read -p "Location of your server-block (leave empty for default(/var/www/$domain/html)): " content_location
	if [ -z $content_location ]; then
		content_location="/var/www/$domain/html"
	fi
	# adding default site if no index.html file exists
	mkdir -p  $content_location
	if [ ! -f "$content_location/index.html" ]; then
		echo "welcome to $domain" > "$content_location/index.html"
	fi
	certtype="webroot --webroot-path $content_location"
fi
echo "server {
listen 80;
listen [::]:80;
server_name $www $domain;
location / {
$root $content_location;
index index.html index.htm index.php;
}
}
" > /etc/nginx/sites-available/$domain
ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain
systemctl restart nginx
# generating certificate
cert=$(ask "Do you wish to generate a new certificate?" "[yYnN]")
if [[ $cert =~ [yY] ]];then
	check_if_installed certbot
	check_firewall_open_ports 443
	certbot="certbot certonly --$certtype -d $domain"
	if [ "$www" != "" ]; then
		certbot="$certbot -d $www"
	fi
	if [ "$certtype" == "standalone" ];then
		systemctl stop nginx
		echo "stopped"
	fi
	$certbot
	systemctl restart nginx
fi
# .htaccess setup
ht=$(ask "Do you want to set up password athentication for this website?" "[yYnN]")
if [[ $ht =~ [yY] ]];then
	newht=$(ask "Do you want to add a new user to the .htaccess file?" "[yYnN]")
	if [[ $newht =~ [yY] ]];then	
		username=$(ask "Username")	
		sh -c "echo -n $username: >> /etc/nginx/.htpasswd"
		sh -c "openssl passwd -apr1 >> /etc/nginx/.htpasswd"
	fi
	ht='auth_basic "Restricted Content"; auth_basic_user_file /etc/nginx/.htpasswd;'
else
	ht=""
fi
# create conf file and linking it
ssl=$(ask "Do you want to use ssl?" "[yYnN]")
if [[ $ssl =~ [yY] ]];then
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
	$root $content_location;
	$ht
	index index.html index.htm index.php;
}
}
server {
listen 80;
listen [::]:80;
server_name $www $domain;
"'return 301 https://$host$request_uri;
}' > /etc/nginx/sites-available/$domain
fi

systemctl restart nginx
echo 'All done!'
