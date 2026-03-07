# ptsd — Project Terminal Switcher for Claude Code Directories

A zsh function that lists your recent [Claude Code](https://claude.ai/code) project directories and lets you jump into one by typing a number.

## How it works

Claude Code stores session data in `~/.claude/projects/`. Each project directory contains JSONL files with the working directory (`cwd`) of each session. `ptsd` reads these, deduplicates by path, sorts by most recently used, and presents a numbered list.

## Installation

1. Clone or download `ptsd.zsh`
2. Add to your `~/.zshrc`:

```zsh
source "/path/to/ptsd/ptsd.zsh"
```

3. Open a new terminal (or `source ~/.zshrc`)

**Requirements:** `jq` must be installed (`brew install jq`)

## Usage

```
$ ptsd

   1) /Users/you/projects/my-app
   2) /Users/you/projects/another-project
   3) /Users/you/projects/old-project

Select project (1-3): 2
→ /Users/you/projects/another-project
```

## Claude Code Skill

You can also use `ptsd` as a Claude Code slash command. Copy `ptsd.md` to `~/.claude/commands/ptsd.md` and use `/ptsd` inside any Claude Code session.

## License

MIT
