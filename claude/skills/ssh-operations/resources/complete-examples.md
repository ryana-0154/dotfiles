# Complete SSH Examples

Real-world SSH scenarios with full implementations, error handling, and security reviews.

## Table of Contents

1. [Example 1: Initial Server Setup with SSH Key](#example-1-initial-server-setup-with-ssh-key)
2. [Example 2: Deploy Node.js Application](#example-2-deploy-nodejs-application)
3. [Example 3: Database Backup Over SSH](#example-3-database-backup-over-ssh)
4. [Example 4: Bastion Host Access Pattern](#example-4-bastion-host-access-pattern)
5. [Example 5: SSH Tunnel for Database Access](#example-5-ssh-tunnel-for-database-access)
6. [Example 6: Multi-Server Deployment Automation](#example-6-multi-server-deployment-automation)
7. [Example 7: Troubleshooting Walkthrough](#example-7-troubleshooting-walkthrough)

---

## Example 1: Initial Server Setup with SSH Key

### Scenario
New VPS at 203.0.113.10. Set up SSH key authentication and harden security.

### Prerequisites
- Server accessible via password (initial setup only)
- Root or sudo access on server

### Step 1: Generate SSH Key

```bash
# Check for existing keys
ls -la ~/.ssh/id_*.pub

# Generate new ed25519 key if needed
ssh-keygen -t ed25519 -C "your_email@example.com"
# Enter passphrase when prompted (REQUIRED for production)

# Verify key created
ls -la ~/.ssh/id_ed25519*
# Should show:
# -rw------- id_ed25519       (private key, 600 permissions)
# -rw-r--r-- id_ed25519.pub   (public key, 644 permissions)
```

### Step 2: Copy Public Key to Server

```bash
# Method 1: Using ssh-copy-id (easiest)
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@203.0.113.10
# Enter password when prompted
# Key automatically added to ~/.ssh/authorized_keys

# Method 2: Manual copy (if ssh-copy-id not available)
cat ~/.ssh/id_ed25519.pub | ssh user@203.0.113.10 \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
# Enter password when prompted
```

### Step 3: Test Key-Based Login

```bash
# Test connection with new key
ssh -i ~/.ssh/id_ed25519 user@203.0.113.10

# Should connect WITHOUT password prompt
# If prompted for passphrase, that's for your private key (correct)
# If prompted for server password, key auth failed (troubleshoot)

# Test and exit
ssh -i ~/.ssh/id_ed25519 user@203.0.113.10 'echo "Key auth works!" && exit'
```

### Step 4: Create SSH Config Entry

```bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config <<'EOF'

Host myvps
    HostName 203.0.113.10
    User myuser
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

# Set correct permissions
chmod 600 ~/.ssh/config

# Test alias
ssh myvps 'hostname'
```

### Step 5: Harden Server SSH Configuration

```bash
# Connect to server
ssh myvps

# Backup current SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# Edit sshd_config (KEEP CURRENT SESSION OPEN!)
sudo vi /etc/ssh/sshd_config

# Recommended changes:
# PasswordAuthentication no          # Disable password auth
# PermitRootLogin no                  # Disable root login
# PubkeyAuthentication yes            # Enable key auth
# ChallengeResponseAuthentication no  # Disable challenge-response

# Test configuration syntax
sudo sshd -t
# No output = config is valid
# Error messages = fix before restarting

# Restart SSH (in existing session!)
sudo systemctl restart sshd

# DO NOT close this session yet!
```

### Step 6: Test in New Terminal

```bash
# Open NEW terminal, test connection
ssh myvps

# Should connect with key-based auth
# If successful, safe to close old session

# If locked out:
# - Use server console (VPS provider panel)
# - Restore backup: sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
# - Restart sshd: sudo systemctl restart sshd
```

### Security Review

✅ Ed25519 key with passphrase
✅ Key-based authentication working
✅ Password authentication disabled
✅ Root login disabled
✅ SSH config organized
✅ Server config backed up before changes

---

## Example 2: Deploy Node.js Application

### Scenario
Deploy Node.js app from Git to production server with zero-downtime.

### Prerequisites
- SSH access to production server
- Git repository with app code
- Node.js and npm installed on server

### Deployment Script

```bash
#!/bin/bash
# deploy-app.sh

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SERVER="prod-web"
APP_DIR="/var/www/myapp"
BACKUP_DIR="/var/backups/myapp"
GIT_REPO="https://github.com/user/myapp.git"
BRANCH="main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment...${NC}"

# Step 1: Create backup
echo -e "${YELLOW}Creating backup...${NC}"
ssh $SERVER "bash -s" <<'ENDSSH'
set -euo pipefail

BACKUP_DIR="/var/backups/myapp/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR
cp -r /var/www/myapp $BACKUP_DIR/ || true
echo "Backup created at: $BACKUP_DIR"
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}Backup failed${NC}"
    exit 1
fi

# Step 2: Deploy new version
echo -e "${YELLOW}Deploying new version...${NC}"
ssh $SERVER "bash -s" <<ENDSSH
set -euo pipefail

cd /var/www/myapp

# Git operations
echo "Pulling latest code..."
git fetch origin
git checkout $BRANCH
git pull origin $BRANCH

# Dependency installation
echo "Installing dependencies..."
npm ci --production

# Build
echo "Building application..."
npm run build

echo "Deployment files ready"
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed${NC}"
    echo -e "${YELLOW}Rolling back...${NC}"

    # Rollback (restore from backup)
    ssh $SERVER "bash -s" <<'ENDSSH'
    LATEST_BACKUP=$(ls -td /var/backups/myapp/backup-* | head -1)
    echo "Restoring from: $LATEST_BACKUP"
    rm -rf /var/www/myapp
    cp -r $LATEST_BACKUP/myapp /var/www/
    sudo systemctl restart myapp
ENDSSH

    echo -e "${RED}Rolled back to previous version${NC}"
    exit 1
fi

# Step 3: Restart application
echo -e "${YELLOW}Restarting application...${NC}"
ssh $SERVER 'sudo systemctl restart myapp'

if [ $? -ne 0 ]; then
    echo -e "${RED}Restart failed${NC}"
    exit 1
fi

# Step 4: Health check
echo -e "${YELLOW}Running health check...${NC}"
sleep 5  # Give app time to start

ssh $SERVER 'curl -f http://localhost:3000/health || exit 1'

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Deployment successful!${NC}"

    # Cleanup old backups (keep last 5)
    ssh $SERVER "bash -s" <<'ENDSSH'
cd /var/backups/myapp
ls -t | tail -n +6 | xargs -r rm -rf
echo "Cleaned up old backups"
ENDSSH

else
    echo -e "${RED}Health check failed${NC}"
    echo -e "${YELLOW}Rolling back...${NC}"

    ssh $SERVER "bash -s" <<'ENDSSH'
    LATEST_BACKUP=$(ls -td /var/backups/myapp/backup-* | head -1)
    rm -rf /var/www/myapp
    cp -r $LATEST_BACKUP/myapp /var/www/
    sudo systemctl restart myapp
ENDSSH

    echo -e "${RED}Rolled back due to failed health check${NC}"
    exit 1
fi
```

### Usage

```bash
# Make executable
chmod +x deploy-app.sh

# Run deployment
./deploy-app.sh
```

### Security Review

✅ No credentials in script
✅ Backup before deployment
✅ Rollback on failure
✅ Health check validation
✅ Set -euo pipefail for safety

---

## Example 3: Database Backup Over SSH

### Scenario
Automated PostgreSQL backup from remote database server.

### Backup Script

```bash
#!/bin/bash
# backup-database.sh

set -euo pipefail

# Configuration
DB_SERVER="db-prod"
DB_NAME="production_db"
DB_USER="backup_user"
BACKUP_LOCAL_DIR="./backups"
BACKUP_REMOTE_DIR="/var/backups/postgres"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="backup-${DB_NAME}-${DATE}.sql.gz"

# Ensure local backup directory exists
mkdir -p "$BACKUP_LOCAL_DIR"

echo "Starting database backup: $DB_NAME"

# Step 1: Create backup on remote server
echo "Creating backup on remote server..."
ssh $DB_SERVER "bash -s" <<ENDSSH
set -euo pipefail

# Ensure backup directory exists
mkdir -p $BACKUP_REMOTE_DIR

# Create backup with compression
echo "Dumping database..."
pg_dump -U $DB_USER -d $DB_NAME | gzip > $BACKUP_REMOTE_DIR/$BACKUP_FILE

# Verify backup file exists and is not empty
if [ ! -s $BACKUP_REMOTE_DIR/$BACKUP_FILE ]; then
    echo "Backup file is empty or doesn't exist"
    exit 1
fi

# Get file size
du -h $BACKUP_REMOTE_DIR/$BACKUP_FILE
ENDSSH

if [ $? -ne 0 ]; then
    echo "Remote backup failed"
    exit 1
fi

# Step 2: Copy backup to local machine
echo "Copying backup to local machine..."
scp $DB_SERVER:$BACKUP_REMOTE_DIR/$BACKUP_FILE $BACKUP_LOCAL_DIR/

if [ $? -ne 0 ]; then
    echo "Backup copy failed"
    exit 1
fi

# Step 3: Verify local backup
echo "Verifying local backup..."
if [ ! -s "$BACKUP_LOCAL_DIR/$BACKUP_FILE" ]; then
    echo "Local backup file is invalid"
    exit 1
fi

echo "Backup file: $BACKUP_LOCAL_DIR/$BACKUP_FILE"
echo "Size: $(du -h "$BACKUP_LOCAL_DIR/$BACKUP_FILE" | cut -f1)"

# Step 4: Test backup integrity (optional but recommended)
echo "Testing backup integrity..."
gunzip -t "$BACKUP_LOCAL_DIR/$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup integrity verified"
else
    echo "Backup corruption detected!"
    exit 1
fi

# Step 5: Cleanup old backups (keep last 7 days locally)
echo "Cleaning up old backups..."
find "$BACKUP_LOCAL_DIR" -name "backup-${DB_NAME}-*.sql.gz" -mtime +7 -delete

# Cleanup remote backups (keep last 3 days)
ssh $DB_SERVER "bash -s" <<ENDSSH
find $BACKUP_REMOTE_DIR -name "backup-${DB_NAME}-*.sql.gz" -mtime +3 -delete
echo "Remote cleanup complete"
ENDSSH

echo "Backup completed successfully: $BACKUP_FILE"
```

### Automated Backups with Cron

```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /path/to/backup-database.sh >> /var/log/db-backup.log 2>&1
```

### Security Review

✅ Dedicated backup user with minimal privileges
✅ No database password in script (uses .pgpass or peer auth)
✅ Backup integrity verification
✅ Automated cleanup
✅ Error handling at each step

---

## Example 4: Bastion Host Access Pattern

### Scenario
Access internal production servers through a bastion host.

### SSH Config Setup

```bash
# ~/.ssh/config

# Bastion host (public internet accessible)
Host bastion
    HostName bastion.example.com
    User bastion-user
    IdentityFile ~/.ssh/id_ed25519_bastion
    IdentitiesOnly yes
    ServerAliveInterval 60

# Production web servers (internal network)
Host prod-web-*
    ProxyJump bastion
    User deploy
    IdentityFile ~/.ssh/id_ed25519_prod
    IdentitiesOnly yes
    StrictHostKeyChecking yes

# Production database servers (internal network)
Host prod-db-*
    ProxyJump bastion
    User db-admin
    IdentityFile ~/.ssh/id_ed25519_prod_db
    IdentitiesOnly yes
    StrictHostKeyChecking yes

# Specific servers
Host prod-web-01
    HostName 10.0.1.10

Host prod-web-02
    HostName 10.0.1.11

Host prod-db-01
    HostName 10.0.2.10
```

### Usage Examples

```bash
# Connect to web server through bastion
ssh prod-web-01

# Execute command on web server
ssh prod-web-01 'systemctl status nginx'

# Copy file to web server through bastion
scp app-config.yml prod-web-01:/etc/app/

# Copy file from database server
scp prod-db-01:/var/backups/db-backup.sql.gz ./

# Multi-hop: bastion → gateway → internal
Host very-internal
    HostName 10.0.50.100
    ProxyJump bastion,prod-web-01
    User admin
```

### Security Review

✅ ProxyJump instead of agent forwarding
✅ Separate keys for bastion and internal servers
✅ IdentitiesOnly prevents key exposure
✅ StrictHostKeyChecking on production hosts

---

## Example 5: SSH Tunnel for Database Access

### Scenario
Access remote PostgreSQL database from local machine through SSH tunnel.

### Method 1: Manual Tunnel

```bash
# Create SSH tunnel
ssh -N -L 5432:localhost:5432 db-server

# In another terminal, connect to database
psql -h localhost -p 5432 -U dbuser -d production

# Ctrl+C in first terminal to close tunnel
```

### Method 2: Background Tunnel

```bash
# Start tunnel in background
ssh -f -N -L 5432:localhost:5432 db-server

# Find SSH process
ps aux | grep "ssh.*5432"

# Connect to database
psql -h localhost -p 5432 -U dbuser -d production

# Kill tunnel when done
pkill -f "ssh.*5432"
```

### Method 3: Tunnel Script with Auto-Cleanup

```bash
#!/bin/bash
# db-tunnel.sh

set -euo pipefail

DB_SERVER="prod-db"
LOCAL_PORT=5432
REMOTE_PORT=5432
PID_FILE="/tmp/ssh-tunnel-db.pid"

start_tunnel() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo "Tunnel already running (PID: $PID)"
            return 0
        fi
    fi

    echo "Starting SSH tunnel to $DB_SERVER..."
    ssh -f -N -L $LOCAL_PORT:localhost:$REMOTE_PORT $DB_SERVER

    # Get PID of SSH process
    PID=$(ps aux | grep "ssh.*$LOCAL_PORT:localhost:$REMOTE_PORT" | grep -v grep | awk '{print $2}')
    echo $PID > "$PID_FILE"

    echo "Tunnel started (PID: $PID)"
    echo "Connect with: psql -h localhost -p $LOCAL_PORT"
}

stop_tunnel() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No tunnel PID file found"
        return 1
    fi

    PID=$(cat "$PID_FILE")

    if ps -p $PID > /dev/null 2>&1; then
        echo "Stopping tunnel (PID: $PID)..."
        kill $PID
        rm "$PID_FILE"
        echo "Tunnel stopped"
    else
        echo "Tunnel process not running"
        rm "$PID_FILE"
    fi
}

status_tunnel() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Tunnel not running"
        return 1
    fi

    PID=$(cat "$PID_FILE")

    if ps -p $PID > /dev/null 2>&1; then
        echo "Tunnel running (PID: $PID)"
        netstat -an | grep $LOCAL_PORT || true
        return 0
    else
        echo "Tunnel PID file exists but process not running"
        rm "$PID_FILE"
        return 1
    fi
}

case "${1:-}" in
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    status)
        status_tunnel
        ;;
    restart)
        stop_tunnel
        start_tunnel
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
```

### Usage

```bash
# Start tunnel
./db-tunnel.sh start

# Check status
./db-tunnel.sh status

# Use tunnel
psql -h localhost -p 5432 -U dbuser -d production

# Stop tunnel
./db-tunnel.sh stop
```

### Security Review

✅ Tunnel encrypted via SSH
✅ Database credentials not exposed
✅ Local-only access (localhost)
✅ Auto-cleanup script
✅ PID tracking prevents duplicates

---

## Example 6: Multi-Server Deployment Automation

### Scenario
Deploy configuration updates to multiple web servers in parallel.

### Deployment Script

```bash
#!/bin/bash
# multi-server-deploy.sh

set -euo pipefail

# Server list
SERVERS=(
    "prod-web-01"
    "prod-web-02"
    "prod-web-03"
)

CONFIG_FILE="nginx.conf"
REMOTE_PATH="/etc/nginx/nginx.conf"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Arrays to track results
declare -a SUCCESS_SERVERS
declare -a FAILED_SERVERS

# Deploy to single server
deploy_to_server() {
    local server=$1

    echo "[$server] Starting deployment..."

    # Backup existing config
    ssh "$server" "sudo cp $REMOTE_PATH ${REMOTE_PATH}.backup.${TIMESTAMP}" || {
        echo "[$server] Backup failed"
        return 1
    }

    # Copy new config
    scp "$CONFIG_FILE" "${server}:/tmp/nginx.conf.new" || {
        echo "[$server] SCP failed"
        return 1
    }

    # Validate and install
    ssh "$server" "bash -s" <<'ENDSSH' || {
set -e

# Test configuration syntax
sudo nginx -t -c /tmp/nginx.conf.new

# Install new config
sudo mv /tmp/nginx.conf.new /etc/nginx/nginx.conf

# Reload nginx
sudo systemctl reload nginx

echo "Deployment successful"
ENDSSH
        echo "[$server] Installation failed"
        # Rollback
        ssh "$server" "sudo cp ${REMOTE_PATH}.backup.${TIMESTAMP} $REMOTE_PATH && sudo systemctl reload nginx"
        return 1
    }

    echo "[$server] Deployment completed"
    return 0
}

# Deploy to all servers in parallel
for server in "${SERVERS[@]}"; do
    deploy_to_server "$server" &
done

# Wait for all background jobs
wait

# Check results
echo ""
echo "==================================="
echo "Deployment Summary"
echo "==================================="

for server in "${SERVERS[@]}"; do
    # Verify deployment
    if ssh "$server" 'sudo nginx -v 2>&1 && sudo systemctl is-active nginx' > /dev/null 2>&1; then
        echo "✅ $server - SUCCESS"
        SUCCESS_SERVERS+=("$server")
    else
        echo "❌ $server - FAILED"
        FAILED_SERVERS+=("$server")
    fi
done

echo ""
echo "Success: ${#SUCCESS_SERVERS[@]}/${#SERVERS[@]}"

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo "Failed servers: ${FAILED_SERVERS[*]}"
    exit 1
fi

echo "All deployments successful"
```

### Security Review

✅ Backup before changes
✅ Configuration validation
✅ Rollback on failure
✅ Parallel execution for efficiency
✅ Deployment summary

---

## Example 7: Troubleshooting Walkthrough

### Problem
Cannot connect to production server. Error: "Permission denied (publickey)"

### Step 1: Gather Information

```bash
# Attempt connection with verbose output
ssh -vvv prod-web-01
```

### Step 2: Analyze Verbose Output

Look for these key lines:
```
debug1: Offering public key: /home/user/.ssh/id_ed25519 ED25519 SHA256:abc123...
debug1: Authentications that can continue: publickey
debug1: No more authentication methods to try.
```

### Step 3: Check Local Key

```bash
# List keys in agent
ssh-add -l
# If empty, key not loaded

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Verify correct permissions
ls -la ~/.ssh/id_ed25519
# Should be: -rw------- (600)

# Fix if needed
chmod 600 ~/.ssh/id_ed25519
```

### Step 4: Verify SSH Config

```bash
# Check effective config for this host
ssh -G prod-web-01

# Look for:
# - identityfile (correct key?)
# - user (correct username?)
# - hostname (correct server?)
```

### Step 5: Check Server-Side (if accessible via alternate method)

```bash
# Via console or alternate user
cat ~/.ssh/authorized_keys

# Verify your public key is present
# Check file permissions
ls -la ~/.ssh/
ls -la ~/.ssh/authorized_keys

# Should be:
# drwx------ .ssh/ (700)
# -rw------- authorized_keys (600)

# Fix if needed
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Step 6: Test with Specific Key

```bash
# Explicitly specify key
ssh -i ~/.ssh/id_ed25519 user@host

# If works, issue is with SSH config or agent
# If fails, issue is with key or server config
```

### Solution Found
Key was not in agent. Fixed with `ssh-add ~/.ssh/id_ed25519`.

### Prevention
Add to ~/.ssh/config:
```
AddKeysToAgent yes
```

---

**Related Resources:**
- [remote-execution.md](remote-execution.md) - Command execution patterns
- [security-best-practices.md](security-best-practices.md) - Security guidance
- [troubleshooting.md](troubleshooting.md) - Error diagnostics
