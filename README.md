# setup-nginx-certbot
A script that automaticly sets up a nginx serverblock with ssl on GNU/Linux
## How it works:
<ul>
	<li>The scriptcreates configuration files in /etc/nginx/sites-available/...</li>
	<li>The path for the html files will be  /var/www/*domain*/content/html</li>
	<li>If you want to, certbot generates a new new ssl certificate which the script can include in the nginx conf file</li>
</ul>

## How to use it:

```
install nginx and certbot
```
```
sudo ./setup.sh
```
```
answer the prompts
```

## Host from git repo

