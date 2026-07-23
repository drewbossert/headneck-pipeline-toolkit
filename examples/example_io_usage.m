%% example_io_usage.m
% Add the toolkit root, not the +opensimio folder itself, to the MATLAB path.

toolkitRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(toolkitRoot);

%% Read and write a motion file

motion = opensimio.readMot( ...
    "C:\path\to\input_coordinates.mot");

fprintf("Rows: %d\n", motion.NumRows);
fprintf("Columns: %d\n", motion.NumColumns);
fprintf("inDegrees: %g\n", motion.InDegrees);

% Example: inspect pitch1.
pitch1Index = find(motion.Labels == "pitch1", 1);

if ~isempty(pitch1Index)
    pitch1Values = motion.Data(:, pitch1Index);
    fprintf("pitch1 range: %.6f to %.6f\n", ...
        min(pitch1Values), max(pitch1Values));
end

% Round-trip write after any edits to motion.Data or motion.Labels.
opensimio.writeMot( ...
    "C:\path\to\output_coordinates.mot", ...
    motion);

%% Read and write an STO file

storage = opensimio.readSto( ...
    "C:\path\to\results.sto");

opensimio.writeSto( ...
    "C:\path\to\results_copy.sto", ...
    storage);

%% Read, edit, and write XML with DOM methods

xmlData = opensimio.readXml( ...
    "C:\path\to\ik_setup.xml");

modelNodes = xmlData.Document.getElementsByTagName("model_file");

if modelNodes.getLength() ~= 1
    error("Expected exactly one <model_file> element.");
end

modelNodes.item(0).setTextContent( ...
    "C:\path\to\trial_model.osim");

opensimio.writeXml( ...
    "C:\path\to\ik_setup_trial.xml", ...
    xmlData);

%% Render a text/XML template

template = opensimio.readTemplate( ...
    "C:\path\to\ik_setup_template.xml");

values = struct;
values.MODEL_FILE = "C:\path\to\trial_model.osim";
values.MARKER_FILE = "C:\path\to\trial_markers.trc";
values.OUTPUT_MOTION_FILE = "C:\path\to\trial_ik.mot";

[renderedXml, report] = opensimio.renderTemplate( ...
    template, ...
    values, ...
    "Strict", true, ...
    "EscapeXmlValues", true);

disp(report);

opensimio.writeText( ...
    "C:\path\to\ik_setup_rendered.xml", ...
    renderedXml);
