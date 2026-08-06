function result = detectContactEventsFromCom(comInput, varargin)
%DETECTCONTACTEVENTSFROMCOM Detect lift-off and re-contact from 3-D skull CoM.
%
% result = hsf.detectContactEventsFromCom(comInput)
%
% The detector uses displacement of the skull CoM from a supported baseline
% position. A two-threshold hysteresis strategy is used:
%   - lift-off: sustained displacement >= LiftOffThresholdM
%   - re-contact: sustained displacement <= RecontactThresholdM after peak
%
% Run this on the RAW Body Kinematics CoM trajectory rather than the
% 1000-Hz interpolated HSF trajectory so event timing reflects the native
% kinematic sampling resolution.
%
% REQUIRED INPUT
%   comInput       Struct with Time, X, Y, and Z.
%
% NAME-VALUE OPTIONS
%   BaselineWindow           [] -> first 0.5 s
%   LiftOffThresholdM        0.005
%   RecontactThresholdM      0.003
%   MinimumAboveDurationSec  0.10
%   MinimumBelowDurationSec  0.10
%   SmoothingWindowSec       0.05 (moving median; detection only)
%   SearchWindow             [] -> after baseline through end
%   Plot                     true
%   PlotFile                 ""
%   FigureVisible            "on"
%
% OUTPUT includes detected event times, displacement signals, baseline-noise
% metrics, a one-row Summary table, and the diagnostic figure handle.

    parser = inputParser;
    parser.FunctionName = "hsf.detectContactEventsFromCom";

    addRequired(parser, "comInput", @isstruct);
    addParameter(parser, "BaselineWindow", [], ...
        @(x) isempty(x) || (isnumeric(x) && numel(x)==2 && all(isfinite(x)) && x(2)>x(1)));
    addParameter(parser, "LiftOffThresholdM", 0.005, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>0);
    addParameter(parser, "RecontactThresholdM", 0.003, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>=0);
    addParameter(parser, "MinimumAboveDurationSec", 0.10, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>=0);
    addParameter(parser, "MinimumBelowDurationSec", 0.10, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>=0);
    addParameter(parser, "SmoothingWindowSec", 0.05, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>=0);
    addParameter(parser, "SearchWindow", [], ...
        @(x) isempty(x) || (isnumeric(x) && numel(x)==2 && all(isfinite(x)) && x(2)>x(1)));
    addParameter(parser, "Plot", true, @(x) islogical(x) && isscalar(x));
    addParameter(parser, "PlotFile", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "FigureVisible", "on", ...
        @(x) any(strcmpi(string(x), ["on","off"])));

    parse(parser, comInput, varargin{:});

    requiredFields = ["Time","X","Y","Z"];
    assert(all(isfield(comInput, requiredFields)), ...
        "hsf:InvalidComStructure", ...
        "comInput must contain Time, X, Y, and Z.");

    time = double(comInput.Time(:));
    x = double(comInput.X(:));
    y = double(comInput.Y(:));
    z = double(comInput.Z(:));

    n = numel(time);
    assert(n >= 3, "hsf:TooFewComSamples", ...
        "At least three CoM samples are required.");
    assert(all([numel(x),numel(y),numel(z)] == n), ...
        "hsf:ComLengthMismatch", ...
        "Time, X, Y, and Z must have equal lengths.");
    assert(all(isfinite([time,x,y,z]), "all"), ...
        "hsf:NonfiniteCom", "CoM input contains nonfinite values.");

    dt = diff(time);
    assert(all(dt > 0), "hsf:NonmonotonicComTime", ...
        "CoM time must be strictly increasing.");
    sampleRateHz = 1 / median(dt);

    if isempty(parser.Results.BaselineWindow)
        baselineWindow = [time(1), min(time(end), time(1)+0.50)];
    else
        baselineWindow = double(parser.Results.BaselineWindow(:).');
    end

    assert(baselineWindow(1) >= time(1) && baselineWindow(2) <= time(end), ...
        "hsf:BaselineOutsideComRange", ...
        "BaselineWindow is outside the CoM time range.");

    baselineMask = time >= baselineWindow(1) & time <= baselineWindow(2);
    assert(nnz(baselineMask) >= 3, ...
        "hsf:InsufficientBaselineSamples", ...
        "BaselineWindow contains fewer than three samples.");

    baselineX = median(x(baselineMask));
    baselineY = median(y(baselineMask));
    baselineZ = median(z(baselineMask));

    relativeX = x - baselineX;
    relativeY = y - baselineY;
    relativeZ = z - baselineZ;

    rawDisplacement = sqrt(relativeX.^2 + relativeY.^2 + relativeZ.^2);

    smoothingWindowSec = double(parser.Results.SmoothingWindowSec);
    if smoothingWindowSec > 0
        smoothingSamples = max(1, round(smoothingWindowSec * sampleRateHz));
        if mod(smoothingSamples,2) == 0
            smoothingSamples = smoothingSamples + 1;
        end
        detectionDisplacement = movmedian(rawDisplacement, smoothingSamples, ...
            "Endpoints", "shrink");
    else
        smoothingSamples = 1;
        detectionDisplacement = rawDisplacement;
    end

    liftThreshold = double(parser.Results.LiftOffThresholdM);
    recontactThreshold = double(parser.Results.RecontactThresholdM);
    assert(recontactThreshold < liftThreshold, ...
        "hsf:InvalidHysteresisThresholds", ...
        "RecontactThresholdM must be lower than LiftOffThresholdM.");

    if isempty(parser.Results.SearchWindow)
        searchWindow = [baselineWindow(2), time(end)];
    else
        searchWindow = double(parser.Results.SearchWindow(:).');
    end

    assert(searchWindow(1) >= time(1) && searchWindow(2) <= time(end), ...
        "hsf:SearchWindowOutsideComRange", ...
        "SearchWindow is outside the CoM time range.");

    searchIndices = find(time >= searchWindow(1) & time <= searchWindow(2));
    assert(~isempty(searchIndices), "hsf:EmptySearchWindow", ...
        "SearchWindow contains no CoM samples.");

    minAboveSamples = max(1, ceil(double(parser.Results.MinimumAboveDurationSec)*sampleRateHz));
    minBelowSamples = max(1, ceil(double(parser.Results.MinimumBelowDurationSec)*sampleRateHz));

    above = detectionDisplacement >= liftThreshold;
    liftOffIndex = localFindFirstSustainedRun(above, searchIndices(1), ...
        searchIndices(end), minAboveSamples);
    assert(~isempty(liftOffIndex), "hsf:LiftOffNotDetected", ...
        "No sustained lift-off crossing detected at %.3f m for %.3f s.", ...
        liftThreshold, parser.Results.MinimumAboveDurationSec);

    postLiftIndices = liftOffIndex:searchIndices(end);
    [peakExcursionM, peakRelativeIndex] = max(detectionDisplacement(postLiftIndices));
    peakIndex = postLiftIndices(peakRelativeIndex);

    below = detectionDisplacement <= recontactThreshold;
    recontactIndex = localFindFirstSustainedRun(below, peakIndex+1, ...
        searchIndices(end), minBelowSamples);
    assert(~isempty(recontactIndex), "hsf:RecontactNotDetected", ...
        "No sustained re-contact crossing detected at %.3f m for %.3f s after peak.", ...
        recontactThreshold, parser.Results.MinimumBelowDurationSec);

    liftOffTime = time(liftOffIndex);
    recontactTime = time(recontactIndex);
    assert(recontactTime > liftOffTime, "hsf:InvalidDetectedEventOrder", ...
        "Detected re-contact does not occur after lift-off.");

    baselineDisplacement = rawDisplacement(baselineMask);
    baselineMedianM = median(baselineDisplacement);
    baselineMaxM = max(baselineDisplacement);
    baselineP95M = prctile(baselineDisplacement,95);
    baselineMadM = median(abs(baselineDisplacement-baselineMedianM));

    baselineNoise = struct;
    baselineNoise.MedianM = baselineMedianM;
    baselineNoise.MaximumM = baselineMaxM;
    baselineNoise.P95M = baselineP95M;
    baselineNoise.MadM = baselineMadM;

    summary = table( ...
        sampleRateHz, baselineWindow(1), baselineWindow(2), ...
        baselineMedianM, baselineP95M, baselineMaxM, ...
        liftThreshold, recontactThreshold, ...
        parser.Results.MinimumAboveDurationSec, ...
        parser.Results.MinimumBelowDurationSec, ...
        smoothingWindowSec, smoothingSamples, ...
        liftOffTime, recontactTime, recontactTime-liftOffTime, ...
        peakExcursionM, time(peakIndex), ...
        'VariableNames', { ...
        'SampleRateHz','BaselineStartTime','BaselineEndTime', ...
        'BaselineMedianDisplacementM','BaselineP95DisplacementM', ...
        'BaselineMaximumDisplacementM','LiftOffThresholdM', ...
        'RecontactThresholdM','MinimumAboveDurationSec', ...
        'MinimumBelowDurationSec','SmoothingWindowSec', ...
        'SmoothingWindowSamples','LiftOffTime','RecontactTime', ...
        'OffSupportDurationSec','PeakExcursionM','PeakExcursionTime'});

    figureHandle = [];
    if parser.Results.Plot
        figureHandle = figure("Name","HSF Contact Event Detection", ...
            "Visible",char(parser.Results.FigureVisible));
        layout = tiledlayout(figureHandle,4,1, ...
            "TileSpacing","compact","Padding","compact");

        nexttile(layout);
        plot(time,relativeX*1000,"LineWidth",1); hold on;
        xline(liftOffTime,"--","Lift-off");
        xline(recontactTime,"--","Re-contact");
        ylabel("\\DeltaX (mm)"); grid on;

        nexttile(layout);
        plot(time,relativeY*1000,"LineWidth",1); hold on;
        xline(liftOffTime,"--","Lift-off");
        xline(recontactTime,"--","Re-contact");
        ylabel("\\DeltaY (mm)"); grid on;

        nexttile(layout);
        plot(time,relativeZ*1000,"LineWidth",1); hold on;
        xline(liftOffTime,"--","Lift-off");
        xline(recontactTime,"--","Re-contact");
        ylabel("\\DeltaZ (mm)"); grid on;

        nexttile(layout);
        plot(time,rawDisplacement*1000,"LineWidth",0.8, ...
            "DisplayName","Raw 3-D displacement"); hold on;
        plot(time,detectionDisplacement*1000,"LineWidth",1.5, ...
            "DisplayName","Detection signal");
        yline(liftThreshold*1000,":","Lift-off threshold", ...
            "HandleVisibility","off");
        yline(recontactThreshold*1000,":","Re-contact threshold", ...
            "HandleVisibility","off");
        xline(liftOffTime,"--","Lift-off","HandleVisibility","off");
        xline(recontactTime,"--","Re-contact","HandleVisibility","off");
        ylabel("3-D displacement (mm)"); xlabel("Time (s)");
        grid on; legend("Location","best");

        title(layout,sprintf("Skull CoM event detection | lift-off %.3f s | re-contact %.3f s | peak %.1f mm", ...
            liftOffTime,recontactTime,peakExcursionM*1000));

        plotFile = string(parser.Results.PlotFile);
        if strlength(plotFile) > 0
            [plotFolder,~,~] = fileparts(plotFile);
            if strlength(string(plotFolder)) > 0 && ~isfolder(plotFolder)
                mkdir(plotFolder);
            end
            exportgraphics(figureHandle,plotFile,"Resolution",200);
        end
    end

    result = struct;
    result.LiftOffTime = liftOffTime;
    result.RecontactTime = recontactTime;
    result.LiftOffIndex = liftOffIndex;
    result.RecontactIndex = recontactIndex;
    result.PeakExcursionM = peakExcursionM;
    result.PeakExcursionTime = time(peakIndex);
    result.BaselinePositionM = [baselineX,baselineY,baselineZ];
    result.BaselineWindow = baselineWindow;
    result.BaselineNoise = baselineNoise;
    result.RawDisplacementM = rawDisplacement;
    result.DetectionDisplacementM = detectionDisplacement;
    result.RelativeX = relativeX;
    result.RelativeY = relativeY;
    result.RelativeZ = relativeZ;
    result.Summary = summary;
    result.Figure = figureHandle;
end

function runStart = localFindFirstSustainedRun(logicalSignal,startIndex,endIndex,minimumLength)
    runStart = [];
    if startIndex > endIndex
        return;
    end
    signal = logicalSignal(startIndex:endIndex);
    if isempty(signal)
        return;
    end
    padded = [false; signal(:); false];
    transitions = diff(padded);
    runStarts = find(transitions==1);
    runEnds = find(transitions==-1)-1;
    runLengths = runEnds-runStarts+1;
    qualifying = find(runLengths>=minimumLength,1,"first");
    if isempty(qualifying)
        return;
    end
    runStart = startIndex + runStarts(qualifying)-1;
end
