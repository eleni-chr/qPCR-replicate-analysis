# qPCR Replicate Analysis

**Code written by Dr Eleni Christoforidou for MATLAB R2024b.**

## Introduction
This repository contains MATLAB code for processing quantitative PCR (qPCR) data to evaluate the consistency and reliability of cycle threshold (Ct) values across technical triplicates. The analysis assesses the reproducibility of triplicates and compares the performance of replicate pairs and single Ct measurements for determining gene expression levels. The complete dataset used in our manuscript is included in the repository as `master_dataset.xlsx` to ensure full transparency and reproducibility.

## Purpose
The script performs the following tasks:
- **Data Import and Preparation:** Reads data from an Excel file and converts date fields.
- **Data Grouping and Statistical Analysis:** Groups data by instrument, detection method, and operator experience; calculates mean Ct, standard deviation, coefficient of variation (CV), outlier frequency, and maximum deviations.
- **Visualisation:** Generates a series of SVG plots including bar charts, scatter plots, histograms, residual plots, calibration analysis plots, time trend analyses, and comparative machine analyses.
- **Statistical Testing:** Applies various tests (e.g., Kolmogorov-Smirnov, Pearson’s/Spearman’s correlation, Wilcoxon rank-sum) and bootstrapping to assess the significance of differences.
- **Helper Functions:** Contains modular helper functions (e.g., `sanitiseFieldName`, `plotBarWithAnnotations`, `plot_with_fit`, `computeTimeTrends`, and `calculateTriplicateCVs`) for processing and plotting the data.

## Required Input
The script requires an Excel file named `master_dataset.xlsx` in the working directory with the following columns (order is not critical):
- **Instrument:** qPCR instrument used (e.g., QS7, Mx4000).
- **Run_date:** Date of the qPCR run (DD/MM/YYYY).
- **Detection_method:** Detection method employed (e.g., Probe, Dye).
- **Operator_level:** Operator experience level ("Experienced" or "Inexperienced").
- **Operator_number:** Identifier for the operator (e.g., 1, 2, 3, 4, …).
- **Run:** Run number associated with each sample.
- **Replicate:** Replicate number within each sample (typically 1, 2, or 3).
- **Ct:** Observed cycle threshold value.
- **Is_calibration_expired:** Calibration status ("Yes" or "No").
- **Last_calibration:** Date of the last instrument calibration (DD/MM/YYYY).
- **Days_since_last_calibration:** Number of days elapsed since the last calibration.

## How the Script Works
1. **Data Import and Preparation:**  
   - Reads data from `master_dataset.xlsx` using MATLAB’s import options.
   - Converts date fields to datetime format.
   - Extracts grouping factors (Instrument, Detection_method, Operator_level).

2. **Data Grouping and Statistical Analysis:**  
   - Processes triplicate data by calculating means, standard deviations, CV, outlier frequency (Ct deviations >2 units), and pairwise replicate differences.

3. **Visualisation:**  
   - Generates various plots (bar charts, scatter plots, histograms, residual plots, calibration plots, time trend analyses, and machine comparisons).  
   - Plots are saved as SVG vector graphics in the working directory.

4. **Statistical Testing:**  
   - Applies statistical tests (e.g., Kolmogorov-Smirnov, Pearson’s/Spearman’s, Wilcoxon rank-sum) and bootstrapping for evaluating differences.

5. **Helper Functions:**  
   - **sanitiseFieldName:** Ensures valid field names.
   - **plotBarWithAnnotations:** Creates annotated bar charts.
   - **plot_with_fit:** Plots data with a linear fit and calibration threshold.
   - **computeTimeTrends:** Analyzes CV trends over time for operators.
   - **calculateTriplicateCVs:** Computes CVs for triplicate Ct measurements.

## Caveats and Data-specific Considerations
- The script assumes data are collected in triplicates and will skip non-triplicate entries.
- Thresholds (e.g., 2 Ct unit cutoff for outliers and specific calibration thresholds) are specific to our experimental conditions.
- Calibration and comparison sections are tailored for specific instruments (e.g., QS3(A), QS3(B), QS7). For example, QS3(B) is excluded from certain analyses due to the absence of valid calibration data and Experienced operator data.
- Specific operators (e.g., operators "16" and "27") are excluded from time trend analyses due to limited data.
- The Excel file must follow the specified format; any deviation requires adjustments in the code.

## Dataset
The repository includes the complete `master_dataset.xlsx` file used in the manuscript. This dataset is provided for full transparency and reproducibility of the study results.

## License
This code is released under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). Please see the LICENSE file for details. By using this code, you agree to the terms of the Apache License 2.0, which grants explicit patent rights and requires that any redistributed or derivative works include the original copyright and attribution notices.

## Manuscript Association:
This repository contains the code and complete dataset used in a manuscript that has been submitted for publication. Upon publication, the DOI of the final published article will be provided here for proper citation and reference.

## Citation
If you use this code for your research, please cite it using the Zenodo DOI provided in the repository.

## Disclaimer
The code provided herein has not been peer-reviewed and may contain errors. Users are encouraged to test the code thoroughly and verify its accuracy for their specific applications. The author is not responsible for any errors or inaccuracies in the results generated by this script.
