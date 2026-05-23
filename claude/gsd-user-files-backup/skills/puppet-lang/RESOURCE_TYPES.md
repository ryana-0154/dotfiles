# Puppet Resource Types

## Resource Uniqueness

Each resource must be unique by title OR namevar. Duplicate declarations cause compilation failure.

## Common Resource Types

### file
```puppet
file { '/etc/motd':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  content => "Welcome to ${facts['networking']['fqdn']}\n",
}

file { '/etc/app':
  ensure  => directory,
  recurse => true,
  purge   => true,
  source  => 'puppet:///modules/mymodule/app',
}

file { '/usr/local/bin/myapp':
  ensure => link,
  target => '/opt/myapp/bin/myapp',
}
```

### package
```puppet
package { 'nginx':
  ensure => installed,
}

package { 'httpd':
  ensure => '2.4.6',
}

package { ['vim', 'git', 'curl']:
  ensure => present,
}
```

### service
```puppet
service { 'nginx':
  ensure => running,
  enable => true,
}
```

### exec
```puppet
exec { 'update-grub':
  command     => '/usr/sbin/update-grub',
  refreshonly => true,
  subscribe   => File['/etc/default/grub'],
}

exec { 'download-app':
  command => '/usr/bin/curl -o /tmp/app.tar.gz https://example.com/app.tar.gz',
  creates => '/tmp/app.tar.gz',
  unless  => '/usr/bin/test -f /opt/app/installed',
}
```

### user
```puppet
user { 'deploy':
  ensure     => present,
  uid        => 1001,
  gid        => 'deploy',
  home       => '/home/deploy',
  shell      => '/bin/bash',
  managehome => true,
}
```

### group
```puppet
group { 'deploy':
  ensure => present,
  gid    => 1001,
}
```

### cron
```puppet
cron { 'daily-backup':
  ensure  => present,
  command => '/usr/local/bin/backup.sh',
  user    => 'root',
  hour    => 2,
  minute  => 0,
}
```

## Metaparameters (Available on All Resources)

| Parameter | Purpose |
|-----------|---------|
| `alias` | Alternative name for referencing |
| `audit` | Track attribute changes |
| `before` | Apply before specified resources |
| `loglevel` | Log verbosity for this resource |
| `noop` | Simulate without applying |
| `notify` | Notify resources of changes |
| `require` | Apply after specified resources |
| `schedule` | When resource can be applied |
| `stage` | Which run stage |
| `subscribe` | Refresh on change of target |
| `tag` | Tags for collection/searching |

## Resource Defaults

```puppet
File {
  owner => 'root',
  group => 'root',
  mode  => '0644',
}

Exec {
  path => '/usr/bin:/usr/sbin:/bin:/sbin',
}
```

## Virtual Resources

Declare but don't apply until realized:

```puppet
@user { 'admin':
  ensure => present,
}

# Realize later
realize User['admin']

# Or with collector
User <| title == 'admin' |>
```

## Exported Resources

Share across nodes (requires PuppetDB):

```puppet
@@host { $facts['networking']['fqdn']:
  ip => $facts['networking']['ip'],
}

# Collect on other nodes
Host <<| |>>
```

## Resource Collectors

Select resources by attributes:

```puppet
# Basic collector
User <| groups == 'admin' |>

# With search expressions
Package <| tag == 'webserver' and ensure == 'present' |>

# Exported resource collector
Host <<| environment == $environment |>>
```

### Search Operators

| Operator | Meaning |
|----------|---------|
| `==` | Equal |
| `!=` | Not equal |
| `and` | Both conditions |
| `or` | Either condition |
