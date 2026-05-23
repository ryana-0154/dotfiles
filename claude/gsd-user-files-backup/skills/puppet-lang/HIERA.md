# Hiera Data Management

Hiera separates configuration data from Puppet code.

## Hierarchy Configuration (hiera.yaml)

```yaml
---
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: "Per-node data"
    path: "nodes/%{trusted.certname}.yaml"

  - name: "Per-OS family"
    path: "os/%{facts.os.family}.yaml"

  - name: "Per-environment"
    path: "environments/%{environment}.yaml"

  - name: "Common data"
    path: "common.yaml"
```

## Data Files

**data/common.yaml:**
```yaml
---
mymodule::port: 8080
mymodule::enable_ssl: false
mymodule::allowed_hosts:
  - localhost
  - 127.0.0.1
```

**data/os/RedHat.yaml:**
```yaml
---
mymodule::package_name: mymodule-rhel
mymodule::config_path: /etc/sysconfig/mymodule
```

**data/nodes/web01.example.com.yaml:**
```yaml
---
mymodule::port: 443
mymodule::enable_ssl: true
mymodule::ssl_cert: /etc/pki/tls/certs/web01.crt
```

## Automatic Parameter Lookup

Hiera automatically provides values for class parameters:

```puppet
class mymodule (
  Integer $port,              # Looks up mymodule::port
  Boolean $enable_ssl,        # Looks up mymodule::enable_ssl
  Array[String] $allowed_hosts,
) {
  # Parameters populated from Hiera
}
```

## Explicit Lookups

```puppet
# Simple lookup
$value = lookup('mymodule::port')

# With default
$value = lookup('mymodule::port', Integer, 'first', 8080)

# Hash merge
$merged = lookup('mymodule::config', Hash, 'deep')

# Array unique merge
$hosts = lookup('mymodule::hosts', Array[String], 'unique')
```

## Merge Behaviors

| Strategy | Description |
|----------|-------------|
| `first` | First found value wins (default) |
| `unique` | Merge arrays, remove duplicates |
| `hash` | Merge hashes, first key wins |
| `deep` | Deep merge hashes recursively |

## lookup() Function Syntax

```puppet
# Full syntax
lookup(
  <NAME>,
  [<VALUE TYPE>],
  [<MERGE BEHAVIOR>],
  [<DEFAULT VALUE>]
)

# Examples
lookup('mymodule::port')
lookup('mymodule::port', Integer)
lookup('mymodule::port', Integer, 'first')
lookup('mymodule::port', Integer, 'first', 8080)

# Hash lookup with options
lookup('mymodule::config', {
  'value_type'    => Hash,
  'merge'         => 'deep',
  'default_value' => {},
})
```

## Sensitive Data with EYAML

Use EYAML for encrypted values:

**Install:**
```bash
puppetserver gem install hiera-eyaml
eyaml createkeys
```

**hiera.yaml:**
```yaml
---
version: 5

defaults:
  datadir: data

hierarchy:
  - name: "Encrypted data"
    lookup_key: eyaml_lookup_key
    path: "secrets.eyaml"
    options:
      pkcs7_private_key: /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem
      pkcs7_public_key: /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem

  - name: "Common data"
    path: "common.yaml"
```

**data/secrets.eyaml:**
```yaml
---
mymodule::database_password: >
  ENC[PKCS7,MIIBeQYJKoZIhvc...]
```

## Module-Level Hiera

Each module can have its own hiera.yaml:

**modules/mymodule/hiera.yaml:**
```yaml
---
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: "OS family"
    path: "%{facts.os.family}.yaml"

  - name: "Common"
    path: "common.yaml"
```

**modules/mymodule/data/common.yaml:**
```yaml
---
mymodule::default_port: 8080
```

## Best Practices

1. **Keep data out of code** - Use Hiera for all configuration values
2. **Use hierarchy wisely** - Most specific at top, general at bottom
3. **Encrypt secrets** - Always use EYAML for passwords/keys
4. **Document keys** - Include comments in YAML files
5. **Validate data** - Use data types in class parameters
