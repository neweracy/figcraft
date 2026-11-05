---
inclusion: always
---

# Research and asset rules (FigCraft)

This repo forbids third-party product assets. `AGENTS.md` is the authority; this file applies it to
agents that have web-search tools.

## Web search is for reading, not for fetching assets

- Use the `web-search` MCP server (`search`, `fetch_content`, `expand_link`) to read public
  documentation and to check facts. Summarise what you learn in your own words.
- Never download, save, trace, redraw, embed or commit any icon, image, illustration, cursor, logo,
  template, UI kit, preset library, font file or screenshot found on the web. This covers Figma,
  Adobe, Avid, Autodesk and every other source, and "lookalike" redraws of their icons.
- Never read, disassemble or copy anything inside the incumbent app's bundle or network traffic.
  Behaviour comes from public documentation and black-box observation with synthetic documents.
- Never copy GPL or AGPL code.
- Do not paste large passages of a page into the repo. Paraphrase and link the source.

## Compose from built-in tools

- Build designs, test content and demos with FigCraft's own commands (`create_node`, `set_properties`,
  `run_command`, `batch`). Draw UI icons in code (`crates/ui-egui/src/icons.rs`) as new work.
- Fonts come from `storytold/craft-fonts` through `CRAFT_FONTS_DIR`, never from this repo.
- Test and demo content must be synthetic or public domain.

## If an asset is really needed

- It must be original work, OSI open source, CC0 or public domain, or Creative Commons that allows
  redistribution.
- Add a row to `ATTRIBUTION.md` (path, author, source, licence, notes). `cargo xtask assets` fails on
  any unlisted file under `assets/`, `docs/brand/` or `docs/images/`.
- If the provenance is unclear, do not add it. Ask the user.

## File access for the MCP server

- Prefer `figcraft-cli mcp --automation-read-root DIR --automation-write-root DIR` so an agent can
  only touch the folders you name. Use `export` without `path` when you only need the bytes.
