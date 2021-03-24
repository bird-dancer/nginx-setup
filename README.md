# setup-nginx-certbot
A script that automaticly sets up a nginx serverblock with ssl
## This script:
<ul>
	<li>creates configuration files in /etc/nginx/sites-available/...</li>
	<li>creates an index.html file in /var/www/*domain*/html</li>
	<li>if you want to uses certbot to genrate an ssl certificate and uses it</li>
</ul>

## How to use it:

```
install nginx and certbot
```
```
sudo ./setup.sh
```
```
answer the questions
```
