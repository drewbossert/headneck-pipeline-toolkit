function valuesDisplay = siToDisplay(valuesSI, coordinateType)
%SITODISPLAY Convert SI values to human-readable audit units.

    if coordinateType == "rotation"
        valuesDisplay = rad2deg(valuesSI);
    else
        valuesDisplay = valuesSI;
    end
end
