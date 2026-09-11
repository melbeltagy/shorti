# shorti conventions

Shell helpers sourced into `~/.bashrc`. Each folder wraps one CLI; `setup/apply.bash` sources every `<folder>/*.bash`.

## Functions

- One dispatcher per file, named after the command: `function v() { ... }`. Subcommands are private helpers named `_<cmd>_<sub>()`.
- Dispatcher shape: `help` or no args prints help and returns 0; `_shorti_require <cli>` guards the tool; unknown subcommand prints to **stderr**, shows help, returns **1**.
- Use `print` (green banner) for step/section headings, plain `echo` for data. Tables: build tab-separated rows and pipe through `column -t -s $'\t'`.
- Indent 2 spaces in tool files, 4 in `shell/common.bash` (pre-existing).
- Reports never mutate. A read-only command prints the destructive command for the user to run instead of running it.
- One job per function. If it needs a comment marking sections inside it, split it. Past ~15 lines, split it.
- `awk` is for extracting or filtering fields, one line, like the rest of the repo. Grouping, joining and counting belong in bash with associative arrays: no `NR == FNR` joins, no multi-line awk programs.
- `local x; x=$(...)` on separate lines, quote expansions, `xargs -r` for possibly-empty lists.
- Add every new top-level command to the `shorti` registry in `shell/common.bash`.

## Output

- Print data, plus at most one line saying what to do next. Reasons, caveats and workflows go in the help text and the README, never in the printed output.
- No warning paragraphs, no "what you can do" footers, no restating a caveat the help already carries.

## Help

- One `_<cmd>_help()` per dispatcher, body in `cat <<'EOF'` (quoted delimiter, no expansion), space-aligned, never tabs.
- `Usage:` line, `Commands:` block, `Examples:` block.
- Descriptions start with a verb and say what you get: "List mounted filesystems and free space", not "Mounted filesystems".
- Mark anything needing root with `[sudo]`, in both the parent help and any nested help, with one line saying what the marker means.

## READMEs

- Root `README.md` owns what's included, prerequisites, setup. All general prerequisites live there.
- A folder README covers only what's specific to that folder and links back to the root prerequisites. Keep it in the 13 to 27 line range the existing ones sit in.
- Document the non-obvious: why a flag is there, a caveat, a gotcha. Never restate what `<cmd> help` already prints.

## Scope

- Don't add a subcommand that prints what another one already prints. Propose a new subcommand before writing it, with what it does that the existing ones don't.
- Apply a correction everywhere the pattern occurs, not only the line the user pointed at.

## Writing

- Be brief and be specific. Brevity is not vagueness: cut the explanation, keep the facts.
- No em-dashes or en-dashes, in code, comments, docs or replies.
- Comments explain the non-obvious *why* in one or two lines, never what the code does.

## Before finishing

- `shellcheck --shell=bash --external-sources --severity=warning <files>` must pass (CI runs this).
- Run the command and paste real output rather than assuming. Say plainly which paths went untested (destructive ones usually are).
- Never commit or push. Report what changed and let the user commit.
