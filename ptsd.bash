# ptsd - Project Terminal Switch Directory (bash)
# Lists recent Claude project directories and cd's into the selected one.
# Source this file in ~/.bashrc: source "/path/to/ptsd/ptsd.bash"

ptsd() {
  # Run collection in a subshell; redirect stderr to suppress any xtrace/debug output
  local dir_list
  dir_list=$(
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
      for s in "${seen[@]}"; do
        [[ "$s" == "$cwd" ]] && dup=1 && break
      done
      (( dup )) && continue

      seen+=("$cwd")
      cwds+=("$cwd")
    done < <(ls -dt "$projects_dir"/*/ 2>/dev/null)

    for cwd in "${cwds[@]}"; do
      printf '%s\n' "$cwd"
    done
  ) 2>/dev/null

  { set +x; } 2>/dev/null

  # Parse collected dirs into an array (bash arrays are 0-indexed)
  local -a cwds=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && cwds+=("$line")
  done <<< "$dir_list"

  if [[ ${#cwds[@]} -eq 0 ]]; then
    echo "No Claude project directories found."
    return 1
  fi

  # Display numbered list
  echo ""
  local i
  for (( i=0; i<${#cwds[@]}; i++ )); do
    printf "  %2d) %s\n" "$((i+1))" "${cwds[$i]}"
  done
  echo ""

  # Read selection
  echo -n "Select project (1-${#cwds[@]}): "
  read -r selection

  if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#cwds[@]} )); then
    local target="${cwds[$((selection-1))]}"
    echo "→ $target"
    cd "$target"
  else
    echo "Invalid selection"
    return 1
  fi
}
