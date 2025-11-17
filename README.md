# Module

A tiny framework for routing shell script entrypoints so every executable can behave like a small module with multiple exported functions.

## Installation

Clone the repository and either copy `src/module.sh` into your own project or install it somewhere on your `$PATH` (renamed to simply `module`) with the included make target:

```sh
make install                    # prompts for a target directory (defaults to ~/Scripts)
make install to=/usr/local/bin  # non-interactive install
```

This copies the framework to `<target>/module`. Because the file lives on your `$PATH` without an extension, you can source it succinctly in any script via `source module` (the shell resolves it through `$PATH`). The `make install` target already performs this rename and is the recommended path so everyone can assume the canonical name `module`. Treat this naming as a requirement: third-party scripts written for this framework expect to load it with `source module`, so keep the filename consistent even if you install it somewhere else.

## Usage

All examples assume the framework is available on your `$PATH` as `module` (no extension); if you rename it, scripts that rely on `source module` will fail to resolve the dependency.

1. Source the framework near the top of your script.
2. Define one or more functions using the naming convention `<script_basename>::function`.
3. Optionally define a `<script_basename>` function to act as the default handler (similar to `main`).
4. Execute your script like `./script.sh subcommand arg1 arg2`. The framework automatically routes the call to the matching function.

Example `greet.sh`:

```sh
#!/usr/bin/env bash
source module

greet::hello() {
  local name="${1:-friend}"
  echo "Hello, $name!"
}

greet() {
  echo "Usage: $0 hello [name]"
}
```

```sh
$ ./greet.sh hello "Terry"
Hello, Terry!
$ ./greet.sh
Usage: ./greet.sh hello [name]
```

### Routing rules

- The framework infers the module name from the calling script (e.g., `greet.sh` → `greet`).
- If you pass an argument, it looks for `<module>::<argument>` (e.g., `greet::hello`).
- If no matching sub-function is found, it falls back to calling `<module>` itself.
- When the script is sourced (e.g., for reuse), routing is skipped so you can import functions without executing them.

### Debugging

Set `MODULE_DEBUG=1` before running your script to see routing details and stack traces:

```sh
MODULE_DEBUG=1 ./greet.sh hello
```

## Development

- Format: `make format` (requires [`shfmt`](https://github.com/mvdan/sh))
- Lint: `make lint` (requires [`shellcheck`](https://www.shellcheck.net/))
- Tests: `make test`

## License

MIT
