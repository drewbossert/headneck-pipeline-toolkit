%% assess_initialization_ik_psd.m
% Diagnostic script for evalluating frequency content of selected
% initialization-IK coordinates before Model B lock extraction.
%
% This script does NOT modify any pipeline data.
%
% Primary questions:
%   1. Are yaw1/yaw2 dominated by low-frequency physical motion or
%       higher-frequency IK noise?
%   2. How do yaw1/yaw2 compare with roll1/roll2?
%   3. What fraction of signal power lies above candidate filter cutoffs?

clear;
clc;

%% 0. Load project configuration

scriptPath = string(mfilename("fullpath"));
examplesDirectory = string(fileparts(scriptPath));
projectRoot = string(fileparts(examplesDirectory));

addpath(projectRoot);

projectCfg = load_project_config();

%% 1. Trial settings

trialCfg = struct;

trialCfg.conditionDeg = 0;
trialCfg.trialNumber = 1;

% Independent out-of-plane coordinates.
% roll1/roll2 are included as comparison channels.
trialCfg.coordinates = [ ...
    "roll1"
    "yaw1"
    "roll2"
    "yaw2"
];

% Candidate freqs used only for reporting spectral power.
% These are NOT proposed filter cutoffs yet.
trialCfg.candidateCutoffsHz = [ ...
    0.5
    1
    2
    3
    5
    10
];

%% 2. Resolve Phase A IK motion files

conditionTag = sprintf("%02ddeg", trialCfg.conditionDeg);
trialTag = sprintf("trial%02d", trialCfg.trialNumber);

phaseADirectory = fullfile( ...
    projectCfg.outputRoot, ...
    conditionTag, ...
    trialTag, ...
    "01_initialization_ik");

ikMotionFile = fullfile( ...
    phaseADirectory, ...
    sprintf("%02ddeg_trial%02d_initialization_ik.mot", ...
    trialCfg.conditionDeg, ...
    trialCfg.trialNumber));

assert(isfile(ikMotionFile), ...
    "Initialization IK motion file not found:\n%s", ...
    ikMotionFile);

fprintf("Initialization IK file:\n%s\n\n", ikMotionFile);

%% 3. Read IK motion

ikMotion = opensimio.readMot(ikMotionFile);

assert(isstruct(ikMotion), ...
    "opensimio.readMot did not return the expected struct.");

requiredFields = [
    "Labels"
    "Data"
    "Time"
    "InDegrees"
];

for iField = 1:numel(requiredFields)

    fieldName = requiredFields(iField);

    assert(isfield(ikMotion, fieldName), ...
        "IK motion struct is missing required field '%s'.", ...
        fieldName);

end

labels = reshape(string(ikMotion.Labels), 1, []);
data   = ikMotion.Data;
time   = ikMotion.Time;

assert(isnumeric(data) && ismatrix(data), ...
    "ikMotion.Data must be a two-dimensional numeric array.");

assert(size(data, 2) == numel(labels), ...
    ["Number of columns in ikMotion.Data (%d) does not match " ...
     "number of labels (%d)."], ...
    size(data, 2), numel(labels));

assert(numel(time) == size(data, 1), ...
    "Length of ikMotion.Time does not match number of data rows.");

assert(all(isfinite(time)), ...
    "Time vector contains nonfinite values.");

assert(all(diff(time) > 0), ...
    "Time vector must be strictly increasing.");

% These diagnostic coordinates are rotational, so report everything
% consistently in degrees.
if ~ikMotion.InDegrees
    warning( ...
        ["IK file reports InDegrees = false. Selected rotational " ...
         "coordinates will be converted from radians to degrees " ...
         "for the PSD assessment."]);
end

%% 4. Determine sampling frequency

dt = diff(time);

medianDt = median(dt);
Fs = 1 / medianDt;

numSamples = size(data, 1);

fprintf("Samples:             %d\n", numSamples);
fprintf("Duration:            %.3f s\n", time(end) - time(1));
fprintf("Median sample dt:    %.6f s\n", medianDt);
fprintf("Estimated Fs:        %.3f Hz\n", Fs);
fprintf("Maximum dt deviation %.3e s\n\n", ...
    max(abs(dt - medianDt)));

% Require approximately uniform sampling for Welch PSD.
relativeDtVariation = max(abs(dt - medianDt)) / medianDt;

assert(relativeDtVariation < 1e-3, ...
    "Time samples are not sufficiently uniform for direct PSD analysis.");

%% 5. Validate requested coordinates

for i = 1:numel(trialCfg.coordinates)

    coordinate = trialCfg.coordinates(i);

    matches = find(labels == coordinate);

    assert(~isempty(matches), ...
        "Coordinate '%s' was not found in the IK motion file.", ...
        coordinate);

    assert(numel(matches) == 1, ...
        "Coordinate '%s' occurs more than once in the IK motion file.", ...
        coordinate);

end

%% 6. Configure Welch PSD

% Use approximately 4-second Welch segments where possible.
desiredSegmentDuration = 4.0;

segmentSamples = round(desiredSegmentDuration * Fs);

% Do not allow segment length to exceed the available trajectory.
segmentSamples = min(segmentSamples, numSamples);

% Ensure a reasonable minimum.
segmentSamples = max(segmentSamples, 32);

window = hann(segmentSamples, "periodic");

noverlap = floor(segmentSamples / 2);

% Pad FFT for convenient spectral display.
nfft = max(1024, 2^nextpow2(segmentSamples));

fprintf("Welch segment length: %d samples (%.2f s)\n", ...
    segmentSamples, segmentSamples / Fs);

fprintf("Welch overlap:         %d samples\n", noverlap);
fprintf("FFT length:            %d\n\n", nfft);

%% 7. Calculate PSD and spectral metrics

summaryRows = table;
spectrumRows = table;

for i = 1:numel(trialCfg.coordinates)

    coordinate = trialCfg.coordinates(i);

    columnIndex = find(labels == coordinate, 1);

    raw = data(:, columnIndex);

    assert(all(isfinite(raw)), ...
        "Coordinate '%s' contains nonfinite values.", ...
        coordinate);

    % Convert rotational coordinate values to degrees if necessary.
    if ~ikMotion.InDegrees
        raw = rad2deg(raw);
    end

    % Remove mean and linear trend before PSD calculation.
    signal = detrend(raw, 1);

    [pxx, frequency] = pwelch( ...
        signal, ...
        window, ...
        noverlap, ...
        nfft, ...
        Fs, ...
        "psd");

    totalPower = trapz(frequency, pxx);

    cumulativePower = cumtrapz(frequency, pxx);

    if totalPower > 0
        cumulativeFraction = cumulativePower ./totalPower;
    else
        cumulativeFraction = zeros(size(cumulativePower));
    end

    % Frequency below which 95% of spectral power occurs.
    idx95 = find(cumulativeFraction >= 0.95, 1, "first");

    if isempty(idx95)
        f95 = NaN;
    else
        f95 = frequency(idx95);
    end

    % Basic time-domain metrics
    rawRangeDeg = range(raw);
    rawStdDeg = std(raw);
    detrendedStdDeg = std(signal);

    % Create one summary row per coordinate.
    row = table( ...
        coordinate, ...
        rawRangeDeg, ...
        rawStdDeg, ...
        detrendedStdDeg, ...
        f95, ...
        'VariableNames', { ...
            'Coordinate', ...
            'RawRangeDeg', ...
            'RawStdDeg', ...
            'DetrendedStdDeg', ...
            'Frequency95PowerHz'});

    % Add power fractions above candidate cutoff frequencies.
    for j = 1:numel(trialCfg.candidateCutoffsHz)

        cutoff = trialCfg.candidateCutoffsHz(j);

        highMask = frequency >= cutoff;

        highPower = trapz( ...
            frequency(highMask), ...
            pxx(highMask));

        if totalPower > 0
            fractionAbove = highPower / totalPower;
        else
            fractionAbove = NaN;
        end

        variableName = sprintf( ...
            "PowerAbove_%gpct", cutoff);

        % Make legal MATLAB variable name.
        variableName = matlab.lang.makeValidName(variableName);

        row.(variableName) = fractionAbove * 100;

    end

    summaryRows = [summaryRows; row]; %#ok<AGROW>

    % Save full spectrum for later inspection if desired.
    spectrumTable = table( ...
        repmat(coordinate, numel(frequency), 1), ...
        frequency, ...
        pxx, ...
        cumulativeFraction, ...
        'VariableNames', { ...
            'Coordinate', ...
            'FrequencyHz', ...
            'PSD', ...
            'CumulativePowerFraction'});

     spectrumRows = [spectrumRows; spectrumTable]; %#ok<AGROW>

end

%% 8. Display summary

fprintf("\nPSD summary:\n\n");
disp(summaryRows);

%% 9. Plot raw coordinate trajectories

figure( ...
    "Name", "Initialization IK - Out-of-plane coordinates", ...
    "Color", "w");

tiledlayout(2, 2);

for i = 1:numel(trialCfg.coordinates)

    coordinate = trialCfg.coordinates(i);

    columnIndex = find(labels == coordinate, 1);

    raw = data(:, columnIndex);

    if ~ikMotion.InDegrees
        raw = rad2deg(raw);
    end

    nexttile;

    plot(time, raw, "LineWidth", 1);

    grid on;

    xlabel("Time (s)");
    ylabel("Angle (deg)");
    title(coordinate, "Interpreter", "none");

end

sgtitle("Initialization IK coordinate trajectories");

%% 10. Plot power spectral densities

figure( ...
    "Name", "Initialization IK - Coordinate PSD", ...
    "Color", "w");

tiledlayout(2, 2);

for i = 1:numel(trialCfg.coordinates)

    coordinate = trialCfg.coordinates(i);

    rows = spectrumRows.Coordinate == coordinate;

    frequency = spectrumRows.FrequencyHz(rows);
    pxx = spectrumRows.PSD(rows);

    nexttile;

    semilogy(frequency, pxx, "LineWidth", 1);

    grid on;

    xlabel("Frequency (Hz)");
    ylabel("PSD (deg^2/Hz)");
    title(coordinate, "Interpreter", "none");

    % Initially focus on frequencies relevant to likely filtering.
    xlim([0 min(20, Fs/2)]);

end

sgtitle("Welch PSD of detrended initialization IK coordinates");

%% 11. Plot cumulative spectral power

figure( ...
    "Name", "Initialization IK - Cumulative spectral power", ...
    "Color", "w");

tiledlayout(2, 2);

for i = 1:numel(trialCfg.coordinates)

    coordinate = trialCfg.coordinates(i);

    rows = spectrumRows.Coordinate == coordinate;

    frequency = spectrumRows.FrequencyHz(rows);
    cumulativePower = ...
        spectrumRows.CumulativePowerFraction(rows);

    nexttile;

    plot( ...
        frequency, ...
        cumulativePower * 100, ...
        "LineWidth", 1);

    hold on;
    yline(95, "--");
    hold off;
    
    grid on;

    xlabel("Frequency (Hz)");
    ylabel("Cumulative power (%)");
    title(coordinate, "Interpreter", "none");

    ylim([0 100]);
    xlim([0 min(20, Fs/2)]);

end

sgtitle("Cumulative spectral power");

%% 12. Save diagnostic tables

qcDirectory = fullfile(phaseADirectory, "qc");

if ~isfolder(qcDirectory)
    mkdir(qcDirectory);
end

summaryFile = fullfile( ...
    qcDirectory, ...
    "initialization_ik_psd_summary.csv");

spectrumFile = fullfile( ...
    qcDirectory, ...
    "initialization_ik_psd_spectrum.csv");

writetable(summaryRows, summaryFile);
writetable(spectrumRows, spectrumFile);

fprintf("\nSaved PSD summary:\n%s\n", summaryFile);
fprintf("\nSaved full PSD spectrum:\n%s\n", spectrumFile);