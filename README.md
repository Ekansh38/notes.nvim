# notes.nvim

Personal Obsidian replacement for Neovim.

## Requirements

- [blink.cmp](https://github.com/saghen/blink.cmp)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `curl` (for smart URL paste)

## Installation

```lua
-- lazy.nvim (local)
{
    dir  = "~/path/to/notes.nvim",
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

All options with their defaults:

```lua
require("notes").setup({
    vault_path      = vim.fn.expand("~/Documents/MyVault"),
    templates_dir   = "Templates",    -- relative to vault_path
    daily_dir       = "Daily",        -- relative to vault_path
    daily_template  = "Daily Note Template.md",
    git_auto_commit = false,          -- stage + commit on exit
    git_auto_push   = false,          -- push on exit (detached, no delay)
})
```

## Keymaps

### Global (any buffer)

| Key | Action |
|-----|--------|
| `<leader>od` | Open / create today's daily note |

### Vault markdown files only

| Key | Mode | Action |
|-----|------|--------|
| `gf` | n | Follow `[[wikilink]]` (creates note if missing) |
| `K` | n | Preview linked note in a floating window |
| `<leader>on` | n | New note (title prompt, template picker) |
| `<leader>ob` | n | Backlinks (all notes linking to this one) |
| `<leader>or` | n | Rename note and update every `[[link]]` to it |
| `<leader>ot` | n | Tag search (browse tags, preview notes) |
| `<leader>oo` | n | Orphan notes (notes with no inbound links) |
| `<leader>oi` | n | Inject template into current note at cursor |
| `<leader>oh` | n | Heading outline (jump to any heading) |
| `<leader>os` | n | Vault stats floating window |
| `<leader>op` | n | Paste clipboard URL as `[Title](url)` markdown link |
| `[d` | n | Previous daily note |
| `]d` | n | Next daily note (creates next day if at the end) |

## Commands

| Command | Action |
|---------|--------|
| `:NotesNew` | Create a new note |
| `:NotesDaily` | Open today's daily note |
| `:NotesBacklinks` | Show backlinks for current note |
| `:NotesRename` | Rename current note and relink |
| `:NotesTagSearch` | Browse tags |
| `:NotesOrphans` | Show orphan notes |
| `:NotesInject` | Inject a template into current note |
| `:NotesStats` | Show vault statistics |
| `:NotesGraph` | Open vault graph in browser |
| `:NotesGraphStop` | Stop the graph server |

## Completion (blink.cmp)

Two custom sources are provided:

```lua
sources = {
    per_filetype = {
        markdown = { "vault", "tags", "lsp", "path", "snippets", "buffer" },
    },
    providers = {
        vault = { name = "Notes", module = "notes.blink_source" },
        tags  = { name = "Tags",  module = "notes.tag_source" },
    },
},
```

| Trigger | Completes |
|---------|-----------|
| `[[` | Note titles (pinned notes shown first) |
| `[[Note#` | Headings inside that note |
| `#word` | Tags (substring match) |
| `  - ` under `tags:` in YAML frontmatter | Tags (no `#` needed) |

Standard sources (LSP, buffer, snippets, path) are automatically suppressed inside `[[` and `#tag` contexts so only vault sources show.

## Features

### Wikilinks
Type `[[` to get note title completion. `gf` follows the link under the cursor; if the note doesn't exist it opens the template picker to create it. `K` shows a floating preview without navigating.

### Heading links
Type `[[Note Title#` to complete headings from that specific note, enabling `[[How slices work in Go#What is a slice?]]`-style links.

### Tags
- Body: `#tagname` -> substring-fuzzy autocomplete
- YAML frontmatter: list items under `tags:` autocomplete without needing `#`
- `<leader>ot` opens a tag browser with note counts and previews

### Daily notes
`<leader>od` opens today's note, creating it from your daily template if it doesn't exist. Navigate between days with `[d` / `]d`. Pressing `]d` on the most recent daily note creates the next calendar day's note with the correct date in all template tokens.

### Smart URL paste
`<leader>op` reads your clipboard. If it's a URL, it fetches the page `<title>` via `curl` and inserts `[Page Title](https://...)`. Falls back to normal paste if the clipboard isn't a URL.

### Note pinning
Add `pinned: true` to a note's YAML frontmatter. Pinned notes always appear at the top of `[[` completion, labeled `pinned`.

### Vault stats
`<leader>os` opens a floating window showing: note count, tag count and uses, orphan count, most-linked note, and last-edited note.

### Graph view
`<leader>og` spawns a local Python server and opens an interactive D3 force graph in your browser. Node positions persist between sessions. Click a node to preview the note, double-click to open it in Neovim.

### Word count for lualine
```lua
-- In your lualine config:
{
    function() return require("notes").word_count() end,
    cond = function()
        return vim.bo.filetype == "markdown"
    end,
}
```
Returns e.g. `"312 words"`, empty string outside vault files.

### Git auto-commit
```lua
require("notes").setup({
    git_auto_commit = true,  -- git add -A + commit on exit
    git_auto_push   = true,  -- push in detached process (no delay on exit)
})
```
One commit per session with timestamp message. Push runs in the background after Neovim exits.

### Conceal and highlighting
Extmark-based concealment:
- `[[Title]]` displays as `Title`
- `[[Dead link]]` shown in warning color
- `[text](url)` displays as `text` with a trailing icon
- `` `code` `` styled inline code
- `==highlight==` styled like `Visual`
- `>[!note]` callout blocks with icons and colored backgrounds
- Code block backgrounds (full-width, theme-aware)
- YAML frontmatter `---` delimiters styled as `Comment`

All highlight groups link to standard theme groups so your colorscheme controls the look automatically.

## Template variables

| Variable | Output |
|----------|--------|
| `{{title}}` | Note filename without `.md` |
| `{{date}}` | `2026-04-20` |
| `{{date:dddd, MMMM D, YYYY}}` | `Sunday, April 20, 2026` |
| `{{date:MMMM D, YYYY}}` | `April 20, 2026` |
| `{{date:D MMMM YYYY}}` | `20 April 2026` |

Tokens: `YYYY` year, `MMMM` month name, `MMM` short month, `MM` month number, `D` day, `DD` zero-padded day, `dddd` weekday name, `ddd` short weekday.

When the note title is a date (e.g. `2026-04-22`), all date tokens resolve to that date rather than today.
