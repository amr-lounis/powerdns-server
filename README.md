# PDNS Docker Compose — Setup Guide

## 1. Update system

```bash
sudo apt update
sudo apt upgrade -y
```

## 2. Install Docker

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
curl -fsSL https://get.docker.com | sudo sh
sudo service docker start
docker version
sudo usermod -aG docker $USER
exit
```

> Re-login after `usermod` for group changes to take effect.

## 3. Remove all Docker containers, networks, volumes, images

```bash
docker stop $(docker ps -q) 2>/dev/null
docker rm $(docker ps -aq) 2>/dev/null
docker volume rm $(docker volume ls -q) 2>/dev/null
docker network prune -f
#docker rmi $(docker images -aq)
```

## 4. Portainer

```bash
docker volume create portainer_data
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:lts
```

## 5. Create self-signed certificate

File names must match `nginx/conf.d/default.conf` (`cert.cert` / `cert.key`).

```bash
PATH_DIR="./nginx/certs"
mkdir -p $PATH_DIR
cd nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout cert.key -out cert.cert -subj "/C=SA/ST=Riyadh/L=Riyadh/O=IT/CN=powerdns-admin.local"
cd ../..
```

## 6. Disable systemd-resolved (free port 53 for PowerDNS)

```bash
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo rm -f /etc/resolv.conf
echo -e "nameserver 127.0.0.1\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
ss -tunap
ping -c 2 google.com
```

## 7. Make *.sh executable

```bash
ls -l *.sh
chmod +x *.sh
```

## 8. Run — VM1 (Primary)

```bash
sudo docker compose -f pdns1.yml up -d
```

## 9. Run — VM2 (Replica)

```bash
sudo docker compose -f pdns2.yml up -d
```

## 10. Backup / Restore

```bash
sudo apt update
sudo apt install postgresql-client
ls -l *.sh

./db_backup.sh
./db_restore.sh
```

## 11. Firewall

```bash
sudo ufw allow 22/tcp
sudo ufw allow 2222/tcp
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
# PostgreSQL: do NOT open 5432 to the world.
# Allow it only between Primary and Replica (replace with your IPs):
# sudo ufw allow from 192.168.10.11 to any port 5432 proto tcp
# sudo ufw allow from 192.168.10.12 to any port 5432 proto tcp
```

```bash
sudo ufw disable
sudo ufw enable
sudo ufw status numbered
```

## 12. Logs

View PostgreSQL Primary/Replica container logs to check startup, replication status, and errors.

```bash
docker logs pg_primary
docker logs pg_replica
```

## 13. Test DNS service

Verify that PowerDNS is answering DNS queries. This asks server `10.10.10.10` to resolve `www.site1.lan`.

```bash
nslookup www.site1.lan 10.10.10.10
```

## 14. Test API

Verify that the PowerDNS authoritative API is reachable. Replace `changeme` with your actual `PDNSAPIKEY` from `.env`.

```bash
# Check if the API webserver is up
curl http://127.0.0.1:8081

# List all servers
curl -H "X-API-Key: changeme" http://localhost:8081/api/v1/servers

# List all zones
curl -H "X-API-Key: changeme" http://localhost:8081/api/v1/servers/localhost/zones

# Get a specific zone (replace example.com with your zone name)
curl -H "X-API-Key: changeme" http://localhost:8081/api/v1/servers/localhost/zones/example.com
```
