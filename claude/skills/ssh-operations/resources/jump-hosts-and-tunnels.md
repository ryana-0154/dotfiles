# Jump Hosts and SSH Tunnels

Guide to accessing internal servers through bastion hosts and SSH port forwarding.

## Table of Contents

1. [ProxyJump vs ProxyCommand](#proxyjump-vs-proxycommand)
2. [Bastion Host Patterns](#bastion-host-patterns)
3. [Local Port Forwarding](#local-port-forwarding)
4. [Remote Port Forwarding](#remote-port-forwarding)
5. [Dynamic Port Forwarding (SOCKS)](#dynamic-port-forwarding-socks)
6. [Multi-Hop Connections](#multi-hop-connections)
7. [Tunnel Security Considerations](#tunnel-security-considerations)

---

## ProxyJump vs ProxyCommand

### ProxyJump (Modern, Recommended)

**What it is:** Built-in SSH feature to connect through intermediate hosts.

**Advantages:**
- Simple syntax
- Automatic connection chaining
- Keys stay on your machine (secure)
- No need for netcat/nc
- Supports multiple hops

**Usage:**
```bash
# Command line
ssh -J jumphost targethost

# Multiple jumps
ssh -J jump1,jump2 targethost

# In SSH config
Host target
    ProxyJump jumphost
```

### ProxyCommand (Legacy)

**What it is:** Older method using external command (usually netcat).

**When to use:**
- Very old SSH versions (pre-OpenSSH 7.3)
- Custom proxy commands needed
- ProxyJump not available

**Example:**
```
Host target
    ProxyCommand ssh -W %h:%p jumphost
```

**Recommendation:** Use ProxyJump unless you have specific requirements for ProxyCommand.

---

## Bastion Host Patterns

### Basic Bastion Configuration

```
# ~/.ssh/config

# Bastion host (publicly accessible)
Host bastion
    HostName bastion.example.com
    User jumpuser
    IdentityFile ~/.ssh/id_ed25519_bastion
    IdentitiesOnly yes
    ServerAliveInterval 60

# Internal servers (via bastion)
Host internal-*
    ProxyJump bastion
    User admin
    IdentityFile ~/.ssh/id_ed25519_internal
    IdentitiesOnly yes

# Specific internal servers
Host internal-web-01
    HostName 10.0.1.10

Host internal-db-01
    HostName 10.0.2.10
```

**Usage:**
```bash
# Connect to internal server
ssh internal-web-01

# Copy files to internal server
scp file.txt internal-web-01:/path/

# Execute command on internal server
ssh internal-web-01 'systemctl status nginx'
```

### Pattern-Based Bastion Routing

```
# Different bastions for different environments

# Production bastion
Host prod-bastion
    HostName bastion-prod.company.com
    User prod-jump

# Staging bastion
Host staging-bastion
    HostName bastion-staging.company.com
    User staging-jump

# Production servers
Host prod-*
    ProxyJump prod-bastion
    User admin
    IdentityFile ~/.ssh/id_ed25519_prod

# Staging servers
Host staging-*
    ProxyJump staging-bastion
    User admin
    IdentityFile ~/.ssh/id_ed25519_staging

# Specific servers
Host prod-web-01
    HostName 10.0.1.10

Host staging-web-01
    HostName 10.1.1.10
```

### Bastion with Different User

```
# Bastion uses different username than target
Host bastion
    HostName bastion.example.com
    User jumpuser
    IdentityFile ~/.ssh/id_ed25519_bastion

Host internal-*
    ProxyJump bastion
    User admin  # Different user on target
    IdentityFile ~/.ssh/id_ed25519_internal
```

---

## Local Port Forwarding

### What is Local Port Forwarding

Forward local port → SSH tunnel → remote port. Access remote services on your local machine.

**Use cases:**
- Access remote database locally
- Access internal web service
- Bypass firewall restrictions

### Basic Local Forwarding

```bash
# Syntax: ssh -L local_port:destination:destination_port user@ssh_server

# Access remote PostgreSQL on local port 5432
ssh -L 5432:localhost:5432 user@db-server

# Now connect to database:
# psql -h localhost -p 5432 -U dbuser
```

### Forwarding to Different Host

```bash
# Forward through SSH server to third host
ssh -L 5432:internal-db:5432 user@bastion

# Connection flow:
# localhost:5432 → bastion → internal-db:5432
```

### Multiple Port Forwards

```bash
# Forward multiple ports
ssh -L 5432:db:5432 -L 6379:redis:6379 -L 3306:mysql:3306 user@bastion

# Or in config:
Host db-tunnels
    HostName bastion.example.com
    User admin
    LocalForward 5432 db-server:5432
    LocalForward 6379 redis-server:6379
    LocalForward 3306 mysql-server:3306
```

### Persistent Tunnel (No Shell)

```bash
# Keep tunnel open without shell session
ssh -N -L 5432:localhost:5432 user@db-server

# -N: Don't execute remote command
# -f: Run in background
ssh -f -N -L 5432:localhost:5432 user@db-server
```

### Bind to Specific Interface

```bash
# Default: binds to localhost only
ssh -L 5432:localhost:5432 user@host

# Bind to specific IP
ssh -L 192.168.1.100:5432:localhost:5432 user@host

# Bind to all interfaces (DANGEROUS - allows network access)
ssh -L 0.0.0.0:5432:localhost:5432 user@host
# or
ssh -L *:5432:localhost:5432 user@host
```

### SSH Config for Tunnels

```
# Database tunnel
Host db-tunnel
    HostName db-server.company.com
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_db
    LocalForward 5432 localhost:5432
    LocalForward 6379 redis:6379
    ExitOnForwardFailure yes  # Exit if forward fails

# Usage: ssh -N db-tunnel
```

---

## Remote Port Forwarding

### What is Remote Port Forwarding

Forward remote port → SSH tunnel → local port. Expose local services to remote server.

**Use cases:**
- Share local development server
- Access local database from remote
- Webhook testing

### Basic Remote Forwarding

```bash
# Syntax: ssh -R remote_port:destination:destination_port user@ssh_server

# Expose local web server (port 80) on remote port 8080
ssh -R 8080:localhost:80 user@remote-server

# Remote server can now access: http://localhost:8080
```

### Remote Forwarding to Third Host

```bash
# Forward remote port to different local host
ssh -R 8080:internal-service:80 user@remote-server

# Remote server port 8080 → your machine → internal-service:80
```

### Allow Remote Connections

By default, remote forwarding binds to localhost only on remote server.

**Server-side configuration** (in /etc/ssh/sshd_config):
```
GatewayPorts yes  # Allow non-localhost binding
# Or:
GatewayPorts clientspecified  # Let client specify
```

**Client usage:**
```bash
# Bind to all interfaces on remote
ssh -R 0.0.0.0:8080:localhost:80 user@remote
# or
ssh -R *:8080:localhost:80 user@remote
```

---

## Dynamic Port Forwarding (SOCKS)

### What is Dynamic Forwarding

Creates SOCKS proxy. Route any TCP traffic through SSH tunnel.

**Use cases:**
- Browse internal websites
- Access multiple internal services
- Bypass geo-restrictions
- Secure public WiFi browsing

### Basic SOCKS Proxy

```bash
# Create SOCKS proxy on local port 1080
ssh -D 1080 user@server

# Now configure browser/app to use:
# SOCKS5 proxy: localhost:1080
```

### Background SOCKS Proxy

```bash
# Run in background without shell
ssh -f -N -D 1080 user@server

# Check if running
ps aux | grep "ssh.*1080"

# Kill proxy
pkill -f "ssh.*1080"
```

### SSH Config for SOCKS

```
Host socks-proxy
    HostName proxy-server.example.com
    User proxy-user
    DynamicForward 1080
```

**Usage:**
```bash
# Start proxy
ssh -N socks-proxy

# Configure browser to use SOCKS5 proxy:
# Host: localhost
# Port: 1080
```

### Using SOCKS with Command Line Tools

```bash
# Start SOCKS proxy
ssh -f -N -D 1080 user@server

# Use with curl
curl --socks5 localhost:1080 http://internal-service

# Use with git
git config --global http.proxy 'socks5://localhost:1080'

# Use with wget
http_proxy=socks5://localhost:1080 wget http://internal-site
```

### Browser Configuration

**Firefox:**
1. Settings → Network Settings → Manual proxy configuration
2. SOCKS Host: localhost, Port: 1080
3. Select: SOCKS v5
4. Check: Proxy DNS when using SOCKS v5

**Chrome/Chromium:**
```bash
# Launch with proxy
google-chrome --proxy-server="socks5://localhost:1080"
```

**System-wide (Linux):**
```bash
# Environment variables
export http_proxy="socks5://localhost:1080"
export https_proxy="socks5://localhost:1080"
```

---

## Multi-Hop Connections

### Chaining Jump Hosts

```bash
# Command line: Two jumps
ssh -J jump1,jump2 target

# Three jumps
ssh -J jump1,jump2,jump3 target

# Different users on different jumps
ssh -J user1@jump1,user2@jump2 user3@target
```

### Multi-Hop in SSH Config

```
# First jump
Host jump1
    HostName jump1.example.com
    User jumpuser1

# Second jump
Host jump2
    HostName jump2.example.com
    User jumpuser2
    ProxyJump jump1

# Final target
Host target
    HostName target.example.com
    User targetuser
    ProxyJump jump2

# Alternative: chain directly
Host target-direct
    HostName target.example.com
    User targetuser
    ProxyJump jump1,jump2
```

### Complex Multi-Environment Setup

```
# Public bastion
Host bastion-public
    HostName bastion.company.com
    User bastion-user
    IdentityFile ~/.ssh/id_ed25519_bastion

# DMZ gateway (via public bastion)
Host dmz-gateway
    HostName 10.0.1.1
    User dmz-user
    IdentityFile ~/.ssh/id_ed25519_dmz
    ProxyJump bastion-public

# Internal network (via DMZ)
Host internal-*
    ProxyJump dmz-gateway
    User admin
    IdentityFile ~/.ssh/id_ed25519_internal

# High-security zone (via internal)
Host secure-*
    ProxyJump dmz-gateway,internal-gateway
    User secadmin
    IdentityFile ~/.ssh/id_ed25519_secure

# Specific servers
Host internal-web-01
    HostName 10.0.10.10

Host secure-db-01
    HostName 10.0.20.10
```

---

## Tunnel Security Considerations

### Local Port Forwarding Security

**Risks:**
- Exposed ports can be accessed by other local users
- Misconfigured binding exposes to network

**Best practices:**
```bash
# ✅ GOOD: Bind to localhost only (default)
ssh -L 5432:localhost:5432 user@host

# ❌ RISKY: Bind to all interfaces
ssh -L 0.0.0.0:5432:localhost:5432 user@host

# ✅ GOOD: Specific interface
ssh -L 127.0.0.1:5432:localhost:5432 user@host
```

### Remote Port Forwarding Security

**Risks:**
- Exposes your local services to remote server
- All users on remote server can access (if GatewayPorts=yes)

**Best practices:**
- Only use with trusted servers
- Use localhost binding when possible
- Limit who can access remote server
- Monitor connection attempts

### SOCKS Proxy Security

**Risks:**
- Anyone with access to proxy can route traffic through it
- Exposed proxy allows unauthorized network access
- DNS leaks can expose browsing

**Best practices:**
```bash
# ✅ GOOD: Bind to localhost
ssh -D 127.0.0.1:1080 user@host

# ❌ DANGEROUS: Bind to all interfaces
ssh -D 0.0.0.0:1080 user@host

# ✅ GOOD: Use SOCKS5 with DNS proxy
# Configure browser: "Proxy DNS when using SOCKS v5"
```

### Tunnel Monitoring

```bash
# List active tunnels
lsof -i -n | grep ssh

# List SSH connections
netstat -tn | grep :22

# Monitor connection attempts
sudo tcpdump -i any port 22

# Check forwarded ports
ss -tlnp | grep ssh
```

### Tunnel Hardening

```
# SSH config for secure tunnels
Host tunnel-*
    # Limit to tunneling only
    PermitLocalCommand no
    RemoteCommand echo 'Tunnel only'

    # Strong keepalive
    ServerAliveInterval 30
    ServerAliveCountMax 3

    # Exit if forward fails
    ExitOnForwardFailure yes

    # Specific key
    IdentityFile ~/.ssh/id_ed25519_tunnel
    IdentitiesOnly yes
```

---

## Complete Tunnel Management Script

```bash
#!/bin/bash
# ssh-tunnel-manager.sh

PID_DIR="$HOME/.ssh/tunnels"
mkdir -p "$PID_DIR"

start_tunnel() {
    local name=$1
    local config=$2
    local pid_file="$PID_DIR/${name}.pid"

    if [ -f "$pid_file" ] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo "Tunnel '$name' already running (PID: $(cat $pid_file))"
        return 0
    fi

    echo "Starting tunnel '$name'..."
    ssh -f -N $config

    # Find PID
    sleep 1
    pid=$(ps aux | grep "ssh.*$config" | grep -v grep | awk '{print $2}' | head -1)

    if [ -n "$pid" ]; then
        echo $pid > "$pid_file"
        echo "Tunnel started (PID: $pid)"
    else
        echo "Failed to start tunnel"
        return 1
    fi
}

stop_tunnel() {
    local name=$1
    local pid_file="$PID_DIR/${name}.pid"

    if [ ! -f "$pid_file" ]; then
        echo "Tunnel '$name' not found"
        return 1
    fi

    pid=$(cat "$pid_file")
    if kill -0 $pid 2>/dev/null; then
        echo "Stopping tunnel '$name' (PID: $pid)..."
        kill $pid
        rm "$pid_file"
        echo "Tunnel stopped"
    else
        echo "Tunnel not running (stale PID file)"
        rm "$pid_file"
    fi
}

status_tunnels() {
    echo "Active tunnels:"
    for pid_file in "$PID_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            name=$(basename "$pid_file" .pid)
            pid=$(cat "$pid_file")
            if kill -0 $pid 2>/dev/null; then
                echo "  ✅ $name (PID: $pid)"
            else
                echo "  ❌ $name (stale PID: $pid)"
            fi
        fi
    done
}

# Tunnel definitions
DB_TUNNEL="db-tunnel"
DB_CONFIG="-L 5432:localhost:5432 db-server"

REDIS_TUNNEL="redis-tunnel"
REDIS_CONFIG="-L 6379:redis:6379 bastion"

SOCKS_TUNNEL="socks-proxy"
SOCKS_CONFIG="-D 1080 proxy-server"

case "${1:-}" in
    start)
        case "${2:-}" in
            db) start_tunnel "$DB_TUNNEL" "$DB_CONFIG" ;;
            redis) start_tunnel "$REDIS_TUNNEL" "$REDIS_CONFIG" ;;
            socks) start_tunnel "$SOCKS_TUNNEL" "$SOCKS_CONFIG" ;;
            all)
                start_tunnel "$DB_TUNNEL" "$DB_CONFIG"
                start_tunnel "$REDIS_TUNNEL" "$REDIS_CONFIG"
                start_tunnel "$SOCKS_TUNNEL" "$SOCKS_CONFIG"
                ;;
            *) echo "Usage: $0 start {db|redis|socks|all}" ;;
        esac
        ;;
    stop)
        case "${2:-}" in
            db) stop_tunnel "$DB_TUNNEL" ;;
            redis) stop_tunnel "$REDIS_TUNNEL" ;;
            socks) stop_tunnel "$SOCKS_TUNNEL" ;;
            all)
                stop_tunnel "$DB_TUNNEL"
                stop_tunnel "$REDIS_TUNNEL"
                stop_tunnel "$SOCKS_TUNNEL"
                ;;
            *) echo "Usage: $0 stop {db|redis|socks|all}" ;;
        esac
        ;;
    status)
        status_tunnels
        ;;
    *)
        echo "Usage: $0 {start|stop|status} [tunnel]"
        echo "Tunnels: db, redis, socks, all"
        ;;
esac
```

**Usage:**
```bash
# Start specific tunnel
./ssh-tunnel-manager.sh start db

# Stop all tunnels
./ssh-tunnel-manager.sh stop all

# Check status
./ssh-tunnel-manager.sh status
```

---

**Related Resources:**
- [ssh-config-guide.md](ssh-config-guide.md) - ProxyJump configuration
- [security-best-practices.md](security-best-practices.md) - Agent forwarding risks
- [complete-examples.md](complete-examples.md) - Bastion and tunnel examples
