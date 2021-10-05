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

# check if nginx is installed
if [ -z $(which nginx) ]; then
	echo "nginx not installed"
	exit 1
fi
systemctl enable nginx
systemctl start nginx
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
# generating certificate
cert=$(ask "Do you want to generate a new certificate?" "[yYnN]")
if [[ $cert =~ [yY] ]];then
	if [ -z $(which certbot) ]; then
		echo "certbot is not installed"
		exit 1
	fi
	certbot="certbot certonly --$certtype -d $domain"
	if [ "$www" != "" ]; then
		certbot="$certbot -d $www"
	fi
	if [ "$certtype" == "standalone" ];then
		systemctl stop nginx
		echo "stopped"
	fi
	systemctl restart nginx
	$certbot
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
# create a git repo for the content being hosted
git=$(ask "Would you like to create a git repo for the content being hosted in $domain?" "[yYnN]")
if [[ $git =~ [yY] ]];then
	# create a git.domain from where all of the .git files can be easily reached e.g. the git repo for the content in test.example.com would be git.example.com/test.git
	# make website for git
	git_domain=$(ask "What is the domain for your git server (e.g. git.example.com)?")	
	# if the server config for that domain allready exists the user can choose not to create a new one
	if [ -f "/etc/nginx/sites-available/$git_domain" ];then
		skip=($ask "This domain allready exists do you want to create new config files?" "[yYnN]")
	fi
	if ! [[ $skip =~ [yY] ]];then
		read -p "Location of your server-block (leave empty for default(/var/www/$git_domain/html)): " git_content_location
		if [ -z "$git_content_location" ];then
			git_content_location="/var/www/$git_domain/html"
		fi
		echo "server {
		listen 80;
		listen [::]:80;
		server_name $git_domain;
		location / {
			root $git_content_location;
			index index.html index.htm index.php;
		}
		}" > /etc/nginx/sites-available/$git_domain
		ln -s /etc/nginx/sites-available/$git_domain /etc/nginx/sites-enabled/$git_domain

		# generating a certificate for for the git server
		cert=$(ask "Do you want to generate a new certificate for your git server?" "[yYnN]")
		if [[ $cert =~ [yY] ]];then
			if [ -z $(which certbot) ]; then
				echo "certbot is not installed"
				exit 1
			fi
			systemctl restart nginx
			certbot certonly --webroot --webroot-path /var/www/$git_domain/html -d $git_domain
		fi
		ssl=$(ask "Do you want to use ssl?" "[yYnN]")
		if [[ $ssl =~ [yY] ]];then
			echo "server {
			listen 443 ssl http2;
			listen [::]:443 ssl http2;
			server_name $git_domain;
			ssl_certificate /etc/letsencrypt/live/$git_domain/fullchain.pem;
			ssl_certificate_key /etc/letsencrypt/live/$git_domain/privkey.pem;
			ssl_session_cache    shared:SSL:1m;
			ssl_session_timeout  5m;
			ssl_ciphers  HIGH:!aNULL:!MD5;
			ssl_prefer_server_ciphers  on;
			location / {
				root $git_content_location;
				index index.html index.htm index.php;
			}
			}
			server {
			listen 80;
			listen [::]:80;
			server_name $git_domain;
			"'return 301 https://$host$request_uri;
			}' > /etc/nginx/sites-available/$git_domain
		fi
	fi
	if [ -z $git_content_location ];then
		read -p "Location of your server-block (leave empty for default(/var/www/$git_domain/html)): " git_content_location
		if [ -z $git_content_location ];then
			git_content_location="/var/www/$git_domain/html"
		fi
	fi
	mkdir -p $git_content_location/$domain.git
	git init --bare $git_content_location/$domain.git
	single_user=$(ask "Should a single user have ownership over the folder /var/www/$domain? (answer no for a group)" "[yYnN]")
	if [[ $single_user =~ [yY] ]];then
		owner=$(ask "Who is the owner of this workflow?")
		chown -R $owner $git_content_location/$domain.git
	else
		owner=$(ask "Which group should have ownership over the folder $domain?")
		chgrp $owner $git_content_location/$domain.git
	fi
	touch $git_content_location/$domain.git/hooks/post-receive
	echo "git --work-tree=$content_location --git-dir=$git_content_location/domain.git checkout -f master" > $git_content_location/$domain.git/hooks/post-receive
	chmod +x $git_content_location/$domain.git/hooks/post-receive
	rm $content_location/index.html
fi

systemctl restart nginx
echo 'All done!'
