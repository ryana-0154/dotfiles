# Classes and Modules

## Class Definition

```puppet
class mymodule (
  String $config_dir = '/etc/mymodule',
  Integer $port = 8080,
  Boolean $enable_ssl = false,
  Optional[String] $ssl_cert = undef,
) {
  # Class body
}
```

## Including Classes

```puppet
# Include (idempotent, uses Hiera for params)
include mymodule

# Include multiple
include mymodule, othermodule

# Require (include + ordering - all resources in required class apply first)
require mymodule

# Contain (include + containment - class resources are contained)
contain mymodule

# Resource-like (explicit params, not idempotent)
class { 'mymodule':
  port       => 9090,
  enable_ssl => true,
}
```

### include vs require vs contain

| Function | Idempotent | Parameters | Containment |
|----------|------------|------------|-------------|
| `include` | Yes | Hiera only | No |
| `require` | Yes | Hiera only | No (but orders) |
| `contain` | Yes | Hiera only | Yes |
| `class {}` | No | Explicit | No |

## Containment

Use `contain` when a class's resources should be treated as a unit:

```puppet
class mymodule {
  contain mymodule::install
  contain mymodule::config
  contain mymodule::service

  Class['mymodule::install']
    -> Class['mymodule::config']
    ~> Class['mymodule::service']
}
```

With containment, relationships to `mymodule` apply to all contained classes:

```puppet
# This ensures ALL resources in mymodule complete before the exec
class { 'mymodule': }
-> exec { 'post-install': ... }
```

## Inheritance (Use Sparingly)

```puppet
class mymodule::params {
  $config_dir = '/etc/mymodule'
}

class mymodule inherits mymodule::params {
  # Can access $mymodule::params::config_dir
  # or just $config_dir due to inheritance
}
```

**Better alternative:** Use Hiera for data.

## Defined Types

Reusable, instantiable resource patterns:

```puppet
define mymodule::config_file (
  String $content,
  String $owner = 'root',
  String $mode = '0644',
) {
  file { "/etc/mymodule/${title}.conf":
    ensure  => file,
    owner   => $owner,
    mode    => $mode,
    content => $content,
  }
}

# Usage - each instance gets unique title
mymodule::config_file { 'database':
  content => template('mymodule/database.conf.erb'),
}

mymodule::config_file { 'cache':
  content => template('mymodule/cache.conf.erb'),
}
```

### $title and $name

Every defined type instance has:
- `$title` - The unique identifier (always set)
- `$name` - Defaults to `$title`, can be overridden

```puppet
define mymodule::vhost (
  Integer $port,
  String $docroot,
  String $servername = $title,  # Uses title as default
) {
  # $title is guaranteed unique
  file { "/etc/httpd/conf.d/${title}.conf":
    content => template('mymodule/vhost.conf.erb'),
  }
}
```

## Module Layout

```
mymodule/
├── manifests/
│   ├── init.pp              # class mymodule
│   ├── install.pp           # class mymodule::install
│   ├── config.pp            # class mymodule::config
│   ├── service.pp           # class mymodule::service
│   └── config_file.pp       # define mymodule::config_file
├── files/
│   └── script.sh            # puppet:///modules/mymodule/script.sh
├── templates/
│   ├── config.epp
│   └── config.erb
├── lib/
│   ├── facter/
│   │   └── custom_fact.rb   # Custom facts
│   └── puppet/
│       ├── functions/
│       │   └── mymodule/
│       │       └── helper.rb
│       └── types/
│           └── myport.rb    # Custom type alias
├── data/
│   ├── common.yaml
│   └── os/
│       └── RedHat.yaml
├── hiera.yaml               # Module hiera config
├── metadata.json            # Module metadata
├── README.md
└── CHANGELOG.md
```

### File Naming Rules

| Manifest | Class/Type |
|----------|------------|
| `init.pp` | `class mymodule` |
| `install.pp` | `class mymodule::install` |
| `config/file.pp` | `class mymodule::config::file` |
| `vhost.pp` | `define mymodule::vhost` |

## Node Definitions

```puppet
node 'web01.example.com' {
  include role::webserver
}

node /^db\d+\.example\.com$/ {
  include role::database
}

node default {
  include role::base
}
```

### Node Matching Order

1. Exact name match
2. Regex match (first matching regex wins - order is undefined)
3. `default` node

A node only gets ONE node definition's content.

## Roles and Profiles Pattern

**Profile** - Technology-specific wrapper:
```puppet
# modules/profile/manifests/webserver.pp
class profile::webserver {
  include apache
  include apache::mod::ssl

  apache::vhost { $facts['networking']['fqdn']:
    port    => 443,
    docroot => '/var/www/html',
  }
}
```

**Role** - Business-specific composition:
```puppet
# modules/role/manifests/webapp.pp
class role::webapp {
  include profile::base
  include profile::webserver
  include profile::app
  include profile::monitoring
}
```

**Node** - Role assignment:
```puppet
node 'web01.example.com' {
  include role::webapp
}
```

## Class Parameters Best Practices

1. **Always use data types**
2. **Provide sensible defaults** (or use Hiera)
3. **Document parameters**
4. **Use Optional[] for truly optional params**

```puppet
# @param port The port to listen on
# @param enable_ssl Whether to enable SSL
# @param ssl_cert Path to SSL certificate (required if ssl enabled)
class mymodule (
  Integer[1, 65535] $port = 8080,
  Boolean $enable_ssl = false,
  Optional[Stdlib::Absolutepath] $ssl_cert = undef,
) {
  if $enable_ssl and $ssl_cert == undef {
    fail('ssl_cert is required when enable_ssl is true')
  }
}
```
