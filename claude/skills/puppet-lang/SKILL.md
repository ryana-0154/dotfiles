---
name: puppet-lang
description: Comprehensive Puppet language guide for writing manifests, modules, classes, defined types, and resources. Use when creating or editing .pp files, working with Puppet modules, declaring resources, writing classes, using Hiera data, creating templates (ERB/EPP), or any Puppet infrastructure code. Covers Puppet Core 8 syntax, style guide, resource relationships, facts, variables, conditionals, iteration, and best practices.
---

# Puppet Language Guidelines

This skill provides comprehensive guidance for writing Puppet code following official Puppet Core 8 standards.

## Core Principles

1. **Readability First**: Choose the more readable option when alternatives are equal
2. **Single Responsibility**: Modules should handle one thing; if you need "and" to describe it, split it
3. **Maintainability**: Treat modules as software with long-term maintenance in mind
4. **Declarative Style**: Describe desired state, not procedures

## Quick Reference

### Resource Declaration Syntax

```puppet
<TYPE> { '<TITLE>':
  <ATTRIBUTE> => <VALUE>,
}
```

**Example:**
```puppet
file { '/etc/ssh/sshd_config':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0600',
  content => template('ssh/sshd_config.erb'),
  require => Package['openssh-server'],
  notify  => Service['sshd'],
}
```

### Class Definition Syntax

```puppet
class <CLASS_NAME> (
  <DATA_TYPE> $<PARAMETER> = <DEFAULT_VALUE>,
) {
  # Resources and code
}
```

**Example:**
```puppet
class apache (
  String $version = 'latest',
  Boolean $ssl = true,
  Integer $port = 80,
) {
  package { 'httpd':
    ensure => $version,
  }

  service { 'httpd':
    ensure => running,
    enable => true,
  }
}
```

### Defined Type Syntax

```puppet
define <TYPE_NAME> (
  <DATA_TYPE> $<PARAMETER>,
) {
  # Resources using $title for uniqueness
}
```

**Example:**
```puppet
define apache::vhost (
  Integer $port,
  String $docroot,
  String $servername = $title,
) {
  file { "/etc/httpd/conf.d/${servername}.conf":
    ensure  => file,
    content => template('apache/vhost.conf.erb'),
  }
}
```

## Variable Rules

- Prefix with `$`: `$my_variable`
- Single assignment per scope
- Access facts via `$facts['os']['family']`
- Access trusted facts via `$trusted['certname']`
- Use `${variable}` for string interpolation
- Qualify out-of-scope variables: `$apache::params::vhost_dir`

```puppet
$content = "Hello, ${facts['networking']['hostname']}!"
```

## Relationship Metaparameters

| Metaparameter | Meaning |
|---------------|---------|
| `require`     | Apply after target |
| `before`      | Apply before target |
| `notify`      | Apply first; refresh target on change |
| `subscribe`   | Apply after target; refresh if target changes |

**Chaining arrows:**
```puppet
Package['httpd'] -> File['/etc/httpd/conf/httpd.conf'] ~> Service['httpd']
```

- `->` ordering (left before right)
- `~>` notify (left before right, right refreshes on change)

## Conditionals

**If/elsif/else:**
```puppet
if $facts['os']['family'] == 'RedHat' {
  include redhat::base
} elsif $facts['os']['family'] == 'Debian' {
  include debian::base
} else {
  include generic::base
}
```

**Case statement:**
```puppet
case $facts['os']['name'] {
  'RedHat', 'CentOS': { $package = 'httpd' }
  /^(Debian|Ubuntu)$/: { $package = 'apache2' }
  default: { fail("Unsupported OS: ${facts['os']['name']}") }
}
```

**Selector:**
```puppet
$package_name = $facts['os']['family'] ? {
  'RedHat' => 'httpd',
  'Debian' => 'apache2',
  default  => 'apache',
}
```

## Iteration

**each:**
```puppet
['a', 'b', 'c'].each |Integer $index, String $value| {
  notice("${index}: ${value}")
}
```

**Resource iteration:**
```puppet
$users = ['alice', 'bob', 'charlie']
$users.each |String $username| {
  user { $username:
    ensure => present,
    shell  => '/bin/bash',
  }
}
```

**filter/map/reduce:**
```puppet
$filtered = [1, 20, 3].filter |$v| { $v < 10 }  # [1, 3]
$doubled = [1, 2, 3].map |$v| { $v * 2 }        # [2, 4, 6]
$sum = [1, 2, 3].reduce |$r, $v| { $r + $v }    # 6
```

## Data Types

| Type | Example |
|------|---------|
| String | `'hello'`, `"hello ${var}"` |
| Integer | `42`, `-17` |
| Float | `3.14` |
| Boolean | `true`, `false` |
| Array | `['a', 'b', 'c']` |
| Hash | `{ 'key' => 'value' }` |
| Undef | `undef` |

**Type constraints:**
```puppet
class myclass (
  String[1] $required_string,           # Non-empty string
  Optional[String] $maybe_string,       # String or undef
  Array[String] $string_list,           # Array of strings
  Hash[String, Integer] $counts,        # String keys, integer values
  Enum['present', 'absent'] $ensure,    # Specific values only
  Variant[String, Integer] $mixed,      # Either type
) { }
```

## Module Structure

```
<MODULE_NAME>/
├── manifests/
│   ├── init.pp           # Main class (class <module_name>)
│   ├── install.pp        # class <module_name>::install
│   ├── config.pp         # class <module_name>::config
│   └── service.pp        # class <module_name>::service
├── files/                # Static files
├── templates/            # ERB/EPP templates
├── lib/
│   ├── facter/           # Custom facts
│   └── puppet/
│       ├── functions/    # Custom functions
│       └── types/        # Custom types
├── data/                 # Hiera data
├── hiera.yaml            # Module Hiera config
└── metadata.json         # Module metadata
```

## Detailed References

- **Resource Types**: See [RESOURCE_TYPES.md](RESOURCE_TYPES.md)
- **Classes & Modules**: See [CLASSES_AND_MODULES.md](CLASSES_AND_MODULES.md)
- **Data Types**: See [DATA_TYPES.md](DATA_TYPES.md)
- **Control Flow**: See [CONTROL_FLOW.md](CONTROL_FLOW.md)
- **Templates**: See [TEMPLATES.md](TEMPLATES.md)
- **Hiera**: See [HIERA.md](HIERA.md)
- **Style Guide**: See [STYLE_GUIDE.md](STYLE_GUIDE.md)

## Critical Rules

1. **NEVER** duplicate resource titles within a type
2. **ALWAYS** use data types for class/define parameters
3. **ALWAYS** use `$facts` hash, not legacy `$::factname`
4. **PREFER** EPP templates over ERB for new code
5. **PREFER** Hiera for configuration data over hardcoded values
6. **USE** `contain` for classes that should be contained
7. **USE** relationship metaparameters or chaining for ordering
8. **VALIDATE** inputs with data types, not validate functions
9. **FOLLOW** the style guide (2-space indent, no trailing whitespace)
10. **TEST** with `puppet-lint` and `metadata-json-lint`
