# Early validation

Command-specific checks stay inline in the command's Bash script, with the
original comments, error messages and checks retained. There is no shared
validation dispatcher or callback system.

Commands with dependent questions use a small loop:

```bash
# check supplied values first, then check each answer before the next question
for field in "" ${mandatory_flags//,/ }; do
  # run interactive prompt (one field only)
  # read flags
  # assign flags
  # existing inline checks, guarded when their inputs are still missing
done
```

The first pass checks supplied fields and optional defaults without asking a
question. Later passes ask for one missing required field and run the same
inline checks before the next question. Already supplied fields are skipped.
Checks depending on missing fields wait until those fields have been answered.

`src/cmd_prompt.sh` adds only `--field NAME` to select a question while preserving
the full mandatory list for defaults. `--field ""` fills optional defaults only.
Required defaults remain suggestions until accepted. Existing callers without
`--field` retain their normal dialog. A complete request needs no terminal.

Examples:

```text
$ odev get ip --numa 1
Invalid numa: 1

$ odev get ip --numa 0
device: 0
192.0.2.1
```

## Coverage

- `get ip/mac`: NUMA/type resources, device existence and membership, port.
- `set mtu`: interface and port, before asking for the missing MTU.
- `new/run/delete playbook`: existing name, existence and protection checks;
  new playbook local/upstream duplicate checks run before repository writes.
  Invalid explicit run inventory fails before asking for a name.
- `new/delete workflow`: existing local/upstream/template checks; new workflow
  name syntax is checked inline. Template and duplicate checks precede writes.
- `booking add`: existing start checks stay in Bash. Date and shared users are
  checked inline. The existing booking inventory reader accepts `--server` and
  `--duration` to check a target and the inventory's duration limit. Storage and
  client checks are unchanged.
- `booking share`: existing user checks remain; answers are checked between
  questions. `booking list` checks the calendar date before invoking the client.
- `booking cancel`: unchanged operation; benefits from the prompt helper's
  removal of its unnecessary terminal requirement for complete input.

Booking share/cancel still echo parameters; existence/ownership checks need
those operations to be implemented. Global startup status discovery and help
ordering remain separate audit findings. External workflow scripts are not
rewritten. Commands without mandatory dialogs retain their existing flow.

## Tests

Run `python3 -m unittest discover -s src/tests` with Bash 4+ and PyYAML.
The command tests use temporary inventories, real pseudo-terminals and fake
execution programs. They cover supplied errors without questions/actions,
invalid answers before the next question, valid partial/complete input,
dependent checks, missing values and upstream duplicates. Existing booking API
and storage tests continue to verify final execution behavior.
