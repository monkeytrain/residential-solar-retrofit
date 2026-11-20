function c = collectInputs(eff,shift)
% All limits are homeowner-confirmed planning assumptions, not approvals.
fprintf('\nConfirm permitted limits with owner/lessor, installer and utility.\n');
c.ownership = string(input('Existing PV ownership (owned/leased/other): ','s'));
c.maxBudget = number('Maximum upfront budget ($, Inf for unrestricted): ',0,Inf,true);
c.maxAddedPV = number('Maximum permitted and compatible added PV (kW; 0 if unconfirmed): ',0,Inf,false);
c.maxBattery = number('Maximum permitted and compatible battery (kWh; 0 if unconfirmed): ',0,Inf,false);
c.allowEfficiency = logical(number('Efficiency improvements feasible? (0=no, 1=yes): ',0,1,false,true));
c.maxShift = number('Maximum feasible daily load shift (kWh): ',0,Inf,false);
c.efficiencyCosts = nan(numel(eff),1);
c.shiftCosts = nan(numel(shift),1);
if c.allowEfficiency
    for i=1:numel(eff)
        c.efficiencyCosts(i)=cost(sprintf('Upfront cost for %g%% efficiency ($; Enter if unknown): ',100*eff(i)));
    end
end
for i=1:numel(shift)
    if shift(i)<=c.maxShift
        c.shiftCosts(i)=cost(sprintf('Upfront cost for %g kWh/day shift ($; Enter if unknown, 0 if free): ',shift(i)));
    end
end
fprintf('\nPreference profiles are illustrative, not survey-derived.\n');
fprintf('1 Financial; 2 Balanced; 3 Grid independence; 4 Custom\n');
mode=number('Choose profile (1-4): ',1,4,false,true);
switch mode
    case 1, c.judgments=[3 5 2];
    case 2, c.judgments=[1 1 1];
    case 3, c.judgments=[2 1/3 1/5];
    otherwise
        fprintf('Saaty scale 1-9: first criterion favored; reciprocals: second favored.\n');
        fprintf('1 equal, 3 moderate, 5 strong, 7 very strong, 9 extreme.\n');
        while true
            p=[judgment('Economics / affordability: '),judgment('Economics / independence: '),judgment('Affordability / independence: ')];
            [~,cr]=decision.calculateAHPWeights(p);
            if cr<=0.1, c.judgments=p; break; end
            fprintf('CR = %.4f exceeds 0.10. Reconsider judgments.\n',cr);
        end
end
end
function v=number(prompt,lo,hi,allowInf,integer)
if nargin<5, integer=false; end
while true
    v=str2double(input(prompt,'s'));
    if isreal(v) && ~isnan(v) && (allowInf || isfinite(v)) && v>=lo && v<=hi && (~integer || v==floor(v)), return; end
    fprintf('Invalid input. Try again.\n');
end
end
function v=cost(prompt)
while true
    s=strtrim(input(prompt,'s'));
    if isempty(s), v=NaN; return; end
    v=str2double(s);
    if isreal(v) && isfinite(v) && v>=0, return; end
    fprintf('Enter a nonnegative cost or leave blank.\n');
end
end
function v=judgment(prompt)
scale=[1:9 1./(2:9)];
while true
    s=strtrim(input(prompt,'s'));
    v=str2double(s);
    tokens=regexp(s,'^1/([2-9])$','tokens','once');
    if ~isempty(tokens), v=1/str2double(tokens{1}); end
    if isreal(v) && isfinite(v) && any(abs(scale-v)<1e-10), return; end
    fprintf('Use an integer 1-9 or reciprocal such as 1/3.\n');
end
end
