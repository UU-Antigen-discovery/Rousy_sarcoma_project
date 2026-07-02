#!/usr/bin/env bash
#SBATCH --job-name=tims2rescore_proforma
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --mem=100G
#SBATCH --cpus-per-task=16
#SBATCH --output logs_tims2rescore_proforma/tims2rescore_%a.out
#SBATCH --error  logs_tims2rescore_proforma/tims2rescore_%a.err
#SBATCH --time=03:00:00
# NOTE: --array is set dynamically at submission time — see bottom of this file.

# =============================================================================
# tims2rescore_proforma_array.sh
#
# Runs tims2rescore on every *_proforma.pin found under directories matching
# A2_*/  after_A2_*/  HLAI*/  (one level deep), paired with its matching
# .d directory in D_DIR.  Submit with:
#
#   bash tims2rescore_proforma_array.sh --submit
#
# Or manually:
#   N=$(find /path/to/pin_root -maxdepth 2 -name "*_proforma.pin" | wc -l)
#   sbatch --array=0-$((N-1)) tims2rescore_proforma_array.sh
# =============================================================================

# ── Paths ─────────────────────────────────────────────────────────────────────
PIN_ROOT="/hpc/local/Rocky8/uu_immunopeptidomics/rousy_new_data/out_rousy_hlaII_fragpipe"
D_DIR="/hpc/local/Rocky8/uu_immunopeptidomics/rousy_new_data/Gustave_roussy_tissue_HLAII"
OUTPUT_BASE="tims2rescore_output_proforma_HLAII"

export LD_LIBRARY_PATH=/hpc/shared/uu_immunopeptidomics/envs/timsrescore2/lib:$LD_LIBRARY_PATH

# ── Self-submit helper ────────────────────────────────────────────────────────
if [[ "${1:-}" == "--submit" ]]; then
    mapfile -t _PINS < <(
        find "$PIN_ROOT" -maxdepth 2 -name "*_proforma.pin" \
            | awk -F/ '{d=$(NF-1); if (d ~ /^A2_/ || d ~ /^after_A2_/ || d ~ /^HLAII/) print}' \
            | sort
    )
    N=${#_PINS[@]}
    if [[ $N -eq 0 ]]; then
        echo "ERROR: no *_proforma.pin files found under matching directories in $PIN_ROOT" >&2
        exit 1
    fi
    echo "Found $N PIN files — submitting array 0-$((N-1))"
    sbatch --array="0-$((N-1))" "$0"
    exit 0
fi

# ── Build sorted file list (same order on every node) ─────────────────────────
mapfile -t PIN_FILES < <(
    find "$PIN_ROOT" -maxdepth 2 -name "*_proforma.pin" \
        | awk -F/ '{d=$(NF-1); if (d ~ /^A2_/ || d ~ /^after_A2_/ || d ~ /^HLAII/) print}' \
        | sort
)

if [[ ${#PIN_FILES[@]} -eq 0 ]]; then
    echo "ERROR: no *_proforma.pin files found under A2_*/after_A2_*/HLAII* in $PIN_ROOT" >&2
    exit 1
fi

# ── Pick this task's PIN file ─────────────────────────────────────────────────
PIN="${PIN_FILES[$SLURM_ARRAY_TASK_ID]}"
SAMPLE=$(basename "$PIN" _proforma.pin)

D_FILE="${D_DIR}/${SAMPLE}.d"
OUTPUT_DIR="${OUTPUT_BASE}/${SAMPLE}"
CONFIG="${OUTPUT_DIR}/config.json"

echo "=========================================="
echo "SLURM array task : $SLURM_ARRAY_TASK_ID"
echo "Sample           : $SAMPLE"
echo "PIN file         : $PIN"
echo "Spectrum (.d)    : $D_FILE"
echo "Output directory : $OUTPUT_DIR"
echo "=========================================="

# ── Validate inputs ───────────────────────────────────────────────────────────
if [[ ! -f "$PIN" ]]; then
    echo "ERROR: PIN file not found: $PIN" >&2; exit 1
fi
if [[ ! -d "$D_FILE" ]]; then
    echo "ERROR: .d directory not found: $D_FILE" >&2; exit 1
fi

# ── Create output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR" logs_tims2rescore_proforma

# ── Pre-process PIN: append /charge to the Peptide column ────────────────────
# psm_utils reads the PIN but does NOT automatically attach the charge to the
# peptidoform string.  MS²PIP requires ProForma notation with an explicit charge
# suffix, e.g. PEPTIDE/3.  The charge is already encoded in each SpecId:
#
#   {sample}.{scan}.{scan}.{charge}_{rank}
#   e.g.  ...195.4006.4006.3_1  →  charge = 3  →  Peptide becomes PEPTIDE/3
#
# The Python block below reads the original PIN, extracts the charge from the
# SpecId with a regex, and rewrites the Peptide column before passing the file
# to tims2rescore.
PIN_FIXED="${OUTPUT_DIR}/$(basename "$PIN")"

python3 - "$PIN" "$PIN_FIXED" << 'PYEOF'
import sys, re, csv

src, dst = sys.argv[1], sys.argv[2]

# SpecId tail:  .{scan}.{charge}_{rank}
# We want the second-to-last dot-separated number before the underscore.
# e.g.  "...195.4006.4006.3_1"  →  group 1 = "3"
charge_re = re.compile(r'\.\d+\.(\d+)_\d+$')

with open(src, newline='') as fin, open(dst, 'w', newline='') as fout:
    reader = csv.DictReader(fin, delimiter='\t')
    fieldnames = reader.fieldnames

    pep_col = next((f for f in fieldnames if f.strip().lower() == 'peptide'), None)
    if pep_col is None:
        raise ValueError(f"No 'Peptide' column found. Columns: {fieldnames}")

    writer = csv.DictWriter(fout, fieldnames=fieldnames, delimiter='\t',
                            extrasaction='ignore')
    writer.writeheader()

    fixed = skipped = 0
    for row in reader:
        spec_id = row.get('SpecId') or row.get('PSMId') or ''
        m = charge_re.search(spec_id)
        if m:
            charge = m.group(1)
            pep = row[pep_col].strip()
            if not re.search(r'/\d+$', pep):   # don't double-append
                row[pep_col] = f"{pep}/{charge}"
            fixed += 1
        else:
            skipped += 1
        writer.writerow(row)

print(f"[preprocess_pin] Charge appended to {fixed} PSMs; {skipped} skipped (no regex match).",
      flush=True)
PYEOF

if [[ $? -ne 0 ]]; then
    echo "ERROR: PIN pre-processing failed for $PIN" >&2; exit 1
fi
echo "Pre-processed PIN: $PIN_FIXED"

# ── Write per-sample config ───────────────────────────────────────────────────
# Spectrum ID mapping
# ─────────────────────────────────────────────────────────────────────────────
# psm_id_pattern  – applied to the PIN SpecId
#   SpecId format:  {sample_stem}.{scan}.{scan}.{charge}_{rank}
#   e.g.  20251120_..._195.4006.4006.3_1
#   We extract the scan number (4006):  [^.]+\.(\d+)\.
#
# spectrum_id_pattern  – applied to .d internal IDs (bare integers via timsrust)
#   e.g.  "4006"  →  captured by (.*)
cat > "$CONFIG" << EOF
{
    "\$schema": "./config_schema.json",
    "ms2rescore": {
        "feature_generators": {
            "basic": {},
            "ms2pip": {
                "model": "timsTOF2024",
                "ms2_tolerance": 0.02
            },
            "im2deep": {},
            "deeplc": {"calibration_set_size": 0.20}
        },
        "rescoring_engine": {
            "mokapot": {
                "write_weights": true,
                "write_txt": true,
                "fasta_file": null,
                "protein_kwargs": {}
            }
        },
        "config_file": null,
        "psm_file": ["${PIN_FIXED}"],
        "psm_file_type": "percolator",
        "psm_reader_kwargs": {},
        "spectrum_path": "${D_FILE}",
        "output_path": "${OUTPUT_DIR}/report.txt",
        "log_level": "info",
        "id_decoy_pattern": null,
        "psm_id_pattern": "[^.]+\\\\.(\\\\d+)\\\\.",
        "spectrum_id_pattern": "(.*)",
        "psm_id_rt_pattern": null,
        "psm_id_im_pattern": null,
        "lower_score_is_better": false,
        "max_psm_rank_input": 10,
        "max_psm_rank_output": 1,
        "modification_mapping": {
            "119.0041": "U:Carbamidomethyl",
            "15.9949":  "U:Oxidation",
            "42.0106":  "U:Acetyl",
            "-17.0265": "U:Gln->pyro-Glu",
            "-18.0106": "U:Glu->pyro-Glu"
        },
        "fixed_modifications": { "U:Carbamidomethyl": ["C"] },
        "processes": ${SLURM_CPUS_PER_TASK},
        "rename_to_usi": false,
        "fasta_file": null,
        "write_flashlfq": false,
        "write_report": true
    }
}
EOF

echo "=== spectrum_path in config ==="
grep spectrum_path "$CONFIG"
echo "=== psm_id_pattern / spectrum_id_pattern ==="
grep -E '"(psm_id|spectrum_id)_pattern"' "$CONFIG"
echo "=== Peptide column sample (first 3 data rows of fixed PIN) ==="
awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="Peptide") col=i} NR>1 && NR<=4{print $col}' "$PIN_FIXED"

# ── Run tims2rescore ──────────────────────────────────────────────────────────
tims2rescore -c "$CONFIG"

echo "Done: $SAMPLE (exit code $?)"
