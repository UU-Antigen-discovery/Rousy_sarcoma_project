#!/usr/bin/env bash
#SBATCH --job-name=tims2rescore_combined
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --mem=100G
#SBATCH --cpus-per-task=16
#SBATCH --output logs3/tims2rescore_combined_%a.out
#SBATCH --error  logs3/tims2rescore_combined_%a.err
#SBATCH --time=03:00:00
# NOTE: --array is set dynamically at submission time — see bottom of this file.

# =============================================================================
# tims2rescore_combined_array.sh
#
# Runs tims2rescore on every *_combined.tsv in TSV_DIR, paired with its
# matching .d directory in D_DIR.  Submit with:
#
#   N=$(ls /path/to/test_combined/*_combined.tsv | wc -l)
#   sbatch --array=0-$((N-1)) tims2rescore_combined_array.sh
#
# Or use the helper at the bottom of this file:
#   bash tims2rescore_combined_array.sh --submit
# =============================================================================

# ── Paths ─────────────────────────────────────────────────────────────────────
TSV_DIR="/hpc/local/Rocky8/uu_immunopeptidomics/rousy_new_data/out_rousy_hla2_sage"
D_DIR="/hpc/local/Rocky8/uu_immunopeptidomics/rousy_new_data/Gustave_roussy_tissue_HLAII"
OUTPUT_BASE="tims2rescore_output_sage_latest_HLAII_wdeeplc"

export LD_LIBRARY_PATH=/hpc/shared/uu_immunopeptidomics/envs/timsrescore2/lib:$LD_LIBRARY_PATH

# ── Self-submit helper ────────────────────────────────────────────────────────
# Run:  bash tims2rescore_combined_array.sh --submit
# to compute N and submit the array automatically.
if [[ "${1:-}" == "--submit" ]]; then
    mapfile -t _TSVS < <(ls "$TSV_DIR"/*/*.sage.tsv 2>/dev/null | sort)
    N=${#_TSVS[@]}
    if [[ $N -eq 0 ]]; then
        echo "ERROR: no *_combined.tsv files found in $TSV_DIR" >&2
        exit 1
    fi
    echo "Found $N TSV files — submitting array 0-$((N-1))"
    sbatch --array="0-$((N-1))" "$0"
    exit 0
fi

# ── Build sorted file list (same order on every node) ─────────────────────────
mapfile -t TSV_FILES < <(ls "$TSV_DIR"/*/*.sage.tsv 2>/dev/null | sort)
if [[ ${#TSV_FILES[@]} -eq 0 ]]; then
    echo "ERROR: no *.sage.tsv files found in $TSV_DIR" >&2
    exit 1
fi

# ── Rename TSVs to match parent-directory stem ────────────────────────────────
for tsv in "${TSV_FILES[@]}"; do
    parent_dir=$(dirname "$tsv")
    stem=$(basename "$parent_dir")
    target="${parent_dir}/${stem}.sage.tsv"
    if [[ "$tsv" != "$target" && ! -f "$target" ]]; then
        echo "Renaming: $(basename "$tsv")  →  ${stem}.sage.tsv"
        mv "$tsv" "$target"
    fi
done

# Rebuild list after renaming
mapfile -t TSV_FILES < <(find "$TSV_DIR" -maxdepth 2 -name "*.sage.tsv" | sort)

# ── Pick this task's TSV ──────────────────────────────────────────────────────
TSV="${TSV_FILES[$SLURM_ARRAY_TASK_ID]}"
SAMPLE=$(basename "$TSV" .sage.tsv)

# Derive all paths from the corrected SAMPLE
D_FILE="${D_DIR}/${SAMPLE}.d"
OUTPUT_DIR="${OUTPUT_BASE}/${SAMPLE}"
CONFIG="${OUTPUT_DIR}/config.json"


echo "=========================================="
echo "SLURM array task : $SLURM_ARRAY_TASK_ID"
echo "Sample           : $SAMPLE"
echo "TSV file         : $TSV"
echo "Spectrum (.d)    : $D_FILE"
echo "Output directory : $OUTPUT_DIR"
echo "=========================================="

# ── Validate inputs ───────────────────────────────────────────────────────────
if [[ ! -f "$TSV" ]]; then
    echo "ERROR: TSV not found: $TSV" >&2; exit 1
fi
if [[ ! -d "$D_FILE" ]]; then
    echo "ERROR: .d directory not found: $D_FILE" >&2; exit 1
fi

# ── Create output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR" logs

# ── Write per-sample config ───────────────────────────────────────────────────
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
            "deeplc": {}
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
        "psm_file": ["${TSV}"],
        "psm_file_type": "sage_tsv",
        "psm_reader_kwargs": {},
        "spectrum_path": "${D_FILE}",
        "output_path": "${OUTPUT_DIR}/report.txt",
        "log_level": "info",
        "id_decoy_pattern": null,
        "psm_id_pattern": "scan=(\\\\d+)",
        "spectrum_id_pattern": "(\\\\d+)",
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

# ── Run tims2rescore ──────────────────────────────────────────────────────────
tims2rescore -c "$CONFIG"

echo "Done: $SAMPLE (exit code $?)"
