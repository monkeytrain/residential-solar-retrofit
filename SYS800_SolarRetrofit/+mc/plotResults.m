function plotResults(D,X,T,npv,S,R)
labels=T.Alternative;
figure('Name','13 - Sampled distributions','Color','w');
tiledlayout(3,3);
for k=1:height(D)
    nexttile; histogram(X(:,k)); title(D.Properties.RowNames{k},'Interpreter','none'); 
end
figure('Name','14 - NPV uncertainty','Color','w');
ax=axes; hold(ax,'on');
for i=1:height(S)
    if isfinite(S.MedianNPV(i))
        plot(ax,[S.P05NPV(i) S.P95NPV(i)],[i i],'-','LineWidth',2);
        plot(ax,S.MedianNPV(i),i,'ko','MarkerSize',4);
    end
end
xline(ax,0,'--'); yticks(ax,1:height(S)); yticklabels(ax,labels); set(ax,'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'Incremental NPV ($): median and 5th–95th percentiles');
figure('Name','15 - Positive NPV probability','Color','w');
barh(100*S.ProbabilityPositiveNPV); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); xlabel('Probability (%)');
figure('Name','16 - Preferred alternative probability','Color','w');
barh(100*[S.WinFinancial S.WinBalanced S.WinIndependence]); yticks(1:height(S)); yticklabels(labels); set(gca,'YDir','reverse','TickLabelInterpreter','none'); xlim([0 100]); legend('Financial','Balanced','Independence'); xlabel('Unconditional first-place probability (%)');
figure('Name','17 - NPV sensitivity','Color','w');
imagesc(R,[-1 1]); colorbar; xticks(1:height(T)); xticklabels(labels); xtickangle(60); yticks(1:height(D)); yticklabels(D.Properties.RowNames); set(gca,'TickLabelInterpreter','none'); title('Spearman correlation with lifecycle NPV');
% Override report_figures dark defaults for readability.
for f=findall(groot,'Type','figure')'
    if startsWith(string(f.Name),["13 -","14 -","15 -","16 -","17 -"])
        set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k');
        set(findall(f,'Type','text'),'Color','k');
        set(findall(f,'Type','legend'),'Color','w','TextColor','k');
    end
end
end
