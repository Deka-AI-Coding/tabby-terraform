 
docker run -v "$PWD/certbot/www:/var/www/certbot" -v "$PWD/certbot/conf:/etc/letsencrypt" --rm -it certbot/certbot certonly --webroot --webroot-path /var/www/certbot/
