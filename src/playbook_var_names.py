#!/usr/bin/env python3
"""Expose the names of supplied extra variables to the example playbook."""

import json
import shlex
import sys


def main():
    supplied = sys.argv[1]
    if supplied.startswith("@"):
        import yaml

        with open(supplied[1:]) as source:
            variables = yaml.safe_load(source)
    elif supplied.startswith(("{", "[")):
        try:
            variables = json.loads(supplied)
        except ValueError:
            import yaml

            variables = yaml.safe_load(supplied)
    else:
        variables = {}
        for token in shlex.split(supplied):
            name, separator, value = token.partition("=")
            if separator:
                variables[name] = value
    if not isinstance(variables, dict):
        raise ValueError("--vars must contain a mapping of variable names to values")
    print(json.dumps({"odev_extra_var_names": [
        name for name in variables if name != "odev_extra_var_names"
    ]}))


if __name__ == "__main__":
    main()
