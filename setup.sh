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

# location of website files or reverse proxy
while [ -z $reverse ]; do
	read -p 'Are you setting up a reverse proxy?(yn) ' reverse
done
# creating the nginx config file
case $reverse in
[yY])
	# using reverse proxy
	root="proxy_pass"
	#getting proxy address
	while [ -z $conent_location ]; do
		read -p 'Web server address with port (eg. http://127.0.0.1:8080): ' content_location
	done
	certtype="standalone"
	;;
*)
	# using server-block
	root="root"
	#server-block path
	read -p "Location of your server-block (leave empty for default(/var/www/$folder/content/html)): " content_location
	if [ -z $content_location ]; then
		conent_location="/var/www/$folder/content/html"
	fi
	#adding default site if no index.html file exists
	mkdir -p "$content_location"
	if [ ! -f "$content_location/index.html" ]; then
		echo "welcome to $domain" > "$content_location/index.html"
	fi
	certtype="webroot --webroot-path $content_location"
	;;
esac
echo "server {
	listen 80;
	listen [::]:80;
	server_name $www $domain;
	location / {
		$root $content_location;
		index index.html index.htm index.php;
	}
}
" > /etc/nginx/sites-available/$folder
ln -s /etc/nginx/sites-available/$folder /etc/nginx/sites-enabled/$folder
#generating certificate
read -p 'Do you wish to generate a new certificate?(yn) ' cert
case $cert in [yY]* )
	if [ -z $(which certbot) ]; then
		echo "certbot is not installed"
		exit 1
	fi
	certbot="certbot certonly --$certtype -d $domain"
	if [ "$www" != "" ]; then
		certbot="$certbot -d $www"
	fi
	if [ "$certtype" == "standalone" ]; then
		systemctl stop nginx
		echo "stopped"
	fi
	systemctl restart nginx
	$certbot
esac
#.htaccess setup
while [ -z $ht ]; do
	read -p 'Do you want to set up password athentication for this website?(yn) ' ht
done
case $ht in
[yY])
	while [ -z $newht ]; do
		read -p 'Do you want to add a new user to the .htaccess file?(yn) ' newht
	done
	case $newht in [yY])
			while [ -z $username ]; do
				read -p 'Username: ' username
			done
			sh -c "echo -n $username: >> /etc/nginx/.htpasswd"
			sh -c "openssl passwd -apr1 >> /etc/nginx/.htpasswd"
	esac
	ht='auth_basic "Restricted Content"; auth_basic_user_file /etc/nginx/.htpasswd;'
	;;
*)
	ht=""
	;;
esac
# create conf file and linking it
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
	}' > /etc/nginx/sites-available/$folder
esac

# create a git repo for the content being hosted
read -p "would you like to create a git repo for the content being hosted in $domain?(yY) " git
case $git in [yY]* )
	mkdir -p /var/www/$folder/$folder.git
	git init --bare /var/www/$folder/$folder.git
	read "should a single user have ownership over the folder /var/www/$folder?(yY) (answer no for a group) " sigle_user
	case $single_user in [yY]* )
		read -p 'Who is the owner of this workflow? ' owner
		chown -R $owner /var/www/$folder
		;;
	*)
		read -p "Which group should have ownership over the folder $folder" owner
		chgrp $owner /var/www/$folder 
		;;
	esac
	touch /var/www/$folder/$folder.git/hooks/post-receive
	echo "git --work-tree=/var/www/$name/content --git-dir=/var/www/$name/$name.git checkout -f master" > /var/www/$folder/$folder.git/hooks/post-receive
	chmod +x /var/www/$folder/$folder.git/hooks/post-receive
	rm $content_location/index.html
;;
esac

systemctl restart nginx
echo 'All done!'
