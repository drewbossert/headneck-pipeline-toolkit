function report = inspectModel(modelInput)
%INSPECTMODEL Return coordinate and constraint configuration tables.
%
% report = modelprep.inspectModel(modelInput)

    [model, state] = modelprep.loadModel(modelInput);

    coordinateSet = model.getCoordinateSet();
    nCoordinates = coordinateSet.getSize();

    Coordinate = strings(nCoordinates, 1);
    Joint = strings(nCoordinates, 1);
    CoordinateType = strings(nCoordinates, 1);
    DefaultValueSI = nan(nCoordinates, 1);
    RangeMinSI = nan(nCoordinates, 1);
    RangeMaxSI = nan(nCoordinates, 1);
    DefaultLocked = false(nCoordinates, 1);
    DefaultClamped = false(nCoordinates, 1);
    DefaultPrescribed = false(nCoordinates, 1);
    StateLocked = false(nCoordinates, 1);
    StateClamped = false(nCoordinates, 1);
    StatePrescribed = false(nCoordinates, 1);
    StateDependent = false(nCoordinates, 1);
    StateConstrained = false(nCoordinates, 1);

    for index = 0:nCoordinates-1
        coordinate = coordinateSet.get(index);
        row = index + 1;

        Coordinate(row) = modelprep.internal.osimString( ...
            coordinate.getName());

        Joint(row) = modelprep.internal.osimString( ...
            coordinate.getJoint().getName());

        CoordinateType(row) = ...
            modelprep.internal.inferCoordinateType(coordinate);

        DefaultValueSI(row) = coordinate.getDefaultValue();
        RangeMinSI(row) = coordinate.getRangeMin();
        RangeMaxSI(row) = coordinate.getRangeMax();

        DefaultLocked(row) = logical(coordinate.getDefaultLocked());
        DefaultClamped(row) = logical(coordinate.getDefaultClamped());
        DefaultPrescribed(row) = ...
            logical(coordinate.getDefaultIsPrescribed());

        StateLocked(row) = logical(coordinate.getLocked(state));
        StateClamped(row) = logical(coordinate.getClamped(state));
        StatePrescribed(row) = logical(coordinate.isPrescribed(state));
        StateDependent(row) = logical(coordinate.isDependent(state));
        StateConstrained(row) = logical(coordinate.isConstrained(state));
    end

    coordinates = table( ...
        Coordinate, Joint, CoordinateType, ...
        DefaultValueSI, RangeMinSI, RangeMaxSI, ...
        DefaultLocked, DefaultClamped, DefaultPrescribed, ...
        StateLocked, StateClamped, StatePrescribed, ...
        StateDependent, StateConstrained, ...
        'VariableNames', { ...
            'Coordinate', 'Joint', 'CoordinateType', ...
            'DefaultValueSI', 'RangeMinSI', 'RangeMaxSI', ...
            'DefaultLocked', 'DefaultClamped', ...
            'DefaultPrescribed', 'StateLocked', ...
            'StateClamped', 'StatePrescribed', ...
            'StateDependent', 'StateConstrained'});

    constraintSet = model.getConstraintSet();
    nConstraints = constraintSet.getSize();

    Constraint = strings(nConstraints, 1);
    ConstraintClass = strings(nConstraints, 1);
    PropertyEnforced = false(nConstraints, 1);
    StateEnforced = false(nConstraints, 1);

    for index = 0:nConstraints-1
        constraint = constraintSet.get(index);
        row = index + 1;

        Constraint(row) = modelprep.internal.osimString( ...
            constraint.getName());

        ConstraintClass(row) = modelprep.internal.osimString( ...
            constraint.getConcreteClassName());

        PropertyEnforced(row) = ...
            logical(constraint.get_isEnforced());

        StateEnforced(row) = ...
            logical(constraint.isEnforced(state));
    end

    constraints = table( ...
        Constraint, ConstraintClass, ...
        PropertyEnforced, StateEnforced, ...
        'VariableNames', { ...
            'Constraint', 'ConstraintClass', ...
            'PropertyEnforced', 'StateEnforced'});

    report = struct;
    report.ModelName = modelprep.internal.osimString(model.getName());
    report.Coordinates = coordinates;
    report.Constraints = constraints;
end
