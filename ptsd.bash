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

  # Suppress xtrace in the parent shell for the interactive UI
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

  # Parse flags: -a (alphabetical), -o (oldest first), -f (folder), -n (new project)
  local sort_mode="newest"
  local filter=""
  local new_project=""
  local create_new=0
  local folder_mode=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--alpha) sort_mode="alpha"; shift ;;
      -o|--oldest) sort_mode="oldest"; shift ;;
      -f|--folder) folder_mode=1; shift ;;
      -n|--new)
        create_new=1
        shift
        # Consume next arg as project name if it doesn't look like a flag
        if [[ $# -gt 0 && "$1" != -* ]]; then
          new_project="$1"
          shift
        fi
        ;;
      -h|--help)
        echo "Usage: ptsd [-a|-o] [-f] [-n [name]] [filter]"
        echo "  -a          Sort alphabetically by project name (--alpha)"
        echo "  -o          Sort oldest first (--oldest)"
        echo "  -f          cd to parent folder instead of project dir (--folder)"
        echo "  -n [name]   Create a new project folder (--new)"
        echo "  filter      Case-insensitive substring match on path"
        return 0 ;;
      *)  filter="$1"; shift ;;
    esac
  done

  # Handle new project creation
  if (( create_new )); then
    # Collect unique base paths (parent dirs) from existing projects
    local -a base_paths=()
    local -a base_seen=()
    for cwd in "${cwds[@]}"; do
      local parent="${cwd%/*}"
      local already=0
      for bs in "${base_seen[@]}"; do
        [[ "$bs" == "$parent" ]] && already=1 && break
      done
      (( already )) && continue
      base_seen+=("$parent")
      base_paths+=("$parent")
    done

    if [[ ${#base_paths[@]} -eq 0 ]]; then
      echo "No base paths found from existing projects."
      return 1
    fi

    # Let user choose base path
    local chosen_base=""
    if [[ ${#base_paths[@]} -eq 1 ]]; then
      chosen_base="${base_paths[0]}"
      echo "Base path: $chosen_base"
    else
      echo ""
      echo "Choose a base path:"
      local bi=1
      for bp in "${base_paths[@]}"; do
        local display_bp="${bp/#$HOME/\~}"
        printf "  %2d) %s\n" "$bi" "$display_bp"
        (( bi++ ))
      done
      echo ""
      echo -n "Select base path (1-${#base_paths[@]}): "
      read -r bp_selection
      if [[ "$bp_selection" =~ ^[0-9]+$ ]] && (( bp_selection >= 1 && bp_selection <= ${#base_paths[@]} )); then
        chosen_base="${base_paths[$((bp_selection-1))]}"
      else
        echo "Invalid selection."
        return 1
      fi
    fi

    # Get project name if not provided
    if [[ -z "$new_project" ]]; then
      echo -n "Project name: "
      read -r new_project
      if [[ -z "$new_project" ]]; then
        echo "No project name provided."
        return 1
      fi
    fi

    local new_dir="$chosen_base/$new_project"

    # Check if it already exists
    if [[ -e "$new_dir" ]]; then
      echo "\"$new_dir\" already exists."
      echo -n "Switch to it? (Y/n): "
      read -r switch_to
      if [[ "$switch_to" == "n" || "$switch_to" == "N" ]]; then
        return 1
      fi
      cd "$new_dir"
    else
      mkdir -p "$new_dir"
      echo "Created: $new_dir"
      cd "$new_dir"
    fi
    echo -n "Launch Claude here? (Y/n): "
    read -r launch
    if [[ "$launch" != "n" && "$launch" != "N" ]]; then
      claude
    fi
    return 0
  fi

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
      local j=$(( ${#cwds[@]} - 1 ))
      while (( j >= 0 )); do
        reversed+=("${cwds[$j]}")
        (( j-- ))
      done
      cwds=("${reversed[@]}")
      ;;
  esac

  # Apply filter if provided
  local -a filtered=()
  if [[ -n "$filter" ]]; then
    local lower_filter="${filter,,}"
    for cwd in "${cwds[@]}"; do
      if [[ "${cwd,,}" == *"$lower_filter"* ]]; then
        filtered+=("$cwd")
      fi
    done
    cwds=("${filtered[@]}")
    if [[ ${#cwds[@]} -eq 0 ]]; then
      echo "No projects matching \"$filter\"."
      return 1
    fi
  fi

  # Display numbered list: project name bold, path dim on same line
  echo ""
  printf "   0) \033[1;36mhelp menu\033[0m\n"
  local i
  for (( i=0; i<${#cwds[@]}; i++ )); do
    local name="${cwds[$i]##*/}"
    local display_path="${cwds[$i]/#$HOME/\~}"
    printf "  %2d) \033[1m%s\033[0m  \033[2;37m%s\033[0m\n" "$((i+1))" "$name" "$display_path"
  done
  echo ""

  # Read selection
  echo -n "Select project (0-${#cwds[@]}): "
  read -r selection

  if [[ "$selection" == "0" ]]; then
    ptsd --help
    return 0
  elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#cwds[@]} )); then
    local target="${cwds[$((selection-1))]}"
    if (( folder_mode )); then
      target="${target%/*}"
    fi
    echo "→ $target"
    cd "$target"
    echo -n "Launch Claude here? (Y/n): "
    read -r launch
    if [[ "$launch" != "n" && "$launch" != "N" ]]; then
      claude
    fi
  else
    echo "Invalid selection"
    return 1
  fi
}
