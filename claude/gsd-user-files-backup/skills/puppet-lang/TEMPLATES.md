# Puppet Templates

## EPP Templates (Preferred)

Embedded Puppet templates use Puppet syntax.

**Template file (templates/config.epp):**
```epp
<%- | String $hostname,
      Integer $port,
      Array[String] $backends,
| -%>
# Managed by Puppet
server_name = <%= $hostname %>
port = <%= $port %>

<% $backends.each |$backend| { -%>
backend = <%= $backend %>
<% } -%>
```

**Usage in manifest:**
```puppet
file { '/etc/app/config':
  content => epp('mymodule/config.epp', {
    'hostname' => $facts['networking']['fqdn'],
    'port'     => 8080,
    'backends' => ['server1', 'server2'],
  }),
}
```

### EPP Tags

| Tag | Purpose |
|-----|---------|
| `<%= expr %>` | Output expression value |
| `<% code %>` | Execute code, no output |
| `<%- ... %>` | Trim leading whitespace |
| `<% ... -%>` | Trim trailing newline |
| `<%# comment %>` | Comment (not in output) |
| `<%% %>` | Literal `<%` |

### EPP Parameter Declaration

Parameters must be declared at the top of EPP templates:

```epp
<%- |
  String $required_param,
  Optional[Integer] $optional_param = 80,
  Boolean $flag = true,
| -%>
```

### EPP Conditionals

```epp
<% if $enable_ssl { -%>
ssl_enabled = true
ssl_cert = <%= $ssl_cert %>
<% } else { -%>
ssl_enabled = false
<% } -%>
```

### EPP Iteration

```epp
<% $servers.each |$index, $server| { -%>
server.<%= $index %> = <%= $server %>
<% } -%>
```

## ERB Templates (Legacy)

Embedded Ruby templates use Ruby syntax.

**Template file (templates/config.erb):**
```erb
# Managed by Puppet
server_name = <%= @hostname %>
port = <%= @port %>

<% @backends.each do |backend| -%>
backend = <%= backend %>
<% end -%>
```

**Usage in manifest:**
```puppet
file { '/etc/app/config':
  content => template('mymodule/config.erb'),
}
```

In ERB, access variables with `@variable_name`.

### ERB Tags

| Tag | Purpose |
|-----|---------|
| `<%= expr %>` | Output expression value |
| `<% code %>` | Execute code, no output |
| `<% code -%>` | Execute, trim trailing newline |
| `<%# comment %>` | Comment |

### ERB Conditionals

```erb
<% if @enable_ssl -%>
ssl_enabled = true
ssl_cert = <%= @ssl_cert %>
<% else -%>
ssl_enabled = false
<% end -%>
```

### ERB Iteration

```erb
<% @servers.each_with_index do |server, index| -%>
server.<%= index %> = <%= server %>
<% end -%>
```

### ERB Variable Access

```erb
<%# Direct variable access %>
<%= @my_variable %>

<%# Facts access %>
<%= @facts['os']['family'] %>

<%# Scope lookup (for out-of-scope variables) %>
<%= scope['apache::params::config_dir'] %>
```

## Inline Templates

For simple cases, use inline templates:

```puppet
# Inline EPP
$content = inline_epp('Hello, <%= $name %>', { 'name' => 'World' })

# Inline ERB
$content = inline_template('Hello, <%= @name %>')
```

## Template Best Practices

1. **Prefer EPP** for new templates (safer, Puppet-native)
2. **Always declare parameters** in EPP header
3. **Use `-%>` to control whitespace**
4. **Escape user input** when generating configs
5. **Keep templates simple** - complex logic belongs in manifests
6. **Use meaningful variable names**
7. **Add comments** to explain non-obvious sections

## Template File Location

Templates must be in the module's `templates/` directory:

```
mymodule/
└── templates/
    ├── config.epp
    ├── config.erb
    └── subdir/
        └── nested.epp
```

**Reference in manifest:**
```puppet
# templates/config.epp
epp('mymodule/config.epp', { ... })

# templates/subdir/nested.epp
epp('mymodule/subdir/nested.epp', { ... })
```

## Converting ERB to EPP

ERB:
```erb
<% @users.each do |user| -%>
user: <%= user %>
<% end -%>
```

EPP:
```epp
<%- | Array[String] $users | -%>
<% $users.each |$user| { -%>
user: <%= $user %>
<% } -%>
```

Key differences:
- `@variable` becomes `$variable`
- `do |var|` becomes `|$var| {`
- `end` becomes `}`
- Add parameter declaration header
