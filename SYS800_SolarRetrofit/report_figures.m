%% SYS 800 - Centralized report figure generation
% Requires technical_model.m and lifecycle_analysis.m to have run.
% All plotting is isolated here; no calculations or verification changed.
close all;

% Dark figure theme: readable in both MATLAB light and dark desktop modes.
theme.background = [0.10 0.12 0.15];
theme.axes = [0.15 0.17 0.21];
theme.foreground = [0.94 0.95 0.97];
theme.grid = [0.46 0.49 0.54];
theme.palette = [0.35 0.75 1.00; 0.98 0.66 0.33; ...
                 0.45 0.86 0.62; 0.81 0.60 1.00; ...
                 1.00 0.52 0.64; 0.98 0.83 0.40];
% Figure/axes/text defaults apply to plots created below.
set(groot,'defaultFigureColor',theme.background, ...
    'defaultAxesColor',theme.axes, ...
    'defaultAxesXColor',theme.foreground, ...
    'defaultAxesYColor',theme.foreground, ...
    'defaultAxesZColor',theme.foreground, ...
    'defaultAxesGridColor',theme.grid, ...
    'defaultAxesColorOrder',theme.palette, ...
    'defaultTextColor',theme.foreground);

    %% Figure 1 - Monthly energy balance
    figure('Name','01 - Baseline Monthly Energy Flows','NumberTitle','off');
    bar(1:12,[monthlyDemand_kWh monthlySolar_kWh monthlyImport_kWh monthlyExport_kWh],'grouped');
    xticks(1:12); xticklabels(monthNames); xlim([0.5 12.5]);
    xlabel('Month'); ylabel('Energy (kWh/month)');
    title(sprintf('Existing %g kW DC PV System - Monthly Energy Flows',pv.capacity_kW));
    legend('Demand','Aged PV','Imports','Exports','Location','northoutside','Orientation','horizontal'); grid on;

    %% Figure 2 - Grid import reduction
    figure('Name','02 - Retrofit Grid Import Reduction','NumberTitle','off'); hold on;
    for i=1:numAddedPV
        idx=retrofitAddedPV_kW==addedPVSizes(i);
        plot(retrofitBattery_kWh(idx),retrofitImportReduction_pct(idx),'-o', ...
            'LineWidth',1.7,'DisplayName',sprintf('+%g kW new PV',addedPVSizes(i)));
    end
    hold off; grid on; xlabel('Battery capacity (kWh)');
    ylabel('Annual grid-import reduction (%)');
    title('Technical Benefit of Solar and Battery Retrofits'); legend('Location','best');

    %% Figure 3 - Annual savings by tariff
    figure('Name','03 - Annual Savings by Billing Program','NumberTitle','off');
    tiledlayout(1,3,'TileSpacing','compact');
    savingsSets={nem1AnnualSavings,nem2AnnualSavings,nbtAnnualSavings};
    programNames={'NEM 1.0','NEM 2.0','NBT (Solar Billing Plan)'};
    for k=1:3
        nexttile; hold on;
        for i=1:numAddedPV
            idx=retrofitAddedPV_kW==addedPVSizes(i);
            plot(retrofitBattery_kWh(idx),savingsSets{k}(idx),'-o','LineWidth',1.5, ...
                'DisplayName',sprintf('+%g kW PV',addedPVSizes(i)));
        end
        hold off; grid on; xlabel('Battery capacity (kWh)');
        ylabel('Annual modeled savings ($/year)'); title(programNames{k});
        if k==3, legend('Location','best'); end
    end
    sgtitle('Preliminary Annual Operating Savings vs. No Retrofit');

    %% Figure 4 - High-generation day PV vs demand
    dailyPV=sum(reshape(solarAged_kWh,24,365),1);
    [~,selectedDay]=max(dailyPV);
    hourIdx=(selectedDay-1)*24+(1:24);
    hourOfDay=0:23;
    figure('Name','04 - High-Generation Day PV and Demand','NumberTitle','off');
    plot(hourOfDay,solarAged_kWh(hourIdx),'LineWidth',2); hold on;
    plot(hourOfDay,demandHourly_kWh(hourIdx),'LineWidth',2); hold off;
    xlabel('Hour of day'); ylabel('Average power (kW)');
    title(sprintf('PV Generation and Household Demand - High-Generation Day %d',selectedDay));
    legend('Existing PV generation','Household demand','Location','best');
    xlim([0 23]); xticks(0:2:22); grid on;

    %% Figure 5 - Battery dispatch on same day
    battery5=battery;
    battery5.capacity_kWh=5;
    battery5.initialSOC_kWh=0;
    battery5Simulation=sim.calculateBatteryDispatch(demandHourly_kWh,solarAged_kWh,battery5);
    figure('Name','05 - Five-kWh Battery Dispatch','NumberTitle','off');
    tiledlayout(2,1,'TileSpacing','compact');
    nexttile;
    plot(hourOfDay,battery5Simulation.stateOfCharge_kWh(hourIdx),'LineWidth',2);
    ylabel('Stored energy (kWh)'); title(sprintf('5 kWh Battery Operation - Day %d',selectedDay));
    ylim([0 5.2]); xlim([0 23]); xticks(0:2:22); grid on;
    nexttile;
    plot(hourOfDay,battery5Simulation.batteryCharge_kWh(hourIdx),'LineWidth',1.8); hold on;
    plot(hourOfDay,battery5Simulation.batteryDischarge_kWh(hourIdx),'LineWidth',1.8); hold off;
    xlabel('Hour of day'); ylabel('Average power (kW)');
    legend('Battery charging','Battery discharging','Location','best');
    xlim([0 23]); xticks(0:2:22); grid on;

    %% Figure 6 - Reference energy-value savings
    figure('Name','06 - SCE + EPIC Reference Energy Savings','NumberTitle','off'); hold on;
    pvSizes=unique(referenceComparison.AddedPV_kW);
    for i=1:numel(pvSizes)
        idx=referenceComparison.AddedPV_kW==pvSizes(i);
        plot(referenceComparison.BatteryCapacity_kWh(idx), ...
            referenceComparison.EnergyValueSavings(idx),'-o','LineWidth',1.8, ...
            'MarkerSize',6,'DisplayName',sprintf('+%g kW PV',pvSizes(i)));
    end
    hold off; grid on;
    xlabel('Battery capacity (kWh)'); ylabel('Annual reference energy-value savings ($/year)');
    title('SCE + EPIC Reference Tariff Comparison'); legend('Location','best');

    %% Figure 7 - Combined sensitivity heatmap
    figure('Name','07 - Battery Cost and Rate Sensitivity','NumberTitle','off');
    imagesc(rateEscalationCases2D*100,batteryCostCases,npvCostRateMatrix);
    set(gca,'YDir','normal'); colorbar;
    xlabel('Annual real electricity rate escalation (%)');
    ylabel('Installed battery cost ($/kWh)');
    title('5 kWh Battery: 20-Year NPV Sensitivity'); hold on;
    contour(rateEscalationCases2D*100,batteryCostCases,npvCostRateMatrix,[0 0], ...
        'k','LineWidth',2); hold off;

%% Figure 8 - 20-year economic decision matrix
% Case IDs follow the original 15-scenario order (not financial ranking).
% NPV is incremental to no retrofit and includes modeled degradation.

requiredColumns = {'AddedPV_kW','BatteryCapacity_kWh', ...
    'InitialInvestment','NPV_Degraded'};
assert(all(ismember(requiredColumns, ...
    referenceComparison.Properties.VariableNames)), ...
    'Lifecycle economic columns required for Figure 8 are missing.');

casePV = referenceComparison.AddedPV_kW(:);
caseBattery = referenceComparison.BatteryCapacity_kWh(:);
caseCost = referenceComparison.InitialInvestment(:);
caseNPV = referenceComparison.NPV_Degraded(:);
nCases = numel(casePV);
assert(nCases == 15, 'Figure 8 expects 15 retrofit cases.');
assert(all(isfinite([casePV;caseBattery;caseCost;caseNPV])), ...
    'Economic matrix contains nonfinite data.');

% Sort explicitly by PV and battery size so case numbers are stable.
[~,caseOrder] = sortrows([casePV caseBattery],[1 2]);
casePV = casePV(caseOrder);
caseBattery = caseBattery(caseOrder);
caseCost = caseCost(caseOrder);
caseNPV = caseNPV(caseOrder);
caseNumber = (1:nCases)';

% Rank highest NPV first, breaking ties with lower initial cost.
[~,npvOrder] = sortrows([-caseNPV caseCost],[1 2]);
financialRank = zeros(nCases,1);
financialRank(npvOrder) = (1:nCases)';
preferredCase = npvOrder(1);
baselineCase = find(casePV == 0 & caseBattery == 0);
assert(isscalar(baselineCase),'No-retrofit baseline is missing.');
retrofitCases = find(caseNumber ~= baselineCase);
[~,retrofitPosition] = max(caseNPV(retrofitCases));
bestRetrofitCase = retrofitCases(retrofitPosition);

% Draw the table using axes objects, rather than uitable, for reliable
% dark-theme rendering and clean figure exports.
fig8 = figure('Name','08 - Economic Decision Matrix', ...
    'NumberTitle','off','Color',theme.background, ...
    'Position',[100 100 1450 810]);
ax8 = axes('Parent',fig8,'Position',[0.035 0.16 0.93 0.70], ...
    'XLim',[0 1],'YLim',[0 nCases+1],'YDir','reverse', ...
    'Visible','off');
hold(ax8,'on');

% Six columns, with additional width for dollar amounts.
columnEdges = [0 0.125 0.275 0.425 0.635 0.855 1];
headers = {'Retrofit Case','Added PV (kW)','Battery (kWh)', ...
    'Initial Cost ($)','20-Year NPV ($)','Financial Rank'};

% Header background.
rectangle('Parent',ax8,'Position',[0 0 1 1], ...
    'FaceColor',theme.axes,'EdgeColor',theme.grid,'LineWidth',0.7);
for c = 1:6
    text(ax8,(columnEdges(c)+columnEdges(c+1))/2,0.5,headers{c}, ...
        'Color',theme.foreground,'FontSize',11,'FontWeight','bold', ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Interpreter','none');
end

for r = 1:nCases
    y = r;
    if r == preferredCase
        fillColor = [0.16 0.31 0.25];  % Best overall: muted green
    elseif r == bestRetrofitCase
        fillColor = [0.17 0.25 0.35];  % Best retrofit: muted blue
    elseif mod(r,2) == 0
        fillColor = theme.axes;
    else
        fillColor = theme.background;
    end
    rectangle('Parent',ax8,'Position',[0 y 1 1], ...
        'FaceColor',fillColor,'EdgeColor',theme.grid,'LineWidth',0.35);

    % MATLAB sprintf does not support the comma flag (%,.0f).
    % Insert thousands separators explicitly into the integer strings.
    moneyValues = [caseCost(r),caseNPV(r)];
    moneyLabels = cell(1,2);
    for m = 1:2
        rawDigits = sprintf('%.0f',abs(moneyValues(m)));
        groupedDigits = regexprep(rawDigits,'(?<=\d)(?=(\d{3})+$)',',');
        if moneyValues(m) < -0.5
            moneyLabels{m} = ['-$' groupedDigits];
        else
            moneyLabels{m} = ['$' groupedDigits];
        end
    end
    cells = {sprintf('%d',caseNumber(r)), ...
        sprintf('%g',casePV(r)),sprintf('%g',caseBattery(r)), ...
        moneyLabels{1},moneyLabels{2},sprintf('%d',financialRank(r))};
    for c = 1:6
        text(ax8,(columnEdges(c)+columnEdges(c+1))/2,y+0.5,cells{c}, ...
            'Color',theme.foreground,'FontSize',11, ...
            'FontWeight','normal', ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'Interpreter','none');
    end
end

for c = 2:6
    line(ax8,[columnEdges(c) columnEdges(c)],[0 nCases+1], ...
        'Color',theme.grid,'LineWidth',0.4);
end
hold(ax8,'off');

annotation(fig8,'textbox',[0.04 0.92 0.92 0.055], ...
    'String','20-Year Retrofit Economic Decision Matrix', ...
    'FontSize',19,'FontWeight','bold','Color',theme.foreground, ...
    'HorizontalAlignment','center','EdgeColor','none');
annotation(fig8,'textbox',[0.04 0.875 0.92 0.038], ...
    'String','Incremental investment and NPV relative to no retrofit', ...
    'FontSize',11,'Color',theme.foreground, ...
    'HorizontalAlignment','center','EdgeColor','none');

if preferredCase == baselineCase
    summaryText = sprintf(['Preferred overall: Case %d (no retrofit). ' ...
        'Best retrofit: Case %d (+%g kW PV, %g kWh battery).'], ...
        preferredCase,bestRetrofitCase,casePV(bestRetrofitCase), ...
        caseBattery(bestRetrofitCase));
else
    summaryText = sprintf( ...
        'Preferred overall: Case %d (+%g kW PV, %g kWh battery).', ...
        preferredCase,casePV(preferredCase),caseBattery(preferredCase));
end
annotation(fig8,'textbox',[0.04 0.09 0.92 0.045], ...
    'String',summaryText,'FontSize',11,'FontWeight','bold', ...
    'Color',theme.foreground,'HorizontalAlignment','center', ...
    'EdgeColor','none');
annotation(fig8,'textbox',[0.04 0.025 0.92 0.06], ...
    'String',['Green = highest NPV; blue = best retrofit if different. ' ...
    'Rank 1 = highest NPV. 20 years; 5% real discount rate. ' ...
    'Degradation included; battery replacement excluded.'], ...
    'FontSize',10,'Color',theme.foreground, ...
    'HorizontalAlignment','center','EdgeColor','none');

% Numerical table remains available in the MATLAB workspace.
economicDecisionMatrix = table(caseNumber,casePV,caseBattery, ...
    caseCost,caseNPV,financialRank, ...
    'VariableNames',{'RetrofitCase','AddedPV_kW', ...
    'BatteryCapacity_kWh','InitialInvestment', ...
    'NPV_20Year','FinancialRank'});
fprintf('\n=== ECONOMIC DECISION MATRIX ===\n');
disp(economicDecisionMatrix);

%% Figure 9 - PV and battery degradation comparison
figure('Name','09 - Equipment Degradation', ...
    'NumberTitle','off','Position',[100 100 1000 550]);
plot(calendarYears,100*pvRetention,'-o','LineWidth',2, ...
    'MarkerSize',5,'DisplayName','Solar PV output retention');
hold on;
plot(calendarYears,100*batteryRetention,'-s','LineWidth',2, ...
    'MarkerSize',5,'DisplayName','Battery usable capacity retention');
hold off;
xlabel('Calendar year'); ylabel('Remaining performance (%)');
title('Modeled Solar PV and Battery Degradation');
xlim([calendarYears(1) calendarYears(end)]);
ylim([60 105]);
xticks(calendarYears(1):2:calendarYears(end));
legend('Location','southwest'); grid on;

%% Figure 10 - Long-term grid import trajectories
trajectoryConfigs = [0 0; 0 5; 0 10; 2 0; 2 10; 4 20];
figure('Name','10 - Long-Term Grid Imports', ...
    'NumberTitle','off','Position',[100 100 1100 600]);
hold on;
for k = 1:size(trajectoryConfigs,1)
    idx = find(referenceComparison.AddedPV_kW == trajectoryConfigs(k,1) & ...
        referenceComparison.BatteryCapacity_kWh == trajectoryConfigs(k,2));
    assert(isscalar(idx),'Trajectory configuration not found.');
    if k == 1
        label = 'Existing PV - No retrofit';
    elseif trajectoryConfigs(k,1) == 0
        label = sprintf('%g kWh battery only',trajectoryConfigs(k,2));
    elseif trajectoryConfigs(k,2) == 0
        label = sprintf('+%g kW PV only',trajectoryConfigs(k,1));
    else
        label = sprintf('+%g kW PV and %g kWh battery', ...
            trajectoryConfigs(k,1),trajectoryConfigs(k,2));
    end
    plot(calendarYears,annualImports(idx,:),'-o','LineWidth',1.8, ...
        'MarkerSize',4,'DisplayName',label);
end
hold off;
xlabel('Calendar year'); ylabel('Annual grid imports (kWh)');
title('Long-Term Grid Dependence by Retrofit Strategy');
xlim([calendarYears(1) calendarYears(end)]);
xticks(calendarYears(1):2:calendarYears(end));
legend('Location','best'); grid on;

%% Figure verification
assert(height(economicDecisionMatrix) == 15);
assert(isequal(sort(financialRank),(1:nCases)'));
assert(numel(calendarYears) == lifecycle.horizonYears);
assert(numel(pvRetention) == lifecycle.horizonYears);
assert(numel(batteryRetention) == lifecycle.horizonYears);
assert(size(annualImports,2) == lifecycle.horizonYears);
assert(all(isfinite(annualImports(:))));
fprintf('\n=== ADDITIONAL FIGURES VERIFIED ===\n');

%% Consistent legend appearance
allFigures = findall(groot,'Type','figure');
for k = 1:numel(allFigures)
    lgds = findall(allFigures(k),'Type','legend');
    for n = 1:numel(lgds)
        lgds(n).Color = theme.axes;
        lgds(n).TextColor = theme.foreground;
        lgds(n).EdgeColor = theme.grid;
    end
end
fprintf('\n=== REPORT FIGURES GENERATED: 10 ===\n');


%% Figures 11-12 - AHP results (when decision analysis has run)
if exist('decisionRanking','var') && exist('decisionWeights','var')
    figure('Name','11 - AHP Criteria Weights','NumberTitle','off','Color','w');
    ax=axes; bar(ax,100*decisionWeights);
    xticks(ax,1:3); xticklabels(ax,{'Economics','Affordability','Independence'});
    ylabel(ax,'Weight (%)'); title(ax,sprintf('AHP Criteria Weights (CR = %.3f)',decisionCR),'Color','k');
    set(ax,'Color','w','XColor','k','YColor','k'); grid(ax,'on'); ylim(ax,[0 100]);
    figure('Name','12 - AHP Alternative Ranking','NumberTitle','off','Color','w');
    ax=axes; rankedDecision=decisionRanking(decisionRanking.Feasible,:);
    barh(ax,[rankedDecision.NPVUtility*decisionWeights(1),rankedDecision.CostUtility*decisionWeights(2),rankedDecision.SSRUtility*decisionWeights(3)],'stacked');
    yticks(ax,1:height(rankedDecision)); yticklabels(ax,rankedDecision.Alternative);
    set(ax,'YDir','reverse','Color','w','XColor','k','YColor','k','TickLabelInterpreter','none');
    xlabel(ax,'Weighted decision score'); title(ax,'Feasible Retrofit Alternatives','Color','k');
    legend(ax,{'Economics','Affordability','Independence'},'Location','southoutside','Orientation','horizontal','Color','w','TextColor','k');
    xlim(ax,[0 1]); grid(ax,'on');
    fprintf('\n=== AHP FIGURES GENERATED: 2 ===\n');
end
