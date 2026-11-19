# Configuration

## Where things live

| Path | Contents |
| --- | --- |
| `~/.config/sh-term/config.toml` | Settings (this page) |
| `~/.local/share/sh-term/history.sqlite` | Cell history with exit statuses, grouped by session |

`XDG_CONFIG_HOME` and `XDG_DATA_HOME` are respected. Nothing else is written outside your working directory: sessions, cells and sandboxes live in the system's temporary directory and are removed when :sh exits.

## config.toml

Every setting is optional. This example shows each one with its default:

```toml
theme = "pitch"                         # the only theme for now
editing_mode = "emacs"                  # emacs · vi
shell = "bash"                          # bash · sh · dash · zsh · a path like "/bin/bash"
lint = true                             # live shellcheck hint in the footer (when shellcheck is installed)
lint_exclude = ["SC2034", "SC2154"]     # checks skipped for cells (they see variables from other cells)
tty = false                             # run cells attached to a pseudo-terminal (%tty)
save_shebang = ""                       # %save's first line; "" picks #!/usr/bin/env <shell>
startup = []                            # shell lines run in every new session, e.g. ["set -o pipefail", "export LC_ALL=C"]
aliases = ""                            # import your aliases: "auto" ($SHELL), "zsh" or "bash"; "" is off
```

Inside :sh, `%config` lists the current values and `%config name=value` changes one for the session (`%config lint=off`, `%config shell=dash`, `%config editing_mode=vi`). Add `--save` to also write it to `config.toml` — other lines and comments in the file are kept. `%vi --save` does the same for vi mode. Settings with a problem are reported as warnings at startup instead of stopping :sh.

`startup` lines also run after `%restart`, `%shell` and when a session had to be restarted because the shell exited.

Sessions start **non-interactively** and without startup files: bash with `--noprofile --norc`, zsh with `-f`, and `BASH_ENV`/`ENV` removed from the environment — cells behave like a script, not like your login shell. Put what your scripts expect in `startup`. In bash, aliases are enabled (`shopt -s expand_aliases`).

### Your aliases

`aliases = "auto"` brings the aliases of your interactive shell into every session. :sh starts `$SHELL -i` once (or the shell you name: `"zsh"`, `"bash"`), asks it for its aliases and defines them before the `startup` lines, so `startup` can still change one. Only aliases go across — not functions, variables or options — and the rest of your startup files have no effect on cells.

- Each session gets the aliases its own shell understands: zsh's global (`alias -g`) and suffix (`alias -s`) aliases only reach zsh sessions, and dash skips names it can't define.
- An alias whose command doesn't exist in the session is left out — usually one that calls a function from your startup files, like oh-my-zsh's `history` (`omz_history`). The name then means what it does in a plain shell. For :sh's own history of cells, use `%history`.
- They're read once per run of :sh. `%config aliases=auto` reads them again, e.g. after you add one to `~/.zshrc`.
- `%test` and `:sh test` don't import them (nor run `startup`), so a test that uses an alias fails there — as it would in CI. The same goes for scripts written by `%save`.
- In bash, an alias defined in a cell works from the next cell on: bash expands aliases when it reads a cell, before running it.

## Environment variables

| Variable | Effect |
| --- | --- |
| `SH_TERM_THEME` | theme, overriding `config.toml` |
| `SH_TERM_SHELL` | shell, overriding `config.toml` |
| `SH_TERM_PROFILE` | profile to use |
| `VISUAL` / `EDITOR` | editor for Ctrl+O and `%edit` |

## Profiles

`:sh --profile work` (or `SH_TERM_PROFILE=work`) keeps a separate `config.toml` and history in `~/.config/sh-term/profiles/work/` and `~/.local/share/sh-term/profiles/work/`.

## Command-line options

```text
:sh [SCRIPT [ARGS…]]      interactive; with SCRIPT, open it to step through (%open)
  -c CODE                    run CODE as a cell, print the block, exit with the cell's status
  -s, --shell SHELL          bash (default), sh, dash, zsh or a path
  --profile NAME             separate config and history
  --theme pitch
  --vi                       vi key bindings
  --version

:sh test FILE…            run test files; exit status 1 if any check fails
  -s, --shell SHELL          override the shell recorded in the files
  -q, --quiet                only print failing cells and the summary
  --lint                     show shellcheck findings for each cell (reported, not failures)
```

Piping code into :sh (`echo 'ls' | :sh`) runs it like `-c`.

## Test files

`%save-test` writes a file like this:

```sh
#!/usr/bin/env -S :sh test
# :sh test · shell: bash · sandbox: copy
#%% [1] %open deploy.sh
set -- 'staging'
#%% [2] deploy.sh:4  (2/7)
target=${1:-staging}
#%% [3]
./build.sh
#% expect exit 0
#% expect file exists dist/app.tar.gz
```

- The header's `shell:` is the shell to run with; `sandbox:` is `off` (run in the file's directory), `empty` (a new empty temporary directory) or `copy` (a temporary copy of the file's directory).
- Each `#%%` line starts a cell (the rest of the line is a label); the lines until the next `#%%` are its code.
- `#% stdin "…"` (a JSON string) is given to the cell as its input — :sh records what you typed while the cell ran.
- `#% expect …` lines are checked after the cell, with the same syntax as [`%expect`](features.md#expectations-and-tests).

Since cells and checks are comments, the file is also a valid script, and it's easy to write or edit by hand. Being executable with that shebang, `./deploy.test.sh` runs the tests too.

## Themes

One palette, `pitch`: cool blue/violet hues on a pitch-black terminal, the same palette as :py, :js, :http and :docs, with :sh's own cyan accent. Backgrounds stay transparent, so the terminal's own black shows through.

The same palette colors the input, cell output, the footer and syntax highlighting.
