function tests = test_opensimio_roundtrip
%TEST_OPENSIMIO_ROUNDTRIP Basic MATLAB unit tests for the toolkit.

    tests = functiontests(localfunctions);
end

function testMotRoundTrip(testCase)

    temporaryFolder = tempname;
    mkdir(temporaryFolder);
    cleanupObject = onCleanup(@() rmdir(temporaryFolder, "s")); %#ok<NASGU>

    inputFile = fullfile(temporaryFolder, "input.mot");
    outputFile = fullfile(temporaryFolder, "output.mot");

    content = [
        "synthetic_motion"
        "version=1"
        "nRows=3"
        "nColumns=3"
        "inDegrees=yes"
        "endheader"
        "time" + sprintf('\t') + "pitch1" + sprintf('\t') + "pitch2"
        "0" + sprintf('\t') + "1" + sprintf('\t') + "2"
        "0.01" + sprintf('\t') + "3" + sprintf('\t') + "4"
        "0.02" + sprintf('\t') + "5" + sprintf('\t') + "6"
    ];

    opensimio.writeText(inputFile, strjoin(content, newline));

    inputData = opensimio.readMot(inputFile);
    opensimio.writeMot(outputFile, inputData);
    outputData = opensimio.readMot(outputFile);

    verifyEqual(testCase, outputData.Labels, inputData.Labels);
    verifyEqual(testCase, outputData.Data, inputData.Data);
    verifyTrue(testCase, outputData.InDegrees);
end

function testTemplateRendering(testCase)

    templateText = ...
        "<model_file>{{MODEL_FILE}}</model_file>" + newline + ...
        "<output>{{OUTPUT_FILE}}</output>";

    values = struct( ...
        "MODEL_FILE", "model.osim", ...
        "OUTPUT_FILE", "result.mot");

    rendered = opensimio.renderTemplate( ...
        templateText, values);

    verifyTrue(testCase, contains(rendered, "model.osim"));
    verifyTrue(testCase, contains(rendered, "result.mot"));
    verifyFalse(testCase, contains(rendered, "{{"));
end
