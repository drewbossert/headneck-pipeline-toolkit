function tf = hasExplicitStrengthBoundaryBracket(summary)
%HASEXPLICITSTRENGTHBOUNDARYBRACKET Test for comparable boundary evidence.
%
% tf = soopt.hasExplicitStrengthBoundaryBracket(summary)
%
% Returns true when the assessed evidence contains at least one infeasible
% configuration that is no stronger in either dimension than an assessed
% feasible configuration. Such a comparable pair explicitly brackets a
% monotonic feasible/infeasible boundary.
%
% Feasible and infeasible observations that trade muscle capacity against
% actuator capacity are incomparable and do not form an explicit bracket.
%
% This function is side-effect free.

    assert(istable(summary), ...
        "StrengthBoundaryBracket:InvalidSummary", ...
        "summary must be a table.");

    requiredVariables = [
        "MusclePercent"
        "ActuatorPercent"
        "AssessmentComplete"
        "IsFeasible"
    ];

    missingVariables = ...
        requiredVariables( ...
            ~ismember( ...
                requiredVariables, ...
                string(summary.Properties.VariableNames)));

    assert(isempty(missingVariables), ...
        "StrengthBoundaryBracket:VariablesMissing", ...
        "summary is missing required variables: %s", ...
        strjoin(missingVariables, ", "));

    assessed = ...
        logical(summary.AssessmentComplete);

    feasible = ...
        assessed & ...
        logical(summary.IsFeasible);

    infeasible = ...
        assessed & ...
        ~logical(summary.IsFeasible);

    feasibleMuscle = ...
        double(summary.MusclePercent(feasible));

    feasibleActuator = ...
        double(summary.ActuatorPercent(feasible));

    infeasibleMuscle = ...
        double(summary.MusclePercent(infeasible));

    infeasibleActuator = ...
        double(summary.ActuatorPercent(infeasible));

    tf = ...
        false;

    for iInfeasible = 1:numel(infeasibleMuscle)

        if any( ...
                feasibleMuscle >= infeasibleMuscle(iInfeasible) & ...
                feasibleActuator >= infeasibleActuator(iInfeasible))

            tf = ...
                true;

            return;
        end
    end
end
