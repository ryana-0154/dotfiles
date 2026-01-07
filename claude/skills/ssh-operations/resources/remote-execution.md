# Remote Command Execution

## Table of Contents

1. [Single Command Execution](#single-command-execution)
2. [The Quoting Problem](#the-quoting-problem)
3. [Quoting Rules Reference](#quoting-rules-reference)
4. [Shell Context Handling](#shell-context-handling)
5. [Multi-line Commands](#multi-line-commands)
6. [Heredocs Over SSH](#heredocs-over-ssh)
7. [Exit Code Management](#exit-code-management)
8. [Background Processes](#background-processes)
9. [Long-Running Commands](#long-running-commands)
10. [Output Redirection](#output-redirection)
11. [Error Handling Patterns](#error-handling-patterns)
12. [Common Mistakes](#common-mistakes)
13. [Best Practices Summary](#best-practices-summary)

---

## Single Command Execution

### Basic Syntax

```bash
# Simple command
ssh user@host 'command'

# Command with arguments
ssh user@host 'command arg1 arg2'

# Command pipeline
ssh user@host 'command1 | command2'

# Command with redirection
ssh user@host 'command > output.txt'
```

### When to Quote

**Always quote remote commands** to prevent local shell interpretation.

```bash
# ❌ WRONG - No quotes
ssh user@host ls -la /tmp
# Works, but risky - shell metacharacters will break

# ✅ CORRECT - Quoted
ssh user@host 'ls -la /tmp'
# Safe - command interpreted remotely
```

---

## The Quoting Problem

**The fundamental challenge:** Commands are processed by TWO shells:
1. **Local shell** (your machine) - processes quotes, variables, metacharacters
2. **Remote shell** (target machine) - receives the result

Understanding which shell evaluates what is critical.

### Local vs Remote Expansion

```bash
# ❌ WRONG - Variable expands LOCALLY
ssh user@host echo $HOME
# What happens:
# 1. Local shell expands $HOME to /home/localuser
# 2. Sends: echo /home/localuser
# 3. Remote executes: echo /home/localuser
# 4. Output: /home/localuser (WRONG - local path!)

# ✅ CORRECT - Variable expands REMOTELY
ssh user@host 'echo $HOME'
# What happens:
# 1. Local shell sees single quotes - no expansion
# 2. Sends: echo $HOME (literal)
# 3. Remote shell expands $HOME to /home/remoteuser
# 4. Output: /home/remoteuser (CORRECT!)
```

### Single vs Double Quotes

**Single quotes (`'...'`)**: Prevent ALL local expansion
```bash
# ✅ Use for remote variable expansion
ssh user@host 'echo $HOME $USER $PWD'
# Everything expands remotely
```

**Double quotes (`"..."`)**: Allow local expansion
```bash
# ✅ Use when you want local expansion
local_file="config.yml"
ssh user@host "cat /etc/$local_file"
# $local_file expands locally to config.yml
# Sends: cat /etc/config.yml

# ⚠️ Be careful with multiple variables
local_var="test"
ssh user@host "echo Local: $local_var Remote: $HOME"
# $local_var expands locally
# $HOME expands locally (probably not what you want!)
```

**Escaping in double quotes:**
```bash
# ✅ CORRECT - Escape $ for remote expansion
ssh user@host "echo Local: $local_var Remote: \$HOME"
# $local_var → expands locally
# \$HOME → sends literal $HOME for remote expansion
```

### Nested Quoting

```bash
# ❌ COMPLEX - Nested quotes with grep
ssh user@host "grep 'pattern' /var/log/app.log | awk '{print \$2}'"
# Outer double quotes allow local expansion (be careful!)
# Inner single quotes around 'pattern' protect it
# \$ escapes the $ for awk (remote side)

# ✅ SIMPLER - Use single quotes + escape
ssh user@host 'grep pattern /var/log/app.log | awk '\''{print $2}'\'
# Breaks down:
# 'grep ... awk ' - first part in single quotes
# \' - escaped single quote
# '{print $2}' - middle part (awk script)
# \' - escaped single quote
# (empty) - last part

# ✅ SIMPLEST - Use heredoc for complex commands (see below)
```

---

## Quoting Rules Reference

### Quick Reference

| Goal | Use | Example |
|------|-----|---------|
| Remote variable expansion | Single quotes | `ssh host 'echo $HOME'` |
| Local variable expansion | Double quotes + escape | `ssh host "echo \$HOME is $LOCAL"` |
| Mix local and remote | Double quotes + escaping | `ssh host "cd $LOCAL_DIR && ls \$PWD"` |
| Complex nested commands | Heredoc | See heredoc section |
| Prevent all expansion | Single quotes | `ssh host 'echo * $VAR `cmd`'` |

### Special Characters

**Characters that need protection:**
```bash
# Metacharacters: * ? [ ] { } $ ` " ' \ ; & | > < ( )

# ❌ WRONG - Unprotected metacharacters
ssh user@host ls *.log
# * expands LOCALLY (wrong files!)

# ✅ CORRECT - Quoted
ssh user@host 'ls *.log'
# * expands REMOTELY (correct files!)

# ❌ WRONG - Unprotected semicolon
ssh user@host cd /app; ls
# Sends "cd /app" remotely, runs "ls" LOCALLY!

# ✅ CORRECT - Quoted or &&
ssh user@host 'cd /app; ls'
# OR
ssh user@host 'cd /app && ls'
# Both commands execute remotely
```

### Command Substitution

```bash
# ❌ WRONG - Command substitution runs locally
ssh user@host echo $(hostname)
# $(hostname) runs on LOCAL machine

# ✅ CORRECT - Command substitution runs remotely
ssh user@host 'echo $(hostname)'
# $(hostname) runs on REMOTE machine

# Alternative backticks (older style)
ssh user@host 'echo `hostname`'
```

---

## Shell Context Handling

### Default Shell

```bash
# SSH uses the user's login shell on remote host
# Usually: bash, sh, zsh, etc.

# Check remote shell
ssh user@host 'echo $SHELL'
```

### Force Specific Shell

```bash
# Force bash
ssh user@host 'bash -c "echo $BASH_VERSION"'

# Force sh (POSIX)
ssh user@host 'sh -c "command"'

# Force bash with strict mode
ssh user@host 'bash -c "set -euo pipefail; command"'
```

### Shell Flags for Scripts

```bash
# ✅ RECOMMENDED - Strict mode for remote scripts
ssh user@host 'bash -s' <<'EOF'
set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Pipeline fails if any command fails

# Your commands here
cd /app || exit 1
./script.sh
EOF
```

---

## Multi-line Commands

### Method 1: Semicolons or &&

```bash
# Semicolons - Continue even if command fails
ssh user@host 'cd /app; git pull; npm install; npm start'

# && - Stop on first failure (RECOMMENDED)
ssh user@host 'cd /app && git pull && npm install && npm start'

# || - Run if previous command fails
ssh user@host 'command || echo "Command failed"'
```

### Method 2: Bash -c with Newlines

```bash
# Readable multi-line (quoted)
ssh user@host 'bash -c "
cd /app &&
git pull &&
npm install &&
npm run build
"'
```

### Method 3: Heredoc (BEST for complex scripts)

See next section.

---

## Heredocs Over SSH

**Best practice for complex multi-line scripts.**

### Basic Heredoc

```bash
# ✅ RECOMMENDED - Heredoc with quoted delimiter
ssh user@host 'bash -s' <<'EOF'
# Everything here is sent to remote bash

cd /app
git status
ls -la

# Variables expand REMOTELY
echo "Home: $HOME"
echo "User: $USER"
EOF
```

**Key point:** Quote the delimiter (`<<'EOF'`) to prevent local expansion.

### Heredoc with Local Variables

```bash
# Mix local and remote expansion
local_var="production"

ssh user@host 'bash -s' <<EOF
# $local_var expands LOCALLY (before sending)
# \$REMOTE_VAR expands REMOTELY

echo "Deploying to: $local_var"
echo "Remote user: \$USER"
echo "Remote home: \$HOME"
EOF
```

### Heredoc with Strict Error Handling

```bash
# ✅ PRODUCTION PATTERN - Full error handling
ssh user@host 'bash -s' <<'EOF'
set -euo pipefail  # Strict mode

# Trap errors
trap 'echo "Error on line $LINENO"' ERR

# Your commands
cd /app || exit 1
git pull || exit 2
npm install || exit 3
npm run build || exit 4
systemctl restart app || exit 5

echo "Deployment successful"
EOF

# Check exit code
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "Deployment failed at step $exit_code"
    exit $exit_code
fi
```

### Heredoc with Function

```bash
deploy() {
    local environment=$1
    local version=$2

    ssh user@host 'bash -s' <<EOF
set -euo pipefail

echo "Deploying $environment version $version"

cd /app/$environment
git fetch
git checkout $version
npm install
npm run build
systemctl restart app-$environment

echo "Deployment complete"
EOF
}

# Usage
deploy production v2.1.0
```

---

## Exit Code Management

### Checking Exit Codes

```bash
# Method 1: if statement
if ssh user@host 'systemctl status nginx'; then
    echo "Nginx is running"
else
    echo "Nginx is not running (exit code: $?)"
fi

# Method 2: || operator
ssh user@host 'command' || {
    echo "Command failed with exit code: $?"
    exit 1
}

# Method 3: && operator (only run next if successful)
ssh user@host 'cd /app' && ssh user@host 'git pull'

# Method 4: Capture exit code explicitly
ssh user@host 'command'
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "Failed with code: $exit_code"
    # Handle error
fi
```

### Preserving Exit Codes

```bash
# ❌ WRONG - Exit code is from local command
output=$(ssh user@host 'command')
echo "$output"
echo $?  # Exit code of echo, not ssh!

# ✅ CORRECT - Preserve exit code
ssh user@host 'command'
exit_code=$?
# Now you can use both output and exit code

# ✅ CORRECT - Or check immediately
if ssh user@host 'command'; then
    # Success path
else
    # Failure path (exit code in $?)
fi
```

### Multiple Exit Codes

```bash
# Track which command failed
ssh user@host 'bash -s' <<'EOF'
cd /app || exit 1
git pull || exit 2
npm install || exit 3
npm run build || exit 4
EOF

case $? in
    1) echo "Failed to change directory" ;;
    2) echo "Failed to pull from git" ;;
    3) echo "Failed to install dependencies" ;;
    4) echo "Failed to build" ;;
    0) echo "Success" ;;
    *) echo "Unknown error" ;;
esac
```

---

## Background Processes

### Running Commands in Background (Remote)

```bash
# ❌ WRONG - Runs in background locally, not remotely
ssh user@host 'long-running-command' &

# ✅ CORRECT - Background on remote
ssh user@host 'long-running-command &'

# ✅ CORRECT - Background with nohup (survives logout)
ssh user@host 'nohup long-running-command > output.log 2>&1 &'

# ✅ CORRECT - With explicit PID capture
ssh user@host 'nohup command > output.log 2>&1 & echo $!'
# Returns PID of remote process
```

### Detaching from SSH Session

```bash
# Use nohup + & + redirect
ssh user@host 'nohup ./long-script.sh > /var/log/script.log 2>&1 &'

# Or use screen
ssh user@host 'screen -dmS mysession ./long-script.sh'
# Reconnect later with: screen -r mysession

# Or use tmux (RECOMMENDED)
ssh user@host 'tmux new-session -d -s mysession "./long-script.sh"'
# Reconnect later with: tmux attach -t mysession
```

---

## Long-Running Commands

### Problem: Connection Drops

```bash
# ❌ WRONG - Connection drop kills process
ssh user@host './backup-database.sh'  # Takes 2 hours
# If network drops, backup stops!
```

### Solution 1: nohup

```bash
# ✅ CORRECT - Survives disconnection
ssh user@host 'nohup ./backup-database.sh > backup.log 2>&1 &'

# Check progress later
ssh user@host 'tail -f backup.log'

# Check if still running
ssh user@host 'ps aux | grep backup-database'
```

### Solution 2: tmux (RECOMMENDED)

```bash
# Start in tmux session
ssh user@host 'tmux new-session -d -s backup "./backup-database.sh"'

# Check progress (attach to session)
ssh user@host 'tmux attach -t backup'
# Detach with Ctrl-b d

# Check output
ssh user@host 'tmux capture-pane -t backup -p'

# Kill session when done
ssh user@host 'tmux kill-session -t backup'
```

### Solution 3: screen

```bash
# Start in screen session
ssh user@host 'screen -dmS backup ./backup-database.sh'

# Attach to session
ssh user@host 'screen -r backup'
# Detach with Ctrl-a d

# List sessions
ssh user@host 'screen -ls'
```

---

## Output Redirection

### Redirect on Remote Side

```bash
# ✅ CORRECT - Redirect remotely
ssh user@host 'command > /remote/output.txt'
ssh user@host 'command 2> /remote/errors.log'
ssh user@host 'command > /remote/output.txt 2>&1'

# ❌ WRONG - Redirect locally
ssh user@host 'command' > local-output.txt
# This captures SSH's stdout locally (different!)
```

### Both Local and Remote Redirection

```bash
# Redirect remotely AND capture locally
ssh user@host 'command 2>&1 | tee /remote/log.txt'
# Remote: saves to /remote/log.txt
# Local: output displayed and can be piped

# Or capture locally for processing
output=$(ssh user@host 'command 2>&1')
echo "$output" > local-copy.txt
```

### stderr Handling

```bash
# Separate stdout and stderr locally
ssh user@host 'command' 2> local-errors.log

# Capture both in variable
output=$(ssh user@host 'command 2>&1')

# Discard stderr
ssh user@host 'command 2>/dev/null'

# Only capture stderr
errors=$(ssh user@host 'command 2>&1 >/dev/null')
```

---

## Error Handling Patterns

### Pattern 1: Basic Error Checking

```bash
if ssh user@host 'command'; then
    echo "Success"
else
    echo "Failed"
    exit 1
fi
```

### Pattern 2: Exit on Any Error

```bash
ssh user@host 'bash -s' <<'EOF'
set -e  # Exit on any error

command1
command2
command3
# If any fail, script stops
EOF
```

### Pattern 3: Specific Error Handling

```bash
ssh user@host 'bash -s' <<'EOF'
set -e

# Function for cleanup
cleanup() {
    echo "Cleaning up..."
    # Cleanup commands
}

# Trap errors
trap cleanup ERR

# Your commands
cd /app || exit 1
git pull || exit 2
npm install || exit 3
EOF
```

### Pattern 4: Comprehensive Error Handling

```bash
deploy_with_rollback() {
    local backup_dir="/tmp/backup-$(date +%s)"

    ssh user@host "bash -s" <<EOF
set -euo pipefail

# Backup current version
echo "Creating backup..."
cp -r /app $backup_dir

# Trap for rollback
rollback() {
    echo "Error detected, rolling back..."
    rm -rf /app
    mv $backup_dir /app
    systemctl restart app
    echo "Rollback complete"
    exit 1
}

trap rollback ERR

# Deployment
echo "Deploying..."
cd /app
git pull
npm install
npm run build
systemctl restart app

# Success - remove backup
rm -rf $backup_dir
echo "Deployment successful"
EOF

    if [ $? -ne 0 ]; then
        echo "Deployment failed and rolled back"
        return 1
    fi
}
```

---

## Common Mistakes

### Mistake 1: Unquoted Commands

```bash
# ❌ WRONG
ssh user@host ls *.log
# * expands locally!

# ✅ CORRECT
ssh user@host 'ls *.log'
```

### Mistake 2: Local Variable Expansion

```bash
# ❌ WRONG
ssh user@host echo $HOME
# Echoes local $HOME

# ✅ CORRECT
ssh user@host 'echo $HOME'
# Echoes remote $HOME
```

### Mistake 3: Broken Command Chains

```bash
# ❌ WRONG
ssh user@host cd /app; ls
# cd runs remotely, ls runs LOCALLY!

# ✅ CORRECT
ssh user@host 'cd /app; ls'
# Both run remotely

# ✅ BETTER
ssh user@host 'cd /app && ls'
# ls only runs if cd succeeds
```

### Mistake 4: Ignoring Exit Codes

```bash
# ❌ WRONG
ssh user@host 'risky-command'
ssh user@host 'next-command'
# If first fails, second still runs!

# ✅ CORRECT
ssh user@host 'risky-command' || exit 1
ssh user@host 'next-command'
# Second won't run if first fails
```

### Mistake 5: Improper Background Jobs

```bash
# ❌ WRONG
ssh user@host 'long-command' &
# SSH connection stays open until command completes

# ✅ CORRECT
ssh user@host 'nohup long-command > output.log 2>&1 &'
# SSH connection closes immediately
```

---

## Best Practices Summary

**Quoting:**
- ✅ Always quote remote commands
- ✅ Use single quotes for remote expansion
- ✅ Use heredocs for complex multi-line scripts
- ✅ Escape $ when mixing local and remote variables

**Error Handling:**
- ✅ Check exit codes explicitly
- ✅ Use `set -e` in scripts to fail fast
- ✅ Use `&&` instead of `;` for command chains
- ✅ Implement rollback for critical operations

**Long-Running Commands:**
- ✅ Use tmux or screen for interactive long tasks
- ✅ Use nohup for fire-and-forget background tasks
- ✅ Redirect output to files for later review

**Command Structure:**
- ✅ Test commands locally first when possible
- ✅ Use verbose mode (-v) when debugging
- ✅ Keep commands simple and focused
- ✅ Document complex command chains

**Security:**
- ✅ Avoid passing secrets in command line (use files or env vars)
- ✅ Be careful with user input in commands (injection risk)
- ✅ Use absolute paths when possible
- ✅ Validate inputs before execution

---

**Related Resources:**
- [security-best-practices.md](security-best-practices.md) - Security considerations for remote execution
- [complete-examples.md](complete-examples.md) - Real-world execution examples
- [troubleshooting.md](troubleshooting.md) - Debugging failed commands
