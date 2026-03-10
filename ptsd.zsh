# ptsd - Project Terminal Switch Directory
# Lists recent Claude project directories and cd's into the selected one.
# Source this file in ~/.zshrc: source "/path/to/ptsd/ptsd.zsh"

ptsd() {
  # Run collection in a subshell; redirect stderr to suppress any xtrace/debug output
  local dir_list
  dir_list=$(
    { set +x; } 2>/dev/null
    projects_dir="$HOME/.claude/projects"
    declare -a cwds=()
    declare -a seen=()

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

  # Suppress xtrace in the parent shell for the interactive UI
  { set +x; } 2>/dev/null

  # Parse collected dirs into an array
  local -a cwds=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && cwds+=("$line")
  done <<< "$dir_list"

  if [[ ${#cwds[@]} -eq 0 ]]; then
    echo "No Claude project directories found."
    return 1
  fi

  # Parse flags: -a (alphabetical), -o (oldest first)
  local sort_mode="newest"
  local filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a) sort_mode="alpha"; shift ;;
      -o) sort_mode="oldest"; shift ;;
      -h|--help)
        echo "Usage: ptsd [-a|-o] [filter]"
        echo "  -a  Sort alphabetically by project name"
        echo "  -o  Sort oldest first (default: newest first)"
        echo "  filter  Case-insensitive substring match on path"
        return 0 ;;
      *)  filter="$1"; shift ;;
    esac
  done

  # Apply sort
  case "$sort_mode" in
    alpha)
      # Sort by project name (basename), case-insensitive
      local -a sorted=()
      while IFS=$'\t' read -r _ path; do
        [[ -n "$path" ]] && sorted+=("$path")
      done < <(for c in "${cwds[@]}"; do printf '%s\t%s\n' "${c##*/}" "$c"; done | sort -f)
      cwds=("${sorted[@]}")
      ;;
    oldest)
      # Reverse the array (it's already newest-first)
      local -a reversed=()
      local j=${#cwds[@]}
      while (( j >= 1 )); do
        reversed+=("${cwds[$j]}")
        (( j-- ))
      done
      cwds=("${reversed[@]}")
      ;;
  esac

  # Apply filter if provided
  local -a filtered=()
  if [[ -n "$filter" ]]; then
    for cwd in "${cwds[@]}"; do
      if [[ "${cwd:l}" == *"${filter:l}"* ]]; then
        filtered+=("$cwd")
      fi
    done
    cwds=("${filtered[@]}")
    if [[ ${#cwds[@]} -eq 0 ]]; then
      echo "No projects matching \"$filter\"."
      return 1
    fi
  fi

  # Display numbered list: project name bold, path very dim on same line
  echo ""
  local i=1
  for cwd in "${cwds[@]}"; do
    local name="${cwd##*/}"
    local display_path="${cwd/#$HOME/~}"
    printf "  %2d) \033[1m%s\033[0m  \033[2;37m%s\033[0m\n" "$i" "$name" "$display_path"
    (( i++ ))
  done
  echo ""

  # If only one result, auto-select it
  if [[ ${#cwds[@]} -eq 1 ]]; then
    local target="${cwds[1]}"
    echo "→ $target"
    cd "$target"
    echo -n "Launch Claude here? (y/n): "
    read -r launch
    if [[ "$launch" == "y" || "$launch" == "Y" ]]; then
      claude
    fi
    return 0
  fi

  # Read selection
  echo -n "Select project (1-${#cwds[@]}): "
  read -r selection

  if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#cwds[@]} )); then
    local target="${cwds[$selection]}"
    echo "→ $target"
    cd "$target"
    echo -n "Launch Claude here? (y/n): "
    read -r launch
    if [[ "$launch" == "y" || "$launch" == "Y" ]]; then
      claude
    fi
  else
    echo "Invalid selection"
    return 1
  fi
}
