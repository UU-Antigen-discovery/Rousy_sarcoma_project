# Rousy_sarcoma_project
Codes used for analysis, rescoring and visualization of the Rousy Sarcoma data

# Description of the folders:
1) sage_analysis_codes
```
The pipeline used to analyze the raw data with sage v0.14.7
```
2) sage_rescoring_codes
```
The pipeline used to rescore the sage-derived outputs using tims2rescore v3.2.1
```
3) fragpipe_analysis_codes
```
The pipeline used to analyze the raw data with fragpipe v24.0
```
4) fragpipe_rescoring_codes
```
The pipeline used to rescore the fragpipe-derived outputs using tims2rescore v3.2.1
```
5) binding_affinity_analysis
```
The pipeline used to perform binding affinity analysis of each peptide using NetMHCpan 4.1
```
To activate the conda environment to run tims2rescore
```
conda env create -f tims2rescore.yml
conda activate tims2rescore
```
