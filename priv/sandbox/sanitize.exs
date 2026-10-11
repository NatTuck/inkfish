# Entry point for the symlink sanitizer, run *inside* the tmpfs namespace.
#
# The extracted tree only exists inside the namespace that `tmptmpfs` created,
# so the sanitizer has to run there too. Its warnings are written to stdout
# with a sentinel prefix so the parent process can forward them into its own
# `Logger` -- `Inkfish.Sandbox.Archive.safe_extract/3` does exactly that, which
# is what keeps the `capture_log` assertions in `archive_test.exs` meaningful
# even though the sanitizer is a separate OS process.
#
# Usage: sanitize.exs BASE

Code.require_file("sanitize_logic.exs", __DIR__)

sentinel = "INKFISH-SANITIZE "

# Take over the logger completely. The default handler writes a timestamped
# line to stderr, which the parent would have to strip; stdout is otherwise
# unused by this script.
:logger.remove_handler(:default)

:logger.add_handler(:inkfish_sanitize, :logger_std_h, %{
  config: %{type: :standard_io},
  formatter:
    {:logger_formatter,
     %{
       template: [sentinel, :msg, "\n"],
       single_line: true,
       legacy_header: false
     }}
})

case System.argv() do
  [base] ->
    Inkfish.Sandbox.SanitizeLinks.sanitize_links!(base)

  args ->
    IO.puts(:stderr, "usage: sanitize.exs BASE (got #{inspect(args)})")
    System.halt(2)
end
