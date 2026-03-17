#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1"

MAX_ASSEMBLY=99
WORKDIR_NAME="S-NAXS-Temp"

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

log() {
  echo "[INFO] $*" >&2
}

show_help() {
  cat <<'EOF'

==================================================

S-NAXS: Standardizer of Nucleic Acid X-ray Structures

Usage:
  S-NAXS <PDB_ID>
  S-NAXS -i=<input.pdb>
  S-NAXS -i=<input.cif>
  S-NAXS -d <PDB_ID>
  S-NAXS -d -i=<input.pdb>
  S-NAXS -d -i=<input.cif>
  S-NAXS -h
  S-NAXS --help
  S-NAXS -v
  S-NAXS --version

Modes:
  1) PDB ID mode
     S-NAXS 9K7R
     The structure of the ID you specified will be downloaded from the PDB and processed.

  2) Local PDB mode
     S-NAXS -i=model.pdb
     The PDB file in your directory will be processed.

  3) Local CIF mode
     S-NAXS -i=model.cif
     The CIF file in your directory will be processed.

Options:
  -h, --help
     Show this help message and exit.
     
  -v, --version
     Show the program version and exit.
     
  -d
     In the case of a double-stranded structure, a structure is obtained in which the loop has been removed.

Outputs:
  PDB files with a standardized structure will be output.

==================================================

EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

write_min_params() {
  cat > min.params <<'EOF'
pdb_interpretation {
  link_distance_cutoff = 7.0
}
selection = name " P  " or name " OP1" or name " OP2" or name " O5'" or name " C5'" or name " C4'" or name " O4'" or name " C3'" or name " O3'" or name " C2'"
EOF
}

cleanup_analysis_files() {
  rm -f \
    *.out *.outs *.dat *.r3d *.scr \
    stacking.pdb hstacking.pdb bestpairs.pdb hel_regions.pdb \
    auxiliary.par bp_step.par cf_7methods.par
}

cleanup_d_mode_files() {
  rm -f \
    *.out *.dat *.r3d *.scr \
    stacking.pdb hstacking.pdb bestpairs.pdb hel_regions.pdb \
    auxiliary.par bp_helical.par cf_7methods.par
}

cleanup_duplex_classification_files() {
  rm -f \
    *.dat *.r3d *.scr \
    stacking.pdb hstacking.pdb bestpairs.pdb hel_regions.pdb \
    auxiliary.par bp_helical.par cf_7methods.par bp_step.par
}

extract_chain_ids_from_pdb() {
  local pdb="$1"
  awk '
    /^(ATOM  |HETATM)/ {
      c = substr($0, 22, 1)
      if (c == " ") c = "_"
      seen[c] = 1
    }
    END {
      for (k in seen) print k
    }
  ' "$pdb" | LC_ALL=C sort
}

split_na_chains() {
  local na_pdb="$1"
  local prefix="$2"

  local chains=()
  while IFS= read -r ch; do
    [[ -n "$ch" ]] || continue
    chains+=("$ch")
  done < <(extract_chain_ids_from_pdb "$na_pdb")

  if [[ ${#chains[@]} -eq 0 ]]; then
    die "No chain IDs could be extracted from the nucleic-acid PDB file: $na_pdb"
  fi

  local valid_chains=()
  local ch out chain_expr

  for ch in "${chains[@]}"; do
    if [[ "$ch" == "_" ]]; then
      chain_expr="chain ' '"
      out="${prefix}-blank.pdb"
    else
      chain_expr="chain $ch"
      out="${prefix}-${ch}.pdb"
    fi

    phenix.pdbtools "$na_pdb" keep="$chain_expr" output.file_name="$out" >/dev/null 2>&1 || true

    if [[ -s "$out" ]] && grep -Eq '^(ATOM  |HETATM)' "$out"; then
      valid_chains+=("$ch")
    else
      rm -f "$out"
    fi
  done

  if [[ ${#valid_chains[@]} -eq 0 ]]; then
    die "No valid chain-specific PDB files were generated from: $na_pdb"
  fi

  printf '%s\n' "${valid_chains[@]}" | LC_ALL=C sort
}

index_to_chain_id() {
  local i="$1"

  if (( i < 0 || i > 25 )); then
    die "Too many chains were detected. Only 26 chain IDs (A-Z) are supported in this workflow."
  fi

  printf '%b' "\\$(printf '%03o' $((65 + i)))"
}

determine_chain_type_from_par() {
  local par_file="$1"

  [[ -f "$par_file" ]] || {
    printf '%s\n' "UNKNOWN"
    return
  }

  awk '
    {
      c = toupper(substr($0, 1, 1))
      if (c == "T") t++
      else if (c == "U") u++
    }
    END {
      if (t > 0 && u == 0) print "DNA"
      else if (u > 0 && t == 0) print "RNA"
      else if (t > u) print "DNA"
      else if (u > t) print "RNA"
      else print "UNKNOWN"
    }
  ' "$par_file"
}

determine_chain_type_from_pdb() {
  local pdb_file="$1"

  [[ -f "$pdb_file" ]] || {
    printf '%s\n' "DNA"
    return
  }

  awk '
    /^(ATOM  |HETATM)/ {
      res = toupper(substr($0, 18, 3))
      seq = substr($0, 23, 4)
      ins = substr($0, 27, 1)
      key = res "|" seq "|" ins
      if (!(key in seen)) {
        seen[key] = 1
        if (res == " DA" || res == " DC" || res == " DG" || res == " DT" || res == "DA" || res == "DC" || res == "DG" || res == "DT") dna++
        else if (res == "  A" || res == "  C" || res == "  G" || res == "  U" || res == "A" || res == "C" || res == "G" || res == "U") rna++
      }
    }
    END {
      if (dna > rna) print "DNA"
      else if (rna > dna) print "RNA"
      else print "DNA"
    }
  ' "$pdb_file"
}

determine_chain_type() {
  local chain_pdb="$1"
  local par_file="$2"

  local par_type pdb_type
  par_type="$(determine_chain_type_from_par "$par_file")"

  if [[ "$par_type" == "DNA" || "$par_type" == "RNA" ]]; then
    printf '%s\n' "$par_type"
    return
  fi

  pdb_type="$(determine_chain_type_from_pdb "$chain_pdb")"
  printf '%s\n' "$pdb_type"
}

classify_duplex_form() {
  local na_pdb="$1"
  local stem="${na_pdb%.pdb}"
  local out_file="${stem}.out"

  log "Classifying duplex form from: $na_pdb"

  find_pair "$na_pdb" | analyze >&2
  cleanup_duplex_classification_files

  [[ -f "$out_file" ]] || {
    printf '%s\n' "UNKNOWN"
    return
  }

  awk '
    BEGIN {
      in_block = 0
      in_table = 0
      a = 0
      b = 0
    }

    /Classification of each dinucleotide step in a right-handed nucleic acid/ {
      in_block = 1
      next
    }

    in_block && /step[[:space:]]+Xp[[:space:]]+Yp[[:space:]]+Zp[[:space:]]+XpH[[:space:]]+YpH[[:space:]]+ZpH[[:space:]]+Form/ {
      in_table = 1
      next
    }

    in_table && /^\*{5,}/ {
      exit
    }

    in_table {
      form = $NF
      if (form == "A") a++
      else if (form == "B") b++
    }

    END {
      if (a == 0 && b == 0) print "UNKNOWN"
      else if (a >= b) print "A"
      else print "B"
    }
  ' "$out_file"
}

normalize_chain_par() {
  local input_par="$1"
  local output_par="$2"

  sed 's/^[acgut]/\U&/' "$input_par" > "$output_par"
}

choose_x3dna_standard() {
  local chain_type="$1"
  local chain_count="$2"
  local duplex_form="$3"

  if [[ "$chain_type" == "RNA" ]]; then
    printf '%s\n' "RNA"
    return
  fi

  if [[ "$chain_count" -eq 2 ]]; then
    case "$duplex_form" in
      A)
        printf '%s\n' "ADNA"
        ;;
      B)
        printf '%s\n' "BDNA"
        ;;
      UNKNOWN)
        printf '%s\n' "UNDECIDABLE"
        ;;
      *)
        printf '%s\n' "ADNA"
        ;;
    esac
  else
    printf '%s\n' "ADNA"
  fi
}

process_one_chain() {
  local chain_pdb="$1"
  local target_chain_id="$2"
  local chain_count="$3"
  local duplex_form="$4"

  local stem="${chain_pdb%.pdb}"
  local par_file="${stem}.par"
  local fixed_par="${stem}-Fixed.par"
  local rebuild_pdb="${stem}-Rebuild.pdb"
  local minimized_pdb="${stem}-Rebuild_minimized.pdb"
  local phenix_pdb="${stem}-Rebuild-Phenix.pdb"
  local aligned_pdb
  local renamed_pdb
  local chain_type std_type

  if [[ "$target_chain_id" == "A" ]]; then
    log "Processing the first chain: $chain_pdb"
  else
    log "Processing a subsequent chain as chain ${target_chain_id}: $chain_pdb"
  fi

  find_pair -s "$chain_pdb" | analyze >&2
  cleanup_analysis_files

  [[ -f bp_helical.par ]] || die "bp_helical.par was not generated for: $chain_pdb"
  mv bp_helical.par "$par_file"

  chain_type="$(determine_chain_type "$chain_pdb" "$par_file")"
  log "Detected chain type for $chain_pdb: $chain_type"

  std_type="$(choose_x3dna_standard "$chain_type" "$chain_count" "$duplex_form")"

  if [[ "$std_type" == "UNDECIDABLE" ]]; then
    printf '%s\n' "__USE_ORIGINAL_NA_PDB__"
    return
  fi

  log "Selected X3DNA standard for $chain_pdb: $std_type"

  normalize_chain_par "$par_file" "$fixed_par"

  x3dna_utils cp_std "$std_type" >&2
  rebuild -atomic "$fixed_par" "$rebuild_pdb" >&2

  rm -f Atomic*.pdb ref_frames.dat

  phenix.geometry_minimization "$rebuild_pdb" min.params >&2
  rm -f "${stem}-Rebuild_minimized.cif" *.geo

  [[ -f "$minimized_pdb" ]] || die "The minimized PDB file was not found: $minimized_pdb"
  mv "$minimized_pdb" "$phenix_pdb"

  if [[ "$target_chain_id" == "A" ]]; then
    aligned_pdb="${stem}-Rebuild-Phenix-Align.pdb"

    if phenix.superpose_pdbs "$chain_pdb" "$phenix_pdb" >&2; then
      if [[ -f "${phenix_pdb}_fitted.pdb" ]]; then
        mv "${phenix_pdb}_fitted.pdb" "$aligned_pdb"
      else
        log "Superposition did not produce a fitted file for $chain_pdb. Using the original chain PDB instead."
        cp "$chain_pdb" "$aligned_pdb"
      fi
    else
      log "Superposition failed for $chain_pdb. Using the original chain PDB instead."
      cp "$chain_pdb" "$aligned_pdb"
    fi

  else
    renamed_pdb="${stem}-Rebuild-Phenix-Renamed.pdb"
    phenix.pdbtools \
      "$phenix_pdb" \
      rename_chain_id.old_id=A \
      rename_chain_id.new_id="$target_chain_id" \
      output.file_name="$renamed_pdb" >/dev/null 2>&1

    aligned_pdb="${stem}-Rebuild-Phenix-${target_chain_id}-Align.pdb"

    if phenix.superpose_pdbs "$chain_pdb" "$renamed_pdb" >&2; then
      if [[ -f "${renamed_pdb}_fitted.pdb" ]]; then
        mv "${renamed_pdb}_fitted.pdb" "$aligned_pdb"
      else
        log "Superposition did not produce a fitted file for $chain_pdb. Using the original chain PDB instead."
        cp "$chain_pdb" "$aligned_pdb"
      fi
    else
      log "Superposition failed for $chain_pdb. Using the original chain PDB instead."
      cp "$chain_pdb" "$aligned_pdb"
    fi
  fi

  [[ -f "$aligned_pdb" ]] || die "The output PDB file was not created: $aligned_pdb"

  printf '%s\t%s\n' "$aligned_pdb" "$chain_type"
}

run_d_mode() {
  local standardized_pdb="$1"
  local outdir="$2"
  local d_std_type="$3"
  local prefix="${standardized_pdb%.pdb}"

  [[ -f "$standardized_pdb" ]] || die "The standardized PDB file was not found for duplex post-processing: $standardized_pdb"

  log "Running duplex post-processing for: $standardized_pdb"

  find_pair "$standardized_pdb" | analyze >&2
  cleanup_d_mode_files

  [[ -f bp_step.par ]] || die "bp_step.par was not generated for: $standardized_pdb"
  mv bp_step.par "${prefix}.par"

  awk '
  {
    a = substr($0, 1, 1)
    b = substr($0, 2, 1)
    c = substr($0, 3, 1)

    if (a ~ /[acgtu]/) a = toupper(a)
    if (c ~ /[acgtu]/) c = toupper(c)
    if (b == "+") b = "-"

    print a b c substr($0, 4)
  }
  ' "${prefix}.par" > "${prefix}-Fixed.par"

  x3dna_utils cp_std "$d_std_type" >&2
  rebuild -atomic "${prefix}-Fixed.par" "${prefix}-Rebuild.pdb" >&2

  rm -f Atomic*.pdb ref_frames.dat

  phenix.geometry_minimization "${prefix}-Rebuild.pdb" min.params >&2
  rm -f "${prefix}-Rebuild_minimized.cif" *.geo

  [[ -f "${prefix}-Rebuild_minimized.pdb" ]] || die "The minimized PDB file was not found: ${prefix}-Rebuild_minimized.pdb"
  mv "${prefix}-Rebuild_minimized.pdb" "${prefix}-NoLoop.pdb"

  cp "${prefix}-NoLoop.pdb" "$outdir/"
  log "Duplex post-processing finished. Output written to: $outdir/${prefix}-NoLoop.pdb"
}

run_chain_workflow_from_pdb() {
  local pdb="$1"
  local prefix="$2"
  local outdir="$3"

  local na_pdb="${prefix}-NA.pdb"
  local standardized="${prefix}-Standardized.pdb"
  local duplex_form="UNKNOWN"

  [[ -f "$pdb" ]] || die "The input PDB file was not found: $pdb"

  get_part -n "$pdb" "$na_pdb"
  [[ -f "$na_pdb" ]] || die "get_part failed for: $pdb"

  mapfile -t chains < <(split_na_chains "$na_pdb" "${prefix}-NA")

  if [[ ${#chains[@]} -eq 0 ]]; then
    die "No chains were detected in: $na_pdb"
  fi

  log "Detected chains: ${chains[*]}"

  local aligned_files=()
  local chain_types=()
  local i ch chain_pdb aligned new_chain_id result chain_type
  local chain_count="${#chains[@]}"

  if [[ "$chain_count" -eq 2 ]]; then
    duplex_form="$(classify_duplex_form "$na_pdb")"
    log "Detected duplex form for $na_pdb: $duplex_form"
  fi

  for i in "${!chains[@]}"; do
    ch="${chains[$i]}"
    if [[ "$ch" == "_" ]]; then
      chain_pdb="${prefix}-NA-blank.pdb"
    else
      chain_pdb="${prefix}-NA-${ch}.pdb"
    fi

    if [[ "$i" -eq 0 ]]; then
      new_chain_id="A"
    else
      new_chain_id="$(index_to_chain_id "$i")"
    fi

    result="$(process_one_chain "$chain_pdb" "$new_chain_id" "$chain_count" "$duplex_form")"

    if [[ "$result" == "__USE_ORIGINAL_NA_PDB__" ]]; then
      cp "$na_pdb" "$standardized"
      cp "$standardized" "$outdir/"
      log "Duplex form classification was undecidable for a DNA chain. Rebuild was skipped, and the final output is: $outdir/$na_pdb"
      return
    fi

    aligned="${result%%$'\t'*}"
    chain_type="${result#*$'\t'}"

    aligned_files+=("$aligned")
    chain_types+=("$chain_type")
  done

  if [[ ${#aligned_files[@]} -eq 1 ]]; then
    cp "${aligned_files[0]}" "$standardized"
  else
    cat "${aligned_files[@]}" > "$standardized"
  fi

  cp "$standardized" "$outdir/"
  log "Finished processing. Output written to: $outdir/$standardized"

  if [[ "$D_MODE" == true ]]; then
    if [[ "$chain_count" -eq 2 ]]; then
      local d_std_type=""

      if [[ "${chain_types[0]}" == "DNA" && "${chain_types[1]}" == "DNA" ]]; then
        d_std_type="ADNA"
      elif [[ "${chain_types[0]}" == "RNA" && "${chain_types[1]}" == "RNA" ]]; then
        d_std_type="RNA"
      else
        log "Option -d was specified, but duplex post-processing was skipped because the two chains are mixed types: ${chain_types[0]} / ${chain_types[1]}"
      fi

      if [[ -n "$d_std_type" ]]; then
        run_d_mode "$standardized" "$outdir" "$d_std_type"
      fi
    else
      log "Option -d was specified, but duplex post-processing was skipped because ${chain_count} chains were detected."
    fi
  fi
}

process_downloaded_assembly() {
  local id="$1"
  local asm="$2"
  local outdir="$3"

  local cif="${id}-${asm}.cif"
  local pdb="${id}-${asm}.pdb"
  local prefix="${id}-${asm}"

  log "Processing assembly ${asm}"

  [[ -f "$cif" ]] || die "The CIF file was not found: $cif"

  phenix.cif_as_pdb "$cif" force_pdb_format=True >/dev/null 2>&1 || die "Failed to convert CIF to PDB: $cif"
  [[ -f "$pdb" ]] || die "The PDB file was not generated: $pdb"

  run_chain_workflow_from_pdb "$pdb" "$prefix" "$outdir"
}

process_local_pdb() {
  local input_path="$1"
  local outdir="$2"

  local input_abs input_name prefix
  input_abs="$(realpath "$input_path")"
  input_name="$(basename "$input_abs")"
  prefix="${input_name%.*}"

  log "Running in local PDB mode with input: $input_name"

  cp "$input_abs" "./${prefix}.pdb"
  run_chain_workflow_from_pdb "${prefix}.pdb" "$prefix" "$outdir"
}

process_local_cif() {
  local input_path="$1"
  local outdir="$2"

  local input_abs input_name prefix
  input_abs="$(realpath "$input_path")"
  input_name="$(basename "$input_abs")"
  prefix="${input_name%.*}"

  log "Running in local CIF mode with input: $input_name"

  cp "$input_abs" "./${prefix}.cif"
  phenix.cif_as_pdb "${prefix}.cif" force_pdb_format=True >/dev/null 2>&1 || die "Failed to convert CIF to PDB: ${prefix}.cif"

  [[ -f "${prefix}.pdb" ]] || die "The PDB file was not generated: ${prefix}.pdb"

  run_chain_workflow_from_pdb "${prefix}.pdb" "$prefix" "$outdir"
}

download_all_assemblies() {
  local id="$1"
  local found=0

  for asm in $(seq 1 "$MAX_ASSEMBLY"); do
    local gz="${id}-assembly${asm}.cif.gz"
    local cif_old="${id}-assembly${asm}.cif"
    local cif_new="${id}-${asm}.cif"
    local url="https://files.rcsb.org/download/${id}-assembly${asm}.cif.gz"

    if curl -fL --silent --show-error -O "$url"; then
      found=1
      log "Downloaded successfully: $gz"
      gunzip -f "$gz"
      [[ -f "$cif_old" ]] || die "The CIF file was not found after decompression: $cif_old"
      mv "$cif_old" "$cif_new"
    else
      if [[ "$found" -eq 0 && "$asm" -eq 1 ]]; then
        die "Failed to download assembly1. Please check whether the PDB ID is valid: $id"
      fi
      log "Assembly ${asm} does not exist. Downloading has been stopped."
      break
    fi
  done
}

parse_args() {
  MODE=""
  PDB_ID=""
  INPUT_FILE=""
  D_MODE=false

  if [[ $# -eq 0 ]]; then
    show_help
    exit 1
  fi

  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--version)
        echo "S-NAXS version ${VERSION}"
        exit 0
        ;;
      -d)
        D_MODE=true
        ;;
      -i=*)
        if [[ -n "$PDB_ID" || -n "$INPUT_FILE" ]]; then
          die "Please provide either one PDB ID or one -i=<file> argument."
        fi
        INPUT_FILE="${arg#-i=}"
        MODE="input"
        ;;
      -*)
        die "Unknown option: $arg"
        ;;
      *)
        if [[ -n "$PDB_ID" || -n "$INPUT_FILE" ]]; then
          die "Please provide either one PDB ID or one -i=<file> argument."
        fi
        PDB_ID="$arg"
        MODE="pdbid"
        ;;
    esac
  done

  if [[ "$MODE" == "pdbid" ]]; then
    PDB_ID="$(echo "$PDB_ID" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
    [[ "$PDB_ID" =~ ^[A-Z0-9]{4}$ ]] || die "A PDB ID must normally consist of four alphanumeric characters: $PDB_ID"
  elif [[ "$MODE" == "input" ]]; then
    [[ -n "$INPUT_FILE" ]] || die "No input file was provided."
    [[ -f "$INPUT_FILE" ]] || die "The specified input file was not found in the execution directory: $INPUT_FILE"
  else
    die "Please provide either a PDB ID or -i=<input.pdb|input.cif>."
  fi
}

main() {
  need_cmd curl
  need_cmd gunzip
  need_cmd phenix.cif_as_pdb
  need_cmd phenix.pdbtools
  need_cmd phenix.geometry_minimization
  need_cmd phenix.superpose_pdbs
  need_cmd get_part
  need_cmd find_pair
  need_cmd analyze
  need_cmd x3dna_utils
  need_cmd rebuild
  need_cmd realpath
  need_cmd awk
  need_cmd sed

  parse_args "$@"

  local start_dir
  start_dir="$(pwd)"

  rm -rf "$WORKDIR_NAME"
  mkdir -p "$WORKDIR_NAME"

  cd "$WORKDIR_NAME"
  write_min_params

  if [[ "$MODE" == "pdbid" ]]; then
    log "Running in PDB ID mode with ID: $PDB_ID"
    download_all_assemblies "$PDB_ID"

    local asm=1
    while [[ -f "${PDB_ID}-${asm}.cif" ]]; do
      process_downloaded_assembly "$PDB_ID" "$asm" "$start_dir"
      ((asm++))
    done
  else
    case "${INPUT_FILE##*.}" in
      pdb|PDB)
        process_local_pdb "$start_dir/$INPUT_FILE" "$start_dir"
        ;;
      cif|CIF)
        process_local_cif "$start_dir/$INPUT_FILE" "$start_dir"
        ;;
      *)
        die "The input file must have a .pdb or .cif extension: $INPUT_FILE"
        ;;
    esac
  fi

  cd "$start_dir"
  log "All processing has been completed successfully."
  log "Output files have been copied to the execution directory."
}

main "$@"
