plot_fasta_lengths() {
  local format="png"
  local outfile="fasta_lengths"
  local mode="auto"

  # Leer argumentos
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        format="$2"
        shift 2
        ;;
      --output)
        outfile="$2"
        shift 2
        ;;
      --mode)
        mode="$2"
        shift 2
        ;;
      *)
        echo "Uso: get_fasta_length archivo.fasta | plot_fasta_lengths [--format png|pdf|svg] [--mode barras|histograma|boxplot|cdf|auto] [--output nombre]" >&2
        return 1
        ;;
    esac
  done

  case "$format" in
    png|pdf|svg) ;;
    *) echo "Formato no soportado: $format. Usa png, pdf o svg." >&2; return 1 ;;
  esac

  case "$mode" in
    auto|barras|histograma|boxplot|cdf) ;;
    *) echo "Modo no válido: $mode. Usa auto, barras, histograma, boxplot o cdf." >&2; return 1 ;;
  esac

  local tmpdata
  tmpdata=$(mktemp)
  trap "rm -f \"$tmpdata\"" EXIT

  cat > "$tmpdata"

  if [[ ! -s "$tmpdata" ]]; then
    echo "Error: no se recibieron datos de entrada." >&2
    return 1
  fi

  local numseqs
  numseqs=$(wc -l < "$tmpdata")
  local outfile_full="${outfile}.${format}"

  # Decidir modo automático si no fue especificado
  if [[ "$mode" == "auto" ]]; then
    if [[ "$numseqs" -le 100 ]]; then
      mode="barras"
    else
      mode="histograma"
    fi
  fi

  # Preparar archivo temporal solo con longitudes si se necesita (boxplot, cdf)
  local tmpvalues=""
  if [[ "$mode" == "boxplot" || "$mode" == "cdf" ]]; then
    tmpvalues=$(mktemp)
    awk '{print $2}' "$tmpdata" > "$tmpvalues"
  fi

  # Ejecutar gnuplot según modo
  case "$mode" in
    barras)
      gnuplot <<EOF
set terminal ${format}cairo size 1000,600 enhanced font 'Arial,10'
set output "$outfile_full"
set title "Longitud de secuencias en archivo FASTA"
set xlabel "ID de secuencia"
set ylabel "Longitud (bp)"
set style data histogram
set style histogram clustered gap 1
set boxwidth 0.8
set style fill solid border -1
set xtics rotate by -45 font ",8"
set grid ytics
plot "$tmpdata" using 2:xtic(1) title "Longitud"
EOF
      ;;
    histograma)
      gnuplot <<EOF
set terminal ${format}cairo size 1000,600 enhanced font 'Arial,10'
set output "$outfile_full"
set title "Distribución de longitudes de secuencia (n=${numseqs})"
set xlabel "Longitud (bp)"
set ylabel "Frecuencia"
binwidth=50
bin(x,width)=width*floor(x/width)
set boxwidth binwidth
set style fill solid
set grid
plot "$tmpdata" using (bin(\$2,binwidth)):(1.0) smooth freq with boxes title "Frecuencia"
EOF
      ;;
    boxplot)
      gnuplot <<EOF
set terminal ${format}cairo size 800,500 enhanced font 'Arial,10'
set output "$outfile_full"
set style data boxplot
set style boxplot outliers pointtype 7
set boxwidth 0.5
set style fill solid
set title "Boxplot de longitudes de secuencia"
set ylabel "Longitud (bp)"
plot "$tmpvalues" using (1):1 notitle
EOF
      ;;
    cdf)
      local tmpcdf=$(mktemp)
      sort -n "$tmpvalues" | awk -v n="$numseqs" '{print $1 "\t" (++i)/n}' > "$tmpcdf"
      gnuplot <<EOF
set terminal ${format}cairo size 800,500 enhanced font 'Arial,10'
set output "$outfile_full"
set title "Función de distribución acumulada (CDF)"
set xlabel "Longitud (bp)"
set ylabel "Fracción acumulada"
set grid
plot "$tmpcdf" using 1:2 with lines title "CDF"
EOF
      rm -f "$tmpcdf"
      ;;
  esac

  [[ -n "$tmpvalues" ]] && rm -f "$tmpvalues"

  echo "Gráfico generado: $outfile_full"
}
