# SSH Troubleshooting Guide

Complete diagnostic paths for common SSH errors and connection issues.

## Table of Contents

1. [Permission denied (publickey)](#error-permission-denied-publickey)
2. [Host key verification failed](#error-host-key-verification-failed)
3. [Connection refused](#error-connection-refused)
4. [Connection timed out](#error-connection-timed-out)
5. [Too many authentication failures](#error-too-many-authentication-failures)
6. [Bad owner or permissions](#error-bad-owner-or-permissions)
7. [General Debugging Techniques](#general-debugging-techniques)

---

## Error: Permission denied (publickey)

### What It Means
Server rejected your SSH key authentication attempt.

### Common Causes
1. Public key not in server's authorized_keys
2. Wrong private key being used
3. Incorrect file permissions (client or server)
4. Key not loaded in SSH agent
5. PubkeyAuthentication disabled on server
6. Wrong username
7. SELinux blocking (rare)

### Diagnostic Steps

```bash
# 1. Connect with triple verbose output
ssh -vvv user@host

# Look for these key lines:
# "debug1: Offering public key: /path/to/key TYPE SHA256:fingerprint"
#   - Shows which keys SSH is trying
# "debug1: Authentications that can continue: publickey"
#   - Server allows publickey auth but rejected yours
# "debug1: No more authentication methods to try"
#   - All attempts failed

# 2. Verify key is loaded in agent
ssh-add -l
# If empty or doesn't show your key:
ssh-add ~/.ssh/id_ed25519

# 3. Check key file permissions
ls -la ~/.ssh/id_ed25519
# Must be: -rw------- (600)
# If not:
chmod 600 ~/.ssh/id_ed25519

# 4. Test with explicit key
ssh -i ~/.ssh/id_ed25519 user@host
# If this works, issue is with SSH config or agent

# 5. Verify public key matches private key
ssh-keygen -y -f ~/.ssh/id_ed25519 > /tmp/public.pub
diff /tmp/public.pub ~/.ssh/id_ed25519.pub
# Should show no differences

# 6. Check SSH config
ssh -G hostname | grep -i identity
# Verify correct key file is configured
```

### Server-Side Diagnostics (if accessible)

```bash
# Via console or alternate authentication method

# 1. Check authorized_keys exists and contains your key
cat ~/.ssh/authorized_keys
# Your public key should be present

# 2. Check file permissions on server
ls -la ~/.ssh/
ls -la ~/.ssh/authorized_keys

# Should be:
# drwx------ .ssh/             (700)
# -rw------- authorized_keys   (600)

# 3. Check server logs
sudo tail -f /var/log/auth.log    # Debian/Ubuntu
sudo tail -f /var/log/secure      # RHEL/CentOS

# Look for:
# "Authentication refused: bad ownership or modes"
# "Could not open authorized keys"

# 4. Check sshd_config
sudo grep -i pubkey /etc/ssh/sshd_config
# Should show: PubkeyAuthentication yes

# 5. SELinux check (RHEL/CentOS)
ls -Z ~/.ssh/authorized_keys
# Should show: ssh_home_t

# Fix SELinux context if needed:
restorecon -R -v ~/.ssh/
```

### Solutions

```bash
# Fix client-side permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Fix server-side permissions
ssh user@host 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

# Re-copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host

# Or manually
cat ~/.ssh/id_ed25519.pub | ssh user@host 'cat >> ~/.ssh/authorized_keys'

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Specify key in SSH config
# ~/.ssh/config:
# Host myhost
#   IdentityFile ~/.ssh/id_ed25519
#   IdentitiesOnly yes
```

### Prevention
- Always verify file permissions after key generation
- Use SSH config with IdentityFile specified
- Set IdentitiesOnly yes to avoid trying too many keys
- Test immediately after setup

---

## Error: Host key verification failed

### Full Error Message
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
Host key for 'hostname' has changed and you have requested strict checking.
```

### What It Means
The server's host key doesn't match the key stored in your ~/.ssh/known_hosts file.

### Legitimate Causes (VERIFY FIRST!)
1. Server was reinstalled
2. Server's SSH keys were regenerated
3. Server migrated to new hardware
4. IP address reused for different server
5. Load balancer or proxy in the middle

### Malicious Causes
1. Man-in-the-middle (MITM) attack
2. DNS hijacking
3. ARP spoofing
4. Compromised network

### Diagnostic Steps

**⚠️ CRITICAL: Investigate before proceeding!**

```bash
# 1. Verify this is expected
# Contact server administrator
# Check server logs for reinstallation
# Verify IP address is correct

# 2. Get new fingerprint from server
# Server-side (have admin run):
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
# Output: 256 SHA256:abc123... root@hostname (ED25519)

# 3. Compare with what SSH shows
ssh user@hostname
# Shows: ED25519 key fingerprint is SHA256:xyz789...

# 4. If fingerprints match (verified out-of-band), safe to proceed
```

### Solution (Only if Change is Legitimate)

```bash
# Remove old key
ssh-keygen -R hostname

# Or remove by IP
ssh-keygen -R 203.0.113.10

# Or edit manually
vi ~/.ssh/known_hosts
# Delete line containing hostname

# Reconnect and verify new fingerprint
ssh user@hostname
# Verify fingerprint matches what administrator provided
# Type 'yes' to accept
```

### Prevention
- Maintain inventory of server fingerprints
- Verify fingerprints out-of-band before accepting
- Never use StrictHostKeyChecking=no
- Document server changes (reinstalls, key rotations)

---

## Error: Connection refused

### What It Means
Network connection to SSH port was actively refused by target host.

### Common Causes
1. SSH daemon (sshd) not running
2. Firewall blocking SSH port
3. Wrong port number
4. Service bound to wrong interface
5. SSH daemon crashed

### Diagnostic Steps

```bash
# 1. Verify server is reachable
ping hostname
# If no response, network issue or server down

# 2. Check if SSH port is open
nc -zv hostname 22
# Or with nmap:
nmap -p 22 hostname

# If "Connection refused": Port is closed (firewall or sshd not running)
# If "No route to host": Network/routing issue
# If timeout: Firewall dropping packets

# 3. Try different port (if non-standard)
ssh -p 2222 user@hostname

# 4. Check from different network
# Try from different location to isolate firewall issues
```

### Server-Side Diagnostics (if accessible)

```bash
# Via console access

# 1. Check if sshd is running
sudo systemctl status sshd     # systemd
sudo service ssh status        # SysV init

# 2. Check sshd is listening
sudo netstat -tlnp | grep sshd
# Or:
sudo ss -tlnp | grep sshd

# Should show:
# tcp 0 0 0.0.0.0:22 0.0.0.0:* LISTEN 1234/sshd

# 3. Check sshd configuration
sudo sshd -t    # Test config syntax
sudo grep Port /etc/ssh/sshd_config

# 4. Check firewall
sudo iptables -L -n | grep 22
# Or with firewalld:
sudo firewall-cmd --list-all

# 5. Check sshd logs
sudo journalctl -u sshd -n 50   # systemd
sudo tail -f /var/log/auth.log   # Debian/Ubuntu
sudo tail -f /var/log/secure     # RHEL/CentOS
```

### Solutions

```bash
# Start sshd
sudo systemctl start sshd
# Or:
sudo service ssh start

# Enable sshd to start on boot
sudo systemctl enable sshd

# Allow SSH through firewall (Ubuntu/Debian)
sudo ufw allow 22/tcp
sudo ufw allow ssh

# Allow SSH through firewall (RHEL/CentOS)
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# Or with iptables:
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

### Prevention
- Monitor sshd service status
- Configure sshd to auto-start on boot
- Document firewall rules
- Use monitoring/alerting for sshd downtime

---

## Error: Connection timed out

### What It Means
No response from server within timeout period.

### Common Causes
1. Server is down or unreachable
2. Firewall dropping packets (no response)
3. Wrong IP address or hostname
4. Network routing issues
5. Server overloaded

### Diagnostic Steps

```bash
# 1. Ping test
ping hostname
# If no response: Network issue or ICMP blocked

# 2. Traceroute to identify where packets stop
traceroute hostname
# Or:
mtr hostname

# 3. Test SSH port specifically
telnet hostname 22
# Or:
nc -zv hostname 22

# If timeout: Firewall or network issue
# If connection refused: Different issue (see above)

# 4. Check DNS resolution
nslookup hostname
# Or:
dig hostname

# Verify IP is correct

# 5. Try IP address directly
ssh user@203.0.113.10
# If works, DNS issue

# 6. Reduce timeout to fail faster
ssh -o ConnectTimeout=5 user@hostname
```

### Solutions

```bash
# Verify hostname/IP is correct
ssh -G hostname | grep hostname

# Use IP address if DNS is issue
ssh user@203.0.113.10

# Update SSH config with IP
# ~/.ssh/config:
# Host myhost
#   HostName 203.0.113.10  # Use IP directly

# Contact network/server administrator if persistent
```

### Prevention
- Document correct IP addresses
- Use monitoring to detect server downtime
- Configure reasonable timeouts in SSH config
- Maintain backup access methods

---

## Error: Too many authentication failures

### Full Error Message
```
Received disconnect from host: 2: Too many authentication failures
```

### What It Means
SSH tried too many keys and server disconnected after reaching MaxAuthTries limit (usually 6).

### Common Cause
SSH agent has many keys loaded, SSH tries all of them.

### Diagnostic Steps

```bash
# 1. Check how many keys are loaded
ssh-add -l
# If shows many keys (>5), this is likely the issue

# 2. Verify with verbose output
ssh -v user@host 2>&1 | grep "Offering public key"
# Shows each key being tried
```

### Solutions

```bash
# Solution 1: Use IdentitiesOnly (RECOMMENDED)
# In ~/.ssh/config:
Host myhost
    HostName hostname
    IdentityFile ~/.ssh/id_ed25519_specific
    IdentitiesOnly yes  # Only use specified key

# Solution 2: Specify key on command line
ssh -i ~/.ssh/id_ed25519_specific -o IdentitiesOnly=yes user@host

# Solution 3: Remove unnecessary keys from agent
ssh-add -D  # Remove all keys
ssh-add ~/.ssh/id_ed25519_specific  # Add only needed key

# Solution 4: Increase server's MaxAuthTries (server-side)
# /etc/ssh/sshd_config:
# MaxAuthTries 10
sudo systemctl restart sshd
```

### Prevention
- Always use `IdentitiesOnly yes` in SSH config
- Use separate SSH keys per environment
- Only load necessary keys in agent
- Specify IdentityFile explicitly in config

---

## Error: Bad owner or permissions

### Full Error Messages
```
Permissions 0644 for '/home/user/.ssh/id_ed25519' are too open.
It is required that your private key files are NOT accessible by others.

OR

Bad owner or permissions on /home/user/.ssh/config
```

### What It Means
SSH file permissions are too permissive (security risk).

### Common Causes
- Wrong chmod applied
- Files copied from different system
- Created with wrong umask

### Solutions

```bash
# Fix all SSH directory permissions at once
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*           # All private keys
chmod 644 ~/.ssh/*.pub          # All public keys
chmod 600 ~/.ssh/config         # Config file
chmod 644 ~/.ssh/known_hosts    # Known hosts

# Verify
ls -la ~/.ssh/

# Should show:
# drwx------  .ssh/
# -rw-------  id_ed25519
# -rw-r--r--  id_ed25519.pub
# -rw-------  config
# -rw-r--r--  known_hosts
```

### Prevention
- Set umask 077 before creating SSH files
- Always check permissions after key generation
- Use ssh-keygen which sets correct permissions
- Don't copy private keys (generate on each machine)

---

## General Debugging Techniques

### Enable Verbose Output

```bash
# Level 1 (basic)
ssh -v user@host

# Level 2 (more detail)
ssh -vv user@host

# Level 3 (maximum detail)
ssh -vvv user@host
```

### What to Look For in Verbose Output

**Connection phase:**
```
debug1: Connecting to hostname [203.0.113.10] port 22.
debug1: Connection established.
```

**Host key verification:**
```
debug1: Server host key: ssh-ed25519 SHA256:abc123...
debug1: Host 'hostname' is known and matches the ED25519 host key.
```

**Authentication phase:**
```
debug1: Authentications that can continue: publickey
debug1: Offering public key: /home/user/.ssh/id_ed25519 ED25519 SHA256:xyz789...
debug1: Server accepts key: /home/user/.ssh/id_ed25519 ED25519 SHA256:xyz789...
debug1: Authentication succeeded (publickey).
```

### Test Specific Components

```bash
# Test specific key
ssh -i ~/.ssh/specific_key user@host

# Test without SSH config
ssh -F /dev/null user@host

# Test with specific config file
ssh -F ~/custom_ssh_config user@host

# View effective configuration
ssh -G hostname
```

### Server-Side Logging

```bash
# Debian/Ubuntu
sudo tail -f /var/log/auth.log

# RHEL/CentOS/Fedora
sudo tail -f /var/log/secure

# With systemd
sudo journalctl -u sshd -f

# Increase sshd logging level
# /etc/ssh/sshd_config:
# LogLevel VERBOSE
sudo systemctl restart sshd
```

### Network Diagnostics

```bash
# Test connectivity
ping hostname

# Trace route
traceroute hostname
mtr hostname

# Port scan
nmap -p 22 hostname

# Test port is open
nc -zv hostname 22
telnet hostname 22

# Check DNS
nslookup hostname
dig hostname
```

### Quick Diagnostic Checklist

When SSH connection fails, check in order:

1. **Network connectivity**: `ping hostname`
2. **DNS resolution**: `nslookup hostname`
3. **Port accessibility**: `nc -zv hostname 22`
4. **Client key permissions**: `ls -la ~/.ssh/id_*`
5. **Key in agent**: `ssh-add -l`
6. **SSH config**: `ssh -G hostname`
7. **Verbose output**: `ssh -vvv user@host`
8. **Server logs**: `sudo tail /var/log/auth.log`

---

**Related Resources:**
- [security-best-practices.md](security-best-practices.md) - File permissions and security
- [authentication.md](authentication.md) - SSH key setup and authentication
- [complete-examples.md](complete-examples.md) - Troubleshooting walkthrough example
