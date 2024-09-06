# Tarantool 3.x config json-schema generator

## Usage

```bash
❯ config-schema-gen --help
Usage: schema-gen [-o <output>] [-t <tarantool>] [-h]

Tarantool 3.x json-schema generator

Options:
         -o <output>,
   --output <output>
            -t <tarantool>,
   --tarantool <tarantool>
   -h, --help            Show this help message and exit.

Take a look https://github.com/tarantool/tarantool
```

To generate config for current 3.x tarantool

```bash
❯ config-schema-gen -o .
```

To generate config for specific 3.x tarantool binary

```bash
❯ config-schema-gen -o . -t /path/to/tarantool/binary
```

You can also skip `-o` flag and resulting schema will be written to stdout

## Install

```bash
tt rocks install https://raw.githubusercontent.com/ochaton/config-schema-gen/master/config-schema-gen-dev-1.rockspec
```

## Motivation

You can configure VSCode yaml-language-server with this schemas to ease configuration of Tarantool 3.x

```yaml
# yaml-language-server: $schema=https://gist.githubusercontent.com/ochaton/24957db1617df119b30b5e7cec05e3cf/raw/cf498e23928eefad2cf31748a369a8fa124166f2/config.schema-3.3.0.json
```
