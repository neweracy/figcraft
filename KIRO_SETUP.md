# Using FigCraft from Kiro

This is local tooling for driving the FigCraft MCP server from Kiro. It is separate from the
project README. Paths below assume the repo is at `d:/code/figcraft`.

## 1. Build the MCP server

The server is `figcraft-cli mcp` (newline-delimited JSON-RPC over stdio, see `docs/mcp.md`).

```sh
cargo build --release -p figcraft-cli
```

Output: `target/release/figcraft-cli.exe`. A cold build took about 6 minutes.

## 2. Register it in Kiro

Add this inside `mcpServers` in `~/.kiro/settings/mcp.json` (every project) and/or
`.kiro/settings/mcp.json` (this project only):

```json
"figcraft": {
  "command": "d:/code/figcraft/target/release/figcraft-cli.exe",
  "args": ["mcp", "--no-system-fonts"],
  "disabled": false,
  "autoApprove": [
    "list_commands",
    "inspect_document",
    "get_node",
    "screenshot",
    "inspect_ui",
    "wait_for_changes"
  ]
}
```

Notes:

- `autoApprove` holds only tools the server marks `readOnlyHint: true`. Everything that changes the
  document (`run_command`, `batch`, `create_node`, `set_properties`, `select`, `open_file`,
  `save_file`, `undo`, `redo`, `pointer`, `key`, `type_text`) still asks first.
- `export` is also marked read-only, but it writes a file when you give it a `path`, so it is left out.
  Add it back only together with `--automation-write-root`.
- To keep the agent to certain folders, add
  `"--automation-read-root", "D:/work", "--automation-write-root", "D:/work/out"` to `args`.
- To drive the running app instead of a headless session, start `figcraft --control 7979` and use
  `"args": ["mcp", "--attach", "7979"]`.
- `--no-system-fonts` makes text render the same on every machine. Drop it to use installed fonts.
- Do not put tokens in this file if you sync or share it. Reference them from the environment.

## 3. Check it works

Verified against the release build, over stdio:

1. `initialize` returns `figcraft` 0.15.0, protocol `2025-06-18`.
2. `inspect_document` (read): empty page, `dirty: false`, no undo steps.
3. `create_node` (edit): a 100x50 rectangle is created, `dirty: true`, history shows `Create layer`.
4. `undo`: returns `{"undone": true}`, history is empty again.

## 4. Bedrock model

The agent talks to Bedrock in `us-east-1` with the `Kwaku` IAM user (`aws sts get-caller-identity`
works). Models tested with a one-word Converse call:

| Model id | Result |
|---|---|
| `us.anthropic.claude-sonnet-4-6` | works |
| `us.anthropic.claude-sonnet-4-5-20250929-v1:0` | works |
| `us.anthropic.claude-haiku-4-5-20251001-v1:0` | works |
| `us.anthropic.claude-haiku-5-5` | works |
| `us.anthropic.claude-sonnet-5`, `-sonnet-5-5` | denied (Marketplace subscription) |
| `us.anthropic.claude-opus-4-6-v1`, `-4-7`, `-4-8`, `-5`, `-5-5` | denied (Marketplace subscription) |
| `global.anthropic.claude-sonnet-5-5` | denied (Marketplace subscription) |

Use `us.anthropic.claude-sonnet-4-6`. The denied models need `aws-marketplace:ViewSubscriptions` and
`aws-marketplace:Subscribe` on the IAM user (or an admin to subscribe once).

## 5. Web search and asset rules

A `web-search` MCP server (`duckduckgo-mcp-server`, tools `search`, `fetch_content`, `expand_link`) is
already in the global `mcp.json`. `.kiro/steering/research-and-assets.md` applies the repo's asset
rules from `AGENTS.md` to it: read and paraphrase, never download or commit third-party assets.

## 6. Fork and upstream updates

`origin` should be your fork and `upstream` should be `storytold/figcraft`:

```sh
gh repo fork storytold/figcraft --remote=false
git remote rename origin upstream
git remote add origin https://github.com/<you>/figcraft.git
```

`.kiro/scripts/auto-update.sh` fetches `upstream`, merges `upstream/main` into `main` and rebuilds
`figcraft-cli`. It never pushes and never force-merges:

- It does nothing if there is no `upstream` remote.
- It refuses if you are not on `main`, the tree is dirty, or a merge or rebase is in progress.
- A conflicting merge is aborted and the tree restored.
- Log: `.kiro/logs/auto-update.log`.
- If Kiro is running `figcraft-cli.exe`, Windows blocks the rebuild from replacing it. The merge is
  kept and the failure is logged; close the MCP server and run the build by hand.

Dry run: `bash .kiro/scripts/auto-update.sh --dry-run`.

### Global SessionStart hook

Save as `~/.kiro/hooks/figcraft-auto-update.json`:

```json
{
  "version": "v1",
  "hooks": [
    {
      "name": "FigCraft auto-update (global)",
      "trigger": "SessionStart",
      "description": "Fetches upstream (storytold/figcraft), merges if safe, rebuilds figcraft-cli. Detached; never pushes.",
      "action": {
        "type": "command",
        "command": "\"C:/Program Files/Git/bin/bash.exe\" d:/code/figcraft/.kiro/scripts/auto-update.sh",
        "timeout": 30
      }
    }
  ]
}
```
