#!/usr/bin/env bash
#SBATCH --job-name=netmhc
#SBATCH --nodes=1
#SBATCH --mem=100G
#SBATCH --cpus-per-task=20
#SBATCH --output netmhc_rescore_1.out
#SBATCH --error netmhc_rescore_1.err
#SBATCH --time=01:00:00

#Create the mamba environment 

#mamba create -n torch-light -c pytorch pytorch cpuonly numpy pandas matplotlib scipy scikit-learn seaborn



#Activate mamba environment containing torch (due to OS memory issues with installing torch on the base conda env)
#Ignore if already active

eval "$(mamba shell hook --shell bash)"

mamba activate torch-light

netmhc_path="/hpc/shared/uu_immunopeptidomics/netmhc/netMHCpan-4.2/netMHCpan"

data_path="/hpc/shared/uu_immunopeptidomics/latest_tims2rescore_separate_runs/netmhcpan_inputs_post_rescoring_HLAI"

#PEAKS

#$netmhc_path -p $data_path/comet_gr_ncORF.txt -BA -xls -a HLA-A01:01,HLA-A03:01,HLA-B07:02,HLA-B27:05,HLA-C02:02,HLA-C07:02 > comet_gr_ncORF.txt

#$netmhc_path -p $data_path/classI_peptides.tsv -BA -xls -a HLA-B07:02,HLA-B08:01,HLA-C07:01,HLA-C07:02> classI_binders.txt

##Fragpipe

#$netmhc_path -p $data_path/unique_fragpipe_ncORF_peptides.txt -BA -xls -a HLA-A02:01,HLA-B07:02,HLA-C07:02 > frag_jy_ncORF.txt


#$netmhc_path -p $data_path/combined_peptide_canonical.tsv  -BA -xls -a HLA-A02:01,HLA-B07:02,HLA-C07:02 > frag_jy.txt 

#Exclusive to fragpipe/PEAKS/Spectromine

#$netmhc_path -p $data_path/sage_unique_gr_filtered.txt -BA -a HLA-A01:01,HLA-A03:01,HLA-B07:02,HLA-B27:05,HLA-C02:02,HLA-C07:02 > sage_gr_binders.txt

#$netmhc_path -p $data_path/sage_unique_jy_filtered.txt -BA -a HLA-A02:01,HLA-B07:02,HLA-C07:02 > sage_jy_binders.txt

#Spectromine

#$netmhc_path -p $data_path/spec_unique_peptides_filter.tsv -BA -xls -a HLA-A01:01,HLA-A03:01,HLA-B07:02,HLA-B27:05,HLA-C02:02,HLA-C07:02 > spec_gr_ncORF.txt

#$netmhc_path -p $data_path/spec_unique_peptides_filter.tsv  -BA -xls -a HLA-A02:01,HLA-B07:02,HLA-C07:02 > spec_jy_ncORF.txt

###Pre/post-rescored outputs

#$netmhc_path -p $data_path/after_A2_908.pep -BA -xls -a HLA-A02:01,HLA-A25:01,HLA-B18:01,HLA-B41:01,HLA-C12:03,HLA-C17:01 > post_rescored_after_A2_908_HLAI.txt

#$netmhc_path -p $data_path/after_A2_913.pep -BA -xls -a HLA-A02:01,HLA-A66:01,HLA-B35:03,HLA-B51:01,HLA-C04:01,HLA-C16:02 > post_rescored_after_A2_913_HLAI.txt

#$netmhc_path -p $data_path/after_A2_915.pep -BA -xls -a HLA-A02:01,HLA-A68:02,HLA-B14:02,HLA-B50:01,HLA-C06:02,HLA-C08:02 > post_rescored_after_A2_915_HLAI.txt

#$netmhc_path -p $data_path/HLAI_909.pep -BA -xls -a HLA-A11:01,HLA-A74:01,HLA-B27:06,HLA-B49:01,HLA-C03:04,HLA-C07:01 > post_rescored_HLAI_909_HLAI.txt

#$netmhc_path -p $data_path/HLAI_910.pep -BA -xls -a HLA-A23:01,HLA-A30:02,HLA-B44:03,HLA-B49:01,HLA-C07:01,HLA-C16:01 > post_rescored_HLAI_910_HLAI.txt

#$netmhc_path -p $data_path/HLAI_911.pep -BA -xls -a HLA-A11:01,HLA-A26:01,HLA-B14:01,HLA-B44:03,HLA-C08:02,HLA-C16:01 > post_recored_HLA_911_HLA.txt

#$netmhc_path -p $data_path/HLAI_912.pep -BA -xls -a HLA-A01:01,HLA-A11:01,HLA-B40:01,HLA-B52:01,HLA-C03:04,HLA-C12:02 > post_rescored_HLAI_912_HLAI.txt

#$netmhc_path -p $data_path/HLAI_914.pep -BA -xls -a HLA-A03:01,HLA-A23:01,HLA-B07:02,HLA-B08:01,HLA-C07:02 > post_rescored_HLAI_914_HLAI.txt

$netmhc_path -p $data_path/HLAI_916.pep -BA -xls -a HLA-A03:01,HLA-A11:01,HLA-B52:01,HLA-B55:01,HLA-C01:02,HLA-C12:02 > post_rescored_HLAI_916_HLAI.txt
