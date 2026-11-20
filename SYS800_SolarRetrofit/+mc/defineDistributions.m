function D=defineDistributions()
% Exploratory engineering bounds, not fitted probability distributions.
D=array2table([.8 1 1.2;.9 1 1.1;.0025 .005 .01;.01 .02 .04;2.25 2.95 4;750 1000 1500;.8 1 1.3;.5 1 1.5;.03 .05 .08],...
 'VariableNames',{'Minimum','Mode','Maximum'},'RowNames',{'Demand','PVProduction','PVDegradation','BatteryFade','PVCostPerW','BatteryCostPerKWh','ImportRate','NBTExportRate','DiscountRate'});
end
