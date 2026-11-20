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
        plot(ax,[S.P05NPV(i) S.P95NPV(i)]/1000,[i i],'-','LineWidth',2);
        plot(ax,S.MedianNPV(i)/1000,i,'ko','MarkerSize',4);
    else
        text(ax,0,i,'N/A','VerticalAlignment','middle');
    end
end
xline(ax,0,'--'); yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse','TickLabelInterpreter','none');
title(ax,'Lifecycle NPV Uncertainty'); xlabel(ax,'Incremental NPV ($ thousands): median and 5th–95th percentiles');
figure('Name','15 - Positive NPV probability','Color','w');
barh(100*S.ProbabilityPositiveNPV); title('Probability of Positive Incremental NPV'); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); xlabel('Probability (%)'); hold on;
for i=find(isnan(S.ProbabilityPositiveNPV))', text(1,i,'N/A - unknown cost'); end
figure('Name','16 - Preferred alternative probability','Color','w');
W=100*[S.WinFinancial S.WinBalanced S.WinIndependence]; keep=any(W>0,2); barh(W(keep,:)); yticks(1:nnz(keep)); yticklabels(labels(keep)); title('First-Place Probability (Zero-Win Alternatives Omitted)'); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); legend('Financial','Balanced','Independence'); xlabel('Unconditional first-place probability (%)');
figure('Name','17 - NPV sensitivity','Color','w');
h=imagesc(R,[-1 1]); h.AlphaData=isfinite(R); colorbar; xticks(1:height(T)); xticklabels(labels); xtickangle(60); yticks(1:height(D)); yticklabels(names); set(gca,'TickLabelInterpreter','none'); title('Spearman correlation with lifecycle NPV (gray = undefined)');
figure('Name','18 - Top-three probability','Color','w');
barh(100*[S.Top3Financial S.Top3Balanced S.Top3Independence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse'); xlim([0 100]); xticks(0:10:100); xlabel('Unconditional top-three probability (%)'); title('Top-Three Ranking Probability'); legend('Financial','Balanced','Independence');
figure('Name','19 - Mean rank','Color','w');
barh([S.MeanRankFinancial S.MeanRankBalanced S.MeanRankIndependence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse'); xlabel('Mean rank when feasible (lower is better)'); title('Mean Alternative Rank'); legend('Financial','Balanced','Independence');
figure('Name','20 - Decision score uncertainty','Color','w');
tiledlayout(1,3);
profiles={'Financial','Balanced','Grid independence'};
for p=1:3
    ax=nexttile; hold(ax,'on');
    for i=1:height(S)
        v=scores(:,i,p); v=v(isfinite(v));
        if isempty(v), continue; end
        q=prctile(v,[5 50 95]); plot(ax,q([1 3]),[i i],'-','LineWidth',2); plot(ax,q(2),i,'ko','MarkerSize',4);
    end
    yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse'); ylim(ax,[.5 height(S)+.5]); xlim(ax,[0 1]); xticks(ax,0:.2:1); title(ax,profiles{p}); xlabel(ax,'Weighted score');
end
sgtitle('Decision Score Uncertainty When Feasible (Median and 5th–95th Percentiles)');
% Explicit light presentation.
for f=findall(groot,'Type','figure')'
    if startsWith(string(f.Name),["13 -","14 -","15 -","16 -","17 -","18 -","19 -","20 -"])
        set(f,'Position',[100 100 1300 850]);
        if startsWith(string(f.Name),'20 -'), set(f,'Position',[50 50 1650 850]); end
        set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k');
        if startsWith(string(f.Name),'17 -'), set(findall(f,'Type','axes'),'Color',[.8 .8 .8]); end
        set(findall(f,'Type','colorbar'),'Color','k');
        set(findall(f,'Type','text'),'Color','k');
        set(findall(f,'Type','legend'),'Color','w','TextColor','k');
    end
end
end
,';
scale=[1 1 100 100 1 1 1 1 100];
figure('Name','13 - Sampled distributions','Color','w');
tiledlayout(3,3);
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
        plot(ax,[S.P05NPV(i) S.P95NPV(i)]/1000,[i i],'-','LineWidth',2);
        plot(ax,S.MedianNPV(i)/1000,i,'ko','MarkerSize',4);
    else
        text(ax,0,i,'N/A','VerticalAlignment','middle');
    end
end
xline(ax,0,'--'); yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'Incremental NPV ($ thousands): median and 5th–95th percentiles');
figure('Name','15 - Positive NPV probability','Color','w');
barh(100*S.ProbabilityPositiveNPV); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); xlabel('Probability (%)'); hold on;
for i=find(isnan(S.ProbabilityPositiveNPV))', text(1,i,'N/A - unknown cost'); end
figure('Name','16 - Preferred alternative probability','Color','w');
barh(100*[S.WinFinancial S.WinBalanced S.WinIndependence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); legend('Financial','Balanced','Independence'); xlabel('Unconditional first-place probability (%)');
figure('Name','17 - NPV sensitivity','Color','w');
h=imagesc(R,[-1 1]); h.AlphaData=isfinite(R); colorbar; xticks(1:height(T)); xticklabels(labels); xtickangle(60); yticks(1:height(D)); yticklabels(names); set(gca,'TickLabelInterpreter','none'); title('Spearman correlation with lifecycle NPV (gray = undefined)');
% Override report_figures dark defaults for readability.
for f=findall(groot,'Type','figure')'
    if startsWith(string(f.Name),["13 -","14 -","15 -","16 -","17 -"])
        set(f,'Position',[100 100 1100 750]);
        set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k');
        if startsWith(string(f.Name),'17 -'), set(findall(f,'Type','axes'),'Color',[.8 .8 .8]); end
        set(findall(f,'Type','colorbar'),'Color','k');
        set(findall(f,'Type','text'),'Color','k');
        set(findall(f,'Type','legend'),'Color','w','TextColor','k');
    end
end
end
,';
scale=[1 1 100 100 1 1 1 1 100];
figure('Name','13 - Sampled distributions','Color','w');
tiledlayout(3,3);
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
        plot(ax,[S.P05NPV(i) S.P95NPV(i)]/1000,[i i],'-','LineWidth',2);
        plot(ax,S.MedianNPV(i)/1000,i,'ko','MarkerSize',4);
    else
        text(ax,0,i,'N/A','VerticalAlignment','middle');
    end
end
xline(ax,0,'--'); yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'Incremental NPV ($ thousands): median and 5th–95th percentiles');
figure('Name','15 - Positive NPV probability','Color','w');
barh(100*S.ProbabilityPositiveNPV); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); xlabel('Probability (%)'); hold on;
for i=find(isnan(S.ProbabilityPositiveNPV))', text(1,i,'N/A - unknown cost'); end
figure('Name','16 - Preferred alternative probability','Color','w');
barh(100*[S.WinFinancial S.WinBalanced S.WinIndependence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); legend('Financial','Balanced','Independence'); xlabel('Unconditional first-place probability (%)');
figure('Name','17 - NPV sensitivity','Color','w');
h=imagesc(R,[-1 1]); h.AlphaData=isfinite(R); colorbar; xticks(1:height(T)); xticklabels(labels); xtickangle(60); yticks(1:height(D)); yticklabels(names); set(gca,'TickLabelInterpreter','none'); title('Spearman correlation with lifecycle NPV (gray = undefined)');
% Override report_figures dark defaults for readability.
for f=findall(groot,'Type','figure')'
    if startsWith(string(f.Name),["13 -","14 -","15 -","16 -","17 -"])
        set(f,'Position',[100 100 1100 750]);
        set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k');
        if startsWith(string(f.Name),'17 -'), set(findall(f,'Type','axes'),'Color',[.8 .8 .8]); end
        set(findall(f,'Type','colorbar'),'Color','k');
        set(findall(f,'Type','text'),'Color','k');
        set(findall(f,'Type','legend'),'Color','w','TextColor','k');
    end
end
end
,'%'};
scale=[1 1 100 100 1 1 1 1 100];
figure('Name','13 - Sampled distributions','Color','w');
tiledlayout(3,3);
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
        plot(ax,[S.P05NPV(i) S.P95NPV(i)]/1000,[i i],'-','LineWidth',2);
        plot(ax,S.MedianNPV(i)/1000,i,'ko','MarkerSize',4);
    else
        text(ax,0,i,'N/A','VerticalAlignment','middle');
    end
end
xline(ax,0,'--'); yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'Incremental NPV ($ thousands): median and 5th–95th percentiles');
figure('Name','15 - Positive NPV probability','Color','w');
barh(100*S.ProbabilityPositiveNPV); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); xlabel('Probability (%)'); hold on;
for i=find(isnan(S.ProbabilityPositiveNPV))', text(1,i,'N/A - unknown cost'); end
figure('Name','16 - Preferred alternative probability','Color','w');
barh(100*[S.WinFinancial S.WinBalanced S.WinIndependence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); legend('Financial','Balanced','Independence'); xlabel('Unconditional first-place probability (%)');
figure('Name','17 - NPV sensitivity','Color','w');
h=imagesc(R,[-1 1]); h.AlphaData=isfinite(R); colorbar; xticks(1:height(T)); xticklabels(labels); xtickangle(60); yticks(1:height(D)); yticklabels(names); set(gca,'TickLabelInterpreter','none'); title('Spearman correlation with lifecycle NPV (gray = undefined)');
% Override report_figures dark defaults for readability.
for f=findall(groot,'Type','figure')'
    if startsWith(string(f.Name),["13 -","14 -","15 -","16 -","17 -"])
        set(f,'Position',[100 100 1100 750]);
        set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k');
        if startsWith(string(f.Name),'17 -'), set(findall(f,'Type','axes'),'Color',[.8 .8 .8]); end
        set(findall(f,'Type','colorbar'),'Color','k');
        set(findall(f,'Type','text'),'Color','k');
        set(findall(f,'Type','legend'),'Color','w','TextColor','k');
    end
end
end
