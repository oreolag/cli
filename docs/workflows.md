# Workflows

A workflow defines how to create, build, program, run, validate and delete a
project. Workflow scripts live in `~/odev/workflows`; project files live in
`~/odev/projects` by default. These paths are configured in `vars.yml`.

## Create

Authenticate with GitHub CLI and use an account in `odev-developers`:

```bash
gh auth login
odev new workflow --name wf_name
```

On first use, `odev` creates or reuses your fork of `oreolag/workflows`, clones it
to `~/odev/workflows`, and prepares the `my_workflows` branch. The upstream
repository remains available through the `upstream` remote. The branch name is
configured by `github.push_branch_workflows` in `vars.yml`.

The command creates the workflow scripts, registers personal command links and
commits/pushes the initial files to your fork. Later workflows reuse the checkout.
Choose a name that does not already exist in your checkout, fork or community
workflows.

To start from an existing personal or community workflow:

```bash
odev new workflow --name my_nccl --template nccl
```

## Implement

Edit your workflow in your checkout:

```text
~/odev/workflows/wf_name/
  cmd_spec.sh
  new.sh
  build.sh
  program.sh
  program.yml
  run.sh
  validate.sh
  delete.sh
```

The generated scripts contain the usual help, flag parsing and dialogs. Add your
logic at `# add your code here!` and keep the existing command structure.

| Script | Command | Workflow logic |
|---|---|---|
| `new.sh` | `odev new wf_name` | Prepare project files |
| `build.sh` | `odev build wf_name` | Compile or build the project |
| `program.sh` | `odev program wf_name` | Configure devices |
| `run.sh` | `odev run wf_name` | Execute the application |
| `validate.sh` | `odev validate wf_name` | Check functionality |
| `delete.sh` | `odev delete wf_name` | Remove the project |

For example, build logic can use the project selected by `--name`:

```bash
# add your code here!
cd "$PROJECTS_PATH/$SUBCOMMAND/$name" || exit 1
make
```

This example assumes `new.sh` prepares a project with a Makefile. The templates
provide scaffolding; you implement the application's behavior.

`odev` resolves personal commands through links under
`$ODEV_PATH/users/<username>/workflows/`. Editing the original scripts in
`~/odev/workflows/wf_name` therefore changes what your commands execute. Built-in
and community commands retain precedence; edit your personal checkout rather
than the installed community submodule.

## Define flags

Edit `~/odev/workflows/wf_name/cmd_spec.sh` to define descriptions, flags, defaults
and required values:

```bash
BUILD_WF_NAME_DESCRIPTION="Build the project"
BUILD_WF_NAME_FLAGS=(
  "name,n,Project name,-,-"
)
BUILD_WF_NAME_FLAGS_MANDATORY="name"
```

Each flag uses `name,short,description,options,default`. An empty short field means
no short alias; `-` means no options or default. Required values missing from the
command line are requested in the dialog. Choices appear in parentheses and
defaults in brackets, for example `push (0|1) [1]:`.

Read new flags from `V` in the corresponding script, following the generated
`# assign flags` section. Definitions also supply help and flag-name completion.

## Test

```bash
odev new wf_name --help
odev new wf_name --name test_project --push 0
odev build wf_name --name test_project
odev run wf_name --name test_project
```

The default project path is `~/odev/projects/wf_name/test_project`. In the generated
`new.sh`, `--push 0` keeps the project local; `--push 1` creates a private GitHub
repository named `wf_name-test_project`. This is separate from the workflow fork.

## Share

```bash
odev gh diff --workflow wf_name
odev gh push --workflow wf_name
odev gh pr --workflow wf_name
```

Review your changes, commit/push them to your fork, and optionally open a pull
request to `oreolag/workflows`.

To bring upstream updates into your workflow checkout:

```bash
odev gh pull --workflows
```
