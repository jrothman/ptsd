---
name: ptsd
description: List recent Claude project directories and navigate to one. Use when the user wants to switch to a recent project, open a previous project directory, or see a list of recently used Claude projects.
allowed-tools:
  - Bash
---

List recent Claude project directories sorted by most recently used, display them numbered, ask the user to pick one, then switch to it.

## Steps

1. Collect recent project directories with this Bash command:

```bash
{ set +x; } 2>/dev/null
projects_dir="$HOME/.claude/projects"
cwds=()
seen=()
while IFS= read -r project_dir; do
  [[ -d "$project_dir" ]] || continue
  newest_file=$(ls -t "$project_dir"/ 2>/dev/null | grep '\.jsonl$' | head -1)
  [[ -z "$newest_file" ]] && continue
  cwd=$(grep -m1 '"cwd"' "$project_dir/$newest_file" 2>/dev/null | jq -r '.cwd // empty' 2>/dev/null)
  [[ -z "$cwd" ]] && continue
  [[ -d "$cwd" ]] || continue
  dup=0
  for s in "${seen[@]}"; do [[ "$s" == "$cwd" ]] && dup=1 && break; done
  (( dup )) && continue
  seen+=("$cwd")
  cwds+=("$cwd")
done < <(ls -dt "$projects_dir"/*/ 2>/dev/null)
i=1
for cwd in "${cwds[@]}"; do
  printf '%d|%s\n' "$i" "$cwd"
  ((i++))
done
```

2. Display the list clearly, e.g.:
```
  1) /Users/you/projects/foo
  2) /Users/you/projects/bar
```

3. Ask the user: "Which project? (enter a number)"

4. Print the selected path and a ready-to-run command to open a new Claude session there:

```
→ /path/to/project

Run in your terminal:
  cd "/path/to/project" && claude
```

Note: Claude cannot launch a nested session from within a skill, so the command must be run in the terminal directly.
