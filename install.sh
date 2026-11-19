#!/bin/sh
# Install :sh from GitHub into its own virtual environment and put the `:sh` command (and its plain
# alias `sh-term`) on your PATH.
#
#   curl -fsSL https://raw.githubusercontent.com/arthurdaquinosilva/sh-term/main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- 0.2.0         # a specific version
#   curl -fsSL .../install.sh | sh -s -- --uninstall   # remove it again
#
# Running it again upgrades to the latest code on main. Settings (environment variables):
#   SH_TERM_VENV     where the virtual environment lives   (default: ~/.local/share/sh-term/venv)
#   SH_TERM_BIN_DIR  where the `:sh` link goes           (default: ~/.local/bin)
#   SH_TERM_PYTHON   the Python to use                      (default: the newest python3 >= 3.10 found)
#   SH_TERM_PACKAGE  what pip installs, e.g. a local checkout (default: :sh's source archive on GitHub)
#
# Everything is inside main(), so a download cut short runs nothing.

main() {
    set -eu

    # Next to :sh's history, but only this folder belongs to the installer.
    venv=${SH_TERM_VENV:-${XDG_DATA_HOME:-$HOME/.local/share}/sh-term/venv}
    bin_dir=${SH_TERM_BIN_DIR:-$HOME/.local/bin}
    version=""
    uninstall=0
    COMMANDS=":sh sh-term"

    for arg in "$@"; do
        case $arg in
            --uninstall) uninstall=1 ;;
            -h|--help) usage; return 0 ;;
            latest|main) version="" ;;
            -*) die "unknown option: $arg (see --help)" ;;
            *) version=${arg#v} ;;
        esac
    done

    if [ "$uninstall" = 1 ]; then
        do_uninstall
        return 0
    fi

    case $(uname -s) in
        Darwin|Linux) ;;
        *) die ":sh runs on macOS and Linux; this is $(uname -s)." ;;
    esac

    python=$(find_python) || die ":sh needs Python 3.10 or newer, and none was found.
  macOS:          brew install python
  Debian/Ubuntu:  sudo apt install python3 python3-venv
  Fedora:         sudo dnf install python3
Or point SH_TERM_PYTHON at one and run this again."
    say "Using $python ($("$python" -c 'import sys; print(sys.version.split()[0])'))"

    # A source archive from GitHub, so neither git nor a package index is needed.
    if [ -n "${SH_TERM_PACKAGE:-}" ]; then
        package=$SH_TERM_PACKAGE
    elif [ -n "$version" ]; then
        package="sh-term @ https://github.com/arthurdaquinosilva/sh-term/archive/refs/tags/v$version.tar.gz"
    else
        package="sh-term @ https://github.com/arthurdaquinosilva/sh-term/archive/refs/heads/main.tar.gz"
    fi

    if [ ! -x "$venv/bin/python" ] || ! "$venv/bin/python" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
        say "Creating a virtual environment in $venv"
        rm -rf "$venv"
        mkdir -p "$(dirname "$venv")"
        "$python" -m venv "$venv" 2>/dev/null || die "could not create a virtual environment with $python.
  On Debian/Ubuntu: sudo apt install python3-venv"
    fi

    say "Installing $package"
    "$venv/bin/python" -m pip install --quiet --disable-pip-version-check --upgrade pip >/dev/null 2>&1 || true
    # --force-reinstall: the main archive keeps its URL while its contents change.
    "$venv/bin/python" -m pip install --quiet --disable-pip-version-check --upgrade --force-reinstall "$package" \
        || die "pip could not install $package."

    mkdir -p "$bin_dir"
    for cmd in $COMMANDS; do
        ln -sf "$venv/bin/$cmd" "$bin_dir/$cmd"
    done
    remove_old_install
    installed=$("$bin_dir/:sh" --version) || die ":sh was installed but does not run: $bin_dir/:sh --version failed."
    say "Installed $installed to $bin_dir/:sh"

    case ":$PATH:" in
        *":$bin_dir:"*) ;;
        *) path_hint ;;
    esac

    if ! command -v shellcheck >/dev/null 2>&1; then
        say "Optional: install shellcheck for live linting (brew install shellcheck, apt install shellcheck)."
    fi
    say "Run: :sh"
}

usage() {
    cat <<'EOF'
Install :sh, a playground for writing and testing shell scripts.

usage: install.sh [VERSION | main] [--uninstall]

  VERSION        install this release (e.g. 0.2.0); default: the main branch
  --uninstall    remove :sh's virtual environment and the `:sh` link

Environment: SH_TERM_VENV, SH_TERM_BIN_DIR, SH_TERM_PYTHON, SH_TERM_PACKAGE (see the top of this script).
EOF
}

# Prints the first Python 3.10+ it finds, preferring SH_TERM_PYTHON and then the newest version.
find_python() {
    for candidate in ${SH_TERM_PYTHON:-} python3.13 python3.12 python3.11 python3.10 python3 python; do
        if command -v "$candidate" >/dev/null 2>&1 \
            && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

do_uninstall() {
    # Only remove the links if they are ours, so a :sh installed another way is left alone.
    for cmd in $COMMANDS; do
        link="$bin_dir/$cmd"
        if [ -L "$link" ] && [ "$(readlink "$link")" = "$venv/bin/$cmd" ]; then
            rm -f "$link"
            say "Removed $link"
        fi
    done
    if [ -d "$venv" ]; then
        rm -rf "$venv"
        say "Removed $venv"
    else
        say "Nothing to remove in $venv"
    fi
    say "Your config and history were kept (~/.config/sh-term, ~/.local/share/sh-term)."
}

# :sh used to be called shtick: remove that installation (its venv and link), keep its history.
# :sh copies the old settings and history over on first start.
remove_old_install() {
    old_venv=${XDG_DATA_HOME:-$HOME/.local/share}/shtick/venv
    if [ -L "$bin_dir/shtick" ] && [ "$(readlink "$bin_dir/shtick")" = "$old_venv/bin/shtick" ]; then
        rm -f "$bin_dir/shtick"
    fi
    if [ -d "$old_venv" ]; then
        rm -rf "$old_venv"
        say "Removed the old shtick installation ($old_venv)"
    fi
}

# The ~ in the file names is shown to the user, not expanded.
# shellcheck disable=SC2088
path_hint() {
    case ${SHELL:-} in
        */zsh) rc='~/.zshrc' line="export PATH=\"$bin_dir:\$PATH\"" ;;
        */bash) rc='~/.bashrc' line="export PATH=\"$bin_dir:\$PATH\"" ;;
        */fish) rc='~/.config/fish/config.fish' line="fish_add_path $bin_dir" ;;
        *) rc="your shell's startup file" line="export PATH=\"$bin_dir:\$PATH\"" ;;
    esac
    say ""
    say "$bin_dir is not on your PATH. Add this line to $rc and open a new terminal:"
    say "  $line"
    say ""
}

say() {
    printf '%s\n' "$*"
}

die() {
    printf ':sh install: %s\n' "$*" >&2
    exit 1
}

main "$@"
