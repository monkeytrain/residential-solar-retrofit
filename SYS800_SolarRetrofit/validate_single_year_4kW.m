%% SYS 800: single representative-year validation (no calibration)
% Put this script in SYS800_SolarRetrofit project root.
% Put the TWO supplied CSVs in the project's data/ folder, using these names:
%   SCE_Usage_8014172872_11-07-23_to_11-07-24(1).csv
%   monitoring_data(1).csv
% Requires existing data/198638-0.parquet, data/pvwatts_hourly.csv,
% and +sim/calculateEnergyFlows.m. Run: validate_single_year_4kW
clearvars; clc; close all;
root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
addpath(root);
dataDir = fullfile(root,'data');
outDir = fullfile(root,'validation_results','single_year_4kW');
if ~isfolder(outDir), mkdir(outDir); end

%% Independent model assumptions (not fitted to actual data)
installedDC_kW = 4.0;         % confirmed DC nameplate
pvwattsReferenceDC_kW = 6.0; % reference file generated for 6 kW DC
installationYear = 2014;
representativeYear = 2026;    % solar-company observations Nov 2025-Oct 2026
annualDegradation = 0.005;
resstockFile = '198638-0.parquet'; % medium home, 1500-1999 sq ft
% Both actual datasets are aligned by calendar MONTH, not calendar YEAR.
% Nov in SCE export is incomplete, so use Dec-Oct (11 complete months).
comparisonMonths = (12:-1:1)'; % reordered below to Dec, Jan, ..., Oct
comparisonMonths = [12; (1:10)'];
labels = ["Dec";"Jan";"Feb";"Mar";"Apr";"May";"Jun";"Jul";"Aug";"Sep";"Oct"];

%% SCE raw interval records
sceFile = fullfile(dataDir,'SCE_Usage_8014172872_11-07-23_to_11-07-24.csv');
assert(isfile(sceFile),'Missing SCE file: %s',sceFile);
fid=fopen(sceFile,'r','n','UTF-8'); assert(fid>=0,'Cannot open SCE file');
found=false;
while ~feof(fid)
    s=fgetl(fid);
    if ischar(s) && startsWith(strtrim(s),'Date,Energy Consumption time Period Start')
        found=true; break;
    end
end
assert(found,'Could not find detailed-usage header');
raw=textscan(fid,'%q%q%q%q%q','Delimiter',',','EndOfLine','\n','ReturnOnError',false);
fclose(fid);
rawTimes=strtrim(erase(string(raw{2}),char(160)));
t=datetime(rawTimes,'InputFormat','MM/dd/yyyy hh:mma','Locale','en_US');
imp=str2double(string(raw{4})); exp=str2double(string(raw{5}));
valid=~isnat(t)&isfinite(imp)&isfinite(exp)&imp>=0&exp>=0;
t=t(valid); imp=imp(valid); exp=exp(valid);
actualImport=zeros(11,1); actualExport=zeros(11,1);
for j=1:11
    if j==1, dt=datetime(2023,12,1); else, dt=datetime(2024,j-1,1); end
    sel=t>=dt & t<dt+calmonths(1);
    expectedDays=days(dt+calmonths(1)-dt);
    nDays=numel(unique(dateshift(t(sel),'start','day')));
    assert(nDays==expectedDays && nnz(sel)>=23*expectedDays, ...
        'SCE month incomplete: %s',datestr(dt));
    actualImport(j)=sum(imp(sel)); actualExport(j)=sum(exp(sel));
end

%% Solar-company billed PV production (not reportedKWh)
solarFile=fullfile(dataDir,'monitoring_data.csv');
assert(isfile(solarFile),'Missing solar-company file: %s',solarFile);
s=readtable(solarFile,'TextType','string','VariableNamingRule','preserve');
assert(all(ismember({'startDate','billingKWh'},s.Properties.VariableNames)), ...
    'Expected startDate and billingKWh in monitoring file');
solarDates=datetime(s.startDate,'InputFormat','yyyy-MM-dd''T''HH:mm:ss');
actualPV=zeros(11,1);
for j=1:11
    if j==1, dt=datetime(2025,12,1); else, dt=datetime(2026,j-1,1); end
    idx=find(year(solarDates)==year(dt) & month(solarDates)==month(dt));
    assert(numel(idx)==1,'Missing/duplicate solar month: %s',datestr(dt));
    actualPV(j)=double(s.billingKWh(idx));
end
assert(abs(actualPV(10)-669.845)<0.001,'Check Sep 2026 billed PV');

%% Run EXACT same hourly grid-exchange logic as +sim/calculateEnergyFlows
res=parquetread(fullfile(dataDir,resstockFile));
load15=double(res.out_electricity_total_energy_consumption);
assert(numel(load15)==35040,'Expected 35,040 ResStock quarter-hour records');
loadHourly=sum(reshape(load15,4,[]),1)';
pvTable=readtable(fullfile(dataDir,'pvwatts_hourly.csv'), ...
    'NumHeaderLines',31,'VariableNamingRule','preserve');
pvRef=double(pvTable.("AC System Output (W)"))/1000;
assert(numel(pvRef)==8760,'Expected 8,760 PVWatts hourly records');
% Existing PV is aged, exactly as in technical_model.m. Scale the 6 kW
% reference to independently confirmed 4 kW nameplate before degradation.
pvHourly=pvRef*(installedDC_kW/pvwattsReferenceDC_kW)* ...
    (1-annualDegradation)^(representativeYear-installationYear);
flow=sim.calculateEnergyFlows(loadHourly,pvHourly);
monthHours=[31 28 31 30 31 30 31 31 30 31 30 31]*24;
lastHour=cumsum(monthHours); firstHour=[1 lastHour(1:end-1)+1];
modelImport=zeros(11,1);modelExport=zeros(11,1);modelPV=zeros(11,1);
for j=1:11
    mo=comparisonMonths(j); ix=firstHour(mo):lastHour(mo);
    % February SCE actuals include 29 days (2024), while model is 365-day.
    % Adjust modeled February monthly energy totals by 29/28 for parity.
    leapScale=1; if mo==2, leapScale=29/28; end
    modelImport(j)=sum(flow.gridImport_kWh(ix))*leapScale;
    modelExport(j)=sum(flow.gridExport_kWh(ix))*leapScale;
    modelPV(j)=sum(pvHourly(ix))*leapScale;
end

%% Comparison table and metrics
comparison=table(labels,actualImport,modelImport,actualExport,modelExport, ...
    actualPV,modelPV,'VariableNames',{'Month','ActualImport_kWh', ...
    'ModeledImport_kWh','ActualExport_kWh','ModeledExport_kWh', ...
    'ActualPV_kWh','ModeledPV_kWh'});
writetable(comparison,fullfile(outDir,'monthly_observed_vs_modeled.csv'));
quantity=["Grid imports";"Grid exports";"PV generation"];
A=[actualImport actualExport actualPV]; M=[modelImport modelExport modelPV];
actualTotal=sum(A,1)'; modeledTotal=sum(M,1)';
MAE=mean(abs(M-A),1)'; RMSE=sqrt(mean((M-A).^2,1))';
biasPct=100*(modeledTotal-actualTotal)./actualTotal;
MAPE=mean(100*abs(M-A)./max(A,eps),1)';
metrics=table(quantity,actualTotal,modeledTotal,MAE,RMSE,biasPct,MAPE, ...
    'VariableNames',{'Quantity','ObservedTotal_kWh','ModeledTotal_kWh', ...
    'MonthlyMAE_kWh','MonthlyRMSE_kWh','AggregateBias_pct','MonthlyMAPE_pct'});
writetable(metrics,fullfile(outDir,'validation_metrics.csv'));
disp(metrics);

%% Three grouped bar charts with explicit light theme AFTER plotting
names={'Grid imports','Grid exports','PV generation'};
fileNames={'grid_imports_comparison.png','grid_exports_comparison.png','pv_generation_comparison.png'};
monthNames={'Dec','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct'};
for k=1:3
    fig=figure('Visible','off','Color',[1 1 1], ...
        'InvertHardcopy','off','Position',[100 100 1200 680]);
    ax=axes('Parent',fig);
    bars=bar(ax,1:11,[A(:,k),M(:,k)],'grouped');
    % IMPORTANT: bar() can reset axes properties when NextPlot='replace'.
    % Apply ALL appearance settings AFTER bar() to prevent theme overrides.
    set(fig,'Color',[1 1 1],'InvertHardcopy','off');
    set(ax,'Color',[1 1 1],'XColor',[0 0 0],'YColor',[0 0 0], ...
        'FontSize',13,'FontWeight','normal','LineWidth',1.2, ...
        'Box','off','XLim',[0.4 11.6], ...
        'XTick',1:11,'XTickLabel',monthNames, ...
        'YGrid','on','GridColor',[0.8 0.8 0.8],'GridAlpha',0.5);
    ax.YAxis.Exponent=0;
    yMax=max([A(:,k);M(:,k)]);
    ylim(ax,[0 max(100,ceil(1.15*yMax/100)*100)]);
    ax.YTickMode='auto';
    ax.YTickLabelMode='auto';
    xlabel(ax,'Calendar month (December-October)', ...
        'Color',[0 0 0],'FontSize',14,'FontWeight','bold');
    ylabel(ax,[names{k} ' (kWh/month)'], ...
        'Color',[0 0 0],'FontSize',14,'FontWeight','bold');
    title(ax,[names{k} ': observed vs. modeled (4 kW DC)'], ...
        'Color',[0 0 0],'FontSize',16,'FontWeight','bold');
    lgd=legend(ax,bars,{'Actual','Model (4 kW DC, medium home)'}, ...
        'Location','northoutside','Orientation','horizontal');
    set(lgd,'TextColor',[0 0 0],'Color',[1 1 1], ...
        'EdgeColor',[0.7 0.7 0.7],'FontSize',12);
    set(ax,'Position',[0.12 0.15 0.83 0.68]);
    drawnow;
    exportgraphics(fig,fullfile(outDir,fileNames{k}), ...
        'Resolution',200,'BackgroundColor',[1 1 1]);
    close(fig);
end
fprintf('Saved 3 plots and 2 CSVs to %s\n',outDir);
fprintf('SCE Dec 2023-Oct 2024 aligned by month with solar Dec 2025-Oct 2026.\n');
fprintf('No fitted demand/PV scaling; November omitted due to incomplete SCE coverage.\n');
