## Azure VM Setup (No Docker) — Node.js + Nginx + PM2 + MySQL

End-to-end guide to deploy the Node.js backend on an Azure Virtual Machine without Docker.

---

### Overview
- Runtime: Node.js 24.x LTS (or 20.x LTS)
- Web server: Nginx (reverse proxy)
- Process manager: PM2
- Database: MySQL 8+ (self-managed on VM) or Azure Database for MySQL (managed)
- OS: Ubuntu Server 22.04 LTS
- SSL: Self-signed (for MVP/testing) or Let's Encrypt (Certbot) for production

Estimated cost: ~$10/month (Standard B1s VM) + optional managed MySQL (~$12/month)

---

### 1) Provision Azure Resources

```bash
# Login
az login

# Resource group
az group create --name dayparty-rg --location westeurope

# VM (Ubuntu 22.04 LTS)
az vm create \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --authentication-type ssh \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-sku Basic

# Open ports (HTTP 80, HTTPS 443, SSH 22)
az vm open-port --resource-group dayparty-rg --name dayparty-vm --port 80
az vm open-port --resource-group dayparty-rg --name dayparty-vm --port 443
az vm open-port --resource-group dayparty-rg --name dayparty-vm --port 22

# Get public IP
az vm show -d -g dayparty-rg -n dayparty-vm --query publicIps -o tsv

# Current VM IP: 172.167.43.172 (uksouth region)

**Current Status:** ✅ VM configured with Node.js 24.11.0, Nginx, PM2, and MySQL 8.0.43

---

### 2) Connect and Base Setup

```bash
# SSH into the VM
ssh azureuser@<PUBLIC_IP>

# Update system
sudo apt update && sudo apt -y upgrade

# Optional: enable UFW and allow ports
sudo ufw allow OpenSSH
sudo ufw allow "Nginx Full"  # opens 80/443
sudo ufw enable
```

---

### 3) Install Node.js 20.x LTS and PM2

```bash
# NodeSource setup for Node LTS (24.x or 20.x)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
# Or for Node 20.x specifically: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs build-essential

# Verify
node -v
npm -v

# PM2 global
sudo npm i -g pm2
pm2 startup
```

---

### 4) Get Application Code on the VM

Options (choose one):
- Git pull from your repository (recommended)
- scp/rsync a build from local

```bash
# Example: clone into /var/www/dayparty-api
sudo mkdir -p /var/www/dayparty-api
sudo chown -R $USER:$USER /var/www/dayparty-api
cd /var/www/dayparty-api

git clone <YOUR_REPO_URL> .

# Install deps and build (TypeScript)
npm ci
npx prisma generate || true
npm run build
```

Create environment file:
```bash
cp .env.example .env
nano .env
# Set DATABASE_URL, JWT_SECRET, etc.
```

Run DB migrations (if using Prisma migrations):
```bash
npx prisma migrate deploy
```

---

### 5) Configure PM2 to Run the App

```bash
# Start app
pm2 start dist/server.js --name dayparty-api

# Persist across restarts
pm2 save
# PM2 startup was set earlier; follow printed command if shown
```

Check logs:
```bash
pm2 logs dayparty-api
```

---

### 6) Install and Configure Nginx (Reverse Proxy)

```bash
sudo apt install -y nginx

# Create site config (HTTP-only or with SSL redirect)
sudo tee /etc/nginx/sites-available/dayparty-api > /dev/null <<'NGINX'
# HTTP server - redirect to HTTPS (if using SSL)
server {
    listen 80;
    server_name api.dayparty.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl;
    server_name api.dayparty.com;

    # SSL configuration (for self-signed or Let's Encrypt)
    ssl_certificate /etc/nginx/ssl/dayparty.crt;
    ssl_certificate_key /etc/nginx/ssl/dayparty.key;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Optional: increase body size for uploads
    client_max_body_size 50M;
}

# If NOT using SSL, use this simpler config instead:
# server {
#     listen 80;
#     server_name api.dayparty.com;
#     location / {
#         proxy_pass http://127.0.0.1:3000;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade $http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host $host;
#         proxy_cache_bypass $http_upgrade;
#     }
# }
NGINX

# Enable site
sudo ln -s /etc/nginx/sites-available/dayparty-api /etc/nginx/sites-enabled/dayparty-api
sudo nginx -t
sudo systemctl reload nginx
```

---

### 7) SSL Setup

#### Option A: Self-Signed Certificate (For Testing/MVP)

```bash
# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate (valid for 365 days)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/dayparty.key \
  -out /etc/nginx/ssl/dayparty.crt \
  -subj "/C=US/ST=State/L=City/O=DayParty/CN=<YOUR_DOMAIN_OR_IP>"

# Update Nginx config to use SSL (see section 6)
```

**Note:** Browsers will show a security warning for self-signed certificates. Use only for development/testing.

#### Option B: Let's Encrypt (Certbot) — Recommended for Production

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.dayparty.com
# Follow prompts (email, agree, redirect HTTP→HTTPS)

# Auto-renewal (installed by default)
sudo systemctl status certbot.timer
```

---

### 8) Database Options

#### A) Self-Managed MySQL on VM (Lowest Cost) ✅ **COMPLETED**
```bash
sudo apt install -y mysql-server
sudo mysql_secure_installation

# Create DB and user
sudo mysql -uroot <<SQL
CREATE DATABASE dayparty CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'dayparty'@'localhost' IDENTIFIED BY 'DayParty2024!SecurePW';
GRANT ALL PRIVILEGES ON dayparty.* TO 'dayparty'@'localhost';
GRANT PROCESS ON *.* TO 'dayparty'@'localhost';
FLUSH PRIVILEGES;
SQL

# Load DDL schema
mysql -u dayparty -p dayparty < 11-MySQL-DDL.sql
# Password: DayParty2024!SecurePW

# Verify tables
mysql -u dayparty -p dayparty -e 'SHOW TABLES;'
```

**.env DATABASE_URL:** `mysql://dayparty:DayParty2024!SecurePW@localhost:3306/dayparty`

**Backups:**
- Backup script created: `~/backup-mysql.sh`
- Stores backups in `/var/backups/mysql/`
- Keeps 7 days of backups
- Can be scheduled with cron (optional)

**Current Database Stats:**
- MySQL version: 8.0.43
- Database: `dayparty` (utf8mb4_unicode_ci)
- Tables created: 10 (users, user_identities, topics, topic_roles, threads, nodes, node_votes, node_versions, modality_generation_jobs, reports, notifications)

#### B) Managed MySQL (Azure Database for MySQL Flexible Server)
- Provision per `16-Azure-Hosting-Options.md`
- Update `.env` with `DATABASE_URL` including SSL
- Open firewall or use private endpoint (preferred)

---

### 9) Hardening and Maintenance
- Create a non-root deploy user, limit sudo access
- Disable password SSH login; use SSH keys only
- Keep system updated: `sudo apt update && sudo apt -y upgrade`
- Enable unattended upgrades if desired
- Regularly rotate JWT secrets and DB passwords
- Monitor disk space: `df -h` (logs, MySQL data)

---

### 10) Monitoring & Logs
- PM2 logs: `pm2 logs dayparty-api`
- Nginx logs: `/var/log/nginx/access.log`, `/var/log/nginx/error.log`
- Systemd services status: `systemctl status nginx`
- Consider Azure Monitor/Log Analytics for centralized metrics

---

### 11) Zero-Downtime Deployments (Basic)
```bash
# Pull latest code
cd /var/www/dayparty-api
git pull

# Install deps/build (if needed)
npm ci
npx prisma migrate deploy || true
npm run build

# Reload app
pm2 reload dayparty-api
pm2 save
```

---

### 12) Troubleshooting
- 502/Bad Gateway: Check app is running on port 3000; verify Nginx config
- SSL issues: Rerun Certbot; ensure DNS points to VM public IP
- Port blocked: Check NSG rules and UFW
- App crash loop: Check PM2 logs; verify `.env` values

---

### 13) Cost Notes
- VM Standard B1s: ~ $10/month
- Self-managed MySQL: included on the VM (no extra Azure DB cost)
- Managed MySQL (optional): ~ $12/month
- Domain + DNS: external provider cost (varies)

---

### 14) Next Steps
- Set up CI/CD (GitHub Actions) to SSH and deploy
- Add Application Insights or Prometheus for metrics
- Implement backups (database + VM snapshots)
- Create staging environment (smaller VM)
