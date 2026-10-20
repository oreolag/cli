# Playbooks

A playbook defines Ansible tasks to run on selected servers. Personal playbooks
live in `~/odev/playbooks` by default, configured by `paths.playbooks` in `vars.yml`.

## Create

Authenticate with GitHub CLI and use an account in `odev-developers`:

```bash
gh auth login
odev new playbook --name server_info
```

On first use, `odev` creates or reuses your fork of `oreolag/playbooks`, clones it
to `~/odev/playbooks`, and prepares the `my_playbooks` branch. The upstream
repository remains available through the `upstream` remote. The branch name is
configured by `github.push_branch_playbooks` in `vars.yml`.

The command creates two files and commits/pushes them to your fork:

```text
~/odev/playbooks/
  server_info.yml
  server_info_vars.yml
```

Later playbooks reuse the checkout. Choose a name that does not already exist in
your checkout, fork or community playbooks. Names cannot end in `_vars`.

## Implement

Edit `~/odev/playbooks/server_info.yml`. Keep `oreol_target` so `--hosts` selects
the target, and load the companion variables file:

```yaml
---
- name: Show server information
  hosts: "{{ oreol_target }}"
  become: false
  gather_facts: true

  vars_files:
    - server_info_vars.yml

  tasks:
    - name: Show hostname
      ansible.builtin.debug:
        msg: "Server: {{ ansible_facts['hostname'] }}"

    - name: Show a setting
      ansible.builtin.debug:
        msg: "Value: {{ value }}"
```

Set defaults in `~/odev/playbooks/server_info_vars.yml`:

```yaml
---
value: 5
```

Add your tasks to the playbook. Set `become: true` for tasks requiring elevated
permissions, with the appropriate access configured for the target servers.

## Run

```bash
odev run playbook --help
odev run playbook --name server_info
odev run playbook --name server_info --hosts incus-01
odev run playbook --name server_info --hosts incus_hosts --inventory ~/my_oreol_mgmt/hosts
odev run playbook --name server_info --vars "value=10"
```

The default target is `local`. `--hosts` accepts an inventory host or group;
`--inventory` selects a custom inventory. Without it, `odev` uses the user's
generated inventory when available, otherwise the management runner's inventory.

`--vars` overrides values from the companion file. Missing required flags open
the usual dialog. Running playbooks requires `odev-developers` membership and the
management runner installed at `paths.mgmt` (normally `/opt/mgmt`).

## Completion

Press Tab to complete flags and existing playbook names:

```text
odev run playbook --<TAB>
odev run playbook --name <TAB>
odev gh diff --playbook <TAB>
```

Playbook-name completion reads your checkout and excludes companion `_vars.yml`
files. `odev new playbook --name` takes a new name rather than an existing one.

## Share

```bash
odev gh diff --playbook server_info
odev gh push --playbook server_info
odev gh pr --playbook server_info
```

Review your changes, commit/push the playbook and its companion variables file to
your fork, and optionally open a pull request to `oreolag/playbooks`.

To bring fork and community updates into your checkout:

```bash
odev gh pull --playbooks
```

## Delete

```bash
odev delete playbook --name server_info
```

This removes the playbook and its tracked companion variables file, commits the
deletion and pushes it to your fork. Community playbooks are protected from this
command. Deleting a playbook does not undo tasks already applied to servers.
