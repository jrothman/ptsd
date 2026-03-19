# ptsd — Project Terminal Switcher for Claude Code Directories

A shell function that lists your recent [Claude Code](https://claude.ai/code) project directories and lets you jump into one by typing a number.

## Usage

```
$ ptsd

   0) help menu
   1) my-app           ~/projects/my-app
   2) another-project   ~/projects/another-project
   3) old-project       ~/projects/old-project

Select project (0-3): 2
→ /Users/you/projects/another-project
Launch Claude here? (Y/n):
```

Project names are shown in **bold** with paths dimmed beside them. If only one project matches, it's auto-selected.

### Options

```
ptsd              # List projects, newest first
ptsd -a           # Sort alphabetically by project name
ptsd -o           # Sort oldest first
ptsd myapp        # Filter by substring (case-insensitive)
ptsd -a myapp     # Combine sort + filter
ptsd -n           # Create a new project folder
ptsd -n myapp     # Create a new project folder named "myapp"
```

## Installation

### zsh (macOS / Linux)

**Requirements:** `jq` (`brew install jq` or `apt install jq`)

1. Clone or download `ptsd.zsh`
2. Add to your `~/.zshrc`:

```zsh
source "/path/to/ptsd/ptsd.zsh"
```

3. Open a new terminal (or `source ~/.zshrc`)

### bash (macOS / Linux / Git Bash / WSL) ⚠️ untested

**Requirements:** `jq` (`brew install jq`, `apt install jq`, or download from [jqlang.github.io](https://jqlang.github.io/jq/))

1. Clone or download `ptsd.bash`
2. Add to your `~/.bashrc`:

```bash
source "/path/to/ptsd/ptsd.bash"
```

3. Open a new terminal (or `source ~/.bashrc`)

### PowerShell (Windows) ⚠️ untested

No external dependencies — uses PowerShell's built-in `ConvertFrom-Json`.

1. Clone or download `ptsd.ps1`
2. Add to your PowerShell profile (`$PROFILE`):

```powershell
. "C:\path\to\ptsd\ptsd.ps1"
```

3. Open a new terminal (or `. $PROFILE`)

> If you get an execution policy error, run:
> `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## How it works

Claude Code stores session data in `~/.claude/projects/`. Each project directory contains JSONL files with the working directory (`cwd`) of each session. `ptsd` reads these, deduplicates by path, sorts by most recently used, and presents a numbered list.

## Claude Code Skill

You can also use `ptsd` as a Claude Code slash command. Copy `ptsd.md` to `~/.claude/commands/ptsd.md` and use `/ptsd` inside any Claude Code session.

## License

MIT
