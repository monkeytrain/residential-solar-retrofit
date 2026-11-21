function plotResults(D,X,T,npv,S,R,scores)
labels=replace(T.Alternative,"+0 kW PV / ","");
labels=replace(labels," / 0 kWh battery"," PV only");
labels=replace(labels," kW PV PV only"," kW PV only");
names={'Household demand','PV production','PV degradation','Battery fade','PV installed cost','Battery installed cost','Import rates','NBT export rates','Real discount rate','5% efficiency cost','10% efficiency cost','15% efficiency cost','Shift participation'};
units={'Multiplier','Multiplier','%/year','%/year','$/W','$/kWh','Multiplier','Multiplier','%','$','$','$','%'};
scale=[1 1 100 100 1 1 1 1 100 1 1 1 100];
figure('Name','13 - Sampled distributions','Color','w');
tiledlayout(4,4);
for k=1:height(D)
    nexttile; histogram(X(:,k)*scale(k),'Normalization','pdf'); hold on;
    a=D.Minimum(k)*scale(k); m=D.Mode(k)*scale(k); z=D.Maximum(k)*scale(k);
    plot([a m z],[0 2/(z-a) 0],'k-','LineWidth',1.5);
    title(names{k}); xlabel(units{k}); ylabel('Density'); 
end
figure('Name','14 - NPV uncertainty','Color','w');
ax=axes; hold(ax,'on');
for i=1:height(S)
    if isfinite(S.MedianNPV(i))
        plot(ax,[S.P05NPV(i) S.P95NPV(i)]/1000,[i i],'-','Color',[0.10 0.35 0.65],'LineWidth',2);
        plot(ax,S.MedianNPV(i)/1000,i,'ko','MarkerSize',4);
    else
        text(ax,0,i,'N/A','VerticalAlignment','middle');
    end
end
xline(ax,0,'--'); yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse','TickLabelInterpreter','none');
title(ax,'20-Year Incremental NPV Uncertainty'); xlabel(ax,'Incremental NPV ($ thousands): median and 5th–95th percentiles');
figure('Name','15 - Positive NPV probability','Color','w');
barh(100*S.ProbabilityPositiveNPV); title('Probability of Positive Incremental NPV'); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); xlabel('Probability (%)'); hold on;
for i=find(isnan(S.ProbabilityPositiveNPV))', text(1,i,'N/A - unknown cost'); end
text(2,1,'Baseline: NPV = $0 by definition','FontSize',9,'Color',[.3 .3 .3]);
figure('Name','16 - Preferred alternative probability','Color','w');
W=100*[S.WinFinancial S.WinBalanced S.WinIndependence]; keep=any(W>0,2); barh(W(keep,:)); yticks(1:nnz(keep)); yticklabels(labels(keep)); title('Probability of Ranking First by Preference Profile'); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); legend('Financial','Balanced','Independence'); xlabel('First-place probability (%) - alternatives with zero wins omitted');
figure('Name','17 - NPV sensitivity','Color','w', ...
    'Position',[50 50 1850 900]);
ax17=axes('Position',[0.12 0.30 0.81 0.61]);
h=imagesc(ax17,R,[-1 1]);
h.AlphaData=isfinite(R);
set(ax17,'Color',[.8 .8 .8],'TickLabelInterpreter','none', ...
    'FontSize',10,'YDir','normal');
cb17=colorbar(ax17);
cb17.Label.String='Spearman rank correlation';
cb17.Color='k';
% Compact labels avoid overlapping the 21 alternative names.
shortLabels=string(labels);
shortLabels=replace(shortLabels," battery"," batt.");
shortLabels=replace(shortLabels," kWh batt."," kWh batt.");
shortLabels=replace(shortLabels," efficiency"," eff.");
shortLabels=replace(shortLabels," kWh/day shift"," kWh/d shift");
shortLabels=replace(shortLabels,"No retrofit","No retrofit");
xticks(ax17,1:height(T)); xticklabels(ax17,shortLabels);
xtickangle(ax17,55);
yticks(ax17,1:height(D)); yticklabels(ax17,names);
xlim(ax17,[.5 height(T)+.5]);
% Separate the 15 hardware cases, three efficiency cases, and three shifts.
hold(ax17,'on');
xline(ax17,15.5,'k-','LineWidth',1.8);
xline(ax17,18.5,'k-','LineWidth',1.8);
hold(ax17,'off');
title(ax17,'Spearman Correlation With 20-Year Incremental NPV');
xlabel(ax17,'Retrofit alternatives (hardware | efficiency | load shifting)');
ylabel(ax17,'Uncertain model input');
figure('Name','18 - Top-three probability','Color','w');
barh(100*[S.Top3Financial S.Top3Balanced S.Top3Independence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse'); xlim([0 100]); xticks(0:10:100); xlabel('Unconditional top-three probability (%)'); title('Top-Three Ranking Probability'); legend('Financial','Balanced','Independence');
figure('Name','19 - Mean rank','Color','w');
barh([S.MeanRankFinancial S.MeanRankBalanced S.MeanRankIndependence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse'); xlim([0 height(S)]); xticks(0:3:height(S)); xlabel('Mean rank when feasible (1 = best, 21 = worst)'); title('Mean Alternative Rank'); legend('Financial','Balanced','Independence');
figure('Name','20 - Decision score uncertainty','Color','w');
tiledlayout(1,3);
profiles={'Financial','Balanced','Grid independence'};
for p=1:3
    ax=nexttile; hold(ax,'on');
    for i=1:height(S)
        v=scores(:,i,p); v=v(isfinite(v));
        if isempty(v), continue; end
        q=prctile(v,[5 50 95]); plot(ax,q([1 3]),[i i],'-','Color',[0.10 0.35 0.65],'LineWidth',2); plot(ax,q(2),i,'ko','MarkerSize',4);
    end
    yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse'); ylim(ax,[.5 height(S)+.5]); xlim(ax,[0 1]); xticks(ax,0:.2:1); title(ax,profiles{p}); xlabel(ax,'Weighted score');
end
st=sgtitle('Decision Score Uncertainty (Median and 5th–95th Percentiles)');
set(st,'Color','k','FontWeight','bold');
% Explicit light presentation.
for f=findall(groot,'Type','figure')'
    if startsWith(string(f.Name),["13 -","14 -","15 -","16 -","17 -","18 -","19 -","20 -"])
        set(f,'Position',[100 100 1300 850]);
        if startsWith(string(f.Name),'20 -'), set(f,'Position',[50 50 1650 850]); end
        if startsWith(string(f.Name),'17 -'), set(f,'Position',[50 50 1850 900]); end
        set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k');
        if startsWith(string(f.Name),'17 -'), set(findall(f,'Type','axes'),'Color',[.8 .8 .8]); end
        set(findall(f,'Type','colorbar'),'Color','k');
        set(findall(f,'Type','text'),'Color','k');
        set(findall(f,'Type','axes'),'TickLabelInterpreter','none');
        set(findall(f,'Type','legend'),'Color','w','TextColor','k');
    end
end
end
