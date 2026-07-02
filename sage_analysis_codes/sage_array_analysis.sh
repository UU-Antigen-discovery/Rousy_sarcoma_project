#!/usr/bin/env bash
#SBATCH --job-name=sage
#SBATCH --array=0-19
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --mem=400G
#SBATCH --cpus-per-task=15
#SBATCH --output=sage_%a.out
#SBATCH --error=sage_%a.err
#SBATCH --time=03:00:00
set -euo pipefail
# 1. Paths
sage_path="/hpc/local/Rocky8/uu_immunopeptidomics/sage_new/sage-v0.15.0-beta.1-x86_64-unknown-linux-gnu/sage"
sage_params="/hpc/local/Rocky8/uu_immunopeptidomics/sage_new/sage-v0.15.0-beta.1-x86_64-unknown-linux-gnu/mhc2_rousy.json"
fasta_path="/hpc/shared/uu_immunopeptidomics/spectronaut/search_fasta/combined_rousy_database.fas"
out_base="/hpc/local/Rocky8/uu_immunopeptidomics/sage_new/sage-v0.15.0-beta.1-x86_64-unknown-linux-gnu/out_rousy_hla2"
# 2. Gather all mzML files (same directory you use today)
data_dir="/hpc/local/Rocky8/uu_immunopeptidomics/rousy_new_data/Gustave_roussy_tissue_HLAII/"
mapfile -t mzml_files < <(find "$data_dir" -maxdepth 1 -type f -name "*.mzML" | sort)
num_files=${#mzml_files[@]}
echo "Found $num_files mzML files."
index=${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID is not set}
if (( index < 0 || index >= num_files )); then
    echo "Error: Array task ID $index is out of range. Only $num_files files exist."
    exit 1
fi
input_file="${mzml_files[$index]}"
stem=$(basename "$input_file" .mzML)
out_path="${out_base}/${stem}"
mkdir -p "$out_path"
echo "Processing file: $input_file"
echo "Output directory: $out_path"
# 3. Run SAGE — one job per mzML, one output dir per job
srun "$sage_path" \
    "$sage_params" \
    --fasta "$fasta_path" \
    --output_directory "$out_path" \
    --write-pin \
    --batch-size 1 \
    "$input_file"
