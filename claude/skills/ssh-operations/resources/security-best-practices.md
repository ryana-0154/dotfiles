# SSH Security Best Practices

## Table of Contents

1. [Security Hierarchy](#security-hierarchy)
2. [Level 1: Authentication (CRITICAL)](#level-1-authentication-critical)
3. [Level 2: Host Verification (CRITICAL)](#level-2-host-verification-critical)
4. [Level 3: Key Management](#level-3-key-management)
5. [Level 4: Connection Security](#level-4-connection-security)
6. [Hardened SSH Client Configuration](#hardened-ssh-client-configuration)
7. [Principle of Least Privilege](#principle-of-least-privilege)
8. [File Permissions Reference](#file-permissions-reference)
9. [Agent Forwarding vs ProxyJump](#agent-forwarding-vs-proxyjump)
10. [Common Security Mistakes](#common-security-mistakes)
11. [Key Rotation Strategy](#key-rotation-strategy)
12. [Defense in Depth](#defense-in-depth)
13. [Security Checklist](#security-checklist)

---

## Security Hierarchy

SSH security follows a layered approach. Each level builds on the previous:

**Level 1: Authentication (CRITICAL)**
Foundation - How you prove your identity

**Level 2: Host Verification (CRITICAL)**
Trust - How you verify the server's identity

**Level 3: Key Management**
Organization - How you organize and protect keys

**Level 4: Connection Security**
Hardening - How you secure the connection itself

Failure at Levels 1 or 2 compromises everything. Levels 3 and 4 provide defense in depth.

---

## Level 1: Authentication (CRITICAL)

### Use SSH Keys, Not Passwords

**✅ DO:**
- Use SSH keys for all production environments
- Use ed25519 keys (or RSA 4096+ for compatibility)
- Protect private keys with strong passphrases
- Use separate keys per environment/purpose
- Rotate keys regularly (annually minimum)
- Generate keys on the machine that will use them

**❌ NEVER:**
- Use password authentication in production
- Share private keys between users
- Use keys without passphrases for critical systems
- Commit keys to version control (even private repos)
- Use weak key types (DSA, RSA 2048 or less)
- Copy private keys over insecure channels

### Key Type Security Levels (2025)

```bash
# ✅ BEST - Ed25519 (Recommended for all new keys)
ssh-keygen -t ed25519 -C "your_email@example.com"
# - Modern elliptic curve cryptography
# - 256-bit security (equivalent to RSA 3072)
# - Fast, small keys (68 bytes public)
# - Resistant to timing attacks

# ✅ GOOD - RSA 4096 (Legacy compatibility only)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# - Widely supported (older systems)
# - 4096 bits required (never use 2048)
# - Larger keys, slower operations

# ⚠️ AVOID - ECDSA
# - Concerns about NIST curve generation
# - Not recommended for new deployments

# ❌ NEVER - DSA or RSA 1024/2048
# - Cryptographically weak
# - Deprecated by OpenSSH
# - Consider compromised
```

### Passphrase Best Practices

**Why passphrases matter:**
- Private keys are only as secure as their storage
- Stolen key file without passphrase = complete compromise
- Passphrase adds second factor of protection

**Strong passphrase requirements:**
```bash
# ✅ GOOD passphrases:
# - 20+ characters OR 5+ random words
# - Mix of uppercase, lowercase, numbers, symbols (if not using words)
# - Not based on personal information
# - Unique to this key (don't reuse)

# Example strong passphrases:
# "correct-horse-battery-staple-2024"
# "M7!pQ@nK4$zT9&vL2^wR5#"

# ❌ WEAK passphrases:
# "password123"
# "YourName2024"
# ""  # No passphrase
```

**Adding passphrase to existing key:**
```bash
# Add or change passphrase
ssh-keygen -p -f ~/.ssh/id_ed25519

# Verify passphrase is set (will prompt)
ssh-keygen -y -f ~/.ssh/id_ed25519
```

---

## Level 2: Host Verification (CRITICAL)

### The TOFU (Trust On First Use) Model

SSH uses TOFU: first connection establishes trust, subsequent connections verify against initial fingerprint.

**First Connection:**
```bash
ssh user@new-server.example.com
# The authenticity of host 'new-server.example.com (203.0.113.10)' can't be established.
# ED25519 key fingerprint is SHA256:abc123xyz789...
# Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

**✅ CORRECT Response:**
1. **Verify fingerprint out-of-band** (separate communication channel)
2. Contact server administrator or check trusted documentation
3. Compare fingerprint character-by-character
4. Type "yes" only if fingerprints match
5. Fingerprint stored in ~/.ssh/known_hosts

**❌ WRONG Response:**
- Blindly typing "yes" without verification
- Using `StrictHostKeyChecking=no`
- Ignoring fingerprint warnings

### StrictHostKeyChecking Levels

```bash
# ✅ BEST - ask (default for most systems)
StrictHostKeyChecking ask
# - Prompts on unknown hosts
# - Rejects changed keys
# - Recommended for most users

# ✅ GOOD - yes (strict mode)
StrictHostKeyChecking yes
# - Rejects unknown hosts
# - Rejects changed keys
# - Best for production automation with pre-populated known_hosts

# ⚠️ RISKY - accept-new
StrictHostKeyChecking accept-new
# - Accepts new hosts without prompting
# - Still rejects changed keys
# - Only for trusted networks

# ❌ NEVER - no (DANGEROUS)
StrictHostKeyChecking no
# - Accepts any host
# - Ignores changed keys
# - VULNERABLE TO MITM ATTACKS
# - Never use in production
```

### Verifying Fingerprints

**Get fingerprint from server (server-side):**
```bash
# On the server, run:
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
# Output: 256 SHA256:abc123xyz789... root@server (ED25519)
```

**Pre-populate known_hosts (for automation):**
```bash
# Scan and add host key
ssh-keyscan server.example.com >> ~/.ssh/known_hosts

# Verify fingerprint
ssh-keygen -lf ~/.ssh/known_hosts -F server.example.com
```

### Host Key Verification Failed

**Legitimate reasons:**
- Server was reinstalled
- Server's SSH keys were regenerated
- Server migrated to new hardware
- IP address reused for different server

**Malicious reasons:**
- Man-in-the-middle attack
- DNS hijacking
- ARP spoofing

**How to handle:**
```bash
# 1. Investigate WHY the key changed
# Contact server administrator
# Check server logs for reinstallation
# Verify IP address is correct

# 2. If legitimate, verify new fingerprint out-of-band

# 3. Remove old key
ssh-keygen -R server.example.com

# 4. Connect and verify new fingerprint
ssh user@server.example.com
# Verify fingerprint matches what administrator provided
```

---

## Level 3: Key Management

### Dedicated Keys Per Purpose

**Anti-pattern:**
```bash
# ❌ WRONG - One key for everything
~/.ssh/
├── id_rsa       # Used for GitHub, production, development, personal
└── id_rsa.pub
```

**Best practice:**
```bash
# ✅ CORRECT - Separate keys per purpose
~/.ssh/
├── id_ed25519_github        # GitHub only
├── id_ed25519_github.pub
├── id_ed25519_prod          # Production servers
├── id_ed25519_prod.pub
├── id_ed25519_dev           # Development servers
├── id_ed25519_dev.pub
├── id_ed25519_personal      # Personal projects
├── id_ed25519_personal.pub
└── config

# Benefits:
# - Revoke one key without affecting others
# - Limit blast radius if key compromised
# - Clear audit trail
# - Easier compliance and access control
```

### SSH Config with Dedicated Keys

```bash
# ~/.ssh/config

# GitHub - Read-only access to repositories
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes  # IMPORTANT: Only use this key

# Production Servers - Write access
Host prod-*
    User deploy
    IdentityFile ~/.ssh/id_ed25519_prod
    IdentitiesOnly yes
    StrictHostKeyChecking yes  # Strict in production

# Development Servers - Less restrictive
Host dev-*
    User developer
    IdentityFile ~/.ssh/id_ed25519_dev
    IdentitiesOnly yes
    StrictHostKeyChecking ask

# Personal Projects
Host personal-*
    User me
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

**Why `IdentitiesOnly yes` is critical:**
- Prevents SSH from trying all keys in agent
- Avoids "Too many authentication failures" error
- Ensures only specified key is used
- Improves security (don't expose all your keys)

### Key Naming Convention

```bash
# Pattern: id_{algorithm}_{purpose}
id_ed25519_github
id_ed25519_prod_webserver
id_ed25519_prod_database
id_ed25519_client_acme_corp
id_ed25519_personal_blog

# Benefits:
# - Self-documenting
# - Easy to identify purpose
# - Easy to rotate specific keys
# - Clear audit trail
```

---

## Level 4: Connection Security

### Connection Timeouts

**Prevent hanging connections:**
```bash
# In ~/.ssh/config
Host *
    ConnectTimeout 10             # Fail if can't connect in 10 seconds
    ServerAliveInterval 30        # Send keepalive every 30 seconds
    ServerAliveCountMax 3         # Disconnect after 3 failed keepalives
    TCPKeepAlive yes              # Enable TCP-level keepalive
```

**Why this matters:**
- Network issues don't leave connections hanging
- Failed connections detected quickly
- Prevents resource exhaustion
- Better user experience

### Disable Unnecessary Features

```bash
# In ~/.ssh/config
Host *
    # Disable risky features by default
    ForwardAgent no               # No agent forwarding (use ProxyJump)
    ForwardX11 no                 # No X11 forwarding
    PermitLocalCommand no         # No automatic local commands
    HashKnownHosts yes            # Obscure hostnames in known_hosts
```

### Modern Cryptographic Algorithms

```bash
# In ~/.ssh/config - Use modern, secure algorithms
Host *
    # Prefer ChaCha20-Poly1305 and AES-GCM
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

    # Prefer SHA2-based MACs with encrypt-then-MAC
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

    # Modern key exchange algorithms
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

    # Prefer Ed25519 and RSA-SHA2
    HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
```

**Note:** Only use if target servers support these algorithms. Older systems may require compatibility mode.

---

## Hardened SSH Client Configuration

Complete security-focused ~/.ssh/config:

```bash
# Secure defaults for all connections
Host *
    # Authentication
    PubkeyAuthentication yes
    PasswordAuthentication no
    ChallengeResponseAuthentication no

    # Host verification
    StrictHostKeyChecking ask
    CheckHostIP yes
    HashKnownHosts yes

    # Disable risky features
    ForwardAgent no
    ForwardX11 no
    PermitLocalCommand no

    # Connection reliability
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
    TCPKeepAlive yes

    # Modern algorithms (adjust for compatibility)
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
    KexAlgorithms curve25519-sha256
    HostKeyAlgorithms ssh-ed25519,rsa-sha2-512

    # Only use specified identity files
    IdentitiesOnly yes

# Production servers - Extra strict
Host prod-*
    StrictHostKeyChecking yes
    PasswordAuthentication no
    # Add production-specific keys here

# Bastion/Jump hosts
Host bastion
    HostName bastion.example.com
    User jumpuser
    IdentityFile ~/.ssh/id_ed25519_bastion
    IdentitiesOnly yes

# Internal hosts through bastion
Host internal-*
    ProxyJump bastion
    StrictHostKeyChecking yes
```

---

## Principle of Least Privilege

### Minimize Access Scope

**Anti-pattern:**
```bash
# ❌ WRONG - root access everywhere
Host *
    User root
```

**Best practice:**
```bash
# ✅ CORRECT - Minimal necessary privileges
Host prod-web-*
    User www-deploy  # Only web deployment permissions

Host prod-db-*
    User db-admin    # Only database admin permissions

Host dev-*
    User developer   # Development access only
```

### Limited-Scope Keys on Server

Restrict what SSH keys can do in ~/.ssh/authorized_keys:

```bash
# Restrict key to specific command
command="/usr/local/bin/backup.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAAC3... backup-key

# Restrict source IP
from="192.168.1.0/24",no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3... office-key

# Restrict to specific commands (force command)
command="rsync --server --sender -vlHogDtprze.iLsfxCIvu . /var/backups/" ssh-ed25519 AAAAC3... rsync-key

# Multiple restrictions
command="/scripts/deploy.sh",no-agent-forwarding,no-port-forwarding,no-pty,no-X11-forwarding,from="203.0.113.0/24" ssh-ed25519 AAAAC3... deploy-key
```

**Available restrictions:**
- `command="..."` - Force specific command
- `from="pattern"` - Restrict source IP/hostname
- `no-agent-forwarding` - Disable agent forwarding
- `no-port-forwarding` - Disable port forwarding
- `no-X11-forwarding` - Disable X11 forwarding
- `no-pty` - Disable PTY allocation
- `no-user-rc` - Disable user rc execution

---

## File Permissions Reference

**Critical:** Incorrect permissions compromise security or prevent SSH from working.

```bash
# ✅ CORRECT permissions

# SSH directory
chmod 700 ~/.ssh
# Owner: rwx (read, write, execute)
# Group: --- (no access)
# Other: --- (no access)

# Private keys
chmod 600 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_rsa
# Owner: rw- (read, write only)
# Group: --- (no access)
# Other: --- (no access)

# Public keys
chmod 644 ~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/id_rsa.pub
# Owner: rw- (read, write)
# Group: r-- (read only)
# Other: r-- (read only)

# SSH config
chmod 600 ~/.ssh/config
# Owner: rw- (read, write only)
# Group: --- (no access)
# Other: --- (no access)

# known_hosts
chmod 644 ~/.ssh/known_hosts
# Owner: rw- (read, write)
# Group: r-- (read only)
# Other: r-- (read only)

# authorized_keys (on server)
chmod 600 ~/.ssh/authorized_keys
# Owner: rw- (read, write only)
# Group: --- (no access)
# Other: --- (no access)
```

**Fix all permissions at once:**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
chmod 600 ~/.ssh/config
chmod 644 ~/.ssh/known_hosts
```

**Why these permissions:**
- SSH refuses to use files with overly permissive settings
- Prevents other users from reading private keys
- Prevents tampering with config files
- Security by default

---

## Agent Forwarding vs ProxyJump

### Why Agent Forwarding is Dangerous

**Agent forwarding mechanism:**
```bash
ssh -A user@jumphost
# Your SSH agent socket is forwarded to jumphost
# Anyone with root on jumphost can use your keys
```

**Risks:**
1. **Root access = key access:** Admin on jump host can use your keys
2. **Socket hijacking:** Attacker with access can use the agent socket
3. **No audit trail:** Can't track which keys were used
4. **Temporal exposure:** Keys available for entire session duration
5. **Chain exposure:** Each hop exposes keys to that host

**Attack scenario:**
```bash
# You: Connect with agent forwarding
ssh -A user@compromised-jump

# Attacker on compromised-jump:
export SSH_AUTH_SOCK=/tmp/ssh-xxxx/agent.12345  # Your agent socket
ssh prod-server  # Uses YOUR keys!
# No password needed, no trace back to attacker
```

### ProxyJump: The Secure Alternative

**How ProxyJump works:**
```bash
ssh -J jumphost user@target
# SSH connection: You → jumphost → target
# Keys stay on your machine
# jumphost only proxies TCP connection
```

**Benefits:**
1. **Keys never leave your machine:** jumphost doesn't see keys
2. **No root risk:** Admin on jumphost can't use your keys
3. **Transparent:** Works like agent forwarding but secure
4. **Simple config:** Easy to set up
5. **Chained hops:** Supports multiple jumps

**Configuration:**
```bash
# In ~/.ssh/config

# Jump host
Host bastion
    HostName bastion.example.com
    User jumpuser
    IdentityFile ~/.ssh/id_ed25519_bastion

# Target through jump
Host internal-*
    ProxyJump bastion
    User admin
    IdentityFile ~/.ssh/id_ed25519_internal

# Multi-hop jump
Host very-internal
    HostName 10.0.50.100
    ProxyJump bastion,internal-gateway
    User admin
```

**Usage:**
```bash
# Single command
ssh -J bastion internal-server

# With config
ssh internal-server  # Automatically uses ProxyJump

# Multiple hops
ssh -J bastion,gateway internal-server
```

### When Agent Forwarding Might Be Acceptable

**Very limited scenarios:**
- Fully trusted jump host (you control root)
- Jump host is hardened bastion
- Jump host has no other users
- Jump host is regularly audited
- No other option available (legacy systems)
- Temporary troubleshooting (disable after)

**Even then, prefer ProxyJump.**

---

## Common Security Mistakes

### Mistake 1: Disabling Host Key Checking

```bash
# ❌ NEVER DO THIS
ssh -o StrictHostKeyChecking=no user@host
ssh -o UserKnownHostsFile=/dev/null user@host

# Why it's dangerous:
# - Vulnerable to MITM attacks
# - Accepts any host without verification
# - Defeats SSH's security model

# ✅ CORRECT alternatives:
# - Verify fingerprint on first connection
# - Pre-populate known_hosts for automation
# - Use StrictHostKeyChecking=accept-new (still risky)
```

### Mistake 2: Using Password Authentication in Production

```bash
# ❌ WRONG
# /etc/ssh/sshd_config
PasswordAuthentication yes

# Why it's dangerous:
# - Vulnerable to brute force
# - No MFA available
# - Passwords can be weak
# - Credentials can be phished

# ✅ CORRECT
# /etc/ssh/sshd_config
PasswordAuthentication no
PubkeyAuthentication yes
```

### Mistake 3: World-Readable Private Keys

```bash
# ❌ WRONG
chmod 644 ~/.ssh/id_ed25519  # Anyone can read your private key!

# SSH will refuse to use this key with error:
# Permissions 0644 for '~/.ssh/id_ed25519' are too open.

# ✅ CORRECT
chmod 600 ~/.ssh/id_ed25519
```

### Mistake 4: Committing Keys to Git

```bash
# ❌ NEVER commit:
# - Private keys (id_rsa, id_ed25519)
# - Config files with sensitive info
# - known_hosts with internal hostnames

# ✅ CORRECT - Add to .gitignore:
echo ".ssh/" >> .gitignore
echo "*.pem" >> .gitignore
echo "*_rsa" >> .gitignore
echo "*_ed25519" >> .gitignore

# If already committed:
# - Rotate ALL affected keys immediately
# - Use git-filter-branch or BFG Repo-Cleaner
# - Consider keys permanently compromised
```

### Mistake 5: Using Weak Key Types

```bash
# ❌ DEPRECATED - Do not use
ssh-keygen -t dsa              # DSA: Broken, max 1024 bits
ssh-keygen -t rsa -b 2048      # RSA 2048: Too weak
ssh-keygen -t rsa -b 1024      # RSA 1024: Completely broken

# ✅ CORRECT
ssh-keygen -t ed25519                    # Best choice
ssh-keygen -t rsa -b 4096                # RSA 4096+ for compatibility
```

---

## Key Rotation Strategy

### Why Rotate Keys

- Reduce exposure window if compromised
- Limit damage from undetected breach
- Comply with security policies
- Remove access for departed team members
- Maintain security hygiene

### Rotation Frequency

**Recommended:**
- Production keys: Annual minimum
- High-security environments: Quarterly
- After team member departure: Immediate
- Suspected compromise: Immediate
- Regulatory compliance: As required

### Rotation Process

**1. Generate new key:**
```bash
# Use date in comment for tracking
ssh-keygen -t ed25519 -C "rotation-$(date +%Y%m%d)"
```

**2. Add new key to all servers:**
```bash
# Add to each server
ssh-copy-id -i ~/.ssh/new_key.pub user@server1
ssh-copy-id -i ~/.ssh/new_key.pub user@server2
# ... all servers
```

**3. Test new key:**
```bash
# Verify new key works
ssh -i ~/.ssh/new_key user@server1
ssh -i ~/.ssh/new_key user@server2
# ... test all servers
```

**4. Update configs:**
```bash
# Update ~/.ssh/config to use new key
# Change IdentityFile path
```

**5. Remove old key from servers:**
```bash
# On each server, edit ~/.ssh/authorized_keys
# Remove old public key line
# Keep new key only
```

**6. Archive old key:**
```bash
# Don't delete immediately, keep for rollback
mv ~/.ssh/old_key ~/.ssh/archived/old_key.$(date +%Y%m%d)
# Delete after grace period (30 days)
```

---

## Defense in Depth

Multiple security layers:

**Layer 1: Strong Authentication**
- SSH keys only (no passwords)
- Ed25519 keys with passphrases
- Separate keys per environment

**Layer 2: Host Verification**
- StrictHostKeyChecking enabled
- Verified fingerprints
- Regular known_hosts audits

**Layer 3: Connection Security**
- Modern cryptographic algorithms
- Connection timeouts configured
- Unnecessary features disabled

**Layer 4: Access Control**
- Principle of least privilege
- Limited scope keys on server
- IP restrictions where possible

**Layer 5: Monitoring & Auditing**
- Log all SSH connections
- Alert on suspicious activity
- Regular access reviews

**Layer 6: Network Security**
- Firewall rules (SSH port limited)
- VPN or bastion for external access
- Network segmentation

---

## Security Checklist

Use this checklist for each new SSH setup:

**Initial Setup:**
- [ ] Generate ed25519 key with passphrase
- [ ] Set correct file permissions (600 private, 644 public)
- [ ] Add public key to server's authorized_keys
- [ ] Test key-based authentication
- [ ] Disable password authentication on server
- [ ] Configure SSH config entry
- [ ] Set IdentitiesOnly yes

**First Connection:**
- [ ] Verify host key fingerprint out-of-band
- [ ] Document fingerprint in secure location
- [ ] Accept only after verification
- [ ] Add to known_hosts

**Ongoing:**
- [ ] Review authorized_keys quarterly
- [ ] Rotate keys annually
- [ ] Audit SSH connections monthly
- [ ] Remove departed users' keys immediately
- [ ] Update known_hosts when servers change
- [ ] Test disaster recovery procedures

**Never:**
- [ ] Never use StrictHostKeyChecking=no
- [ ] Never use password auth in production
- [ ] Never share private keys
- [ ] Never commit keys to version control
- [ ] Never use agent forwarding to untrusted hosts
- [ ] Never use keys without passphrases in production

---

**Related Resources:**
- [authentication.md](authentication.md) - Key generation and authentication details
- [troubleshooting.md](troubleshooting.md) - Security error diagnostics
- [ssh-config-guide.md](ssh-config-guide.md) - Secure configuration examples
