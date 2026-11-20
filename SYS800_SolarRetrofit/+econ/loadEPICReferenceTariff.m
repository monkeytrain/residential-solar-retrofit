
function tariff = loadEPICReferenceTariff()
% LOADEPICREFERENCETARIFF
% Published EPIC residential TOU-D-4 generation rates.
%
% Source: Energy for Palmdale's Independent Choice
% Residential Rates, effective February 1, 2024.
%
% Fixed-reference scenario for annual economic modeling.
% These are generation-only rates, not SCE delivery rates.

    tariff.plan = "TOU-D-4";
    tariff.effectiveDate = datetime(2024,2,1);

    tariff.periods = [ ...
        "Summer On Peak";
        "Summer Mid Peak";
        "Summer Off Peak";
        "Winter Mid Peak";
        "Winter Off Peak";
        "Winter Super Off Peak"];

    tariff.generationRates = [ ...
        0.31299;
        0.18747;
        0.11419;
        0.23432;
        0.14279;
        0.12008];

    tariff.source = ...
        "EPIC Residential Rates, effective February 1, 2024";

    tariff.rateStatus = "Published generation-only rates";
end
