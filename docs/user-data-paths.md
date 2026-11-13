# User-data path resolver

`src/odev_path.py` reads `/opt/odev_path.yml`:

```yaml
data_path: "${HOME}/odev"
```

For shared data, use `/scratch/${USER}/odev`. The four directory names are fixed:
`models`, `projects`, `workflows` and `playbooks`.

```bash
python3 /opt/odev/src/odev_path.py workflows
```

This prints the absolute workflows path. Omit the directory argument to print
the root. `--db /path/to/odev_path.yml` selects a configuration for testing.

The account database supplies the user's home and name. When running as root
through sudo, `SUDO_UID` selects the original account. A regular user cannot
select another account by setting sudo environment variables. `${HOME}` and
`${USER}` (also `$HOME`, `$USER` and `~/`) are expanded without shell evaluation.
Other variables are rejected. Shell snippets are never executed.

Missing or invalid configuration produces an error rather than selecting a
different location. The resolver does not create directories, check mounts,
change ownership or migrate data. Those operations belong to later steps.

Commands, metadata/discovery, login synchronization and workflow templates use
this helper instead of the removed user-data entries in `vars.yml`. The legacy
NCCL workflow is excluded from this migration because it is scheduled for removal.

Configuration deployment is still pending: install `/opt/odev_path.yml` before
deploying these callers. Existing personal workflows generated from older
templates need the same caller update. Mount checks, directory provisioning and
data migration remain separate steps.
