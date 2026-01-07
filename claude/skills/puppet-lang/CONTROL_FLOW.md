# Control Flow in Puppet

## Conditionals

### if/elsif/else

```puppet
if $condition {
  # true branch
} elsif $other_condition {
  # elsif branch
} else {
  # false branch
}
```

Conditions can use:
- Boolean values
- Comparison operators (`==`, `!=`, `<`, `>`, `<=`, `>=`)
- Boolean operators (`and`, `or`, `!`)
- Regex match (`=~`, `!~`)
- `in` operator

```puppet
if $facts['os']['family'] == 'RedHat' and $facts['os']['release']['major'] >= '8' {
  include rhel8::optimizations
}

if $hostname =~ /^web\d+/ {
  include webserver
}

if 'production' in $trusted['extensions']['pp_environment'] {
  include production::hardening
}
```

### unless

Executes when condition is false:

```puppet
unless $facts['is_virtual'] {
  include physical_server::hardware
}

# Equivalent to:
if !$facts['is_virtual'] {
  include physical_server::hardware
}
```

### case

Pattern matching with multiple options:

```puppet
case $facts['os']['name'] {
  'RedHat', 'CentOS', 'Rocky', 'AlmaLinux': {
    $package = 'httpd'
    $service = 'httpd'
  }
  /^(Debian|Ubuntu)$/: {
    $package = 'apache2'
    $service = 'apache2'
  }
  default: {
    fail("Unsupported OS: ${facts['os']['name']}")
  }
}
```

Case matches can be:
- Literal strings
- Multiple values (comma-separated)
- Regular expressions
- Data types
- `default` (catch-all)

### Selector

Returns a value (use in assignments):

```puppet
$package = $facts['os']['family'] ? {
  'RedHat'              => 'httpd',
  'Debian'              => 'apache2',
  /(FreeBSD|DragonFly)/ => 'apache24',
  default               => 'apache',
}
```

Selectors can appear anywhere a value is expected:

```puppet
file { '/etc/app/config':
  ensure  => file,
  content => $environment ? {
    'production' => template('mymodule/prod.erb'),
    default      => template('mymodule/default.erb'),
  },
}
```

## Iteration Functions

### each

```puppet
# Array iteration
['one', 'two', 'three'].each |$value| {
  notice($value)
}

# With index
['one', 'two', 'three'].each |$index, $value| {
  notice("${index}: ${value}")
}

# Hash iteration
{'a' => 1, 'b' => 2}.each |$key, $value| {
  notice("${key} = ${value}")
}

# Hash with single parameter (receives array)
{'a' => 1, 'b' => 2}.each |$pair| {
  notice("${pair[0]} = ${pair[1]}")
}
```

### map

Transform values:

```puppet
$uppered = ['a', 'b', 'c'].map |$v| { upcase($v) }
# Result: ['A', 'B', 'C']

$doubled = [1, 2, 3].map |$v| { $v * 2 }
# Result: [2, 4, 6]

# Transform hash values
$config = {'port' => '80', 'timeout' => '30'}.map |$k, $v| {
  [$k, Integer($v)]
}
# Result: [['port', 80], ['timeout', 30]]
```

### filter

Select matching values:

```puppet
$small = [1, 20, 3, 15, 5].filter |$v| { $v < 10 }
# Result: [1, 3, 5]

$evens = [1, 2, 3, 4, 5, 6].filter |$v| { $v % 2 == 0 }
# Result: [2, 4, 6]

# Filter hash
$admins = $users.filter |$name, $data| { $data['role'] == 'admin' }
```

### reduce

Accumulate a result:

```puppet
$sum = [1, 2, 3, 4, 5].reduce |$memo, $v| { $memo + $v }
# Result: 15

# With initial value
$product = [1, 2, 3, 4].reduce(1) |$memo, $v| { $memo * $v }
# Result: 24

# Build a hash
$lookup = ['a', 'b', 'c'].reduce({}) |$memo, $v| {
  $memo + { $v => upcase($v) }
}
# Result: {'a' => 'A', 'b' => 'B', 'c' => 'C'}
```

### slice

Process elements in groups:

```puppet
# Process pairs
[1, 2, 3, 4, 5, 6].slice(2) |$pair| {
  notice("${pair[0]} and ${pair[1]}")
}
# Outputs: "1 and 2", "3 and 4", "5 and 6"
```

### with

Execute code in isolated scope:

```puppet
with($complex_expression) |$result| {
  # Use $result multiple times without re-evaluating
  notice("Result: ${result}")
  file { "/tmp/${result}": ensure => file }
}
```

## Flow Control

```puppet
# Skip iteration
$evens = [1, 2, 3, 4, 5].filter |$v| {
  if $v % 2 != 0 { next(false) }
  true
}

# Exit loop early
[1, 2, 3, 4, 5].each |$v| {
  if $v > 3 { break() }
  notice($v)
}
# Outputs: 1, 2, 3
```

## Expressions and Operators

### Comparison Operators

| Operator | Meaning |
|----------|---------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |
| `=~` | Regex match |
| `!~` | Regex no match |
| `in` | Membership |

### Boolean Operators

| Operator | Meaning |
|----------|---------|
| `and` | Logical AND |
| `or` | Logical OR |
| `!` | Logical NOT |

### Arithmetic Operators

| Operator | Meaning |
|----------|---------|
| `+` | Addition / Concatenation |
| `-` | Subtraction / Removal |
| `*` | Multiplication |
| `/` | Division |
| `%` | Modulo |
| `<<` | Left shift / Append |
| `>>` | Right shift |

### Operator Precedence (High to Low)

1. `!` (NOT)
2. `-` (unary negation)
3. `*` (splat)
4. `in`
5. `=~`, `!~`
6. `*`, `/`, `%`
7. `+`, `-`
8. `<<`, `>>`
9. `==`, `!=`
10. `>=`, `<=`, `>`, `<`
11. `and`
12. `or`
13. `=`

Use parentheses to clarify complex expressions:
```puppet
$result = ($a + $b) * ($c - $d)
$match = ($x == 1) or ($y == 2)
```
