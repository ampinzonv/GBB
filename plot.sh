#
# This script contains functions for generating visualizations,
# including histograms, heatmaps, and other graphical representations
# of Bioinformatics data using tools like gnuplot.
#
# Created by: 
# Andres M. Pinzón [ampinzonv@unal.edu.co]
# Institute for Genetics - National University of Colombia
#

bb_plot_check_dependencies() {
  if ! command -v gnuplot >/dev/null 2>&1; then
    echo "❌ Error: gnuplot no está instalado o no está en el PATH." >&2
    return 1
  fi
  return 0
}

#=========================

bb_plot_blast_hits_txt() {
  local infile="$1"
  local top_hits_number=""
  local line_width=50

  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --top_hits_number)
        top_hits_number="$2"
        shift 2
        ;;
      *)
        echo "❌ Opción no reconocida: $1" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$infile" || ! -f "$infile" ]]; then
    echo "Uso: plot_blast_hits <archivo_blast_outfmt6_con_qlen_slen> [--top_hits_number N]" >&2
    return 1
  fi

  local ncols
  ncols=$(awk 'NF {print NF; exit}' "$infile")
  if (( ncols < 14 )); then
    echo "❌ Error: se requieren al menos 14 columnas en el archivo (incluyendo qlen y slen)." >&2
    return 1
  fi

  local tmp_best="__blast_best.tsv"

  if [[ -n "$top_hits_number" ]]; then
    blast_best_hit "$infile" | sort -k12,12nr | head -n "$top_hits_number" > "$tmp_best"
  else
    blast_best_hit "$infile" | sort -k12,12nr > "$tmp_best"
  fi

  echo "🔍 Visualización de los HSPs (modo texto plano):"
  echo

  awk -v width="$line_width" '
  {
    qid = $1
    sid = $2
    sstart = $9 + 0
    send = $10 + 0
    slen = $14 + 0

    if (sstart > send) { tmp = sstart; sstart = send; send = tmp }

    hsp_len = send - sstart + 1
    coverage = (slen > 0) ? (hsp_len / slen) * 100 : 0

    bar = ""
    for (i = 1; i <= width; i++) bar = bar "-"

    hsp_start_scaled = int((sstart / slen) * width)
    hsp_end_scaled   = int((send / slen) * width)

    if (hsp_start_scaled < 0) hsp_start_scaled = 0
    if (hsp_end_scaled >= width) hsp_end_scaled = width - 1

    prefix = substr(bar, 1, hsp_start_scaled)
    middle = ""
    for (i = hsp_start_scaled + 1; i <= hsp_end_scaled + 1; i++) middle = middle "="
    suffix = substr(bar, hsp_end_scaled + 2)
    bar = prefix middle suffix

    printf "%-15s %-25s %s  %d (%d-%d) [%.1f%%]\n", qid, sid, bar, slen, sstart, send, coverage
  }
  ' "$tmp_best"

  rm -f "$tmp_best"
}


#=========================
bb_plot_histogram_txt() {
  local infile=""
  local max_width=50
  local char="="

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --in) infile="$2"; shift 2 ;;
      --char) char="$2"; shift 2 ;;
      *)
        echo "Uso: ascii_plot_awk [--in archivo] [--char símbolo] < input" >&2
        return 1 ;;
    esac
  done

  local data
  if [[ -n "$infile" ]]; then
    [[ ! -f "$infile" ]] && { echo "❌ No se encuentra $infile" >&2; return 1; }
    data=$(cat "$infile")
  else
    if [[ -t 0 ]]; then
      echo "❌ No se proporcionó archivo ni datos por STDIN." >&2
      return 1
    fi
    data=$(cat)
  fi

  echo "$data" | awk -v width="$max_width" -v sym="$char" '
  {
    label = $1
    value = $2 + 0
    labels[NR] = label
    values[NR] = value
    if (value > maxval) maxval = value
    count++
  }
  END {
    # Ordenar por valores descendentes
    for (i = 1; i <= count; i++) idx[i] = i
    for (i = 1; i <= count - 1; i++) {
      for (j = i + 1; j <= count; j++) {
        if (values[idx[j]] > values[idx[i]]) {
          tmp = idx[i]; idx[i] = idx[j]; idx[j] = tmp
        }
      }
    }

    printf "📊 Distribución (máximo: %d)\n\n", maxval
    for (k = 1; k <= count; k++) {
      i = idx[k]
      scaled = int(values[i] / maxval * width)
      bar = ""
      for (j = 0; j < scaled; j++) bar = bar sym
      printf "%-10s | %s %3d\n", labels[i], bar, values[i]
    }
  }'
}


