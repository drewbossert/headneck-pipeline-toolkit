function [model, report] = setConstraintEnforcement( ...
        modelInput, enforced, varargin)
%SETCONSTRAINTENFORCEMENT Enable or disable model constraints.
%
% [model, report] = modelprep.setConstraintEnforcement(modelInput, enforced)
%
% Name-value options:
%   ConstraintNames  string array; default all constraints
%   ConstraintClass  class name filter; default ""
%   AllowMissing     false (default)
%
% The serialized isEnforced property and initialized-state enforcement are
% both checked in the returned report.

    parser = inputParser;
    parser.FunctionName = "modelprep.setConstraintEnforcement";

    addRequired(parser, "modelInput");
    addRequired(parser, "enforced", ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "ConstraintNames", strings(0,1), ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));

    addParameter(parser, "ConstraintClass", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "AllowMissing", false, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, modelInput, enforced, varargin{:});

    model = modelprep.internal.resolveModel(modelInput);
    requestedNames = string(parser.Results.ConstraintNames);
    requestedNames = requestedNames(:);
    classFilter = string(parser.Results.ConstraintClass);

    constraintSet = model.getConstraintSet();
    nConstraints = constraintSet.getSize();

    selected = false(nConstraints, 1);
    names = strings(nConstraints, 1);
    classes = strings(nConstraints, 1);
    previous = false(nConstraints, 1);

    for index = 0:nConstraints-1
        constraint = constraintSet.get(index);
        row = index + 1;

        names(row) = modelprep.internal.osimString( ...
            constraint.getName());

        classes(row) = modelprep.internal.osimString( ...
            constraint.getConcreteClassName());

        previous(row) = logical(constraint.get_isEnforced());

        nameMatch = isempty(requestedNames) || ...
            any(names(row) == requestedNames);

        classMatch = strlength(classFilter) == 0 || ...
            classes(row) == classFilter;

        selected(row) = nameMatch && classMatch;

        if selected(row)
            constraint.set_isEnforced(enforced);
        end
    end

    if ~isempty(requestedNames)
        missingNames = setdiff(requestedNames, names(selected), "stable");

        if ~isempty(missingNames) && ~parser.Results.AllowMissing
            error("modelprep:MissingConstraint", ...
                "Constraint(s) not found: %s", ...
                strjoin(missingNames, ", "));
        end
    end

    [model, state] = modelprep.internal.finalizeAndInitialize(model);

    selectedIndices = find(selected);
    nSelected = numel(selectedIndices);

    Constraint = strings(nSelected, 1);
    ConstraintClass = strings(nSelected, 1);
    PreviousPropertyEnforced = false(nSelected, 1);
    NewPropertyEnforced = false(nSelected, 1);
    NewStateEnforced = false(nSelected, 1);

    for outputIndex = 1:nSelected
        sourceIndex = selectedIndices(outputIndex);
        constraint = constraintSet.get(sourceIndex - 1);

        Constraint(outputIndex) = names(sourceIndex);
        ConstraintClass(outputIndex) = classes(sourceIndex);
        PreviousPropertyEnforced(outputIndex) = previous(sourceIndex);
        NewPropertyEnforced(outputIndex) = ...
            logical(constraint.get_isEnforced());
        NewStateEnforced(outputIndex) = ...
            logical(constraint.isEnforced(state));
    end

    report = table( ...
        Constraint, ConstraintClass, ...
        PreviousPropertyEnforced, ...
        NewPropertyEnforced, NewStateEnforced, ...
        'VariableNames', { ...
            'Constraint', 'ConstraintClass', ...
            'PreviousPropertyEnforced', ...
            'NewPropertyEnforced', 'NewStateEnforced'});
end
