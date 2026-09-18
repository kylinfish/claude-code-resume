# Grouped Runtime Dashboard Design

## Goal

Replace pane switching with one portable `fzf` screen that shows Claude Code
sessions, likely localhost preview servers, and development watchers together.
The interface must not require tmux or Vim-style navigation.

## Interface

The left side is one selectable list divided into three visible sections in
this order:

1. Sessions
2. Preview Servers
3. Watchers

The right side is the existing `fzf` preview window. It shows details and the
available action for the selected row. Section headings and empty-state rows
are visible but not actionable. Up and Down move through the unified list.

Actions depend on row type:

- Session: Enter resumes, Ctrl-R resumes with Remote Control, and Ctrl-Y prints
  the resume command.
- Preview Server: Enter opens the localhost URL in the default browser.
- Watcher: Delete shows PID and full command, asks for confirmation, revalidates
  process identity, and sends SIGTERM.
- Escape exits without changing external state.

Session sorting shortcuts continue to sort rows only inside the Sessions
section. Preview Servers sort by port. Watchers sort by PID.

## Data Model

Every selectable row uses a common tab-separated record:

```text
display  type  primary_id  cwd  detail_1  detail_2  action_value
```

`type` is `session`, `preview`, or `watcher`. Dispatch and preview rendering use
the type field rather than the current UI mode. Section headings use a separate
non-actionable marker and never reach action dispatch.

## Preview Server Classification

A listening port is shown only when both checks pass:

1. Its process command or working directory indicates a development server,
   using a focused allowlist such as Vite, Next, Nuxt, webpack, package-manager
   dev scripts, Python HTTP servers, Rails, Django, or other existing watcher
   signatures.
2. A short localhost HTTP or HTTPS probe receives a protocol response. Any HTTP
   status counts; connection refusal, timeout, or a non-HTTP protocol does not.

The probe uses Python 3, which is already a required dependency, and has a
strict sub-second timeout so startup remains responsive. HTTP is attempted
before HTTPS. TLS certificate verification is disabled only for this local
classification probe so self-signed development certificates can be detected.

The UI calls these entries "Preview Servers", not "agent-generated previews",
because detached processes cannot reliably be attributed to the agent that
started them.

## Watcher Classification and Safety

Watcher detection keeps the focused development-command allowlist and excludes
unrelated background services. The row snapshot includes PID, start time, and
full command. Before confirmation and again immediately before SIGTERM, `ccr`
compares start time and command with the current process. A missing or changed
identity fails closed.

## Error and Empty States

- Missing `lsof`: show an empty Preview Servers section; Sessions and Watchers
  remain usable.
- Failed or timed-out probes: omit the port without delaying other rows.
- No rows in a section: show a non-actionable `(none)` row.
- Browser opener missing: display an error and keep the picker available.
- A process disappears or changes identity: refuse termination and refresh the
  unified list.

## Testing

Shell integration tests will cover:

- Unified section order and visible empty states.
- System listening ports excluded from Preview Servers.
- HTTP and HTTPS development previews included after a successful probe.
- Type-based Enter, Ctrl-R, Ctrl-Y, and Delete dispatch.
- Session sorting without disturbing section order.
- Missing and reused PID termination safety.
- Bash 3.2 syntax and current command behavior.

## Documentation

Update English and Traditional Chinese help, README, and changelog. Remove the
tab/pane-switch language and document the grouped list, right-side detail pane,
classification limits, and type-specific actions.
