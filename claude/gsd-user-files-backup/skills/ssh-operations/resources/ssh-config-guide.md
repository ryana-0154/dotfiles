# SSH Config Guide

Comprehensive guide to ~/.ssh/config file structure and configuration options.

## Table of Contents

1. [SSH Config Basics](#ssh-config-basics)
2. [Host Patterns and Matching](#host-patterns-and-matching)
3. [Essential Configuration Options](#essential-configuration-options)
4. [Security-Related Options](#security-related-options)
5. [Connection Management Options](#connection-management-options)
6. [Advanced Patterns](#advanced-patterns)
7. [Complete Examples](#complete-examples)

---

## SSH Config Basics

### What is SSH Config

The `~/.ssh/config` file allows you to customize SSH client behavior on a per-host basis.

**Benefits:**
- Simplify complex SSH commands
- Create memorable host aliases
- Set default options for all hosts
- Organize SSH connections
- Share configurations across machines

### File Location

```bash
# User-specific config (recommended)
~/.ssh/config

# System-wide config
/etc/ssh/ssh_config
```

### Basic Structure

```
# Comments start with #

# Global defaults
Host *
    Option value

# Specific host
Host alias
    HostName actual.hostname.com
    User username
    Option value
```

### Creating Your First Config Entry

```bash
# Create config file if it doesn't exist
touch ~/.ssh/config
chmod 600 ~/.ssh/config

# Add an entry
cat >> ~/.ssh/config <<'EOF'

Host myserver
    HostName 203.0.113.10
    User deploy
    IdentityFile ~/.ssh/id_ed25519
EOF

# Usage
ssh myserver  # Instead of: ssh -i ~/.ssh/id_ed25519 deploy@203.0.113.10
```

---

## Host Patterns and Matching

### Exact Match

```
Host myserver
    HostName server.example.com
    User admin
```

### Wildcard Matching

```
# All production servers
Host prod-*
    User deploy
    IdentityFile ~/.ssh/id_ed25519_prod

# All database servers
Host *-db
    User dbadmin
    Port 2222

# All development hosts
Host dev*
    StrictHostKeyChecking no
```

### Multiple Hosts

```
# Same config for multiple hosts
Host server1 server2 server3
    User admin
    IdentityFile ~/.ssh/id_ed25519_servers
```

### Global Defaults

```
# Applied to all hosts (put at end of file)
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Order Matters

**SSH uses first match only:**
```
# ✅ CORRECT - Specific before general
Host prod-web-01
    Port 2222
    User specialuser

Host prod-*
    Port 22
    User deploy

Host *
    ServerAliveInterval 60

# ❌ WRONG - General before specific
Host *
    ServerAliveInterval 60
    Port 22  # This overrides everything!

Host prod-web-01
    Port 2222  # Never reached!
```

---

## Essential Configuration Options

### Host Identity

```
Host myserver
    # Alias you type
    HostName actual-server.example.com
    # Real hostname or IP
    User deploy
    # Username for connection
    Port 2222
    # SSH port (default: 22)
```

### Authentication

```
Host myserver
    IdentityFile ~/.ssh/id_ed25519_server
    # Path to private key
    IdentitiesOnly yes
    # Only use specified key(s)
    PubkeyAuthentication yes
    # Enable public key auth
    PasswordAuthentication no
    # Disable password auth
```

### Connection Keepalive

```
Host *
    ServerAliveInterval 60
    # Send keepalive every 60 seconds
    ServerAliveCountMax 3
    # Disconnect after 3 failed keepalives
    TCPKeepAlive yes
    # Enable TCP-level keepalive
    ConnectTimeout 10
    # Connection timeout (seconds)
```

---

## Security-Related Options

### Host Verification

```
# Production - Strict
Host prod-*
    StrictHostKeyChecking yes
    # Reject unknown or changed hosts
    CheckHostIP yes
    # Verify IP address matches

# Development - Less strict
Host dev-*
    StrictHostKeyChecking ask
    # Prompt for unknown hosts

# Local VMs - Accept new (risky)
Host vagrant-*
    StrictHostKeyChecking accept-new
    # Auto-accept new hosts, reject changed
```

### Disable Risky Features

```
Host *
    ForwardAgent no
    # Disable SSH agent forwarding (use ProxyJump)
    ForwardX11 no
    # Disable X11 forwarding
    PermitLocalCommand no
    # Disable automatic local commands
    HashKnownHosts yes
    # Obscure hostnames in known_hosts
```

### Modern Algorithms

```
Host *
    # Prefer modern ciphers
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

    # Prefer SHA2-based MACs
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

    # Modern key exchange
    KexAlgorithms curve25519-sha256

    # Prefer Ed25519 host keys
    HostKeyAlgorithms ssh-ed25519,rsa-sha2-512
```

---

## Connection Management Options

### Connection Multiplexing

**Reuse existing connections for speed:**
```
Host *
    ControlMaster auto
    # Automatically create master connection
    ControlPath ~/.ssh/master/%r@%h:%p
    # Socket path (%r=user, %h=host, %p=port)
    ControlPersist 10m
    # Keep master connection open for 10 minutes

# Setup socket directory
mkdir -p ~/.ssh/master
```

**Benefits:**
- Faster subsequent connections (no re-authentication)
- Share connections across terminal windows
- Reduces load on server

**Usage:**
```bash
# First connection creates master
ssh myserver  # Authenticates normally

# Subsequent connections reuse master (instant!)
ssh myserver  # No authentication needed
scp file.txt myserver:/path/  # Uses master connection

# Close master connection
ssh -O exit myserver
```

### Compression

```
Host slow-connection
    Compression yes
    # Enable compression (useful for slow connections)
```

---

## Advanced Patterns

### Jump Hosts / Bastion

```
# Bastion host
Host bastion
    HostName bastion.example.com
    User jumpuser
    IdentityFile ~/.ssh/id_ed25519_bastion

# Internal hosts through bastion
Host internal-*
    ProxyJump bastion
    User admin
    IdentityFile ~/.ssh/id_ed25519_internal

# Specific internal server
Host internal-web-01
    HostName 10.0.1.10

# Multi-hop
Host very-internal
    HostName 10.0.50.100
    ProxyJump bastion,internal-gateway
```

### Port Forwarding

```
# Local port forwarding
Host db-tunnel
    HostName db-server.example.com
    LocalForward 5432 localhost:5432
    # Forward local port 5432 to remote localhost:5432

# Remote port forwarding
Host expose-local
    HostName remote-server.example.com
    RemoteForward 8080 localhost:80
    # Expose local port 80 on remote port 8080

# Dynamic forwarding (SOCKS proxy)
Host socks-proxy
    HostName proxy-server.example.com
    DynamicForward 1080
    # Create SOCKS proxy on local port 1080
```

### SendEnv for Environment Variables

```
Host myserver
    SendEnv LANG LC_*
    # Send local environment variables to remote
```

### Match Conditions

```
# Match based on conditions
Match host=*.example.com user=admin
    IdentityFile ~/.ssh/id_ed25519_admin

Match host=10.* !host=10.0.1.*
    ProxyJump bastion

# Match for external connections only
Match host=* !exec="hostname | grep -q prod"
    IdentityFile ~/.ssh/id_ed25519_external
```

---

## Complete Examples

### Personal Development Setup

```
# ~/.ssh/config

# Global defaults
Host *
    AddKeysToAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    IdentitiesOnly yes

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github

# Personal VPS
Host vps
    HostName my-vps.example.com
    User deploy
    IdentityFile ~/.ssh/id_ed25519_personal
    Port 2222

# Development VM
Host dev
    HostName 192.168.1.100
    User developer
    IdentityFile ~/.ssh/id_ed25519_dev
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### Professional/Enterprise Setup

```
# ~/.ssh/config

# Security defaults
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    ConnectTimeout 10
    ForwardAgent no
    ForwardX11 no
    IdentitiesOnly yes
    StrictHostKeyChecking ask
    HashKnownHosts yes

# Connection multiplexing
Host *
    ControlMaster auto
    ControlPath ~/.ssh/master/%r@%h:%p
    ControlPersist 10m

# Bastion host
Host bastion
    HostName bastion.company.com
    User jumpuser
    IdentityFile ~/.ssh/id_ed25519_bastion
    IdentitiesOnly yes

# Production web servers
Host prod-web-*
    ProxyJump bastion
    User deploy
    IdentityFile ~/.ssh/id_ed25519_prod
    StrictHostKeyChecking yes
    Port 2222

# Production database servers
Host prod-db-*
    ProxyJump bastion
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_prod_db
    StrictHostKeyChecking yes
    Port 3322

# Specific servers
Host prod-web-01
    HostName 10.0.1.10

Host prod-web-02
    HostName 10.0.1.11

Host prod-db-01
    HostName 10.0.2.10

# Development servers (direct access)
Host dev-*
    User developer
    IdentityFile ~/.ssh/id_ed25519_dev
    StrictHostKeyChecking ask

Host dev-web-01
    HostName dev-web-01.company.com

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
```

### Multi-Account GitHub/GitLab

```
# Personal GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_personal

# Work GitHub
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_work

# Personal GitLab
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab_personal

# Work GitLab
Host gitlab-work
    HostName gitlab.company.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab_work
    Port 2222

# Usage:
# Personal: git clone git@github.com:personal/repo.git
# Work: git clone git@github-work:company/repo.git
```

### Database Access via Tunnel

```
# PostgreSQL tunnel
Host pg-tunnel
    HostName db-server.company.com
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_db
    LocalForward 5432 localhost:5432
    ExitOnForwardFailure yes

# MySQL tunnel
Host mysql-tunnel
    HostName db-server.company.com
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_db
    LocalForward 3306 localhost:3306
    ExitOnForwardFailure yes

# Usage:
# ssh -N pg-tunnel  # Start tunnel (no shell)
# psql -h localhost -p 5432 ...  # Connect to DB
```

---

## Testing and Debugging

### View Effective Configuration

```bash
# Show computed config for host
ssh -G hostname

# Shows all options that will be used
# Useful for debugging
```

### Test Connection Without Executing Commands

```bash
# Test connection
ssh -T hostname

# Test with verbose output
ssh -vT hostname
```

### Validate Syntax

```bash
# SSH config has no built-in validation
# Test by running:
ssh -G testhost > /dev/null

# If error in config, will show error message
```

---

**Related Resources:**
- [security-best-practices.md](security-best-practices.md) - Security configuration
- [jump-hosts-and-tunnels.md](jump-hosts-and-tunnels.md) - ProxyJump and tunneling
- [authentication.md](authentication.md) - Key configuration
