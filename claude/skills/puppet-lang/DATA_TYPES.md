# Puppet Data Types

## Strings

### Single-quoted (literal)
```puppet
$str = 'Hello, world!'
$path = '/etc/puppet/puppet.conf'
```

### Double-quoted (interpolation)
```puppet
$str = "Hello, ${name}!"
$path = "Path: ${facts['path']}"
$nested = "OS: ${facts['os']['family']}"
```

### Heredoc
```puppet
# Literal heredoc (no interpolation)
$content = @(END)
  This is a multi-line
  string that preserves
  formatting.
  | END

# Interpolating heredoc
$content = @("END")
  Hello, ${name}!
  Your home is ${facts['home']}
  | END

# With syntax tag (for editor highlighting)
$script = @("SHELL"/L)
  #!/bin/bash
  echo "Hello, ${username}"
  exit 0
  | SHELL
```

### Escape Sequences (double-quoted only)

| Sequence | Meaning |
|----------|---------|
| `\n` | Newline |
| `\r` | Carriage return |
| `\t` | Tab |
| `\\` | Literal backslash |
| `\"` | Literal double quote |
| `\$` | Literal dollar sign |

## Arrays

```puppet
$arr = ['a', 'b', 'c']
$first = $arr[0]      # 'a'
$last = $arr[-1]      # 'c'
$slice = $arr[0, 2]   # ['a', 'b'] (start, length)

# Empty array
$empty = []

# Mixed types
$mixed = ['string', 42, true, ['nested']]
```

### Array Operations

```puppet
# Concatenate
$combined = $arr + ['d', 'e']    # ['a', 'b', 'c', 'd', 'e']

# Remove elements
$without = $arr - ['b']          # ['a', 'c']

# Append
$appended = $arr << 'd'          # ['a', 'b', 'c', 'd']

# Flatten
$flat = flatten([['a'], ['b', ['c']]])  # ['a', 'b', 'c']

# Unique
$unique = unique(['a', 'b', 'a'])  # ['a', 'b']

# Sort
$sorted = sort(['c', 'a', 'b'])   # ['a', 'b', 'c']
```

## Hashes

```puppet
$hash = {
  'key1' => 'value1',
  'key2' => 'value2',
}
$value = $hash['key1']
$nested = $hash['level1']['level2']

# Empty hash
$empty = {}
```

### Hash Operations

```puppet
# Merge (right wins on conflicts)
$merged = $hash1 + $hash2

# Access with default
$val = $hash['missing'] # Returns undef
$val = pick($hash['missing'], 'default')

# Keys and values
$keys = keys($hash)     # ['key1', 'key2']
$vals = values($hash)   # ['value1', 'value2']
```

## Type Constraints

### Basic Types
```puppet
String          # Any string
String[1]       # Non-empty string
String[1, 10]   # 1-10 characters

Integer         # Any integer
Integer[0]      # Non-negative (0 or greater)
Integer[1, 100] # 1 to 100 inclusive

Float           # Floating point
Numeric         # Integer or Float
Boolean         # true or false
```

### Collection Types
```puppet
Array                    # Any array
Array[String]            # Array of strings
Array[String, 1]         # Non-empty array of strings
Array[String, 1, 10]     # 1-10 strings

Hash                     # Any hash
Hash[String, Integer]    # String keys, integer values
Hash[String, Any, 1]     # Non-empty hash with string keys
```

### Special Types
```puppet
Optional[String]         # String or undef
Variant[String, Integer] # Either type
Enum['a', 'b', 'c']      # Specific values only
Pattern[/^\d+$/]         # Regex match
Tuple[String, Integer]   # Fixed array: [String, Integer]
Struct[{a => String}]    # Fixed hash structure
```

### Type Examples
```puppet
# Struct for complex parameters
Struct[{
  host     => String,
  port     => Integer[1, 65535],
  ssl      => Boolean,
  Optional[timeout] => Integer,
}]

# Variant for flexible types
Variant[String, Array[String]]

# Pattern for format validation
Pattern[/^[a-z][a-z0-9_]*$/]

# Enum for specific values
Enum['present', 'absent', 'purged']
```

### Type Aliases

```puppet
# In types/port.pp
type Mymodule::Port = Integer[1, 65535]

# In types/config.pp
type Mymodule::Config = Struct[{
  host => String,
  port => Mymodule::Port,
  ssl  => Boolean,
}]

# Usage
class mymodule (
  Mymodule::Config $config,
) { }
```

## Variable Assignment

```puppet
# Simple
$name = 'value'

# Multiple from array
[$a, $b, $c] = [1, 2, 3]

# Multiple from hash (keys must match)
[$x, $y] = {x => 10, y => 20}

# Nested destructuring
[$a, [$b, $c]] = [1, [2, 3]]

# Ignore values with *
[$first, *$rest] = [1, 2, 3, 4]  # $first = 1, $rest = [2, 3, 4]
```

## Facts Access

```puppet
# Modern (preferred) - via $facts hash
$os = $facts['os']['family']
$ip = $facts['networking']['ip']
$hostname = $facts['networking']['hostname']
$memory = $facts['memory']['system']['total']

# Trusted facts (from certificate)
$certname = $trusted['certname']
$domain = $trusted['domain']
$extensions = $trusted['extensions']

# Server facts
$env = $server_facts['environment']
$servername = $server_facts['servername']

# Legacy (avoid) - top-scope variables
$os_legacy = $::osfamily  # Deprecated
```

### Common Facts

| Fact | Example Value |
|------|---------------|
| `$facts['os']['family']` | `'RedHat'`, `'Debian'` |
| `$facts['os']['name']` | `'CentOS'`, `'Ubuntu'` |
| `$facts['os']['release']['major']` | `'8'`, `'20'` |
| `$facts['networking']['fqdn']` | `'web01.example.com'` |
| `$facts['networking']['ip']` | `'192.168.1.10'` |
| `$facts['kernel']` | `'Linux'`, `'Windows'` |
| `$facts['virtual']` | `'physical'`, `'vmware'` |
| `$facts['is_virtual']` | `true`, `false` |

## Type Checking

```puppet
# Check type at runtime
if $value =~ String {
  notice('It is a string')
}

if $value =~ Array[String] {
  notice('It is an array of strings')
}

# Assert type
assert_type(String, $value)

# Type conversion
$int = Integer($string_number)
$str = String($integer)
$arr = Array($value)  # Wrap in array if not already
```

## Undef

```puppet
# Explicit undef
$maybe = undef

# Check for undef
if $value == undef {
  notice('Value is undefined')
}

# Better: use pick() or pick_default()
$actual = pick($maybe, 'default')  # Fails if both undef
$actual = pick_default($maybe, 'default')  # Returns default if undef
```
