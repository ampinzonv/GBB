get_fasta_header() {
  if [[ -t 0 && ( -z "$1" || ! -f "$1" ) ]]; then
    echo "Uso: get_fasta_header <archivo.fasta> o usar con pipe: cat archivo.fasta | get_fasta_header" >&2
    return 1
  fi

  if [[ -t 0 ]]; then
    # Entrada desde archivo como argumento
    grep '^>' "$1"
  else
    # Entrada desde pipe o redirección
    grep '^>' 
  fi
}


get_fasta_id() {
  if [[ -t 0 && ( -z "$1" || ! -f "$1" ) ]]; then
    echo "Uso: get_fasta_id <archivo.fasta> o usar con pipe: cat archivo.fasta | get_fasta_id" >&2
    return 1
  fi

  if [[ -t 0 ]]; then
    # Entrada desde archivo como argumento
    grep '^>' "$1" | cut -d ' ' -f1 | sed 's/^>//'
  else
    # Entrada desde pipe o redirección
    grep '^>' | cut -d ' ' -f1 | sed 's/^>//'
  fi
}

get_fasta_seq() {
  if [[ -t 0 && ( -z "$1" || ! -f "$1" ) ]]; then
    echo "Uso: get_fasta_seq <archivo.fasta> o usar con pipe: cat archivo.fasta | get_fasta_seq" >&2
    return 1
  fi

  if [[ -t 0 ]]; then
    grep -v '^>' "$1"
  else
    grep -v '^>'
  fi
}

get_fasta_length() {
  local fasta_file="$1"

  if [[ -z "$fasta_file" || "$fasta_file" == "-" ]]; then
    fasta_file="/dev/stdin"
  elif [[ ! -f "$fasta_file" ]]; then
    echo "Uso: get_fasta_length <archivo.fasta | ->" >&2
    return 1
  fi

  awk '
    /^>/ {
      if (id != "") {
        print id "\t" length(seq)
      }
      id = substr($1, 2)
      seq = ""
      next
    }
    {
      gsub(/[ \t\r\n]/, "", $0)
      seq = seq $0
    }
    END {
      if (id != "") {
        print id "\t" length(seq)
      }
    }
  ' "$fasta_file"
}


fastq_to_fasta() {
  if [[ -t 0 && ( -z "$1" || ! -f "$1" ) ]]; then
    echo "Uso: fastq_to_fasta <archivo.fastq> o usar con pipe: cat archivo.fastq | fastq_to_fasta" >&2
    return 1
  fi

  if [[ -t 0 ]]; then
    awk 'NR % 4 == 1 {print ">" substr($0,2)} NR % 4 == 2 {print}' "$1"
  else
    awk 'NR % 4 == 1 {print ">" substr($0,2)} NR % 4 == 2 {print}'
  fi
}

split_multiple_fasta() {
  local infile="$1"
  local outdir="$2"

  if [[ -t 0 && ( -z "$infile" || ! -f "$infile" ) ]]; then
    echo "Uso: split_multiple_fasta <archivo.fasta> [carpeta_salida]" >&2
    return 1
  fi

  # Si no hay salida especificada, usa el directorio actual
  outdir="${outdir:-.}"

  # Crear carpeta si no existe
  mkdir -p "$outdir" || {
    echo "No se pudo crear la carpeta de salida: $outdir" >&2
    return 1
  }

  awk -v outdir="$outdir" '
    /^>/ {
      if (seq) close(outfile)
      id = substr($1, 2)
      gsub(/[^a-zA-Z0-9_.-]/, "_", id)  # sanitiza
      outfile = outdir "/" id ".fasta"
      print $0 > outfile
      seq = 1
      next
    }
    {
      print $0 > outfile
    }
  ' "${infile:-/dev/stdin}"
}


fastq_stats() {
  local infile="$1"
  local filename="${infile:-STDIN}"
  local reader="cat"

  if [[ -t 0 && -z "$infile" ]]; then
    echo "Uso: fastq_stats <archivo.fastq[.gz]> o usar con pipe: cat archivo.fastq | fastq_stats -" >&2
    return 1
  fi

  if [[ -n "$infile" && "$infile" != "-" ]]; then
    if [[ ! -f "$infile" ]]; then
      echo "Error: El archivo '$infile' no existe." >&2
      return 1
    fi

    case "$infile" in
      *.gz)  reader="gzip -dc" ;;
      *.bz2) reader="bzip2 -dc" ;;
      *.xz)  reader="xz -dc" ;;
      *)     reader="cat" ;;
    esac
  else
    infile="/dev/stdin"
  fi

  $reader "$infile" | awk -v file="$filename" '
  BEGIN {
    numseqs = sumlen = minlen = maxlen = q20 = q30 = 0
    show_header = 1
    chars = " !\"#$%&'\''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
  }
  NR % 4 == 2 {
    seqlen = length($0)
    sumlen += seqlen
    numseqs++
    if (minlen == 0 || seqlen < minlen) minlen = seqlen
    if (seqlen > maxlen) maxlen = seqlen
  }
  NR % 4 == 0 {
    for (i = 1; i <= length($0); i++) {
      q = substr($0, i, 1)
      qscore = index(chars, q) - 1
      if (qscore >= 20) q20++
      if (qscore >= 30) q30++
    }
  }
  END {
    if (show_header) {
      printf "#   %-14s %-8s %-8s %-8s %-9s %-8s %-8s %-8s\n",
             "File name", "numseqs", "sumlen", "minlen", "avg_len", "maxlen", "Q20(%)", "Q30(%)"
    }
    avglen = (numseqs > 0) ? sumlen / numseqs : 0
    total_bases = sumlen
    q20pct = (total_bases > 0) ? q20 / total_bases * 100 : 0
    q30pct = (total_bases > 0) ? q30 / total_bases * 100 : 0
    printf "    %-14s %-8d %-8d %-8d %-9.1f %-8d %-8.2f %-8.2f\n",
           file, numseqs, sumlen, minlen, avglen, maxlen, q20pct, q30pct
  }
  '
}

fasta_stats() {
  local infile="$1"
  local filename="${infile:-STDIN}"

  if [[ -t 0 && ( -z "$infile" || ! -f "$infile" ) ]]; then
    echo "Uso: fasta_stats <archivo.fasta> o usar con pipe: cat archivo.fasta | fasta_stats -" >&2
    return 1
  fi

  awk -v file="$filename" '
  BEGIN {
    numseqs = sumlen = minlen = maxlen = 0
    show_header = 1
  }

  /^>/ {
    if (seq != "") {
      seqlen = length(seq)
      lengths[numseqs] = seqlen
      sumlen += seqlen
      if (minlen == 0 || seqlen < minlen) minlen = seqlen
      if (seqlen > maxlen) maxlen = seqlen
      numseqs++
    }
    seq = ""
    next
  }

  {
    gsub(/[ \t\r\n]/, "", $0)
    seq = seq $0
  }

  END {
    if (seq != "") {
      seqlen = length(seq)
      lengths[numseqs] = seqlen
      sumlen += seqlen
      if (minlen == 0 || seqlen < minlen) minlen = seqlen
      if (seqlen > maxlen) maxlen = seqlen
      numseqs++
    }

    # Calcular promedio
    avglen = (numseqs > 0) ? sumlen / numseqs : 0

    # Calcular N50
    n50 = 0
    if (numseqs > 0) {
      # Ordenar longitudes descendentes
      for (i = 0; i < numseqs - 1; i++) {
        for (j = i + 1; j < numseqs; j++) {
          if (lengths[i] < lengths[j]) {
            tmp = lengths[i]
            lengths[i] = lengths[j]
            lengths[j] = tmp
          }
        }
      }
      half = sumlen / 2
      acc = 0
      for (i = 0; i < numseqs; i++) {
        acc += lengths[i]
        if (acc >= half) {
          n50 = lengths[i]
          break
        }
      }
    }

    if (show_header) {
      printf "#   %-14s %-8s %-8s %-8s %-9s %-8s %-8s\n",
             "File name", "numseqs", "sumlen", "minlen", "avg_len", "maxlen", "N50"
    }
    printf "    %-14s %-8d %-8d %-8d %-9.1f %-8d %-8d\n",
           file, numseqs, sumlen, minlen, avglen, maxlen, n50
  }
  ' "${infile:-/dev/stdin}"
}


get_fasta_entry() {
  local fasta_file="$1"
  local query_id="$2"

  if [[ -z "$query_id" ]]; then
    echo "Uso: get_fasta_entry <archivo.fasta | -> <ID>" >&2
    return 1
  fi

  if [[ "$fasta_file" != "-" && ! -f "$fasta_file" ]]; then
    echo "Error: El archivo '$fasta_file' no existe." >&2
    return 1
  fi

  awk -v id="$query_id" '
    /^>/ {
      current_id = substr($1, 2)
      if (found) exit
      found = (current_id == id)
    }
    {
      if (found) print
    }
  ' "${fasta_file:-/dev/stdin}"
}

get_fasta_range() {
  local fasta_file="$1"
  local range_list="$2"

  if [[ -z "$range_list" ]]; then
    echo "Uso: get_fasta_range <archivo.fasta | -> <rango1-rango2,...>" >&2
    return 1
  fi

  if [[ "$fasta_file" != "-" && ! -f "$fasta_file" ]]; then
    echo "Error: El archivo '$fasta_file' no existe." >&2
    return 1
  fi

  # Validación básica de la lista de rangos
  if ! [[ "$range_list" =~ ^[0-9]+-[0-9]+(,[0-9]+-[0-9]+)*$ ]]; then
    echo "Error: Formato de rango no válido. Usa inicio-fin[,inicio-fin...]" >&2
    return 1
  fi

  awk -v ranges="$range_list" '
    function parse_ranges(s, arr,    i, r, start, end) {
      n = split(s, r, ",")
      for (i = 1; i <= n; i++) {
        split(r[i], parts, "-")
        start = parts[1]
        end = parts[2]
        if (start >= 1 && end >= start) {
          arr[i, "start"] = start
          arr[i, "end"] = end
        }
      }
      return n
    }

    BEGIN {
      id = ""
      seq = ""
      n_ranges = parse_ranges(ranges, R)
    }

    /^>/ {
      if (id != "") {
        for (i = 1; i <= n_ranges; i++) {
          start = R[i, "start"]
          end = R[i, "end"]
          subseq = substr(seq, start, end - start + 1)
          if (length(subseq) > 0) {
            print ">" id "_" start "-" end
            print subseq
          }
        }
      }
      id = substr($1, 2)
      seq = ""
      next
    }

    {
      gsub(/[ \t\r\n]/, "", $0)
      seq = seq $0
    }

    END {
      if (id != "") {
        for (i = 1; i <= n_ranges; i++) {
          start = R[i, "start"]
          end = R[i, "end"]
          subseq = substr(seq, start, end - start + 1)
          if (length(subseq) > 0) {
            print ">" id "_" start "-" end
            print subseq
          }
        }
      }
    }
  ' "${fasta_file:-/dev/stdin}"
}
