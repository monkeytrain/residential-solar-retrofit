%% SYS 800 - Integrated Residential Solar Retrofit Decision Model
% Run from the project root containing data/, +sim/, and +econ/.
% Homeowner inputs are collected interactively once per run.
clear; clc; close all;

%% Homeowner inputs
analysisStartYear = 2027;
homeownerInputs = struct();

while true
    value = input('Enter home square footage (sq ft): ');
    if isnumeric(value) && isscalar(value) && isfinite(value) && value > 0
        homeownerInputs.homeArea_sqft = value;
        break;
    end
    fprintf('Please enter a positive number.\n');
end

while true
    value = input('Enter existing PV capacity (kW): ');
    if isnumeric(value) && isscalar(value) && isfinite(value) && value > 0
        homeownerInputs.existingPV_kW = value;
        break;
    end
    fprintf('Please enter a positive number.\n');
end

while true
    value = input('Enter PV installation/interconnection year: ');
    if isnumeric(value) && isscalar(value) && isfinite(value) && ...
            value == floor(value) && value >= 1900 && value <= analysisStartYear
        homeownerInputs.pvInstallationYear = value;
        break;
    end
    fprintf('Please enter a whole-number year from 1900 through %d.\n',analysisStartYear);
end

% Installation and original grid interconnection are assumed to occur in the same year.
homeownerInputs.originalInterconnectionYear = homeownerInputs.pvInstallationYear;

fprintf('\n=== SELECTED HOMEOWNER INPUTS ===\n');
fprintf('Home size: %.0f sq ft\n',homeownerInputs.homeArea_sqft);
fprintf('Existing PV capacity: %.2f kW\n',homeownerInputs.existingPV_kW);
fprintf('PV installation/interconnection year: %d\n',homeownerInputs.pvInstallationYear);
fprintf('Derived PV age in %d: %d years\n',analysisStartYear, ...
    analysisStartYear-homeownerInputs.pvInstallationYear);
fprintf('Assumed NEM expiration year: %d\n',homeownerInputs.pvInstallationYear+20);

fprintf('\n=== RUNNING TECHNICAL MODEL ===\n');
run('technical_model.m');
fprintf('\n=== RUNNING LIFECYCLE ANALYSIS ===\n');
run('lifecycle_analysis.m');
fprintf('\n=== GENERATING REPORT FIGURES ===\n');
run('report_figures.m');
fprintf('\n=== INTEGRATED MODEL COMPLETED ===\n');
