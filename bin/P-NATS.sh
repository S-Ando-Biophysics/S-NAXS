#!/usr/bin/env bash
set -euo pipefail

VERSION="1.1"

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
  echo "[ERROR] Python virtual environment not found: ${VENV_DIR}" >&2
  exit 1
fi

source "${VENV_DIR}/bin/activate"

MAX_ASSEMBLY=99
WORKDIR_NAME="P-NATS-Temp"

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

P-NATS: Purifier of Nucleic Acid Three-dimensional Structures

Usage:
  P-NATS <PDB_ID>
  P-NATS -i=<input.pdb>
  P-NATS -i=<input.cif>
  P-NATS -h
  P-NATS --help
  P-NATS -v
  P-NATS --version

Modes:
  1) PDB ID mode
     P-NATS 9K7R
     The structure for the specified PDB ID will be downloaded from the PDB and processed.

  2) Local PDB mode
     P-NATS -i=model.pdb
     The PDB file in your working directory will be processed.

  3) Local CIF mode
     P-NATS -i=model.cif
     The CIF file in your working directory will be processed.

Options:
  -h, --help
     Show this help message and exit.

  -v, --version
     Show the program version and exit.

Outputs:
  The <PDB_ID>-<Assembly_No>-Purified.pdb will be output to the execution directory.

==================================================

EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

check_gemmi() {
  python3 - <<'PY' >/dev/null 2>&1 || exit 1
import gemmi
PY
}

cleanup_x3dna() {
  rm -f \
    *.out *.outs *.dat *.r3d *.scr \
    stacking.pdb hstacking.pdb bestpairs.pdb hel_regions.pdb \
    auxiliary.par bp_step.par cf_7methods.par
}

convert_cif_to_pdb() {
  local input_cif="$1"
  local output_pdb="$2"

  [[ -f "$input_cif" ]] || die "The CIF file was not found: $input_cif"

  python3 - "$input_cif" "$output_pdb" <<'PY'
import sys
import gemmi

input_cif = sys.argv[1]
output_pdb = sys.argv[2]

try:
    st = gemmi.read_structure(input_cif)
    st.write_pdb(output_pdb)
except Exception as e:
    sys.stderr.write(f"[ERROR] Failed to convert CIF to PDB: {e}\n")
    sys.exit(1)
PY

  [[ -f "$output_pdb" ]] || die "Failed to generate the PDB file: $output_pdb"
}

normalize_initial_pdb() {
  local pdb="$1"
  local tmp="${pdb}.tmp"

  [[ -f "$pdb" ]] || die "The PDB file was not found: $pdb"

  awk '
    function next_chain_id(   code) {
      chain_counter++
      if (chain_counter > 26) {
        printf("[ERROR] Too many chains were detected. Only 26 chain IDs (A-Z) are supported.\n") > "/dev/stderr"
        exit 1
      }
      code = 64 + chain_counter
      return sprintf("%c", code)
    }

    function assign_chain_id(orig_chain) {
      if (orig_chain in chain_map) return chain_map[orig_chain]
      chain_map[orig_chain] = next_chain_id()
      return chain_map[orig_chain]
    }

    function insertion_rank(ic) {
      if (ic == " " || ic == "") return 0
      return 1000 + index("ABCDEFGHIJKLMNOPQRSTUVWXYZ", ic)
    }

    function residue_sort_key(chain, resseq, icode) {
      return sprintf("%s\t%012d\t%04d", chain, resseq + 0, insertion_rank(icode))
    }

    function build_residue_number_map(   i, n, fields, chain, resseq, icode, key) {
      n = asorti(residue_sort, sorted_keys)
      for (i = 1; i <= n; i++) {
        split(sorted_keys[i], fields, "\t")
        chain = fields[1]
        resseq = fields[2] + 0
        icode = residue_sort[sorted_keys[i]]
        key = chain "|" resseq "|" icode
        residue_count[chain]++
        residue_newnum[key] = residue_count[chain]
      }
    }

    BEGIN {
      chain_counter = 0
    }

    FNR == NR {
      record = substr($0, 1, 6)

      if (record == "ATOM  " || record == "HETATM") {
        altloc = substr($0, 17, 1)

        if (!(altloc == " " || altloc == "A")) {
          next
        }

        orig_chain = substr($0, 22, 1)
        new_chain = assign_chain_id(orig_chain)

        raw_resseq = substr($0, 23, 4)
        gsub(/^ +| +$/, "", raw_resseq)
        if (raw_resseq == "") raw_resseq = 0

        icode = substr($0, 27, 1)

        sort_key = residue_sort_key(new_chain, raw_resseq, icode)
        residue_sort[sort_key] = icode
      }
      next
    }

    FNR == 1 {
      build_residue_number_map()
    }

    {
      record = substr($0, 1, 6)

      if (record == "ATOM  " || record == "HETATM") {
        altloc = substr($0, 17, 1)

        if (!(altloc == " " || altloc == "A")) {
          next
        }

        orig_chain = substr($0, 22, 1)
        new_chain = assign_chain_id(orig_chain)

        raw_resseq = substr($0, 23, 4)
        gsub(/^ +| +$/, "", raw_resseq)
        if (raw_resseq == "") raw_resseq = 0

        icode = substr($0, 27, 1)
        key = new_chain "|" (raw_resseq + 0) "|" icode
        new_resseq = residue_newnum[key]

        $0 = "ATOM  " substr($0, 7)
        $0 = substr($0, 1, 16) " " substr($0, 18)
        $0 = substr($0, 1, 21) new_chain substr($0, 23)

        new_resseq_str = sprintf("%4d", new_resseq)
        $0 = substr($0, 1, 22) new_resseq_str substr($0, 27)

        if (length($0) >= 66) {
          $0 = substr($0, 1, 66) "          " substr($0, 77)
        }

        print
      }
      else if (record == "TER   ") {
        next
      }
      else {
        print
      }
    }
  ' "$pdb" "$pdb" > "$tmp" || die "Failed while normalizing the initial PDB file: $pdb"

  mv "$tmp" "$pdb"
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
  local ch out

  for ch in "${chains[@]}"; do
    if [[ "$ch" == "_" ]]; then
      out="${prefix}-blank.pdb"
      awk '
        /^(ATOM  |HETATM)/ {
          c = substr($0, 22, 1)
          if (c == " ") print
        }
      ' "$na_pdb" > "$out"
    else
      out="${prefix}-${ch}.pdb"
      awk -v target="$ch" '
        /^(ATOM  |HETATM)/ {
          c = substr($0, 22, 1)
          if (c == target) print
        }
      ' "$na_pdb" > "$out"
    fi

    if [[ -s "$out" ]] && grep -Eq '^(ATOM  |HETATM)' "$out"; then
      echo "END" >> "$out"
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

rewrite_chain_residues_from_par() {
  local chain_pdb="$1"
  local par_file="$2"
  local tmp="${chain_pdb}.tmp"

  [[ -f "$chain_pdb" ]] || die "The chain PDB file was not found: $chain_pdb"
  [[ -f "$par_file" ]] || die "The PAR file was not found: $par_file"

  awk '
    function trim(s) {
      gsub(/^ +| +$/, "", s)
      return s
    }

    function upper(s) {
      return toupper(s)
    }

    function is_standard_resname(res) {
      return (res == "DA" || res == "DC" || res == "DG" || res == "DT" || res == "DU" || \
              res == "A"  || res == "C"  || res == "G"  || res == "T"  || res == "U")
    }

    function base_from_standard_resname(res) {
      if (res == "DA" || res == "A") return "A"
      if (res == "DC" || res == "C") return "C"
      if (res == "DG" || res == "G") return "G"
      if (res == "DT" || res == "T") return "T"
      if (res == "DU" || res == "U") return "U"
      return "X"
    }

    function family_from_standard_resname(res) {
      if (res == "DA" || res == "DC" || res == "DG" || res == "DT" || res == "DU") return "DNA"
      return "RNA"
    }

    function canonical_standard_resname(family, code) {
      if (family == "DNA") {
        if (code == "A") return " DA"
        if (code == "C") return " DC"
        if (code == "G") return " DG"
        if (code == "T") return " DT"
        if (code == "U") return " DU"
        return "LIG"
      } else {
        if (code == "A") return sprintf("%3s", "A")
        if (code == "C") return sprintf("%3s", "C")
        if (code == "G") return sprintf("%3s", "G")
        if (code == "T") return sprintf("%3s", "T")
        if (code == "U") return sprintf("%3s", "U")
        return "LIG"
      }
    }

    function modified_resname_from_par(code) {
      if (code == "A") return sprintf("%3s", "1")
      if (code == "C") return sprintf("%3s", "3")
      if (code == "G") return sprintf("%3s", "7")
      if (code == "T") return sprintf("%3s", "20")
      if (code == "U") return sprintf("%3s", "21")
      return "LIG"
    }

    FNR == NR {
      if (FNR <= 3) next
      line = $0
      if (length(line) > 0) {
        par_count++
        par_code[par_count] = upper(substr(line, 1, 1))
      }
      next
    }

    {
      if ($0 ~ /^(ATOM  |HETATM)/) {
        chain = substr($0, 22, 1)
        resseq = substr($0, 23, 4)
        icode = substr($0, 27, 1)
        key = chain "|" resseq "|" icode

        if (!(key in residue_index)) {
          residue_seen++
          residue_index[key] = residue_seen
        }

        idx = residue_index[key]
        code = (idx in par_code ? par_code[idx] : "X")

        res = upper(trim(substr($0, 18, 3)))

        if (is_standard_resname(res)) {
          current_base = base_from_standard_resname(res)

          if (current_base == code) {
            newres = substr($0, 18, 3)
          } else {
            family = family_from_standard_resname(res)
            newres = canonical_standard_resname(family, code)
          }
        } else {
          newres = modified_resname_from_par(code)
        }

        $0 = substr($0, 1, 17) newres substr($0, 21)
      }
      print
    }
  ' "$par_file" "$chain_pdb" > "$tmp" || die "Failed while rewriting residue names in: $chain_pdb"

  mv "$tmp" "$chain_pdb"
}

assemble_purified_pdb() {
  local output_pdb="$1"
  shift
  local chain_files=("$@")

  : > "$output_pdb"

  local f
  for f in "${chain_files[@]}"; do
    awk '/^(ATOM  |HETATM)/ { print }' "$f" >> "$output_pdb"
  done

  echo "END" >> "$output_pdb"
}

process_chain_without_rebuild() {
  local chain_pdb="$1"

  local stem="${chain_pdb%.pdb}"
  local par_file="${stem}.par"

  log "Processing chain file: $chain_pdb"

  find_pair -s "$chain_pdb" | analyze >/dev/null 2>&1
  [[ -f bp_helical.par ]] || die "bp_helical.par was not generated for: $chain_pdb"
  mv bp_helical.par "$par_file"

  rewrite_chain_residues_from_par "$chain_pdb" "$par_file"

  cleanup_x3dna

  printf '%s\n' "$chain_pdb"
}

run_chain_workflow_from_pdb() {
  local pdb="$1"
  local prefix="$2"
  local outdir="$3"

  local na_pdb="${prefix}-NA.pdb"
  local purified_pdb="${prefix}-Purified.pdb"

  [[ -f "$pdb" ]] || die "The input PDB file was not found: $pdb"

  get_part -n -d "$pdb" "$na_pdb"
  [[ -f "$na_pdb" ]] || die "get_part failed for: $pdb"

  mapfile -t chains < <(split_na_chains "$na_pdb" "${prefix}-NA")

  if [[ ${#chains[@]} -eq 0 ]]; then
    die "No chains were detected in: $na_pdb"
  fi

  log "Detected chains: ${chains[*]}"

  local processed_chain_files=()
  local ch chain_pdb processed_file

  for ch in "${chains[@]}"; do
    if [[ "$ch" == "_" ]]; then
      chain_pdb="${prefix}-NA-blank.pdb"
    else
      chain_pdb="${prefix}-NA-${ch}.pdb"
    fi

    processed_file="$(process_chain_without_rebuild "$chain_pdb")"
    processed_chain_files+=("$processed_file")
  done

  assemble_purified_pdb "$purified_pdb" "${processed_chain_files[@]}"

  cp "$purified_pdb" "${outdir}/"
  log "Finished processing. Output written to: ${outdir}/${purified_pdb}"
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

  convert_cif_to_pdb "$cif" "$pdb"
  normalize_initial_pdb "$pdb"
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
  normalize_initial_pdb "${prefix}.pdb"
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
  convert_cif_to_pdb "${prefix}.cif" "${prefix}.pdb"
  normalize_initial_pdb "${prefix}.pdb"
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
        echo "P-NATS version ${VERSION}"
        exit 0
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
  need_cmd python3
  need_cmd get_part
  need_cmd find_pair
  need_cmd analyze
  need_cmd realpath
  need_cmd awk
  need_cmd sed

  check_gemmi || die "Python module 'gemmi' is required but was not found."

  parse_args "$@"

  local start_dir
  start_dir="$(pwd)"

  rm -rf "$WORKDIR_NAME"
  mkdir -p "$WORKDIR_NAME"
  cd "$WORKDIR_NAME"

  if [[ "$MODE" == "pdbid" ]]; then
    log "Running in PDB ID mode with ID: $PDB_ID"
    download_all_assemblies "$PDB_ID"

    local asm=1
    while [[ -f "${PDB_ID}-${asm}.cif" ]]; do
      log "Attempting to process assembly ${asm}..."

      (
        set -e
        process_downloaded_assembly "$PDB_ID" "$asm" "$start_dir"
      ) || {
        echo "[WARNING] Assembly ${asm} failed, skipping to next." >&2
      }

      ((asm++))

      if [[ ! -f "${PDB_ID}-${asm}.cif" ]]; then
        break
      fi
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
}

main "$@"
