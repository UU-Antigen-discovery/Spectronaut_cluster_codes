#!/bin/bash
#SBATCH --job-name=spectronaut_array
#SBATCH --output=logs/spec_%A_%a.out
#SBATCH --error=logs/spec_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=40
#SBATCH --mem=200G
#SBATCH --array=1-N%7  #Replace N with total number of .d files


#Batch-file to run spectronaut on the cluster using an array script to launch multiple jobs in parallel

#Create logs directory
mkdir -p logs

#Paths
dotnet_path="/hpc/local/Rocky8/uu_immunopeptidomics/dotnet"
binaries_path="/hpc/local/Rocky8/uu_immunopeptidomics/binaries/Spectronaut/bin/SpectronautCMD.dll"
fasta_path="/hpc/shared/uu_immunopeptidomics/spectronaut/search_fasta/spectromine_ncORF.FASTA"
out_base="/hpc/local/Rocky8/uu_immunopeptidomics/spectronaut_results_ncORF_cpu70"
base_temp="/hpc/local/Rocky8/uu_immunopeptidomics/spectronaut_tmp"
settings="/hpc/shared/uu_immunopeptidomics/spectronaut/settings_files/DIA_HLAI_settings.prop"
condition="/hpc/shared/uu_immunopeptidomics/spectronaut/settings_files/DIA_HLAI_ConditionSetup.tsv"

#Get list of all .d files and select the one for this array task
input_dir="/hpc/local/Rocky8/uu_immunopeptidomics"
mapfile -t d_files < <(find "$input_dir" -maxdepth 1 -type d -name "*.d" | sort)

#Check if array index is valid
if [ ${SLURM_ARRAY_TASK_ID} -gt ${#d_files[@]} ]; then
    echo "ERROR: Array task ID ${SLURM_ARRAY_TASK_ID} exceeds number of .d files (${#d_files[@]})"
    exit 1
fi

#Get the specific .d file for this task (array indices start at 1)
data_path="${d_files[$((SLURM_ARRAY_TASK_ID - 1))]}"
data_basename=$(basename "$data_path" .d)

echo "Processing file ${SLURM_ARRAY_TASK_ID}/${#d_files[@]}: $data_basename"
echo "Full path: $data_path"

#Create output directory for this specific file
out_path="${out_base}/${data_basename}"
mkdir -p "$out_path"

#Job-specific temp config folder
mkdir -p "$base_temp"
export XDG_CONFIG_HOME="${base_temp}/spectronaut_config_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$XDG_CONFIG_HOME"

echo "Spectronaut temp/config dir: $XDG_CONFIG_HOME"
echo "Output directory: $out_path"
df -h "$base_temp"

#Run Spectronaut
#The license key will be removed from this code since it cannot be exposed to the public
#Please add the new license key after "activate"

echo "Starting Spectronaut analysis at $(date)"

"$dotnet_path" "$binaries_path" activate <enter the license key here>

"$dotnet_path" "$binaries_path" direct \
  -r "$data_path" \
  -fasta "$fasta_path" -s "$settings" -con "$condition"\
  -o "$out_path"

exit_code=$?

echo "Spectronaut finished at $(date) with exit code $exit_code"

#Cleanup
echo "Cleaning up temporary Spectronaut config..."
rm -rf "$XDG_CONFIG_HOME"

echo "Job complete for: $data_basename"
echo "Results saved to: $out_path"

exit $exit_code
