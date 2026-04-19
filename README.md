# notes.nvim

> README is AI generated. This is a vibe-coded personal tool — use at your own risk.

A simple, personal Obsidian-replacement for Neovim. Vibe-coded for my own use.

## Features

- `[[Wikilinks]]` — follow links with `gf`, auto-create missing notes with template picker
- `[[` completion — blink.cmp source shows all note titles, inserts `Title]]`
- New notes — title prompt → telescope template picker → variables auto-filled (`{{date}}`, `{{title}}`, `{{date:dddd, MMMM D, YYYY}}`)
- Daily notes — one keymap opens/creates today's note from a fixed template
- Backlinks — telescope shows every note that links to the current one
- Rename + relink — rename a note and every `[[link]]` to it updates automatically

## Requirements

- [blink.cmp](https://github.com/saghen/blink.cmp)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

```lua
-- lazy.nvim (local)
{
    dir = "~/path/to/notes.nvim",
    name = "notes.nvim",
    lazy = false,
    config = function()
        require("notes").setup()
    end,
}

-- lazy.nvim (from GitHub)
{
    "Ekansh38/notes.nvim",
    lazy = false,
    config = function()
        require("notes").setup()
    end,
}
```

## Configuration

```lua
require("notes").setup({
    vault_path     = vim.fn.expand("~/Documents/MyVault"),
    templates_dir  = "Templates",
    daily_dir      = "Daily",
    daily_template = "Daily Note Template.md",
})
```

## Keymaps (vault markdown files only)

| Key | Action |
|-----|--------|
| `gf` | Follow `[[wikilink]]` (creates note if missing) |
| `<leader>on` | New note |
| `<leader>od` | Open / create today's daily note |
| `<leader>ob` | Show backlinks in telescope |
| `<leader>or` | Rename note + update all links |

## blink.cmp source

Add to your blink config:

```lua
sources = {
    per_filetype = {
        markdown = { "notes", "lsp", "path", "snippets", "buffer" },
    },
    providers = {
        notes = { name = "Notes", module = "notes.blink_source" },
    },
},
```

## Template variables

| Variable | Output |
|----------|--------|
| `{{date}}` | `2026-04-19` |
| `{{title}}` | Note filename (without `.md`) |
| `{{date:dddd, MMMM D, YYYY}}` | `Sunday, April 19, 2026` |
