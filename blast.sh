#
# This script contains functions to create BLAST databases,
# run BLAST searches, and process BLAST results, including
# summaries and best-hit extraction.
#
# Created by: 
# Andres M. Pinzón [ampinzonv@unal.edu.co]
# Institute for Genetics - National University of Colombia
#


bb_create_blast_db() {
    # Inicializar variables por defecto
    local in=""
    local outdir="."
    local db_name=""
    local title=""
    local dry_run="false"

    # Parseo de argumentos tipo GNU-style
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --in)        in="$2"; shift 2 ;;
            --outdir)    outdir="$2"; shift 2 ;;
            --db_name)   db_name="$2"; shift 2 ;;
            --title)     title="$2"; shift 2 ;;
            --dry_run)   dry_run="true"; shift ;;
            --help|-h)
                echo "Uso: create_blast_db --in archivo.fasta [--outdir dir] [--db_name nombre] [--title titulo] [--dry_run]"
                return 0
                ;;
            *)
                echo "Error: opción desconocida '$1'" >&2
                return 1
                ;;
        esac
    done

    # Validación de entrada
    if [[ -z "$in" ]]; then
        echo "Error: debes proporcionar --in archivo.fasta" >&2
        return 1
    fi

    if [[ ! -f "$in" ]]; then
        echo "Error: archivo '$in' no encontrado." >&2
        return 1
    fi

    # Verifica que makeblastdb esté disponible
    if ! command -v makeblastdb &> /dev/null; then
        echo "Error: 'makeblastdb' no está en el PATH." >&2
        return 1
    fi

    # Crea el directorio de salida si no existe
    if [[ ! -d "$outdir" ]]; then
        mkdir -p "$outdir" || {
            echo "Error: no se pudo crear el directorio '$outdir'" >&2
            return 1
        }
    fi

    # Nombre base del archivo sin extensión
    local base_name
    base_name=$(basename "$in")
    base_name="${base_name%%.*}"

    # Defaults basados en el nombre base
    db_name="${db_name:-$base_name}"
    title="${title:-$base_name}"

    # Detectar tipo de secuencia
    local db_type
    db_type=$(guess_sequence_type "$in")

    if [[ "$db_type" == "unknown" ]]; then
        echo "Error: no se pudo determinar si el archivo es nucleótido o proteína." >&2
        return 1
    fi

    # Construir comando makeblastdb
    local full_outpath="${outdir%/}/$db_name"
    local cmd="makeblastdb -in \"$in\" -dbtype $db_type -out \"$full_outpath\" -title \"$title\" -parse_seqids"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Comando que se ejecutaría:"
        echo "$cmd"
    else
        echo "[INFO] Ejecutando:"
        echo "$cmd"
        eval "$cmd" || {
            echo "Error: Falló la ejecución de makeblastdb." >&2
            return 1
        }
        echo "[OK] Base de datos BLAST creada en: $full_outpath"
    fi
}

bb_run_blast() {
  local query=""
  local db=""
  local blast_type=""
  local format="6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen"
  local out=""

  # Parseo de argumentos
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --query) query="$2"; shift 2 ;;
      --db) db="$2"; shift 2 ;;
      --blast_type) blast_type="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      *) echo "Opción desconocida: $1" >&2; return 1 ;;
    esac
  done

  # Validaciones básicas
  if [[ -z "$query" || -z "$db" || -z "$blast_type" ]]; then
    echo "Uso: run_blast --query archivo.fasta --db base --blast_type blastn|blastp|...  --out archivo_o_directorio]" >&2
    return 1
  fi

  if [[ ! -f "$query" ]]; then
    echo "❌ Error: archivo de query '$query' no encontrado." >&2
    return 1
  fi

  if ! command -v "$blast_type" &>/dev/null; then
    echo "❌ Error: $blast_type no está instalado o no está en el PATH." >&2
    return 1
  fi

  # Detectar tipo de query
  local query_type
  query_type=$(guess_sequence_type "$query")
  echo "🔍 Tipo de query detectado: $query_type"

  # Detectar tipo de base de datos
  local db_type
  db_type=$(guess_db_type "$db")
  echo "🔍 Tipo de base de datos detectado: $db_type"

  if [[ "$query_type" == "unknown" || "$db_type" == "unknown" ]]; then
    echo "❌ Error: No se pudo determinar el tipo de query o base de datos." >&2
    return 1
  fi

  # Validar combinaciones permitidas
  case "$blast_type" in
    blastn)
      [[ "$query_type" == "nucl" && "$db_type" == "nucl" ]] || {
        echo "❌ Error: blastn requiere query y base de datos de nucleótidos." >&2
        return 1
      }
      ;;
    blastp)
      [[ "$query_type" == "prot" && "$db_type" == "prot" ]] || {
        echo "❌ Error: blastp requiere query y base de datos de proteínas." >&2
        return 1
      }
      ;;
    blastx)
      [[ "$query_type" == "nucl" && "$db_type" == "prot" ]] || {
        echo "❌ Error: blastx requiere query nucleotídico y base de datos de proteínas." >&2
        return 1
      }
      ;;
    tblastn)
      [[ "$query_type" == "prot" && "$db_type" == "nucl" ]] || {
        echo "❌ Error: tblastn requiere query de proteína y base de datos nucleotídica." >&2
        return 1
      }
      ;;
    tblastx)
      [[ "$query_type" == "nucl" && "$db_type" == "nucl" ]] || {
        echo "❌ Error: tblastx requiere query y base de datos de nucleótidos." >&2
        return 1
      }
      ;;
    *)
      echo "❌ Error: Tipo de BLAST '$blast_type' no reconocido o no soportado." >&2
      return 1
      ;;
  esac

  # Determinar nombre de archivo de salida
  local query_name=$(basename "$query")
  local query_basename="${query_name%.*}"
  local output_file=""

  if [[ -z "$out" ]]; then
    output_file="${query_basename}.blastout"
  elif [[ -d "$out" ]]; then
    output_file="${out%/}/${query_basename}.blastout"
  elif [[ "$out" == */ || ! "$out" =~ \.[a-zA-Z0-9]+$ ]]; then
    mkdir -p "$out" || {
      echo "❌ No se pudo crear el directorio '$out'" >&2
      return 1
    }
    output_file="${out%/}/${query_basename}.blastout"
  else
    mkdir -p "$(dirname "$out")" || {
      echo "❌ No se pudo crear el directorio '$(dirname "$out")'" >&2
      return 1
    }
    output_file="$out"
  fi

  echo "🚀 Ejecutando $blast_type..."
  echo "📁 Archivo de salida: $output_file"

  "$blast_type" -query "$query" -db "$db" -out "$output_file" -outfmt "$format"

  echo "✅ BLAST completado. Resultado en: $output_file"
}


bb_guess_db_type() {
  local db_prefix="$1"
  if [[ -f "${db_prefix}.pin" ]]; then
    echo "prot"
  elif [[ -f "${db_prefix}.nin" ]]; then
    echo "nucl"
  else
    echo "unknown"
  fi
}


bb_blast_best_hit() {
  local infile="$1"



  # Obtener lista única de qseqids
  local qseqids
  qseqids=$(cut -f1 "$infile" | sort | uniq)

  while read -r qid; do
    # Filas correspondientes a ese qseqid
    grep -e "^${qid}\t" "$infile" > __tmp_qid_hits.blast

    # Obtener lista única de sseqid asociados a este qseqid
    cut -f2 __tmp_qid_hits.blast | sort | uniq | while read -r sid; do
      # Extraer todas las líneas qid+sid
      # e=1e100 es absurdamente grande asi que siempre se va a reemplazar.
      grep -e "^${qid}\t${sid}\t" __tmp_qid_hits.blast | \
      awk -v min_e=1e100 -v best_line="" '
      {
        e = $11 + 0
        b = $12 + 0
        if (e < min_e || (e == min_e && b > best_b)) {
          min_e = e
          best_b = b
          best_line = $0
        }
      }
      END { if (best_line != "") print best_line }
      '
    done

    rm -f __tmp_qid_hits.blast
  done <<< "$qseqids"
}

bb_blast_summary() {
  local infile="$1"

  if [[ -z "$infile" || ! -f "$infile" ]]; then
    echo "Uso: blast_summary <archivo_blast_outfmt6_con_qlen_slen>" >&2
    return 1
  fi

  awk '
  {
    total_hits++
    qid = $1
    sid = $2
    ident = $3 + 0
    qstart = $7; qend = $8
    sstart = $9; send = $10
    evalue = $11 + 0
    qlen = $13 + 0
    slen = $14 + 0

    qcov = (qend > qstart) ? qend - qstart + 1 : qstart - qend + 1
    scov = (send > sstart) ? send - sstart + 1 : sstart - send + 1
    qcov_pct = (qlen > 0) ? (qcov / qlen) * 100 : 0
    scov_pct = (slen > 0) ? (scov / slen) * 100 : 0

    total_ident += ident
    total_qcov += qcov_pct
    total_scov += scov_pct
    total_evalue += evalue
    if (evalue <= 1e-5) significant++

    queries[qid] = 1
    targets[sid] = 1
    hits_per_query[qid]++
  }

  END {
    num_queries = length(queries)
    num_targets = length(targets)
    queries_with_hits = length(hits_per_query)

    avg_ident = (total_hits > 0) ? total_ident / total_hits : 0
    avg_qcov = (total_hits > 0) ? total_qcov / total_hits : 0
    avg_scov = (total_hits > 0) ? total_scov / total_hits : 0
    avg_eval = (total_hits > 0) ? total_evalue / total_hits : 0
    sig_pct = (total_hits > 0) ? (significant / total_hits) * 100 : 0

    printf "📊 Resumen del archivo BLAST:\n"
    printf "  Total de alineamientos (hits):     %d\n", total_hits
    printf "  Queries únicos:                    %d\n", num_queries
    printf "  Targets únicos (sseqid):           %d\n", num_targets
    printf "  Queries con hits:                  %d\n", queries_with_hits
    printf "  Promedio de identidad:             %.2f%%\n", avg_ident
    printf "  Promedio de cobertura del query:   %.2f%%\n", avg_qcov
    printf "  Promedio de cobertura del target:  %.2f%%\n", avg_scov
    printf "  Promedio de e-value:               %.2g\n", avg_eval
    printf "  Porcentaje de hits con e<=1e-5:    %.2f%%\n", sig_pct
    print ""
    print "🔝 Top 5 qseqids con más hits:"

    for (q in hits_per_query)
      print hits_per_query[q] "\t" q | "sort -nr | head -n 5"
  }
  ' "$infile"
}


bb_blast_on_the_fly() {
  local query=""
  local db=""
  local blast_type=""
  local user_out=""

  # Parseo de argumentos
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --query) query="$2"; shift 2 ;;
      --db) db="$2"; shift 2 ;;
      --blast_type) blast_type="$2"; shift 2 ;;
      --out) user_out="$2"; shift 2 ;;
      *)
        echo "Uso: blast_on_the_fly --query query.fasta --db db.fasta --blast_type blastn|blastp|... [--out salida.blastout]" >&2
        return 1
        ;;
    esac
  done

  # Validación
  if [[ -z "$query" || -z "$db" || -z "$blast_type" ]]; then
    echo "❌ Faltan argumentos. Se requiere: --query, --db y --blast_type" >&2
    return 1
  fi

  if [[ ! -f "$query" || ! -f "$db" ]]; then
    echo "❌ Archivos no encontrados: $query o $db" >&2
    return 1
  fi

  # Definir nombre final de salida
  local query_base
  query_base=$(basename "$query")
  local default_out="${query_base%.*}.blastout"
  local final_out="${user_out:-$default_out}"

  # Validar que se puede escribir en la ruta de salida (si se especifica)
  local out_dir
  out_dir=$(dirname "$final_out")
  if [[ ! -d "$out_dir" ]]; then
    echo "❌ El directorio de salida no existe: $out_dir" >&2
    return 1
  fi
  if [[ ! -w "$out_dir" ]]; then
    echo "❌ No se tiene permiso de escritura en: $out_dir" >&2
    return 1
  fi
  # Intento de creación ficticia
  touch "$final_out" 2>/dev/null || {
    echo "❌ No se puede crear el archivo de salida: $final_out" >&2
    return 1
  }
  rm -f "$final_out"

  # Crear carpeta temporal
  local tmpdir
  tmpdir=$(mktemp -d)
  if [[ ! -d "$tmpdir" ]]; then
    echo "❌ No se pudo crear carpeta temporal" >&2
    return 1
  fi

  # ---------------------
  # Crear base de datos BLAST temporal
  # --------------------
  create_blast_db --in "$db" --outdir "$tmpdir" --db_name tempdb --title "OnTheFlyDB" || {
    echo "❌ Error al crear base de datos temporal." >&2
    rm -rf "$tmpdir"
    return 1
  }

  # ---------------------
  # Ejecutar BLAST
  # --------------------
  run_blast --query "$query" --db "$tmpdir/tempdb" --blast_type "$blast_type" --out "$tmpdir" || {
    echo "❌ Error al ejecutar BLAST." >&2
    rm -rf "$tmpdir"
    return 1
  }

  # Mover resultado final
  local tmp_out="$tmpdir/${query_base%.*}.blastout"
  mv "$tmp_out" "$final_out"

  echo ""
  echo "✅ Resultado BLAST guardado en: $final_out"
  echo "------------------------------"

  # Mostrar resumen
  blast_summary "$final_out"

  # Limpiar
  rm -rf "$tmpdir"
}
