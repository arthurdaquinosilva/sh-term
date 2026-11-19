"""Command-line entry point: `:sh`, `:sh SCRIPT`, `:sh -c CODE`, `:sh test FILE…`."""

from __future__ import annotations

import argparse
import os
import shlex
import sys

from sh_term import __version__
from sh_term.theme import PALETTES


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["test"]:
        return test_main(argv[1:])

    parser = argparse.ArgumentParser(
        prog=":sh",
        description="A playground for writing and testing shell scripts.",
        epilog=":sh test FILE…  runs saved tests non-interactively (exit status 1 on failure).",
    )
    parser.add_argument("script", nargs="?", help="open a script to step through (%%open)")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="positional parameters for the script")
    parser.add_argument("-c", dest="command", help="run shell code as cells, print the blocks and exit")
    parser.add_argument("-s", "--shell", help="shell for the session: bash (default), sh, dash, zsh or a path")
    parser.add_argument("--profile", help="use a named profile (separate config and history)")
    parser.add_argument("--theme", choices=list(PALETTES), help="color theme")
    parser.add_argument("--vi", action="store_true", help="vi key bindings")
    parser.add_argument("--version", action="version", version=f":sh {__version__}")
    opts = parser.parse_args(argv)

    from sh_term.config import load_profile, load_settings
    from sh_term.engine import ShellNotFound
    from sh_term.shell import Shell

    profile = load_profile(opts.profile)
    settings, warnings = load_settings(profile)
    if opts.theme:
        settings.theme = opts.theme
    if opts.vi:
        settings.editing_mode = "vi"
    if opts.shell:
        settings.shell = opts.shell
    try:
        shell = Shell(settings=settings, profile=profile)
    except ShellNotFound as e:
        print(f":sh: {e}", file=sys.stderr)
        return 2

    if opts.command is not None or not sys.stdin.isatty():
        code = opts.command if opts.command is not None else sys.stdin.read()
        try:
            for w in warnings:
                shell.warn(w)
            shell.run_cell(code)
            return shell.last_status or 0
        finally:
            shell.close()

    from sh_term.ui import Repl

    repl = Repl(shell)
    if opts.script:
        repl.banner(warnings)
        warnings = []
        shell.run_cell("%open " + shlex.join([opts.script, *opts.args]))
        return repl.run(warnings, show_banner=False)
    return repl.run(warnings)


def test_main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog=":sh test", description="Run :sh test files; exit status 1 if any check fails.")
    parser.add_argument("files", nargs="+", help="test files saved with %%save-test")
    parser.add_argument("-s", "--shell", help="override the shell recorded in the files")
    parser.add_argument("-q", "--quiet", action="store_true", help="only print failures and the summary")
    parser.add_argument("--lint", action="store_true", help="also run shellcheck on each cell and show its findings (they don't fail the run)")
    opts = parser.parse_args(argv)

    from rich.console import Console
    from rich.text import Text

    from sh_term import lint, testing
    from sh_term.config import Settings
    from sh_term.engine import ShellNotFound, resolve_shell, shell_info

    def shell_kind(name: str) -> str:
        try:
            return shell_info(resolve_shell(name))[0]
        except ShellNotFound:
            return "bash"
    from sh_term.magics.checks import print_report_cell, print_summary
    from sh_term.theme import get_theme

    class Printer:
        """Just enough of Shell for the report printers."""

        def __init__(self) -> None:
            self.settings = Settings()
            self.ui = Console(theme=get_theme(os.environ.get("SH_TERM_THEME")).rich_theme, highlight=False)

        def print(self, renderable="", end="\n", **kwargs) -> None:
            self.ui.print(renderable, end=end, **kwargs)

    out = Printer()
    failed = 0
    for name in opts.files:
        try:
            with open(name) as f:
                tf = testing.load(f.read())
        except (OSError, testing.ExpectationError) as e:
            out.print(Text.assemble(("✗ ", "sh_term.err.bold"), (f"{name}: {e}", "sh_term.fg")))
            failed += 1
            continue
        if opts.shell:
            tf.shell = opts.shell
        out.print(Text.assemble(("● ", "sh_term.accent"), (name, "sh_term.fg.bold"), (f"  {tf.shell} · {len(tf.cells)} cells", "sh_term.muted")))

        lint_count = 0

        def on_cell(report: testing.CellReport) -> None:
            nonlocal lint_count
            findings = lint.check(report.cell.code, shell_kind(tf.shell), Settings().lint_exclude) if opts.lint else []
            lint_count += len(findings)
            if not opts.quiet or not report.passed or findings:
                print_report_cell(out, report)  # type: ignore[arg-type]
            for f in findings:
                out.print(Text.assemble(("    ⚠ ", "sh_term.warn"), (f"SC{f.code} ", "sh_term.accent"), (f"line {f.line}: ", "sh_term.faint"),
                                        (f.message, "sh_term.muted")), no_wrap=True, overflow="ellipsis")

        cwd = os.path.dirname(os.path.abspath(name))
        try:
            report = testing.run(tf, cwd, on_cell=on_cell)
        except ShellNotFound as e:
            out.print(Text.assemble(("✗ ", "sh_term.err.bold"), (str(e), "sh_term.fg")))
            failed += 1
            continue
        out.print()
        print_summary(out, report)  # type: ignore[arg-type]
        if opts.lint:
            if lint.shellcheck_path() is None:
                out.print(Text("--lint: shellcheck isn't installed", style="sh_term.warn"))
            else:
                out.print(Text(f"shellcheck: {lint_count} findings" if lint_count else "shellcheck: no findings",
                               style="sh_term.warn" if lint_count else "sh_term.muted"))
        out.print()
        failed += 0 if report.passed else 1
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
