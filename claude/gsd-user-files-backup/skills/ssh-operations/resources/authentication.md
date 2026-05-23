# SSH Authentication

Comprehensive guide to SSH key types, generation, and authentication setup.

## Table of Contents

1. [SSH Key Types](#ssh-key-types)
2. [Key Generation Best Practices](#key-generation-best-practices)
3. [File Permissions](#file-permissions)
4. [Public Key Authentication Setup](#public-key-authentication-setup)
5. [SSH Agent Usage](#ssh-agent-usage)
6. [Agent Forwarding Considerations](#agent-forwarding-considerations)
7. [Multiple Key Management](#multiple-key-management)
8. [Passphrase Management](#passphrase-management)

---

## SSH Key Types

### Recommended: Ed25519 (2025)

**Best choice for new keys:**
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

**Advantages:**
- Modern elliptic curve cryptography
- 256-bit security (equivalent to RSA 3072)
- Small key size (68 bytes public key)
- Fast key generation and signing
- Resistant to timing attacks
- Widely supported (OpenSSH 6.5+, released 2014)

**When to use:** Default choice for all new keys

### Alternative: RSA 4096

**For legacy compatibility:**
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

**Advantages:**
- Maximum compatibility (very old systems)
- Well-understood algorithm
- 4096-bit provides strong security

**Disadvantages:**
- Larger key size (800+ bytes public key)
- Slower operations
- Requires 4096 bits (never use 2048 or less)

**When to use:** Only when connecting to systems that don't support Ed25519

### Deprecated: DSA, ECDSA, RSA 2048

**❌ DO NOT USE:**
```bash
# These are deprecated and insecure
ssh-keygen -t dsa       # DSA: Broken, max 1024 bits
ssh-keygen -t rsa -b 2048  # RSA 2048: Too weak for 2025
ssh-keygen -t rsa -b 1024  # RSA 1024: Completely broken
```

**Why avoid:**
- DSA: Limited to 1024 bits, considered broken
- RSA 2048 or less: Insufficient security margin
- ECDSA: Concerns about NIST curve generation process

---

## Key Generation Best Practices

### Basic Key Generation

```bash
# Generate Ed25519 key (RECOMMENDED)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Prompts:
# Enter file in which to save the key (/home/user/.ssh/id_ed25519): [Enter]
# Enter passphrase (empty for no passphrase): [Type strong passphrase]
# Enter same passphrase again: [Repeat passphrase]

# Result:
# Your identification has been saved in /home/user/.ssh/id_ed25519
# Your public key has been saved in /home/user/.ssh/id_ed25519.pub
```

### Custom Key Names

```bash
# Generate key with custom name
ssh-keygen -t ed25519 -C "github-account" -f ~/.ssh/id_ed25519_github

# Generate key for specific server
ssh-keygen -t ed25519 -C "prod-server" -f ~/.ssh/id_ed25519_prod
```

### Best Practices

**✅ DO:**
- Always set a strong passphrase (20+ characters or 5+ words)
- Use descriptive comment (-C flag) to identify key purpose
- Generate separate keys for different purposes
- Store keys in default ~/.ssh/ directory
- Generate keys on the machine that will use them

**❌ DON'T:**
- Generate keys without passphrases for production use
- Copy private keys between machines
- Use same key for everything
- Generate keys on shared/untrusted systems
- Email or message private keys

---

## File Permissions

**Critical for SSH security:** Incorrect permissions prevent SSH from working or compromise security.

### Required Permissions

```bash
# SSH directory
chmod 700 ~/.ssh
# -rwx------ (owner: read, write, execute; others: no access)

# Private keys
chmod 600 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_rsa
# -rw------- (owner: read, write; others: no access)

# Public keys
chmod 644 ~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/id_rsa.pub
# -rw-r--r-- (owner: read, write; group/others: read only)

# SSH config
chmod 600 ~/.ssh/config
# -rw------- (owner: read, write; others: no access)

# known_hosts
chmod 644 ~/.ssh/known_hosts
# -rw-r--r-- (owner: read, write; group/others: read only)
```

### Fix All Permissions

```bash
# Run these commands to fix all permissions at once
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
chmod 600 ~/.ssh/config
chmod 644 ~/.ssh/known_hosts
```

### Verify Permissions

```bash
# List with permissions
ls -la ~/.ssh/

# Expected output format:
# drwx------  .ssh/
# -rw-------  id_ed25519
# -rw-r--r--  id_ed25519.pub
# -rw-------  config
# -rw-r--r--  known_hosts
```

### Why These Permissions

- **700 for ~/.ssh:** Prevents other users from listing your keys
- **600 for private keys:** SSH refuses to use keys readable by others
- **644 for public keys:** Allows others to read (needed for some operations)
- **600 for config:** Protects potentially sensitive configuration
- **644 for known_hosts:** Allows reading (some tools need this)

---

## Public Key Authentication Setup

### Method 1: ssh-copy-id (Easiest)

```bash
# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@hostname

# What it does:
# 1. Connects to server (requires password)
# 2. Creates ~/.ssh directory if needed
# 3. Appends public key to ~/.ssh/authorized_keys
# 4. Sets correct permissions

# Test connection
ssh user@hostname
# Should connect without password (only passphrase for private key)
```

### Method 2: Manual Copy

```bash
# If ssh-copy-id is not available

# Copy public key content to clipboard
cat ~/.ssh/id_ed25519.pub

# Connect to server
ssh user@hostname

# On server, add public key
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... your_email@example.com" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Exit and test
exit
ssh user@hostname
```

### Method 3: One-Liner

```bash
# Copy and setup in one command
cat ~/.ssh/id_ed25519.pub | ssh user@hostname \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

### Verify Setup

```bash
# Test connection
ssh user@hostname 'echo "Authentication successful"'

# Should see message without password prompt
# If prompted for passphrase: Correct (for private key)
# If prompted for server password: Setup failed
```

---

## SSH Agent Usage

### What is SSH Agent

SSH agent stores decrypted private keys in memory, so you only need to enter passphrase once per session.

**Benefits:**
- Enter passphrase once, use many times
- Keys automatically available to SSH
- Secure storage (memory only, not disk)

### Starting SSH Agent

```bash
# Start agent (manual)
eval "$(ssh-agent -s)"
# Output: Agent pid 12345

# Check if agent is running
echo $SSH_AUTH_SOCK
# If empty, agent not running

# Check agent is accessible
ssh-add -l
# If error "Could not open a connection to your authentication agent"
# Agent not running or not accessible
```

### Adding Keys to Agent

```bash
# Add default key
ssh-add
# Prompts for passphrase, adds ~/.ssh/id_rsa or ~/.ssh/id_ed25519

# Add specific key
ssh-add ~/.ssh/id_ed25519_github
ssh-add ~/.ssh/id_ed25519_prod

# Add with timeout (key expires from agent after time)
ssh-add -t 3600 ~/.ssh/id_ed25519  # 1 hour

# Add all keys in ~/.ssh
ssh-add ~/.ssh/id_ed25519*
```

### Managing Agent Keys

```bash
# List loaded keys
ssh-add -l
# Shows fingerprint and path for each key

# List with full public keys
ssh-add -L

# Remove specific key
ssh-add -d ~/.ssh/id_ed25519_github

# Remove all keys
ssh-add -D
```

### Auto-start SSH Agent

**Linux/WSL (~/.bashrc or ~/.zshrc):**
```bash
# Start SSH agent if not running
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
fi

# Auto-add keys (optional)
ssh-add -l &>/dev/null || ssh-add ~/.ssh/id_ed25519 2>/dev/null
```

**macOS:**
```bash
# macOS Keychain integration
# In ~/.ssh/config:
Host *
    AddKeysToAgent yes
    UseKeychain yes

# Add key to keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Keys automatically loaded from keychain on macOS
```

---

## Agent Forwarding Considerations

### What is Agent Forwarding

Allows using your local SSH keys on remote servers.

```bash
# Enable agent forwarding
ssh -A user@host

# In SSH config:
Host jumphost
    ForwardAgent yes
```

### Security Risks

**⚠️ WARNING: Agent forwarding exposes your keys**

1. **Socket exposure:** SSH agent socket accessible on remote host
2. **Root access:** Admin on remote host can use your keys
3. **No audit trail:** Can't track which keys were used
4. **Duration:** Keys available entire session duration
5. **Chain risk:** Each hop exposes keys

**Attack scenario:**
```bash
# You connect with agent forwarding
ssh -A user@compromised-host

# Attacker on compromised-host:
export SSH_AUTH_SOCK=/tmp/ssh-xxxx/agent.12345  # Your socket
ssh production-server  # Uses YOUR keys!
# No password needed, attacker leaves no trace
```

### Safe Alternative: ProxyJump

```bash
# ✅ RECOMMENDED: Use ProxyJump instead
ssh -J jumphost target

# In SSH config:
Host target
    ProxyJump jumphost

# Keys stay on your machine
# Jump host only proxies TCP connection
# Jump host admin cannot access your keys
```

**When agent forwarding might be acceptable:**
- You fully control and trust the jump host
- Jump host is hardened bastion with no other users
- Jump host is regularly audited
- No other option available (legacy systems)
- Temporary troubleshooting (disable after)

**Even then, prefer ProxyJump.**

---

## Multiple Key Management

### Organize Keys by Purpose

```bash
# File structure
~/.ssh/
├── id_ed25519_github        # GitHub
├── id_ed25519_github.pub
├── id_ed25519_gitlab        # GitLab
├── id_ed25519_gitlab.pub
├── id_ed25519_prod_web      # Production web servers
├── id_ed25519_prod_web.pub
├── id_ed25519_prod_db       # Production databases
├── id_ed25519_prod_db.pub
├── id_ed25519_dev           # Development
├── id_ed25519_dev.pub
└── config                   # SSH config
```

### SSH Config for Multiple Keys

```bash
# ~/.ssh/config

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes

# GitLab
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab
    IdentitiesOnly yes

# Production web servers
Host prod-web-*
    User deploy
    IdentityFile ~/.ssh/id_ed25519_prod_web
    IdentitiesOnly yes

# Production database servers
Host prod-db-*
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_prod_db
    IdentitiesOnly yes

# Development servers
Host dev-*
    User developer
    IdentityFile ~/.ssh/id_ed25519_dev
    IdentitiesOnly yes
```

### Why IdentitiesOnly is Important

```bash
# Without IdentitiesOnly:
# SSH tries ALL keys in agent before specified key
# Can hit "Too many authentication failures" error

# With IdentitiesOnly:
# SSH ONLY uses specified key
# Faster authentication
# Avoids "Too many authentication failures"
# More secure (don't expose all your keys)
```

---

## Passphrase Management

### Changing Passphrase

```bash
# Change passphrase on existing key
ssh-keygen -p -f ~/.ssh/id_ed25519

# Prompts:
# Enter old passphrase:
# Enter new passphrase:
# Confirm new passphrase:
```

### Removing Passphrase (Not Recommended)

```bash
# Remove passphrase (DANGEROUS for production keys)
ssh-keygen -p -f ~/.ssh/id_ed25519

# When prompted for new passphrase, press Enter twice
# Key is now unprotected!

# Only acceptable for:
# - Development/testing keys
# - Automation keys on secure systems
# - Keys that protect non-sensitive resources
```

### Strong Passphrase Guidelines

**Requirements:**
- 20+ characters OR 5+ random words
- Not based on personal information
- Unique to this key (don't reuse)
- Mix of uppercase, lowercase, numbers, symbols (if not using words)

**Good examples:**
```
correct-horse-battery-staple-2024
T9!mK$2pL@vN7#qR4^wX8&zY1%
bicycle-mountain-coffee-laptop-thunder
```

**Bad examples:**
```
password123
YourName2024
(empty - no passphrase)
```

### Passphrase Storage

**✅ Safe storage:**
- System keychain (macOS Keychain, GNOME Keyring)
- Password manager (1Password, Bitwarden, LastPass)
- Memory only (type each time)

**❌ Unsafe storage:**
- Plain text files
- Shell history
- Environment variables (usually)
- Code repositories
- Cloud sync services

---

**Related Resources:**
- [security-best-practices.md](security-best-practices.md) - Security considerations
- [ssh-config-guide.md](ssh-config-guide.md) - SSH config examples
- [troubleshooting.md](troubleshooting.md) - Authentication errors
