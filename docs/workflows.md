# Workflows

A workflow defines how to create, build, program, run, validate and delete a
project. Workflow scripts live in `~/odev/workflows`; project files live in
`~/odev/projects` by default. These paths are configured in `vars.yml`.

## Create

Authenticate with GitHub CLI and use an account in `odev-developers`:

```bash
gh auth login
odev new workflow --name my_workflow
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
~/odev/workflows/my_workflow/
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
| `new.sh` | `odev new my_workflow` | Prepare project files |
| `build.sh` | `odev build my_workflow` | Compile or build the project |
| `program.sh` | `odev program my_workflow` | Configure devices |
| `run.sh` | `odev run my_workflow` | Execute the application |
| `validate.sh` | `odev validate my_workflow` | Check functionality |
| `delete.sh` | `odev delete my_workflow` | Remove the project |

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
`~/odev/workflows/my_workflow` therefore changes what your commands execute. Built-in
and community commands retain precedence; edit your personal checkout rather
than the installed community submodule.

## Define flags

Edit `~/odev/workflows/my_workflow/cmd_spec.sh` to define descriptions, flags, defaults
and required values:

```bash
BUILD_MY_WORKFLOW_DESCRIPTION="Build the project"
BUILD_MY_WORKFLOW_FLAGS=(
  "name,n,Project name,-,-"
)
BUILD_MY_WORKFLOW_FLAGS_MANDATORY="name"
```

Each flag uses `name,short,description,options,default`. An empty short field means
no short alias; `-` means no options or default. Required values missing from the
command line are requested in the dialog. Choices appear in parentheses and
defaults in brackets, for example `push (0|1) [1]:`.

Read new flags from `V` in the corresponding script, following the generated
`# assign flags` section. Definitions also supply help and flag-name completion.

## Test

```bash
odev new my_workflow --help
odev new my_workflow --name my_project --push 0
odev build my_workflow --name my_project
odev run my_workflow --name my_project
```

The default project path is `~/odev/projects/my_workflow/my_project`. In the generated
`new.sh`, `--push 0` keeps the project local; `--push 1` creates a private GitHub
repository named `my_workflow-my_project`. This is separate from the workflow fork.

## Share

```bash
odev gh diff --workflow my_workflow
odev gh push --workflow my_workflow
odev gh pr --workflow my_workflow
```

Review your changes, commit/push them to your fork, and optionally open a pull
request to `oreolag/workflows`.

To bring upstream updates into your workflow checkout:

```bash
odev gh pull --workflows
```
