# Playbooks

A playbook defines Ansible tasks to run on selected servers. Personal playbooks
live in `~/odev/playbooks` by default, configured by `paths.playbooks` in `vars.yml`.

## Create

Authenticate with GitHub CLI and use an account in `odev-developers`:

```bash
gh auth login
odev new playbook --name my_playbook
```

On first use, `odev` creates or reuses your fork of `oreolag/playbooks`, clones it
to `~/odev/playbooks`, and prepares the `my_playbooks` branch. The upstream
repository remains available through the `upstream` remote. The branch name is
configured by `github.push_branch_playbooks` in `vars.yml`.

The command creates two files and commits/pushes them to your fork:

```text
~/odev/playbooks/
  my_playbook.yml
  my_playbook_vars.yml
```

Later playbooks reuse the checkout. Choose a name that does not already exist in
your checkout, fork or community playbooks. Names cannot end in `_vars`.

## Implement

Edit `~/odev/playbooks/my_playbook.yml`. Keep `oreol_target` so `--hosts` selects
the target, and load the companion variables file:

```yaml
---
- name: Show server information
  hosts: "{{ oreol_target }}"
  become: false
  gather_facts: true

  vars_files:
    - my_playbook_vars.yml

  tasks:
    - name: Show hostname
      ansible.builtin.debug:
        msg: "Server: {{ ansible_facts['hostname'] }}"

    - name: Show a setting
      ansible.builtin.debug:
        msg: "Value: {{ value }}"
```

Set defaults in `~/odev/playbooks/my_playbook_vars.yml`:

```yaml
---
value: 5
```

Add your tasks to the playbook. Set `become: true` for tasks requiring elevated
permissions, with the appropriate access configured for the target servers.

## Run

```bash
odev run playbook --help
odev run playbook --name my_playbook
odev run playbook --name my_playbook --hosts remote
odev run playbook --name my_playbook --hosts all
odev run playbook --name my_playbook --hosts incus-01
odev run playbook --name my_playbook --vars "value=10"
```

The default target is `local` (localhost). `--hosts remote` selects only booked
remote hosts; `--hosts all` selects localhost and booked remotes. `all` is a
built-in Ansible group and needs no explicit inventory section. An empty
`remote` group is valid and contains no targets.

`--hosts` also accepts a booked host's short name, such as `incus-01`. Each remote
host appears once in the inventory, with its full MagicDNS address assigned to
`ansible_host`. `odev` always refreshes and uses the user's generated inventory
before running the playbook. Generated inventories are stored as
`hosts_<username>` in `paths.inventory` from `vars.yml` (default: `/tmp`).
The configured directory must already exist and be writable by the invoking user.
The `--remote` flag has been removed;
use `--hosts remote` or `--hosts all` instead.

`--vars` overrides values from the companion file. Missing required flags open
the usual dialog. Running playbooks requires `odev-developers` membership and the
management runner installed at `paths.mgmt` (normally `/opt/mgmt`).

## Completion

Press Tab to complete flags and existing playbook names:

```text
odev run playbook --<TAB>
odev run playbook --name <TAB>
odev gh diff --repository <TAB>
```

Playbook-name completion reads your checkout and excludes companion `_vars.yml`
files. `odev new playbook --name` takes a new name rather than an existing one.

## Share

Select `--repository workflows` or `--repository playbooks`. The repository is
required for every `odev gh` action. Missing required values use the usual dialog. `status` fetches `origin` and shows standard `git status` output.
`diff` shows standard `git diff` output for the whole
repository (unstaged tracked changes). `pull` updates the whole repository.
`push` uploads existing commits on the current branch to `origin`; it does not
stage or commit changes. `pr` proposes all pushed commits on the current branch
to the configured community repository's `main` branch, using the commits to fill
the title and description. None of these commands takes a name.

```bash
odev gh status --repository playbooks
odev gh diff --repository playbooks
odev gh push --repository playbooks
odev gh pr --repository playbooks
```

Review your changes, commit/push the playbook and its companion variables file to
your fork, and optionally open a pull request to `oreolag/playbooks`.

To bring fork and community updates into your checkout:

```bash
odev gh pull --repository playbooks
```

## Delete

```bash
odev delete playbook --name my_playbook
```

This removes the playbook and its tracked companion variables file, commits the
deletion and pushes it to your fork. Community playbooks are protected from this
command. Deleting a playbook does not undo tasks already applied to servers.
