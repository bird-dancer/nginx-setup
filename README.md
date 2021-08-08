# setup-nginx-certbot
A script that automaticly sets up a nginx serverblock with ssl on GNU/Linux
## What it does:
<ul>
	<li>It sets up nginx as a server block or as a reverse proxy</li>
	<ul>
		<li>For server blocks it generates a folder scructure with a test index.html file</li>
	</ul>	
	<li>If you want to, certbot generates a new new ssl certificate which the script can include in the nginx conf file</li>
	<li>If wanted, the script manages access to website via .htaccess and a username password combination</li>
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
