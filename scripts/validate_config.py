# /// script
# requires-python = ">=3.9"
# dependencies = ["tomli; python_version < '3.11'", "pyyaml"]
# ///
"""Validate TOML/YAML config files. Usage: validate_config.py <toml|yaml> <file>..."""
import sys
import pathlib


def validate(fmt: str, path: str) -> None:
    data = pathlib.Path(path).read_bytes()
    if fmt == "toml":
        try:
            import tomllib
        except ImportError:
            import tomli as tomllib
        tomllib.loads(data.decode())
    elif fmt == "yaml":
        import yaml

        yaml.safe_load(data)
    else:
        raise ValueError(f"unknown format: {fmt}")


def main() -> int:
    fmt, files = sys.argv[1], sys.argv[2:]
    if not files:
        print(f"ERROR: no files given for {fmt}", file=sys.stderr)
        return 1
    for path in files:
        try:
            validate(fmt, path)
        except Exception as exc:
            print(f"ERROR: invalid {fmt}: {path}: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
