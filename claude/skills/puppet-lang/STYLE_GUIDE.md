# Puppet Style Guide

## Indentation and Whitespace

- **2 spaces** for indentation (never tabs)
- No trailing whitespace
- Newline at end of file
- Maximum line length: 140 characters (prefer 80)

## Quoting

- **Single quotes** for strings without variables or escape sequences
- **Double quotes** when interpolating variables or using escapes
- Never quote resource titles that are simple identifiers

```puppet
# Correct
$message = 'Hello'
$greeting = "Hello, ${name}"

# Incorrect
$message = "Hello"
$greeting = 'Hello, ${name}'  # Won't interpolate!
```

## Resource Alignment

Align arrows within a resource body:

```puppet
# Correct
file { '/etc/motd':
  ensure  => file,
  owner   => 'root',
  mode    => '0644',
  content => 'Welcome',
}

# Incorrect - inconsistent alignment
file { '/etc/motd':
  ensure => file,
  owner => 'root',
  mode => '0644',
}
```

## Attribute Ordering

1. `ensure` first
2. Other attributes alphabetically (or logically grouped)
3. Relationship metaparameters last (`require`, `notify`, etc.)

```puppet
file { '/etc/app.conf':
  ensure  => file,
  content => template('mymodule/app.conf.erb'),
  group   => 'app',
  mode    => '0640',
  owner   => 'app',
  require => Package['app'],
  notify  => Service['app'],
}
```

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Module names | lowercase, underscores | `apache`, `my_app` |
| Class names | lowercase, `::` namespacing | `apache::mod::ssl` |
| Defined types | lowercase, `::` namespacing | `apache::vhost` |
| Variables | lowercase, underscores | `$my_variable` |
| Parameters | lowercase, underscores | `$config_dir` |
| Facts | lowercase, underscores | `$facts['os_family']` |

## Class Structure

Standard class layout:

```puppet
class mymodule (
  # Parameters with types and defaults
  String $version = 'latest',
) {
  # 1. Variable assignments
  $config_file = '/etc/mymodule/config'

  # 2. Validation (if needed beyond types)

  # 3. Resource declarations (in dependency order)
  contain mymodule::install
  contain mymodule::config
  contain mymodule::service

  # 4. Relationships
  Class['mymodule::install']
    -> Class['mymodule::config']
    ~> Class['mymodule::service']
}
```

## Comments

```puppet
# Single line comment

# Multi-line comments should use
# multiple single-line comments

/*
 * Block comments are acceptable
 * for longer documentation
 */
```

## Conditionals

- Use `if`/`elsif`/`else` for complex logic
- Use selectors for simple value assignment
- Use `case` for multiple distinct values

```puppet
# Selector for simple assignment
$package = $facts['os']['family'] ? {
  'RedHat' => 'httpd',
  'Debian' => 'apache2',
  default  => fail('Unsupported'),
}

# Case for complex logic
case $facts['os']['family'] {
  'RedHat': {
    $package = 'httpd'
    $service = 'httpd'
  }
  'Debian': {
    $package = 'apache2'
    $service = 'apache2'
  }
  default: {
    fail("Unsupported: ${facts['os']['family']}")
  }
}
```

## Lint Tools

Always run before committing:

```bash
puppet-lint --fix manifests/
puppet parser validate manifests/init.pp
metadata-json-lint metadata.json
```

## Common Lint Errors

| Error | Fix |
|-------|-----|
| `trailing_whitespace` | Remove trailing spaces |
| `hard_tabs` | Replace tabs with 2 spaces |
| `double_quoted_strings` | Use single quotes when not interpolating |
| `arrow_alignment` | Align `=>` arrows |
| `80chars` | Break long lines |
| `variable_scope` | Use fully qualified variable names |

## Spacing Rules

```puppet
# Correct - space after comma
$array = ['a', 'b', 'c']

# Correct - space around operators
$result = $a + $b

# Correct - no space inside brackets
$value = $hash['key']

# Correct - space after opening brace in resource
file { '/path':
  ensure => file,
}
```

## Multiple Resources

```puppet
# Same type, different titles
package { ['vim', 'git', 'curl']:
  ensure => present,
}

# Or explicitly
package { 'vim':
  ensure => present,
}

package { 'git':
  ensure => present,
}
```
