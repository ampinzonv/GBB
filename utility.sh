get_list() {
  local show_freq=0
  local infile="$1"

  if [[ "$1" == "--frequency" ]]; then
    show_freq=1
    infile="$2"
  fi

  if [[ -z "$infile" || "$infile" == "-" ]]; then
    infile="/dev/stdin"
  elif [[ ! -f "$infile" ]]; then
    echo "Uso: get_list [--frequency] <archivo | ->" >&2
    return 1
  fi

  if [[ "$show_freq" -eq 0 ]]; then
    awk 'NF' "$infile" | sort | uniq
  else
    awk 'NF' "$infile" | sort | uniq -c | awk '
      { count[$2] = $1; total += $1; keys[NR] = $2 }
      END {
        for (i = 1; i <= length(keys); i++) {
          val = keys[i]
          freq = count[val]
          pct = (freq / total) * 100
          printf "%s\t%d\t%.0f\n", val, freq, pct
        }
      }
    '
  fi
}
