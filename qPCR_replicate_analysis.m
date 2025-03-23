%% qPCR Replicate Analysis
%
% Code written by Dr Eleni Christoforidou for MATLAB R2024b.
%
% Purpose:
% This script processes quantitative PCR (qPCR) data to evaluate the consistency 
% and reliability of cycle threshold (Ct) values across technical triplicates. 
% The analysis assesses the reproducibility of triplicates and compares the performance 
% of replicate pairs and single Ct measurements for determining gene expression levels.
%
% Required Input:
% The script requires an Excel file named "master_dataset.xlsx" located in the current 
% working directory. The file should contain qPCR data organised under the following 
% column headings (order is not critical):
%   - 'Instrument': qPCR instrument used (e.g., QS7, Mx4000).
%   - 'Run_date': Date of the qPCR run in the format DD/MM/YYYY.
%   - 'Detection_method': Detection method employed (e.g., Probe, Dye).
%   - 'Operator_level': Operator experience level ("Experienced" or "Inexperienced").
%   - 'Operator_number': Identifier for the operator (e.g., 1, 2, 3, 4, …).
%   - 'Run': Run number associated with each sample (e.g., 1, 2, 4, …).
%   - 'Replicate': Replicate number within each sample (1, 2, or 3). This refers to techincal replicates.
%   - 'Ct': Observed cycle threshold value for the sample.
%   - 'Is_calibration_expired': Calibration status of the instrument ("Yes" or "No").
%   - 'Last_calibration': Date of the last instrument calibration (format DD/MM/YYYY).
%   - 'Days_since_last_calibration': Number of days elapsed since the last calibration.
%
% How the Script Works:
% 1. Data Import and Preparation:
%    - Reads the qPCR data from "master_dataset.xlsx" using MATLAB’s import options.
%    - Converts date fields ('Run_date', 'Last_calibration') into datetime format.
%    - Extracts unique grouping factors such as Instrument, Detection_method, and Operator_level.
%
% 2. Data Grouping and Statistical Analysis:
%    - Groups data by Instrument, Detection_method, and Operator_level.
%    - For each group, processes triplicate data by:
%         • Calculating the mean Ct, standard deviation, and coefficient of variation (CV).
%         • Determining outlier frequency (Ct deviations >2 units from the triplicate mean).
%         • Computing all pairwise replicate means and quantifying the maximum deviation from the overall triplicate mean.
%
% 3. Visualisation:
%    - Generates a series of plots that include:
%         • Bar charts for outlier frequencies and average deviations from the mean (with annotations on sample sizes and operator counts).
%         • Scatter plots of CV versus Ct values (with linear regression fits and correlation analysis).
%         • Histograms illustrating the distribution of mean differences between replicates.
%         • Residual plots comparing pairwise replicate means to full triplicate means, and single Ct values versus triplicate means.
%         • Calibration analysis plots showing CV versus time since the last calibration, with subplots for each Instrument + Detection_method combination.
%         • Time trend analysis of CV for both Experienced and Inexperienced operators, with operators ordered by the slope of their trend.
%         • Comparative analysis between different qPCR machines (e.g., QS3(A) vs QS3(B)) using statistical tests and effect size metrics.
%    - All figures are saved as SVG vector graphics (ensuring high-quality scalable output) in the working directory.
%
% 4. Statistical Testing:
%    - The script performs various statistical tests (e.g., Kolmogorov-Smirnov test, Pearson's/Spearman's correlation, Wilcoxon rank-sum test) 
%      to determine the significance of observed differences in CV, replicate concordance, and calibration effects.
%    - Bootstrapping is implemented for assessing differences in medians between calibration categories.
%
% 5. Helper Functions:
%    - The script incorporates several modular helper functions defined at the end of the file. These include:
%         • sanitiseFieldName: Ensures valid structure field names based on instrument or method labels.
%         • plotBarWithAnnotations: Creates annotated bar charts for outlier frequency data.
%         • plot_with_fit: Plots data with a linear fit and calibration threshold indicator.
%         • computeTimeTrends: Aggregates and analyses CV trends over time for individual operators.
%         • calculateTriplicateCVs: Computes CV values for groups of triplicate Ct measurements.
%
% Outputs:
% - A set of SVG plot files illustrating the various aspects of qPCR replicate consistency,
%   calibration effects, and operator performance.
% - Printed statistical summaries and p-values in the MATLAB console for key comparisons.
%
% Dependencies:
% - MATLAB R2024b or later.
% - "master_dataset.xlsx" must be present in the current directory with the specified data format.
%
% Caveats and Data-specific Considerations:
%   - The script assumes that data are collected in triplicates. It issues 
%       warnings and skips processing when non-triplicate data are 
%       encountered. Users with a different replicate structure will need 
%       to adjust this logic.
%   - Several thresholds in the script (e.g., the 2 Ct unit cutoff for 
%       defining outliers and significant residuals, and the calibration 
%       thresholds like 730 and 182.5 days) are specific to our 
%       experimental conditions and may need to be modified for other datasets.
%   - The calibration analysis and comparison sections are tailored for 
%       particular instruments (e.g., QS3(A), QS3(B), and QS7). For 
%       instance, QS3(B) is excluded from certain analyses due to the 
%       absence of valid calibration data and Experienced operator data. 
%       Users with different instruments or calibration conditions should 
%       update these sections accordingly.
%   - The script excludes specific operators (e.g., operators "16" and 
%       "27") from time trend analyses because their data were only 
%       collected on a single date. This exclusion is dataset specific and 
%       should be reviewed if the data structure changes.
%   - The script expects particular column headings and data types (such as
%       date formats and text fields for calibration status) in the Excel 
%       file. Any deviation from this format will require corresponding 
%       adjustments in the data import and processing steps.
%
% Disclaimer:
% The code provided herein has not been peer-reviewed and may contain errors. Users are encouraged 
% to test the code thoroughly and verify its accuracy for their specific applications. The author 
% is not responsible for any errors or inaccuracies in the results generated by this script.
%
% License:
% This code is released under the Apache License 2.0. Please see the 
% LICENSE file in the repository for details. By using this code, you agree
% to abide by the terms of the Apache License 2.0, which grants explicit 
% patent rights and requires that any redistributed or derivative works 
% include the original copyright and attribution notices.

%% 1. Load the qPCR data from an Excel file into a table for processing. 

clear;
clc;

% Define import options for the Excel file
opts = detectImportOptions('master_dataset.xlsx');

% Set the variable type for 'Is_calibration_expired' to text
opts = setvaropts(opts, 'Is_calibration_expired', 'Type', 'char');

% Load data with the specified options
data = readtable('master_dataset.xlsx', opts);

% Extract unique groups for factors
instruments = unique(data.Instrument);
detectionMethods = unique(data.Detection_method);
operators = unique(data.Operator_level);

% Initialise result storage
results = struct();

% Convert the 'Run_date' and 'Last_calibration' columns to datetime format
data.Run_date = datetime(data.Run_date, 'InputFormat', 'dd/MM/yyyy');
data.Last_calibration = datetime(data.Last_calibration, 'InputFormat', 'dd/MM/yyyy');

%% 2. Extract and calculate information to group and process triplicate Ct values.

% Initialise variables for overall plots and duplicate sufficiency analysis
outlierFrequencies = [];
avgMeanDifferences = [];
sampleSizes = [];
labels = {};            % Labels for the outlier frequency (deviation) plot
colours = [];           % Colours for each operator level
cvByCt = [];
ctValues = [];
meanDiffReplicates = [];

% Initialise variables for replicate concordance outlier frequency
outlierFrequenciesConcordance = [];
sampleSizesConcordance = [];
labelsConcordance = {};
coloursConcordance = [];

% Initialise arrays for duplicate sufficiency analysis (used in Section 7)
allTriplicateMeans = [];
allPairwiseMeans = [];
allGroupNames = {};

% Initialise arrays for single Ct analysis (used in Section 8)
singleCtValues = [];
triplicateMeansForSingles = [];

% Define colours for "Experienced" and "Inexperienced" operators
colourExperienced = [0, 0, 1];
colourInexperienced = [1, 0, 0];

% Loop through each grouping factor (Instrument, Detection method, Operator level)
for instrument = 1:length(instruments)
    for detection_method = 1:length(detectionMethods)
        for operator = 1:length(operators)
            
            % Sanitise field names for results storage
            instrumentField = sanitiseFieldName(instruments{instrument});
            detection_methodField = sanitiseFieldName(detectionMethods{detection_method});
            operatorField = sanitiseFieldName(operators{operator});
            
            % Filter data for the current group (Instrument, Detection_method, Operator_level)
            subset = data(strcmp(data.Instrument, instruments{instrument}) & ...
                          strcmp(data.Detection_method, detectionMethods{detection_method}) & ...
                          strcmp(data.Operator_level, operators{operator}), :);
            
            if isempty(subset)
                continue; % Skip if no data for this combination
            end
            
            % -------------------------------------------------------------
            % Main Statistics (Deviation from the Mean)
            % -------------------------------------------------------------
            % Initialise stats for this group (assuming triplicates)
            numSamples = height(subset) / 3;
            outlierCount = 0;
            cvList = zeros(numSamples, 1);
            meanDiffList = zeros(numSamples, 1);
            triplicateMeans = zeros(numSamples, 1);
            pairwiseMeanMatrix = zeros(numSamples, 3); % Stores the 3 possible pairwise means
            
            sampleIndex = 1;
            for run = unique(subset.Run)'
                runData = subset(subset.Run == run, :);
                for replicateIndex = unique(runData.Replicate)'
                    replicateData = runData(runData.Replicate == replicateIndex, :);
                    
                    % Ensure there are triplicate data
                    if height(replicateData) ~= 3
                        warning('Non-triplicate data detected for run %d. Skipping...', run);
                        continue;
                    end
                    
                    Ct = replicateData.Ct;
                    CtMean = mean(Ct, 'omitnan');
                    CtSD = std(Ct, 'omitnan');
                    CV = (CtSD / CtMean) * 100;
                    
                    cvList(sampleIndex) = CV;
                    triplicateMeans(sampleIndex) = CtMean;
                    
                    % Store individual Ct values and their corresponding triplicate mean
                    singleCtValues = [singleCtValues; Ct];
                    triplicateMeansForSingles = [triplicateMeansForSingles; repmat(CtMean, numel(Ct), 1)];
                    
                    % Check for outliers (difference >2 from the mean)
                    diffs = abs(Ct - CtMean);
                    if any(diffs > 2)
                        outlierCount = outlierCount + 1;
                    end
                    
                    % Calculate pairwise means from all duplicate combinations
                    pairMeans = [mean(Ct([1 2]), 'omitnan'), mean(Ct([1 3]), 'omitnan'), mean(Ct([2 3]), 'omitnan')];
                    pairwiseMeanMatrix(sampleIndex, :) = pairMeans;
                    
                    % Compute the maximum deviation from the full triplicate mean
                    meanDiffList(sampleIndex) = max(abs(pairMeans - CtMean));
                    
                    sampleIndex = sampleIndex + 1;
                end
            end
            
            % Store computed stats in the results structure for the current group
            results.(instrumentField).(detection_methodField).(operatorField) = struct(...
                'OutlierFrequency', (outlierCount / numSamples) * 100, ...
                'AverageCV', mean(cvList, 'omitnan'), ...
                'AverageMeanDifference', mean(meanDiffList, 'omitnan'), ...
                'SampleSize', numSamples, ...
                'TriplicateMeans', triplicateMeans, ...
                'PairwiseMeans', pairwiseMeanMatrix);
            
            % Accumulate group-level data for duplicate sufficiency analysis (ignoring operator level)
            groupLabel = sprintf('%s - %s', instruments{instrument}, detectionMethods{detection_method});
            allTriplicateMeans = [allTriplicateMeans; triplicateMeans];
            allPairwiseMeans = [allPairwiseMeans; pairwiseMeanMatrix];
            % For each triplicate, there are 3 pairwise values; assign the same group label for each
            for i = 1:length(triplicateMeans)
                allGroupNames = [allGroupNames; repmat({groupLabel}, 3, 1)];
            end
            
            % Update variables for the outlier frequency (deviation) plot
            outlierFrequencies = [outlierFrequencies; (outlierCount / numSamples) * 100];
            avgMeanDifferences = [avgMeanDifferences; mean(meanDiffList, 'omitnan')];
            sampleSizes = [sampleSizes; numSamples];
            labels = [labels; {sprintf('%s + %s', instruments{instrument}, detectionMethods{detection_method})}];
            if strcmp(operators{operator}, 'Experienced')
                colours = [colours; colourExperienced];
            else
                colours = [colours; colourInexperienced];
            end
            
            % -------------------------------------------------------------
            % Replicate Concordance Outlier Frequency
            % -------------------------------------------------------------
            % Calculate discordance when two replicates are close (difference ≤2) and the third deviates >2 Ct
            numOutliersConcordance = 0;
            for run = unique(subset.Run)'
                runData = subset(subset.Run == run, :);
                for replicateIndex = unique(runData.Replicate)'
                    replicateData = runData(runData.Replicate == replicateIndex, :);
                    
                    if height(replicateData) ~= 3
                        warning('Non-triplicate data detected for run %d. Skipping replicate concordance...', run);
                        continue;
                    end
                    
                    Ct = replicateData.Ct;
                    replicates = sort(Ct);  % Sort to ease comparison
                    
                    if abs(replicates(1) - replicates(2)) <= 2 && abs(replicates(2) - replicates(3)) > 2
                        numOutliersConcordance = numOutliersConcordance + 1;
                    elseif abs(replicates(2) - replicates(3)) <= 2 && abs(replicates(1) - replicates(2)) > 2
                        numOutliersConcordance = numOutliersConcordance + 1;
                    elseif abs(replicates(1) - replicates(3)) <= 2 && abs(replicates(2) - replicates(1)) > 2
                        numOutliersConcordance = numOutliersConcordance + 1;
                    end
                end
            end
            
            outlierFrequencyConcordance = (numOutliersConcordance / numSamples) * 100;
            outlierFrequenciesConcordance = [outlierFrequenciesConcordance; outlierFrequencyConcordance];
            sampleSizesConcordance = [sampleSizesConcordance; numSamples];
            
            % Modify instrument name based on conditions (if needed)
            instrumentName = instruments{instrument};
            if strcmp(instrumentName, 'QS3-0.1ML')
                instrumentName = 'QS3(A)';
            elseif strcmp(instrumentName, 'QS3-0.2ML')
                instrumentName = 'QS3(B)';
            end
            
            % Create a label for replicate concordance plot
            label_conc = sprintf('%s + %s', instrumentName, detectionMethods{detection_method});
            labelsConcordance = [labelsConcordance; {label_conc}];
            
            % Assign colour based on Operator status
            if strcmp(operators{operator}, 'Experienced')
                coloursConcordance = [coloursConcordance; colourExperienced];
            else
                coloursConcordance = [coloursConcordance; colourInexperienced];
            end
            
            % Also store replicate concordance statistic in the results structure
            results.(instrumentField).(detection_methodField).(operatorField).OutlierFrequencyConcordance = outlierFrequencyConcordance;
        end
    end
end

% Store the accumulated duplicate sufficiency data for Section 7
results.DuplicateSufficiency = struct(...
    'TriplicateMeans', allTriplicateMeans, ...
    'PairwiseMeans', allPairwiseMeans, ...
    'GroupNames', {allGroupNames});

% Store the single Ct analysis data for Section 8
results.SingleCtAnalysis = struct(...
    'SingleCtValues', singleCtValues, ...
    'TriplicateMeans', triplicateMeansForSingles);

% Calculate CV vs Ct and mean difference between replicates across all runs
for run = unique(data.Run)'
    runData = data(data.Run == run, :);
    
    % For CV vs Ct: process each replicate (triplicate)
    for replicateIndex = unique(runData.Replicate)'
        replicateData = runData(runData.Replicate == replicateIndex, :);
        if height(replicateData) == 3
            Ct = replicateData.Ct;
            CtMean = mean(Ct, 'omitnan');
            CtSD = std(Ct, 'omitnan');
            if CtMean > 0
                CV = (CtSD / CtMean) * 100;
                cvByCt = [cvByCt; CV];
                ctValues = [ctValues; CtMean];
            end
        end
    end

    % For mean difference between replicates:
    for sampleIndex = unique(runData.Replicate)'
        sampleData = runData(runData.Replicate == sampleIndex, :);
        if height(sampleData) == 3
            Ct = sampleData.Ct;
            meanDiff = mean(abs(Ct - mean(Ct, 'omitnan')), 'omitnan');
            meanDiffReplicates = [meanDiffReplicates; meanDiff];
        end
    end
end

% Remove any NaN values that may have been introduced
validIndices = ~isnan(cvByCt) & ~isnan(ctValues);
cvByCt = cvByCt(validIndices);
ctValues = ctValues(validIndices);

%% 3. Plot Outlier Frequency & Average Deviation from Mean per Replicate

fig = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);

% Subplot 1 - Outlier frequency based on deviation from the mean
ax1 = subplot(2, 1, 1);
plotBarWithAnnotations(ax1, outlierFrequencies, colours, labels, sampleSizes, data, ...
    'A. Outlier Frequency Based on Deviation from the Mean', 'Outlier Frequency (%)');

% Subplot 2 - Outlier Frequency Based on Replicate Concordance
ax2 = subplot(2, 1, 2);
plotBarWithAnnotations(ax2, outlierFrequenciesConcordance, coloursConcordance, ...
    labelsConcordance, sampleSizesConcordance, data, ...
    'B. Outlier Frequency Based on Replicate Concordance', 'Outlier Frequency (%)');

% Universal legend
legendAxes = axes('Position', [0 0 1 1], 'Visible', 'off');
h1 = patch(NaN, NaN, colourExperienced, 'DisplayName', 'Experienced');
h2 = patch(NaN, NaN, colourInexperienced, 'DisplayName', 'Inexperienced');
legend(legendAxes, [h1, h2], {'Experienced operator', 'Inexperienced operator'}, ...
       'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 20);

% Save and close the figure
print(fig, 'Outlier frequency', '-dsvg', '-vector');
close(fig);

%% 4. Plot Average Deviation from Mean per Replicate

fig = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);
barHandle = bar(avgMeanDifferences, 'FaceColor', 'flat');

% Set colours for each bar (based on Operator level)
barHandle.FaceColor = 'flat';
barHandle.CData = colours;

xticks(1:length(labels));
xticklabels(labels);
xtickangle(45);
ylabel('Average  Deviation from Mean per Replicate');
title('Average Absolute Deviation from Mean per Replicate');
grid on;
set(gca, 'FontSize', 20)

% Add a custom legend using patch objects
% Create invisible patch objects for "Experienced" and "Inexperienced" categories
h1 = patch(NaN, NaN, colourExperienced);
h2 = patch(NaN, NaN, colourInexperienced);

% Add legend
legend([h1, h2], {'Experienced operator', 'Inexperienced operator'}, 'Location', 'north', 'FontSize', 20);

% Annotate the sample size and number of unique operators on the bars
yLimit = max(avgMeanDifferences) * 1.2; % Initial y-axis limit with some padding
for i = 1:length(sampleSizes)
    % Parse the label to extract Instrument and Detection method
    currentLabel = labels{i};
    labelParts = split(currentLabel, ' + '); % Split the label into components
    instrumentName = labelParts{1};
    detectionMethodName = labelParts{2};

    % Filter the data for the current combination
    subset = data(strcmp(data.Instrument, instrumentName) & ...
                  strcmp(data.Detection_method, detectionMethodName), :);

    % Count unique operators
    uniqueOperators = unique(subset.Operator_number);
    operatorCount = length(uniqueOperators);

    % Create annotation text
    annotationText = sprintf('N = %d\nO = %d', sampleSizes(i), operatorCount);

    % Calculate the y-position for the text
    yPosition = avgMeanDifferences(i) + (yLimit * 0.02); % Small offset above the bar

    % Update yLimit if the annotation exceeds the current limit
    if yPosition > yLimit
        yLimit = yPosition * 1.1; % Increase y-axis limit with some margin
    end

    % Add annotation to the bar
    text(i, yPosition, annotationText, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 20, 'Color', 'black');
end

% Apply the updated y-axis limit
ylim([0, yLimit]);
hold off;

% Save and close the figure
print(fig, 'Average Absolute Deviation from Mean per Replicate', '-dsvg', '-vector');
close(fig);

%% 5. Plot CV versus Ct

% Test for normality using the Kolmogorov-Smirnov test
[h_ct, p_ct] = kstest(ctValues);  % Test for normality on ctValues
[h_cv, p_cv] = kstest(cvByCt);  % Test for normality on cvByCt

% Decide which correlation test to use based on normality
if h_ct == 0 && h_cv == 0
    % If both ctValues and cvByCt are normally distributed (h = 0 means fail to reject H0)
    [R_Probe, P_Probe] = corr(ctValues, cvByCt);  % Pearson's correlation
    disp('Using Pearson''s correlation (data is normally distributed).');
else
    % If either ctValues or cvByCt is not normally distributed (h = 1 means reject H0)
    [R_Probe, P_Probe] = corr(ctValues, cvByCt, 'Type', 'Spearman');  % Spearman's correlation
    disp('Using Spearman''s correlation (data is not normally distributed).');
end

% Plot CV vs Ct
fig = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);
scatter(ctValues, cvByCt, 'o');
hold on;

% Fit a linear regression (trendline)
p_Probe = polyfit(ctValues, cvByCt, 1); % Linear fit
yFit_Probe = polyval(p_Probe, ctValues); % Evaluate the fit

% Plot trendline
plot(ctValues, yFit_Probe, '-r', 'LineWidth', 2);

% Determine how to display the p-value
if P_Probe < 0.0001
    pText_Probe = 'p < 0.0001'; % Use a fixed string for very small p-values
else
    pText_Probe = sprintf('p = %.4f', P_Probe); % Otherwise, show up to four decimal places
end

% Display correlation coefficient and p-value on the plot
text(min(ctValues) + 1, max(cvByCt) - 5, sprintf('r = %.2f, %s', R_Probe, pText_Probe), 'FontSize', 20);

% Customise the axis limits to start at the origin (0, 0)
xlim([0, max(ctValues) + 1]);  % Ensure x-axis extends slightly beyond max Ct
ylim([0, max(cvByCt) + 5]);    % Ensure y-axis extends slightly beyond max CV

xlabel('Mean Ct Value of triplicates');
ylabel('Coefficient of Variation (%)');
title('Effect of template abundance on triplicate Ct variability');
legend({'Data','Linear fit'});
set(gca, 'FontSize', 20)
grid on;

% Save and close the figure
print(fig, 'CV vs Ct', '-dsvg', '-vector');
close(fig);

%% 6. Plot Mean Difference Between Replicates

fig = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);

% Create a histogram with normalised counts (so y-axis is a percentage)
[counts, edges] = histcounts(meanDiffReplicates, 100);

% Normalise the counts to percentages
binWidth = edges(2) - edges(1);
totalCounts = sum(counts); % Total number of data points
percentages = (counts / totalCounts) * 100; % Convert to percentages

% Plot the histogram with percentages on the y-axis
bar(edges(1:end-1) + binWidth / 2, percentages, 'BarWidth', 1);
xlabel('Mean Absolute Difference in Ct Value Between Replicates');
ylabel('Frequency (%)');
title('Replicate Consistency');
set(gca, 'FontSize', 20);

% Calculate 80th, 90th and 95th percentiles
percentile_80 = prctile(meanDiffReplicates, 80);
percentile_90 = prctile(meanDiffReplicates, 90);
percentile_95 = prctile(meanDiffReplicates, 95);

% Plot lines for 80th, 90th and 95th percentiles
hold on;
plot([percentile_80, percentile_80], ylim, 'k--', 'LineWidth', 2);
plot([percentile_90, percentile_90], ylim, 'c--', 'LineWidth', 2);
plot([percentile_95, percentile_95], ylim, 'm--', 'LineWidth', 2);
hold off;

% Annotate the plot with relevant information
legend({'Histogram', sprintf('80th percentile: %.2f', percentile_80), sprintf('90th percentile: %.2f', percentile_90), sprintf('95th percentile: %.2f', percentile_95)}, 'Location', 'Best', 'FontSize', 20);

% Save and close the figure
print(fig, 'Mean Difference Between Replicates', '-dsvg', '-vector');
close(fig);

%% 7. Residuals Analysis

fig = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);

% Subplot 1: Residuals of Triplicate Mean Ct versus Pairwise Means
subplot(1,2,1);
hold on;

% Extract pre‐computed duplicate sufficiency data
dupData = results.DuplicateSufficiency;
triplicateMeans = dupData.TriplicateMeans;    % Column vector of triplicate means
pairwiseMeans = dupData.PairwiseMeans;          % Matrix with 3 columns (one per pair)

% Define threshold for significant residual deviation (>2 Ct)
residual_threshold = 2;

% Initialise counters for residual analysis
total_residuals = 0;
significant_residuals_count = 0;

% Loop over each pair (each column in pairwiseMeans)
for pairIndex = 1:3
    currentPair = pairwiseMeans(:, pairIndex);
    
    % Fit a linear regression model: pairwise means versus triplicate means
    lm = fitlm(triplicateMeans, currentPair);
    predictedValues = lm.Fitted;
    
    % Calculate residuals: difference between observed and fitted pairwise means
    residuals = currentPair - predictedValues;
    
    % Update counters for residual analysis
    total_residuals = total_residuals + length(residuals);
    significantIndices = abs(residuals) > residual_threshold;
    significant_residuals_count = significant_residuals_count + sum(significantIndices);
    
    % Plot all residuals for this pair (in grey)
    scatter(triplicateMeans, residuals, 20, 'filled', 'MarkerFaceColor', [0.7 0.7 0.7]);
    
    % Overlay significant residuals (in red)
    scatter(triplicateMeans(significantIndices), residuals(significantIndices), 20, 'filled', 'MarkerFaceColor', 'r');
    
    % Plot horizontal reference lines: zero residual and ± threshold lines
    xLimits = xlim;
    plot(xLimits, [0, 0], 'k--', 'LineWidth', 3);
    plot(xLimits, [residual_threshold, residual_threshold], 'b--', 'LineWidth', 3);
    plot(xLimits, [-residual_threshold, -residual_threshold], 'b--', 'LineWidth', 3);
end

% Compute and display the percentage of points with significant residuals
percentage_significant = (significant_residuals_count / total_residuals) * 100;
fprintf('Percentage of points outside ±2 Ct cutoff (duplicate sufficiency): %.2f%%\n', percentage_significant);

% Customise the first subplot
xlabel('Triplicate Mean Ct');
ylabel('Residuals (Pairwise Mean Ct - Triplicate Mean Ct)');
title('Triplicate Mean Ct vs. Pairwise Means');
grid on;
grid minor;
set(gca, 'FontSize', 20);
hold off;

% Subplot 2: Residuals of Single Ct Values Compared to Triplicate Means
subplot(1,2,2);
hold on;

% Extract single Ct analysis data
singleCtData = results.SingleCtAnalysis;
allSingleCtValues = singleCtData.SingleCtValues;
allTriplicateMeans = singleCtData.TriplicateMeans;

% Calculate residuals for each single Ct value relative to its triplicate mean
singleCtResiduals = allSingleCtValues - allTriplicateMeans;

% Define threshold (2 Ct)
residual_threshold_single = 2;

% Identify significant residuals
significantSingleIndices = abs(singleCtResiduals) > residual_threshold_single;

% Count totals for reporting
totalSingleResiduals = length(singleCtResiduals);
significantSingleResidualsCount = sum(significantSingleIndices);

% Plot all single Ct residuals (in grey)
scatter(allTriplicateMeans, singleCtResiduals, 20, 'filled', 'MarkerFaceColor', [0.7 0.7 0.7]);

% Overlay significant residuals (in red)
scatter(allTriplicateMeans(significantSingleIndices), singleCtResiduals(significantSingleIndices), ...
        20, 'filled', 'MarkerFaceColor', 'r');

% Plot horizontal reference lines at 0 and at ± threshold (2 Ct)
plot(xlim, [0, 0], 'k--', 'LineWidth', 3);
plot(xlim, [residual_threshold_single, residual_threshold_single], 'b--', 'LineWidth', 3);
plot(xlim, [-residual_threshold_single, -residual_threshold_single], 'b--', 'LineWidth', 3);

% Compute and display the percentage of significant residuals
percentageSignificantSingle = (significantSingleResidualsCount / totalSingleResiduals) * 100;
fprintf('Percentage of single Ct values outside ±2 Ct cutoff: %.2f%%\n', percentageSignificantSingle);

% Customise the second subplot
xlabel('Triplicate Mean Ct');
ylabel('Residuals (Single Ct - Triplicate Mean Ct)');
title('Single Ct Values vs. Triplicate Means');
grid on;
grid minor;
set(gca, 'FontSize', 20);
hold off;

% Save and close the figure
print(fig, 'Residuals', '-dsvg', '-vector');
close(fig);

%% 8. CV versus Calibration time

% Remove rows where 'Is_calibration_expired' is empty
validCal = ~cellfun(@(x) isempty(x) || (ischar(x) && numel(x)==0), data.Is_calibration_expired);
dataCalibration = data(validCal,:);

% Define groups with Instrument, Detection method, Calibration threshold, text position, 
% and a DisplayName for plot titles (note: QS3(A) is renamed to QS3 in the display).
% Note: QS3(B) is skipped as we do not have data with valid calibration for this instrument.
groups = { ...
    struct('Instrument','QS3(A)','Detection','Probe','CalThreshold',730,'TextPosition','left',  'DisplayName','QS3 + Probe'), ...
    struct('Instrument','QS3(A)','Detection','Dye',  'CalThreshold',730,'TextPosition','left',  'DisplayName','QS3 + Dye'), ...
    struct('Instrument','QS7',  'Detection','Probe','CalThreshold',182.5,'TextPosition','right', 'DisplayName','QS7 + Probe'), ...
    struct('Instrument','QS7',  'Detection','Dye',  'CalThreshold',182.5,'TextPosition','right', 'DisplayName','QS7 + Dye') ...
};

% Preallocate structure to store results for each group
calibResults = struct();

% Loop over each group and compute CV and days since calibration
for i = 1:length(groups)
    grp = groups{i};
    % Filter data for the current group (using the actual instrument name for filtering)
    subset = dataCalibration(strcmp(dataCalibration.Instrument, grp.Instrument) & ...
                             strcmp(dataCalibration.Detection_method, grp.Detection), :);
    cvArray = [];
    daysArray = [];
    for run = unique(subset.Run)'
        runData = subset(subset.Run == run, :);
        for replicateIndex = unique(runData.Replicate)'
            replicateData = runData(runData.Replicate == replicateIndex, :);
            if height(replicateData) == 3
                Ct = replicateData.Ct;
                % Convert calibration days from string to double
                Cal = str2double(replicateData.Days_since_last_calibration);
                CtMean = mean(Ct, 'omitnan');
                CtSD = std(Ct, 'omitnan');
                CalMean = mean(Cal, 'omitnan');
                if CtMean > 0
                    CV = (CtSD / CtMean) * 100;
                    cvArray = [cvArray; CV];
                    daysArray = [daysArray; CalMean];
                end
            end
        end
    end
    % Create a valid field name to store the results
    fieldName = matlab.lang.makeValidName([grp.Instrument '_' grp.Detection]);
    calibResults.(fieldName).CV = cvArray;
    calibResults.(fieldName).Days = daysArray;
    calibResults.(fieldName).CalThreshold = grp.CalThreshold;
    calibResults.(fieldName).TextPosition = grp.TextPosition;
    calibResults.(fieldName).DisplayName = grp.DisplayName;
end

fig = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);

% Create subplots for each group (assuming a 2x2 layout)
groupFields = fieldnames(calibResults);
for i = 1:length(groupFields)
    field = groupFields{i};
    grpResult = calibResults.(field);
    ax = subplot(2, 2, i);
    % Use the DisplayName from the group for the title
    plot_with_fit(ax, grpResult.Days, grpResult.CV, grpResult.DisplayName, grpResult.CalThreshold, grpResult.TextPosition);
end

% Link axes for consistent scaling across subplots
axHandles = findall(fig, 'Type', 'axes');
linkaxes(axHandles, 'xy');

% Apply uniform y-axis limits across all subplots
allYLimits = cell2mat(get(axHandles, 'YLim'));
yMin = min(allYLimits(:,1));
yMax = max(allYLimits(:,2));
for ax = axHandles'
    ylim(ax, [yMin, yMax]);
end

% Add correlation and p-value text to each subplot
for ax = axHandles'
    if ~isempty(ax.UserData) && ~isnan(ax.UserData.R)
        if ax.UserData.P < 0.0001
            pText = 'p < 0.0001';
        else
            pText = sprintf('p = %.4f', ax.UserData.P);
        end
        xLimits = xlim(ax);
        yLimits = ylim(ax);
        if strcmp(ax.UserData.TextPosition, 'left')
            textX = xLimits(1) + 50;
            alignment = 'left';
        else
            textX = xLimits(2) - 50;
            alignment = 'right';
        end
        textY = yLimits(2);
        text(ax, textX, textY - 0.05 * range(yLimits), ...
            sprintf('r = %.2f, %s', ax.UserData.R, pText), ...
            'FontSize', 20, 'Color', 'k', 'VerticalAlignment', 'top', 'HorizontalAlignment', alignment);
    end
end

% Save and close the figure
print(fig, 'CV vs Calibration', '-dsvg', '-vector');
close(fig);

%% 9. CV versus Calibration with subplots for each Instrument + Detection method

% Define the instruments and detection methods to process
allInstruments = unique(dataCalibration.Instrument);
allDetections = unique(dataCalibration.Detection_method);

% Pre-calculate grouping statistics for each instrument+detection combination
% (Skip instrument 'QS3(B)' as before)
groupStats = [];
groupIndex = 1;
for i = 1:length(allInstruments)
    if strcmp(allInstruments{i}, 'QS3(B)')
        continue;
    end
    for j = 1:length(allDetections)
        % Filter data for the current group
        grpData = dataCalibration(strcmp(dataCalibration.Instrument, allInstruments{i}) & ...
                                  strcmp(dataCalibration.Detection_method, allDetections{j}), :);
        % Initialise containers for CV values and calibration category labels
        cvValues = [];
        calCats = {};
        for run = unique(grpData.Run)'
            runData = grpData(grpData.Run == run, :);
            for rep = unique(runData.Replicate)'
                repData = runData(runData.Replicate == rep, :);
                if height(repData) == 3
                    Ct = repData.Ct;
                    CtMean = mean(Ct, 'omitnan');
                    CtSD = std(Ct, 'omitnan');
                    % Determine calibration category from the first row (assume constant within replicate)
                    if strcmp(repData.Is_calibration_expired{1}, 'No')
                        calCats{end+1} = 'Valid cal.';
                    else
                        calCats{end+1} = 'Expired cal.';
                    end
                    if CtMean > 0
                        CV = (CtSD / CtMean) * 100;
                        cvValues = [cvValues; CV];
                    end
                end
            end
        end
        % Save this group’s data
        groupStats(groupIndex).Instrument = allInstruments{i};
        groupStats(groupIndex).Detection = allDetections{j};
        groupStats(groupIndex).cvValues = cvValues;
        groupStats(groupIndex).calCats = categorical(calCats);
        groupIndex = groupIndex + 1;
    end
end

% Compute global y-axis limits from all groups (for error bars)
yMax = -Inf;
yMin = Inf;
for k = 1:length(groupStats)
    means = grpstats(groupStats(k).cvValues, groupStats(k).calCats, 'mean');
    stds  = grpstats(groupStats(k).cvValues, groupStats(k).calCats, 'std');
    yMax = max([yMax; means + stds]);
    yMin = min([yMin; means - stds]);
end
% Add some padding
yPadding = 12;
yMax = yMax + yPadding;
yMin = yMin - yPadding;

% Perform statistical tests and bootstrapping for each group and store p-values.
for k = 1:length(groupStats)
    validData = groupStats(k).cvValues(groupStats(k).calCats == 'Valid cal.');
    expiredData = groupStats(k).cvValues(groupStats(k).calCats == 'Expired cal.');
    pVal = NaN;
    testUsed = '';
    if ~isempty(validData) && ~isempty(expiredData)
        [~, pValidNorm] = kstest(validData);
        [~, pExpiredNorm] = kstest(expiredData);
        if pValidNorm > 0.05 && pExpiredNorm > 0.05
            [~, pEqualVar] = vartest2(validData, expiredData);
            if pEqualVar > 0.05
                [~, pVal] = ttest2(validData, expiredData);
                testUsed = 't-test';
            else
                [~, pVal] = ttest2(validData, expiredData, 'Vartype', 'unequal');
                testUsed = 'Welch''s t-test';
            end
        else
            [pVal,~,~] = ranksum(validData, expiredData);
            testUsed = 'Wilcoxon rank sum test';
        end
    end
    groupStats(k).pValue = pVal;
    groupStats(k).testUsed = testUsed;
    fprintf('For group "%s + %s", the test used is: %s\n', groupStats(k).Instrument, groupStats(k).Detection, testUsed);
    
    % Bootstrapping to calculate p-value for difference in medians
    bootstrapP = NaN;
    if ~isempty(validData) && ~isempty(expiredData)
        numBootstrap = 10000;
        obsDiff = median(validData) - median(expiredData);
        bootDiffs = zeros(numBootstrap,1);
        for b = 1:numBootstrap
            resValid = datasample(validData, length(validData), 'Replace', true);
            resExpired = datasample(expiredData, length(expiredData), 'Replace', true);
            bootDiffs(b) = median(resValid) - median(resExpired);
        end
        bootstrapP = mean(abs(bootDiffs) >= abs(obsDiff));
        groupStats(k).obsDiff = obsDiff;
        groupStats(k).bootDiffs = bootDiffs;
    end
    groupStats(k).bootstrapPValue = bootstrapP;
end

% Figure 1: Bar plots with error bars and annotations
fig1 = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);
% Figure 2: Histograms of bootstrap distributions
fig2 = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);

% Determine layout dimensions (use number of groups as number of subplots)
numGroups = length(groupStats);
subplotRows = ceil(numGroups / 2);  % For example, 2 columns
subplotCols = 2;
for k = 1:numGroups
    % Determine display name for the title (rename QS3(A) to QS3)
    instName = groupStats(k).Instrument;
    if strcmp(instName, 'QS3(A)')
        instName = 'QS3';
    end
    titleStr = sprintf('%s + %s', instName, groupStats(k).Detection);
    
    % Calculate statistics for each calibration category in this group
    cats = categories(groupStats(k).calCats);
    mediansVals = grpstats(groupStats(k).cvValues, groupStats(k).calCats, 'median');
    iqrsVals = grpstats(groupStats(k).cvValues, groupStats(k).calCats, 'iqr');
    % Sample sizes:
    nValid = sum(groupStats(k).calCats == 'Valid cal.');
    nExpired = sum(groupStats(k).calCats == 'Expired cal.');
    
    % Plot bar plot
    figure(fig1);
    subplot(subplotRows, subplotCols, k);
    bar(mediansVals);
    hold on;
    % Scatter individual points with jitter
    for m = 1:length(cats)
        catData = groupStats(k).cvValues(groupStats(k).calCats == cats{m});
        scatter(m + randn(size(catData))*0.05, catData, 50, 'filled', 'MarkerFaceAlpha', 0.6);
    end
    errorbar(1:length(mediansVals), mediansVals, iqrsVals, 'k', 'LineStyle', 'none');
    ylabel('Coefficient of Variation (%)','FontSize',20);
    title(titleStr, 'FontSize',20);
    xticks(1:length(cats));
    xticklabels(cats);
    grid on;
    grid minor;
    % Annotate median ± IQR on top of bars
    for m = 1:length(mediansVals)
        text(m, mediansVals(m) - iqrsVals(m) - 2, sprintf('%.2f ± %.2f', mediansVals(m), iqrsVals(m)),...
            'HorizontalAlignment','center','FontSize',16,'Color','black');
    end
    % Annotate sample sizes below bars
    if length(cats) >= 2
        text(1, mediansVals(1) - iqrsVals(1) - 5, sprintf('N = %d', nValid), 'HorizontalAlignment','center','FontSize',16,'Color','black');
        text(2, mediansVals(2) - iqrsVals(2) - 5, sprintf('N = %d', nExpired), 'HorizontalAlignment','center','FontSize',16,'Color','black');
    end
    % Annotate p-value on plot
    pVal = groupStats(k).pValue;
    if pVal < 0.0001
        pText = 'P < 0.0001';
    elseif ~isnan(pVal)
        pText = sprintf('P = %.4f', pVal);
    else
        pText = '';
    end
    text(1.5, yMax - 5, pText, 'HorizontalAlignment','center','FontSize',20,'Color','black');
    ylim([yMin, yMax]);
    hold off;
    
    % Plot bootstrap distribution
    figure(fig2);
    subplot(subplotRows, subplotCols, k);
    histogram(groupStats(k).bootDiffs, 'Normalization','probability','FaceColor',[0.8,0.4,0.4]);
    hold on;
    xline(groupStats(k).obsDiff, 'k--', 'LineWidth',2);
    xlabel('Bootstrap Differences (Valid - Expired)','FontSize',20);
    ylabel('Probability','FontSize',20);
    title(titleStr, 'Interpreter','none','FontSize',20);
    grid on;
    grid minor;
    set(gca, 'FontSize',20);
    bpVal = groupStats(k).bootstrapPValue;
    if bpVal < 0.0001
        bpText = 'P < 0.0001';
    elseif ~isnan(bpVal)
        bpText = sprintf('P = %.4f', bpVal);
    else
        bpText = '';
    end
    currX = xlim;
    currY = ylim;
    xTop = currX(1) + 0.1*(currX(2)-currX(1));
    yTop = currY(2) - 0.1*(currY(2)-currY(1));
    text(xTop, yTop, bpText, 'HorizontalAlignment','left','FontSize',20,'Color','black');
    hold off;
end

% Save and close the figures
print(fig1, 'Calibration per instrument and detection method', '-dsvg', '-vector');
print(fig2, 'Calibration bootstrapping', '-dsvg', '-vector');
close(fig1);
close(fig2);

%% 10. Analyse and plot CV over time for Experienced operators, ordered by slope

[expTrendResults, sortedExpOps, expGlobalYLimits] = computeTimeTrends(data, 'Experienced');

numExpOps = length(sortedExpOps);
numRows = ceil(sqrt(numExpOps));
numCols = ceil(numExpOps/numRows);
fig = figure('Units','normalized','Position',[0,0,1,1]);

for idx = 1:numExpOps
    op = sortedExpOps{idx};
    opResults = expTrendResults.(matlab.lang.makeValidName(op));
    
    if isempty(opResults.TimePoints)
        continue;
    end
    
    subplot(numRows, numCols, idx);
    hold on;
    
    % Plot CV values over time.
    plot(opResults.TimePoints, opResults.CVValues, '-o', 'LineWidth', 2);
    
    % Plot trendline if available.
    if ~isnan(opResults.Slope) && length(opResults.TimePoints) > 1
        numericTime = datenum(opResults.TimePoints);
        p = polyfit(numericTime, opResults.CVValues, 1);
        trendline = polyval(p, numericTime);
        plot(opResults.TimePoints, trendline, '--r', 'LineWidth', 2);
        xCenter = mean(xlim);
        annotationY = expGlobalYLimits(2) - 0.05*(expGlobalYLimits(2) - expGlobalYLimits(1));
        text(xCenter, annotationY, sprintf('Slope: %.4f', opResults.Slope), ...
            'FontSize', 16, 'Color', 'r', 'HorizontalAlignment', 'center');
    end
    
    ylabel('Mean CV (%)');
    grid on;
    set(gca, 'FontSize', 16);
    ylim(expGlobalYLimits);
    hold off;
end

sgtitle('Coefficient of Variation Over Time for Experienced Operators', 'FontSize', 20);

% Save and close the figure
print(fig, 'CV Over Time by Experienced Operators', '-dsvg', '-vector');
close(fig);

%% 11. Analyse and plot CV over time for Inexperienced operators, ordered by slope

% Exclude specific operators if needed.
excludeOps = {"16", "27"}; % All data from these operators were collected on a single date, so they do not have time series data.
[inexpTrendResults, sortedInexpOps, inexpGlobalYLimits] = computeTimeTrends(data, 'Inexperienced', excludeOps);

numInexpOps = length(sortedInexpOps);
numRows = ceil(sqrt(numInexpOps));
numCols = ceil(numInexpOps/numRows);
fig = figure('Units','normalized','Position',[0,0,1,1]);

for idx = 1:numInexpOps
    op = sortedInexpOps{idx};
    opResults = inexpTrendResults.(matlab.lang.makeValidName(op));
    
    if isempty(opResults.TimePoints)
        continue;
    end
    
    subplot(numRows, numCols, idx);
    hold on;
    
    % Plot CV values over time
    plot(opResults.TimePoints, opResults.CVValues, '-o', 'LineWidth', 2);
    
    % Plot trendline if available
    if ~isnan(opResults.Slope) && length(opResults.TimePoints) > 1
        numericTime = datenum(opResults.TimePoints);
        p = polyfit(numericTime, opResults.CVValues, 1);
        trendline = polyval(p, numericTime);
        plot(opResults.TimePoints, trendline, '--r', 'LineWidth', 2);
        xCenter = mean(xlim);
        annotationY = inexpGlobalYLimits(2) - 0.05*(inexpGlobalYLimits(2) - inexpGlobalYLimits(1));
        text(xCenter, annotationY, sprintf('Slope: %.4f', opResults.Slope), ...
            'FontSize', 16, 'Color', 'r', 'HorizontalAlignment', 'center');
    end
    
    ylabel('Mean CV (%)');
    grid on;
    set(gca, 'FontSize', 16);
    ylim(inexpGlobalYLimits);
    hold off;
end

sgtitle('Coefficient of Variation Over Time for Inexperienced Operators', 'FontSize', 20);

% Save and close the figure
print(fig, 'CV Over Time by Inexperienced Operators', '-dsvg', '-vector');
close(fig);

%% 12. Compare machines

% Define the common detection method between the two machines
commonDetectionMethod = 'Dye';

% Filter data for QS3(A) and QS3(B)
dataQS3_A = data(strcmp(data.Instrument, 'QS3(A)'), :);
dataQS3_B = data(strcmp(data.Instrument, 'QS3(B)'), :);

% Further filter data by detection method and operator experience
% (note: We have no data for the QS3(B) + Experienced combination)
dataQS3_A_Inexperienced = dataQS3_A(strcmp(dataQS3_A.Operator_level, 'Inexperienced') & strcmp(dataQS3_A.Detection_method, commonDetectionMethod), :);
dataQS3_B_Inexperienced = dataQS3_B(strcmp(dataQS3_B.Operator_level, 'Inexperienced') & strcmp(dataQS3_B.Detection_method, commonDetectionMethod), :);

% Calculate CVs for QS3(A) and QS3(B) (inexperienced operators only)
cvQS3_A_Inexperienced = calculateTriplicateCVs(dataQS3_A_Inexperienced);
cvQS3_B_Inexperienced = calculateTriplicateCVs(dataQS3_B_Inexperienced);

% Perform Wilcoxon rank-sum test (equivalent to Mann-Whitney U test)
[p, h] = ranksum(cvQS3_A_Inexperienced, cvQS3_B_Inexperienced);

% Display results
fprintf('Comparison of CVs between QS3(A) and QS3(B)');
fprintf('Mean CV (QS3(A)): %.2f%%\n', mean(cvQS3_A_Inexperienced, 'omitnan'));
fprintf('Mean CV (QS3(B)): %.2f%%\n', mean(cvQS3_B_Inexperienced, 'omitnan'));
fprintf('Mann-Whitney U test p-value: %.4f\n', p);

% Bar graph with error bars
fig = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]); % Full screen
hold on;

% Calculate median, IQR, and sample size for each group
medians = [median(cvQS3_A_Inexperienced, 'omitnan'), median(cvQS3_B_Inexperienced, 'omitnan')];
iqrs = [iqr(cvQS3_A_Inexperienced), iqr(cvQS3_B_Inexperienced)];
sampleSizes = [length(cvQS3_A_Inexperienced), length(cvQS3_B_Inexperienced)];

% Plot bars
barHandle = bar(1:2, medians, 'FaceColor', 'flat');

% Add IQR as error bars
errorbar(1:2, medians, iqrs / 2, 'k', 'LineStyle', 'none', 'LineWidth', 2);

% Annotate sample sizes above the bars
xtips = barHandle.XEndPoints;
ytips = barHandle.YEndPoints;
labels = strcat('N = ', string(sampleSizes));
text(xtips, ytips - 1, labels, 'HorizontalAlignment', 'center', 'FontSize', 20);

% Customise the plot
xticks(1:2);
xticklabels({'Machine A', 'Machine B'});
ylabel('Coefficient of Variation (%)');
title(sprintf('Comparison of QuantStudio^{TM} 3 Machines'), 'Interpreter', 'tex');
grid on;
set(gca, 'FontSize', 20);

% Annotate p-value on the plot
if p < 0.0001
    pText = 'p < 0.0001';
else
    pText = sprintf('p = %.4f', p);
end
text(mean(xtips), max(ytips) + 0.5, pText, 'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', 'black');

hold off;

% Calculate Effect Sizes

% Calculate pooled standard deviation for Cohen's d
std1 = std(cvQS3_A_Inexperienced, 'omitnan');
std2 = std(cvQS3_B_Inexperienced, 'omitnan');
n1 = length(cvQS3_A_Inexperienced);
n2 = length(cvQS3_B_Inexperienced);
pooledStd = sqrt(((n1 - 1) * std1^2 + (n2 - 1) * std2^2) / (n1 + n2 - 2));

% Cohen's d
cohensD = (mean(cvQS3_A_Inexperienced, 'omitnan') - mean(cvQS3_B_Inexperienced, 'omitnan')) / pooledStd;

% Calculate rank-biserial correlation
U = ranksum(cvQS3_A_Inexperienced, cvQS3_B_Inexperienced, 'method', 'approximate');
rankBiserialR = 1 - (2 * U) / (n1 * n2);

% Display results
fprintf('Effect Size Analysis:\n');
fprintf('Cohen''s d: %.4f (Small: <0.2, Medium: 0.5, Large: >0.8)\n', cohensD);
fprintf('Rank-Biserial Correlation: %.4f (Small: <0.1, Medium: 0.3, Large: >0.5)\n', rankBiserialR);

% Save and close the figure
print(fig, 'Comparison of machines', '-dsvg', '-vector');
close(fig);

%% 13. Helper functions

% Function to sanitise field names
function validName = sanitiseFieldName(originalName)
    validName = matlab.lang.makeValidName(originalName);
end

% Function for plotting a bar chart with annotations (used in Section 3)
function plotBarWithAnnotations(ax, frequencies, colours, labels, sampleSizes, data, titleText, yLabel)
    % Create the bar chart on the provided axes
    barHandle = bar(ax, frequencies, 'FaceColor', 'flat');
    barHandle.CData = colours;
    xticks(ax, 1:length(labels));
    xticklabels(ax, labels);
    xtickangle(ax, 45);
    ylabel(ax, yLabel);
    title(ax, titleText);
    grid(ax, 'on');
    grid(ax, 'minor');
    set(ax, 'FontSize', 20);
    
    % Determine a starting y-axis limit (with some padding)
    yLimit = max(frequencies) * 1.2;
    % Annotate each bar with sample size and operator count
    for i = 1:length(sampleSizes)
        % Split label into components using " + " as delimiter
        labelParts = split(labels{i}, ' + ');
        instrumentName = labelParts{1};
        if numel(labelParts) >= 2
            detectionMethodName = labelParts{2};
        else
            detectionMethodName = ''; % no detection method specified
        end
        
        % Filter data for the current combination
        if ~isempty(detectionMethodName)
            subset = data(strcmp(data.Instrument, instrumentName) & ...
                          strcmp(data.Detection_method, detectionMethodName), :);
        else
            subset = data(strcmp(data.Instrument, instrumentName), :);
        end
        
        % Count unique operators
        uniqueOperators = unique(subset.Operator_number);
        operatorCount = length(uniqueOperators);
        
        % Create annotation text
        annotationText = sprintf('N = %d\nO = %d', sampleSizes(i), operatorCount);
        
        % Calculate y-position for annotation
        yPosition = frequencies(i) + (yLimit * 0.02);
        if yPosition > yLimit
            yLimit = yPosition * 1.1;
        end
        text(ax, i, yPosition, annotationText, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 20, 'Color', 'black');
    end
    
    ylim(ax, [0, 22]);
end

% Function for plotting with linear fit and vertical threshold line (used in Section 8)
function plot_with_fit(ax, x, y, titleText, calPeriod, textPosition)
    scatter(ax, x, y, 'MarkerEdgeColor', 'b', 'DisplayName', 'Data', 'LineWidth', 1.5);
    hold(ax, 'on');
    % Add vertical line for calibration threshold
    xline(ax, calPeriod, '--k', 'LineWidth', 2, 'Label', 'Calibration Expiry Threshold', ...
        'LabelHorizontalAlignment', 'left', 'FontSize', 16);
    % If enough data, compute linear fit and correlation
    if numel(x) > 1 && numel(y) > 1
        p = polyfit(x, y, 1);
        yFit = polyval(p, x);
        plot(ax, x, yFit, 'r', 'LineWidth', 2, 'DisplayName', 'Linear Fit');
        % Test for normality and compute correlation accordingly
        [h_x, ~] = kstest(x);
        [h_y, ~] = kstest(y);
        if h_x == 0 && h_y == 0
            [R, P] = corr(x, y, 'Type', 'Pearson', 'Rows', 'complete');
            disp('Using Pearson''s correlation (data is normally distributed).');
        else
            [R, P] = corr(x, y, 'Type', 'Spearman', 'Rows', 'complete');
            disp('Using Spearman''s correlation (data is not normally distributed).');
        end
        % Save correlation info in the axes UserData for later text annotation
        ax.UserData = struct('R', R, 'P', P, 'TextPosition', textPosition, 'TitleText', titleText);
    else
        ax.UserData = struct('R', NaN, 'P', NaN, 'TextPosition', textPosition, 'TitleText', titleText);
        text(ax, 0.5, 0.5, 'Not enough data for fit', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', 'k');
    end
    title(ax, titleText, 'FontSize', 20);
    xlabel(ax, 'Time elapsed since last calibration (days)', 'FontSize', 20);
    ylabel(ax, 'Coefficient of Variation (%)', 'FontSize', 20);
    grid(ax, 'on');
    grid(ax, 'minor');
    set(ax, 'FontSize', 20);
end

% Function for sections 10 and 11
function [timeTrendResults, sortedOperators, globalYLimits] = computeTimeTrends(data, opLevel, excludeOps)
    % Filter data by the specified operator level
    opData = data(strcmp(data.Operator_level, opLevel), :);
    % Get unique operators
    uniqueOps = unique(opData.Operator_number);
    if isnumeric(uniqueOps)
        uniqueOps = arrayfun(@num2str, uniqueOps, 'UniformOutput', false);
    else
        uniqueOps = cellstr(uniqueOps);
    end

    % Convert excludeOps to cell array of char if necessary
    if nargin >= 3 && ~isempty(excludeOps)
        excludeOps = cellstr(excludeOps);
        uniqueOps = setdiff(uniqueOps, excludeOps);
    end
    % Exclude any specified operators
    if nargin >= 3 && ~isempty(excludeOps)
        uniqueOps = setdiff(uniqueOps, excludeOps);
    end

    timeTrendResults = struct();
    slopes = [];
    operatorNames = {};
    allCVValues = [];
    
    % Group each operator's data by time
    for i = 1:length(uniqueOps)
        op = uniqueOps{i};
        opSubset = opData(opData.Operator_number == str2double(op), :);
        % Group data by day (adjust the interval if needed)
        opSubset.TimeGroup = discretize(opSubset.Run_date, 'day');
        uniqueTimeGroups = unique(opSubset.TimeGroup);
        timePoints = [];
        cvValues = [];
        for t = 1:length(uniqueTimeGroups)
            tg = uniqueTimeGroups(t);
            groupData = opSubset(opSubset.TimeGroup == tg, :);
            triplicateCVs = [];
            for run = unique(groupData.Run)'
                runData = groupData(groupData.Run == run, :);
                for rep = unique(runData.Replicate)'
                    repData = runData(runData.Replicate == rep, :);
                    if height(repData) == 3
                        Ct = repData.Ct;
                        CtMean = mean(Ct, 'omitnan');
                        CtSD = std(Ct, 'omitnan');
                        if CtMean > 0
                            CV = (CtSD / CtMean)*100;
                            triplicateCVs = [triplicateCVs; CV];
                        end
                    end
                end
            end
            if ~isempty(triplicateCVs)
                avgCV = mean(triplicateCVs, 'omitnan');
            else
                avgCV = NaN;
            end
            cvValues = [cvValues; avgCV];
            timePoints = [timePoints; min(groupData.Run_date)];  % use earliest date
        end
        
        % Fit a linear trendline if there are at least two points
        if length(timePoints) > 1
            numericTime = datenum(timePoints);
            p = polyfit(numericTime, cvValues, 1);
            slope = p(1);
        else
            slope = NaN;
        end
        
        % Store results for this operator
        timeTrendResults.(matlab.lang.makeValidName(op)) = struct(...
            'TimePoints', timePoints, ...
            'CVValues', cvValues, ...
            'Slope', slope);
        slopes = [slopes; slope];
        operatorNames = [operatorNames; op];
        allCVValues = [allCVValues; cvValues];
    end

    % Compute global y-axis limits based on all CV values
    globalYMin = min(allCVValues, [], 'omitnan');
    globalYMax = max(allCVValues, [], 'omitnan');
    yPadding = 0.2*(globalYMax - globalYMin);
    globalYLimits = [globalYMin, globalYMax+yPadding];
    
    % Sort operators by slope (ascending order)
    [~, sortedIndices] = sort(slopes, 'ascend');
    sortedOperators = operatorNames(sortedIndices);
end

% Function to calculate CVs for a dataset (used in Section 12)
function cvList = calculateTriplicateCVs(subset)
    cvList = [];
    for run = unique(subset.Run)'
        runData = subset(subset.Run == run, :);
        for replicateIndex = unique(runData.Replicate)'
            replicateData = runData(runData.Replicate == replicateIndex, :);
            if height(replicateData) == 3
                Ct = replicateData.Ct;
                CtMean = mean(Ct, 'omitnan');
                CtSD = std(Ct, 'omitnan');
                if CtMean > 0
                    CV = (CtSD / CtMean) * 100;
                    cvList = [cvList; CV];
                end
            end
        end
    end
end
