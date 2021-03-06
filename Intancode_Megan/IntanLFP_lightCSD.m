%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IntanLFP_CSD_v2.m
% Script for extracting LFP data from Intan
%Created 09222015 by Megan A Kirchgessner
% Adapted from LFPv2_latest from Bryan J. Hansen
% mkirchgessner@ucsd.edu
% 5/30/2016 - FILTER CHANGED by MAK - replaced with newfilter.m
% 6/14/2016 - changed to intanphy2matlab_v2; added new code for determining running trials (MAK)
% 8/31/2016 - changed to intan2matlab
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%


function IntanLFP_lightCSD(exp_path,exp_type)
   %%
   
% get necessary data
cd(exp_path)
if exist(sprintf('%s/data.mat',exp_path),'file')
    load(sprintf('%s/data.mat',exp_path))      % data from intanphy2matlab.m
else
    intan2matlab(exp_path);      % data from intanphy2matlab.m
    load(sprintf('%s/data.mat',exp_path))
end

if ~exist(sprintf('%s/LFP_all.mat',exp_path),'file')
    % read in amplifier.dat one channel at a time
    v = read_intan_amp(exp_path,num_channels,amp_sr,1);        

    % filter LFPs
    fRawo_ln = newfilter(v,1000,0);
    save('LFP_all.mat','fRawo_ln')
else
    load(sprintf('%s/LFP_all.mat',exp_path))
end

num_channels = size(fRawo_ln,1);
% get LFPs 
disp('Get the LFPs');
tic
var_name = cell(1,num_channels);
for ch = 1:num_channels
    if ch < 10
        var_name{ch} = sprintf('LFP0%d',ch);
    else
        var_name{ch} = sprintf('LFP%d',ch);
    end
end
cont=struct;

field_file_name = 'fields';
field_output_dir = fullfile(exp_path, field_file_name);
[~,message]=mkdir(field_output_dir); %#ok<NASGU>
cd(field_output_dir);
fileID2 = fopen('lfps.txt','w');    
for i=1:size(fRawo_ln,1)   % number of channels     
    if i>1
        fprintf(fileID2,'\r\n');
    end      
    ch=sprintf('%s%d', 'Processing channel: ', i);
    disp(ch);
    if i<10
        save_lfp=sprintf('%s%d','lfp0', i);
    else
        save_lfp=sprintf('%s%d','lfp', i);   
    end            
    cont(i).sig = fRawo_ln(i,:);
    cd(field_output_dir);
    fprintf(fileID2,save_lfp);                  
end
fclose(fileID2); 
toc    
% clear aux_data lfp data zx 

probetype = input('Did you use NeuroNexus 2x16 probe (1), 1x32 probe (2), 32 channel polytrode (3), or 32 channel linear probe (4)?: ', 's');
probetype = str2double(probetype);
if probetype == 1
    pos=[29
    26
    24
    21
    20
    23
    25
    28
    30
    18
    19
    22
    32
    27
    17
    31
    7
    2
    15
    8
    11
    10
    12
    9
    6
    14
    13
    3
    5
    16
    4
    1
    ];
    spacing = 50;   % vertical spacing of contacts (in microns)
elseif probetype == 2;
    pos= [4
     5
    13
     6
    12
    11
    15
     7
     2
     8
    10
     9
    14
     3
    16
     1
    17
    32
    19
    30
    25
    20
    24
    29
    26
    21
    23
    28
    18
    22
    27
    31];
    spacing = 20;   % vertical spacing of contacts

elseif probetype == 3;      % polytrode(pretending they're on same xplane)
    pos = [ 8      % from highest to lowest
    24
    2
    29
    7
    26
    15
    21
    11
    23
    12
    28
    6
    18
    13
    22
    5
    27
    4
    31
    10
    20
    9
    25
    14
    30
    3
    19
    16
    32
    1
    17];
    spacing = 25;   % vertical spacing of contacts
    
elseif probetype == 4;      % linear 32ch
    pos = [1
    17
    16
    32
    3
    19
    14
    30
    9
    25
    10
    20
    8
    24
    2
    29
    7
    26
    15
    21
    11
    23
    12
    28
    6
    18
    13
    22
    5
    27
    4
    31];
    spacing = 25;
end






for i=1:length(var_name)
    sig{i}=sprintf('%s%d%s','=cont(',pos(i),').sig');
    evalc([var_name{i}, sig{i}]);   % LFPs are ordered from top to bottom!
end

%% find light onset times during blank trials (when mouse was stationary)
disp('Find timing using PD pulses to est. the Evoked Response Potential (ERP)')
tic
% get average light onset time
[~,~,~,av_light_start] = get_lightstim_v2(exp_path,exp_type);   % just to get duration and time of light onset
% get the details of the experiment (trial types, prestim time, etc.)
[prestim,poststim,stimtime,trial_type,IVs] = get_exp_params(exp_path,exp_type);
% identify blank light trials
lightvar = find(strcmp(IVs,'light_bit'));
runvar = find(strcmp(IVs,'running'));
light_blnk = find((trial_type(:,1)==0) & (trial_type(:,lightvar)>=1) & (trial_type(:,runvar)==0));

new_re=zeros(1,length(light_blnk));
disp('Get timestamps of light onset during blank trials')
for i = 1:length(light_blnk)
    trials2 (i,1) = find(time_index>=trials(light_blnk(i),1)&time_index<=trials(light_blnk(i),2),1,'first');  % in samples, starting from 1
    trials2 (i,2) = find(time_index>=(time_index(trials2(i,1)))&time_index<=(time_index(trials2(i,1))+2.000),1,'last');
    trial_time(i,:) = trials2(i,1):1:trials2(i,1)+2000;
end
timing=(time_index(trial_time(1,:))-time_index(trial_time(1,1))-1);


%%
disp('Create ERPs for each LFP trials x time'); 
% Import electrdoes are reordered based on the Neuronexus probe
ERP01=mean(LFP01(trial_time),1);
ERP02=mean(LFP02(trial_time),1);
ERP03=mean(LFP03(trial_time),1);
ERP04=mean(LFP04(trial_time),1);
ERP05=mean(LFP05(trial_time),1);
ERP06=mean(LFP06(trial_time),1);
ERP07=mean(LFP07(trial_time),1);
ERP08=mean(LFP08(trial_time),1);
ERP09=mean(LFP09(trial_time),1);
ERP10=mean(LFP10(trial_time),1);
ERP11=mean(LFP11(trial_time),1);
ERP12=mean(LFP12(trial_time),1);
ERP13=mean(LFP13(trial_time),1);
ERP14=mean(LFP14(trial_time),1);
ERP15=mean(LFP15(trial_time),1);
ERP16=mean(LFP16(trial_time),1);
ERP17=mean(LFP17(trial_time),1);
ERP18=mean(LFP18(trial_time),1);
ERP19=mean(LFP19(trial_time),1);
ERP20=mean(LFP20(trial_time),1);
ERP21=mean(LFP21(trial_time),1);
ERP22=mean(LFP22(trial_time),1);
ERP23=mean(LFP23(trial_time),1);
ERP24=mean(LFP24(trial_time),1);
ERP25=mean(LFP25(trial_time),1);
ERP26=mean(LFP26(trial_time),1);
ERP27=mean(LFP27(trial_time),1);
ERP28=mean(LFP28(trial_time),1);
ERP29=mean(LFP29(trial_time),1);
ERP30=mean(LFP30(trial_time),1);
ERP31=mean(LFP31(trial_time),1);
ERP32=mean(LFP32(trial_time),1);
%----------------------------%
if probetype == 1
    aux_shk1=vertcat(ERP01,ERP02,ERP03,ERP04,ERP05,ERP06,ERP07,ERP08,ERP09,ERP10,ERP11,ERP12,ERP13,ERP14,ERP15,ERP16);
    aux_shk2=vertcat(ERP17,ERP18,ERP19,ERP20,ERP21,ERP22,ERP23,ERP24,ERP25,ERP26,ERP27,ERP28,ERP29,ERP30,ERP31,ERP32);
    % scale factor
    ERP_shk1=(aux_shk1/(1*10^8))*(1*10^6);% Scale factor for  ERP      <<<< MAYBE CHANGE THIS
    ERP_shk2=(aux_shk2/(1*10^8))*(1*10^6);% Scale factor for  ERP
% //elseif probetype ==2
else
    aux_shk1 = vertcat(ERP01,ERP02,ERP03,ERP04,ERP05,ERP06,ERP07,ERP08,ERP09,ERP10,ERP11,ERP12,ERP13,ERP14,ERP15,ERP16,...
       ERP17,ERP18,ERP19,ERP20,ERP21,ERP22,ERP23,ERP24,ERP25,ERP26,ERP27,ERP28,ERP29,ERP30,ERP31,ERP32);
        % scale factor
    ERP_shk1=(aux_shk1/(1*10^8))*(1*10^6);% Scale factor for  ERP      <<<< MAYBE CHANGE THIS
% elseif probetype ==3
% %     aux_shk1 = vertcat(ERP02,ERP04,ERP06,ERP08,ERP10,ERP12,ERP14,ERP16,...
% %        ERP18,ERP20,ERP22,ERP24,ERP26,ERP28,ERP30,ERP32);
% %     aux_shk2 = vertcat(ERP01,ERP03,ERP05,ERP07,ERP09,ERP11,ERP13,ERP15,...
% %         ERP17,ERP19,ERP21,ERP23,ERP25,ERP27,ERP29,ERP31);
%     aux_shk1 = vertcat(ERP01,ERP02,ERP03,ERP04,ERP05,ERP06,ERP07,ERP08,ERP09,ERP10,ERP11,ERP12,ERP13,ERP14,ERP15,ERP16,...
%            ERP17,ERP18,ERP19,ERP20,ERP21,ERP22,ERP23,ERP24,ERP25,ERP26,ERP27,ERP28,ERP29,ERP30,ERP31,ERP32);
%        ERP_shk1=(aux_shk1/(1*10^8))*(1*10^6);% Scale factor for  ERP      <<<< MAYBE CHANGE THIS
%     % scale factor
% %     ERP_shk1=(aux_shk1/(1*10^8))*(1*10^6);% Scale factor for  ERP      <<<< MAYBE CHANGE THIS
%     ERP_shk2=(aux_shk2/(1*10^8))*(1*10^6);% Scale factor for  ERP

end

% clear aux_shk1 aux_shk2

%% Plot and clean up ERP figures
if probetype ==1
    ERP_shk1=clean_ERP(ERP_shk1,timing);
    ERP_shk2=clean_ERP(ERP_shk2,timing);
else
    ERP_shk1=clean_ERP(ERP_shk1,timing);
end

% normalize ERPs by prestim period 

%% The final ERP figure is sent to the screen to view and now the next section deals
%  with the CSD plotter and average analysis
pause(5);
file_name = 'CSD_LFPdata';
save (file_name); 
disp ('saving mat')
HC=CSDplotter;
disp ('Use CSD plotter')
clc
pause(20)
disp ('ERP: normal LFP time series w/o moving trials') 
reply = input('Ready to continue? Y/N: ','s');
if reply == 'Y';    
close all;
disp ('Open CSD matrix file for Shank 1')
filename = uigetfile;
load (filename);
CSD_matrix1=CSD_matrix;
fprintf('%s%s','Filename:   ',filename);
close all
clc
disp ('Plot final ERP and CSD side by side')
X2=timing.*1000;
clear CSD_matrix    
if probetype ==1
    disp ('Open CSD matrix file for Shank 2')
    filename = uigetfile;
    load (filename);
    CSD_matrix2=CSD_matrix;
    fprintf('%s%s','Filename:   ',filename);
    close all
    clc
end
disp ('Plot final ERP and CSD side by side')
%%
    FontName = 'MyriadPro-Regular'; % or choose any other font
    FontSize = 14;      
    figure_width = 14;  
    figure_height = 10;
    figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
    ERP_fig1 = figure;
    set(ERP_fig1,'Visible', figuresVisible)
    set(ERP_fig1, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
    set(ERP_fig1, 'PaperPositionMode', 'auto');    
    set(ERP_fig1, 'Color', [1 1 1]); % Sets figure background
    set(ERP_fig1, 'Color', [1 1 1]); % Sets axes background
    hsp = subplot(1,1,1, 'Parent', ERP_fig1);
    set(hsp,'Position',[0.15 0.17 0.75 0.80]);
    plot (X2, ERP_shk1');
    axis on;      % display axis
    axis tight;   % no white borders
    set(gca, ...
        'Box'         , 'off'      , ...
        'TickDir'     , 'out'      , ...
        'TickLength'  , [.015 .015] , ...
        'XMinorTick'  , 'off'      , ...
        'YMinorTick'  , 'off'     , ...
        'XGrid'       , 'off'     , ...
        'YGrid'       , 'off'     , ...
        'XColor'      , [.0 .0 .0], ...
        'YColor'      , [.0 .0 .0], ...
        'LineWidth'   , 0.6        ); 
    set(gca,'Xlim',[-25 225]);
    yaxis=ylim;
    set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
    prestim_offset_y            = yaxis(1):1:yaxis(2);
    prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
    hold on;plot(prestim_offset_t, prestim_offset_y, 'k','linewidth', 1);        
    xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
    yLabelText = 'Amplitude (uV)';  
    % save handles to set up label properties
    hXLabel = xlabel(xLabelText);
    hYLabel = ylabel(yLabelText);    
    set([gca, hXLabel, hYLabel], ...
    'FontSize'   , FontSize    , ...
    'FontName'   , FontName);
    fig_title=sprintf('%s','ERP 1 ');
    set(gca,'Layer', 'top');
    drawnow
    %export_fig (fig_title, '-pdf')    
        export_fig (fig_title, '-png','-r600','-zbuffer');

    %%
    if probetype ==1
        
        FontName = 'MyriadPro-Regular'; % or choose any other font
        FontSize = 14;      
        figure_width = 14;  
        figure_height = 10;
        figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
        ERP_fig2 = figure;
        set(ERP_fig2,'Visible', figuresVisible)
        set(ERP_fig2, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
        set(ERP_fig2, 'PaperPositionMode', 'auto');    
        set(ERP_fig2, 'Color', [1 1 1]); % Sets figure background
        set(ERP_fig2, 'Color', [1 1 1]); % Sets axes background
        hsp = subplot(1,1,1, 'Parent', ERP_fig2);
        set(hsp,'Position',[0.19 0.19 0.75 0.80]);
        plot (X2, ERP_shk2');
        axis on;      % display axis
        axis tight;   % no white borders
        set(gca, ...
            'Box'         , 'off'      , ...
            'TickDir'     , 'out'      , ...
            'TickLength'  , [.015 .015] , ...
            'XMinorTick'  , 'off'      , ...
            'YMinorTick'  , 'off'     , ...
            'XGrid'       , 'off'     , ...
            'YGrid'       , 'off'     , ...
            'XColor'      , [.0 .0 .0], ...
            'YColor'      , [.0 .0 .0], ...
            'LineWidth'   , 0.6        ); 
        set(gca,'Xlim',[-25 225]);
        yaxis=ylim;
        set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
        prestim_offset_y            = yaxis(1):1:yaxis(2);
        prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
        hold on;plot(prestim_offset_t, prestim_offset_y, 'k','linewidth', 1);        
        xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
        yLabelText = 'Amplitude (uV)';  
        % save handles to set up label properties
        hXLabel = xlabel(xLabelText);
        hYLabel = ylabel(yLabelText);    
        set([gca, hXLabel, hYLabel], ...
        'FontSize'   , FontSize    , ...
        'FontName'   , FontName);
        fig_title=sprintf('%s','ERP 2 ');
        set(gca,'Layer', 'top');
        drawnow
    %     export_fig (fig_title, '-pdf') 
        export_fig (fig_title, '-png','-r600','-opengl')
    end
%%    
if probetype ==1
    left_channels= fliplr([1:1:size(ERP_shk1,1)]);
    right_channels= fliplr([17:1:(size(ERP_shk2,1)+16)]);
    channels={left_channels';right_channels'}';
else 
    left_channels= fliplr([1:1:size(ERP_shk1,1)]);
    channels = {left_channels'};
end
FontName = 'MyriadPro-Regular'; % or choose any other font
    FontSize = 14;      
    figure_width = 28;  
    figure_height = 14;
    figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
    ERP_stacked=figure;% figure('units', 'normalized', 'outerposition', [0 0 1 1]);        
    set(ERP_stacked, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
    set(ERP_stacked, 'PaperPositionMode', 'auto');    
    set(ERP_stacked, 'Color', [1 1 1]); % Sets figure background
    set(ERP_stacked, 'Color', [1 1 1]); % Sets axes background
    hsp = subplot(1,1,1, 'Parent', ERP_stacked);
    set(hsp,'Position',[0.15 0.17 0.75 0.80]);  
for ii = 1:size(channels,2)
    subplot(1, 2, ii);
    depth           = 0;
    depth_spacing   = 50;
    max_y           = 0;        
    hold all;        
    % for each channel
    chan_legends    = {};
 for j=1:length(channels{ii});    
    for i = channels{ii}(j)
        if ii==1 
            averaged_ERP= ERP_shk1(i,:);
        elseif ii==2;
            i=i-16;
            averaged_ERP= ERP_shk2(i,:);
        end
           plot(X2, averaged_ERP*depth_spacing + depth,'LineWidth',2);
           max_y= max_y + max(averaged_ERP);            
           depth= depth + depth_spacing;
           chan_legends= [chan_legends, num2str(i)];
    end
end    
        yaxis=ylim;
        set(gca,'Ylim',[-depth_spacing depth_spacing*length(channels{ii})])
        if ii==1
            set(gca, 'ytick', [0:depth_spacing:(depth_spacing*length(channels{ii}))-depth_spacing],'tickdir','out','yticklabel',[left_channels]);   
            axis on;      % display axis
            set(gca, ...
            'Box'         , 'off'      , ...
            'TickDir'     , 'out'      , ...
            'TickLength'  , [0 0] , ...
            'XMinorTick'  , 'off'      , ...
            'YMinorTick'  , 'off'     , ...
            'XGrid'       , 'off'     , ...
            'YGrid'       , 'off'     , ...
            'XColor'      , [.0 .0 .0], ...
            'YColor'      , [.0 .0 .0], ...
            'LineWidth'   , 0.6        ); 
        set(gca,'Xlim',[-25 225]);
        set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
        xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
        yLabelText = 'Electrode number (Sup-->Deep)';  
        % save handles to set up label properties
        hXLabel = xlabel(xLabelText);
        hYLabel = ylabel(yLabelText);    
        set([gca, hXLabel, hYLabel], ...
        'FontSize'   , FontSize    , ...
        'FontName'   , FontName);
        prestim_offset_y            = yaxis(1):1:yaxis(2);
        prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
        plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',2);        
        % poststimulus onset
        elseif ii==2;
            set(gca, 'ytick', [0:depth_spacing:(depth_spacing*length(channels{ii}))-depth_spacing],'tickdir','out','yticklabel',[right_channels]);   
            axis on;      % display axis
            set(gca, ...
            'Box'         , 'off'      , ...
            'TickDir'     , 'out'      , ...
            'TickLength'  , [0 0] , ...
            'XMinorTick'  , 'off'      , ...
            'YMinorTick'  , 'off'     , ...
            'XGrid'       , 'off'     , ...
            'YGrid'       , 'off'     , ...
            'XColor'      , [.0 .0 .0], ...
            'YColor'      , [.0 .0 .0], ...
            'LineWidth'   , 0.6        ); 
        set(gca,'Xlim',[-25 225]);
        set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
        xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
        yLabelText = 'Electrode number (Sup-->Deep)';  
        % save handles to set up label properties
        hXLabel = xlabel(xLabelText);
        hYLabel = ylabel(yLabelText);    
        set([gca, hXLabel, hYLabel], ...
        'FontSize'   , FontSize    , ...
        'FontName'   , FontName);  
        prestim_offset_y            = yaxis(1):1:yaxis(2);
        prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
        plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',2); 
        end 
end
fig_title=sprintf('%s','ERP Stacked ');
set(gca,'Layer', 'top');
drawnow
%export_fig (fig_title, '-pdf')
    export_fig (fig_title, '-png','-r600','-zbuffer');

%%     Plot CSDs
    
%     CSD_matrix_all = CSD_matrix1;
%     CSD_matrix1 = CSD_matrix_all(2:2:end,:);
%     CSD_matrix2 = CSD_matrix_all(1:2:end,:);

    figure_width = 12;  
    figure_height = 10;
    FontSize = 12;  
    FontName = 'MyriadPro-Regular'; % or choose any other font
    % --- setup plot windows
    figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
    CSD_fig1 = figure;
    set(CSD_fig1,'Visible', figuresVisible)
    set(CSD_fig1, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
    set(CSD_fig1, 'PaperPositionMode', 'auto');    
    set(CSD_fig1, 'Renderer','Zbuffer'); 
    set(CSD_fig1, 'Color', [1 1 1]); % Sets figure background
    set(CSD_fig1, 'Color', [1 1 1]); % Sets axes background
    % --- dimensions and position of plot 
    hsp = subplot(1,1,1, 'Parent', CSD_fig1);
    set(hsp,'Position',[0.15 0.15 0.60 0.80]);    
    colorDepth = 1000;
    colormap(flipud(jet(colorDepth)));
%     pcolor(X2, 1:1:size(CSD_matrix1,1), CSD_matrix1);     
%     imagesc(X2,[],CSD_matrix1)
    imagesc(X2(976:1226),[],CSD_matrix1(:,976:1226))
    shading interp; % do not interpolate pixels    
    axis on; % display axis
    axis tight;% no white borders
        set(gca, ...
            'Box'         , 'off'      , ...
            'TickDir'     , 'in'      , ...
            'Ydir'        , 'reverse', ...
            'TickLength'  , [.01 .01] , ...
            'XMinorTick'  , 'off'      , ...
            'YMinorTick'  , 'off'     , ...
            'XGrid'       , 'off'     , ...
            'YGrid'       , 'off'     , ...
            'XColor'      , [.0 .0 .0], ...
            'YColor'      , [.0 .0 .0], ...
            'LineWidth'   , 0.6        );             
    set(gca,'Xlim',[-25 225]);
    set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
    set(gca, 'yticklabel',1:1:size(CSD_matrix1,1), 'Ytick', 1:1:size(CSD_matrix1,1));                   
    xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
    yLabelText = 'Electrode number';  
    hXLabel = xlabel(xLabelText);
    hYLabel = ylabel(yLabelText);    
    fig_title=sprintf('%s','Shank 1 ');    
    yaxis=ylim;
    prestim_offset_y            = yaxis(1):1:yaxis(2);
    prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
    hold on;plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',1);        
%     caxis([min(min(CSD_matrix1)) max(max(CSD_matrix1))]);    
    zLabelText = 'nA / mm^3';  % greek letters in LaTeX Syntax    
    hcb = colorbar('eastoutside');
    h_bar = findobj(gcf,'Tag','Colorbar');
    initpos = get(h_bar,'Position');
    set(h_bar, ...
    'Position',[initpos(1)+initpos(3)*2.5 initpos(2)+initpos(4)*0.3 ...
      initpos(3)*0.4 initpos(4)*0.4]);     
    hcLabel = ylabel(hcb,zLabelText);    
    set(hcb,'YTickLabel',{'Sink','Source'}, 'Ytick', [min(min(CSD_matrix1)) max(max(CSD_matrix1))])
    set(hcb, ...
     'Box'         , 'on'     , ...
     'TickDir'     , 'in'     , ...
     'TickLength'  , [.010 .010] , ...
     'LineWidth'   , 0.6);
    set([gca, hcb, hXLabel, hYLabel, hcLabel], ...
    'FontSize'   , FontSize    , ...
    'FontName'   , FontName);
    ylabh=get(hcb,'Ylabel');
    set(ylabh,'Position',get(ylabh,'Position')-[8 0 0]); 
    set(gca,'Layer', 'top');
    drawnow   
% % superimpose ERPs    
% ii=1;
%     depth           = 1;
%     depth_spacing   = 1;
%     max_y           = 0;        
%     hold all;        
%     % for each channel
%     chan_legends    = {};
%  for j=1:length(channels{ii});    
%     for i = channels{ii}(j)
%         if ii==1 
%             averaged_ERP= ERP_shk1(i,:);
%         elseif ii==2;
%             i=i-16;
%             averaged_ERP= ERP_shk2(i,:);
%         end
%            plot(X2, averaged_ERP*depth_spacing*10 + depth,'LineWidth',2,'Color','k');
%            max_y= max_y + max(averaged_ERP);            
%            depth= depth + depth_spacing;
%            chan_legends= [chan_legends, num2str(i)];
%     end
% end    
    %export_fig (fig_title, '-pdf')
     nrm = input('Do you want to normalize the CSD plot? Y/N:','s');
        if nrm == 'Y'
            prestim_csd =  mean(CSD_matrix1(:,976:1025),2); % prestim = 200ms before flip
            for c = 1: size(CSD_matrix1,1)
                nrm_CSD_matrix(c,:) = CSD_matrix1(c,976:end)-prestim_csd(c);
            end
            CSD_fig1 = figure;
            set(CSD_fig1,'Visible', figuresVisible)
            set(CSD_fig1, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
            set(CSD_fig1, 'PaperPositionMode', 'auto');    
            set(CSD_fig1, 'Renderer','Zbuffer'); 
            set(CSD_fig1, 'Color', [1 1 1]); % Sets figure background
            set(CSD_fig1, 'Color', [1 1 1]); % Sets axes background
            % --- dimensions and position of plot 
            hsp = subplot(1,1,1, 'Parent', CSD_fig1);
            set(hsp,'Position',[0.15 0.15 0.60 0.80]);    
            colorDepth = 1000;
            colormap(flipud(jet(colorDepth)));
%             pcolor(X2(1001:end), 1:1:size(CSD_matrix1,1), nrm_CSD_matrix);    
            imagesc(X2(976:end), [], nrm_CSD_matrix);
            shading interp; % do not interpolate pixels    
            axis on; % display axis
            axis tight;% no white borders
                set(gca, ...
                    'Box'         , 'off'      , ...
                    'TickDir'     , 'in'      , ...
                    'Ydir'        , 'reverse', ...
                    'TickLength'  , [.01 .01] , ...
                    'XMinorTick'  , 'off'      , ...
                    'YMinorTick'  , 'off'     , ...
                    'XGrid'       , 'off'     , ...
                    'YGrid'       , 'off'     , ...
                    'XColor'      , [.0 .0 .0], ...
                    'YColor'      , [.0 .0 .0], ...
                    'LineWidth'   , 0.6        );             
            set(gca,'Xlim',[-25 225]);
            set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
            set(gca, 'yticklabel',1:1:size(CSD_matrix1,1), 'Ytick', 1:1:size(CSD_matrix1,1));                   
            xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
            yLabelText = 'Electrode number';  
            hXLabel = xlabel(xLabelText);
            hYLabel = ylabel(yLabelText);    
            fig_title=sprintf('%s','Shank 1 - Normalized');    
            yaxis=ylim;
            prestim_offset_y            = yaxis(1):1:yaxis(2);
            prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
            hold on;plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',1);        
            caxis([min(min(CSD_matrix1)) max(max(CSD_matrix1))]);    
            zLabelText = 'nA / mm^3';  % greek letters in LaTeX Syntax    
            hcb = colorbar('eastoutside');
            h_bar = findobj(gcf,'Tag','Colorbar');
            initpos = get(h_bar,'Position');
            set(h_bar, ...
            'Position',[initpos(1)+initpos(3)*2.5 initpos(2)+initpos(4)*0.3 ...
              initpos(3)*0.4 initpos(4)*0.4]);     
            hcLabel = ylabel(hcb,zLabelText);    
            set(hcb,'YTickLabel',{'Sink','Source'}, 'Ytick', [min(min(CSD_matrix1)) max(max(CSD_matrix1))])
            set(hcb, ...
             'Box'         , 'on'     , ...
             'TickDir'     , 'in'     , ...
             'TickLength'  , [.010 .010] , ...
             'LineWidth'   , 0.6);
            set([gca, hcb, hXLabel, hYLabel, hcLabel], ...
            'FontSize'   , FontSize    , ...
            'FontName'   , FontName);
            ylabh=get(hcb,'Ylabel');
            set(ylabh,'Position',get(ylabh,'Position')-[8 0 0]); 
            set(gca,'Layer', 'top');
            plot([25 25],get(gca,'ylim'),'-k','Linewidth',.5);
            drawnow     
        end
        export_fig (fig_title, '-png','-r600','-zbuffer');

%%
    if probetype ==1
        figure_width = 12;  
        figure_height = 10;
        FontSize = 12;  
        FontName = 'MyriadPro-Regular'; % or choose any other font
        % --- setup plot windows
        figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
        CSD_fig2 = figure;
        set(CSD_fig2,'Visible', figuresVisible)
        set(CSD_fig2, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
        set(CSD_fig2, 'PaperPositionMode', 'auto');    
        set(CSD_fig2, 'Renderer','Zbuffer'); 
        set(CSD_fig2, 'Color', [1 1 1]); % Sets figure background
        set(CSD_fig2, 'Color', [1 1 1]); % Sets axes background
        % --- dimensions and position of plot 
        hsp = subplot(1,1,1, 'Parent', CSD_fig2);
        set(hsp,'Position',[0.15 0.15 0.60 0.80]);    
        colorDepth = 1000;
        colormap(flipud(jet(colorDepth)));
%         pcolor(X2, 1:1:size(CSD_matrix2,1), CSD_matrix2);     
        imagesc(X2(976:1226),[],CSD_matrix2(:,976:1226))
        shading interp; % do not interpolate pixels    
        axis on; % display axis
        axis tight;% no white borders
            set(gca, ...
                'Box'         , 'off'      , ...
                'TickDir'     , 'in'      , ...
                'Ydir'        , 'reverse', ...
                'TickLength'  , [.01 .01] , ...
                'XMinorTick'  , 'off'      , ...
                'YMinorTick'  , 'off'     , ...
                'XGrid'       , 'off'     , ...
                'YGrid'       , 'off'     , ...
                'XColor'      , [.0 .0 .0], ...
                'YColor'      , [.0 .0 .0], ...
                'LineWidth'   , 0.6        );             
        set(gca,'Xlim',[-25 225]);
        set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
        set(gca, 'yticklabel',1:1:size(CSD_matrix2,1), 'Ytick', 1:1:size(CSD_matrix2,1));                   
        xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
        yLabelText = 'Electrode number';  
        hXLabel = xlabel(xLabelText);
        hYLabel = ylabel(yLabelText);    
        fig_title=sprintf('%s','Shank 2 ');        
        yaxis=ylim;
        prestim_offset_y            = yaxis(1):1:yaxis(2);
        prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
        hold on;plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',1);        
%         caxis([min(min(CSD_matrix2)) max(max(CSD_matrix2))]);    
        zLabelText = 'nA / mm^3';  % greek letters in LaTeX Syntax    
        hcb = colorbar('eastoutside');
        h_bar = findobj(gcf,'Tag','Colorbar');
        initpos = get(h_bar,'Position');
        set(h_bar, ...
        'Position',[initpos(1)+initpos(3)*2.5 initpos(2)+initpos(4)*0.3 ...
          initpos(3)*0.4 initpos(4)*0.4]);     
        hcLabel = ylabel(hcb,zLabelText);    
        set(hcb,'YTickLabel',{'Sink','Source'}, 'Ytick', [min(min(CSD_matrix2)) max(max(CSD_matrix2))])
        set(hcb, ...
         'Box'         , 'on'     , ...
         'TickDir'     , 'in'     , ...
         'TickLength'  , [.010 .010] , ...
         'LineWidth'   , 0.6);
        set([gca, hXLabel, hYLabel], ...
        'FontSize'   , FontSize    , ...
        'FontName'   , FontName);
        set([hcb, hcLabel], ...
        'FontSize'   , 10    , ...
        'FontName'   , FontName);
        ylabh=get(hcb,'Ylabel');
        set(ylabh,'Position',get(ylabh,'Position')-[8 0 0]); 
        set(gca,'Layer', 'top');
        drawnow   
        
         nrm = input('Do you want to normalize the CSD plot? Y/N:','s');
        if nrm == 'Y'
            prestim_csd =  mean(CSD_matrix2(:,900:1000),2); % prestim = 200ms before flip
            for c = 1: size(CSD_matrix2,1)
                nrm_CSD_matrix(c,:) = CSD_matrix2(c,1001:end)-prestim_csd(c);
            end
            CSD_fig1 = figure;
            set(CSD_fig1,'Visible', figuresVisible)
            set(CSD_fig1, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
            set(CSD_fig1, 'PaperPositionMode', 'auto');    
            set(CSD_fig1, 'Renderer','Zbuffer'); 
            set(CSD_fig1, 'Color', [1 1 1]); % Sets figure background
            set(CSD_fig1, 'Color', [1 1 1]); % Sets axes background
            % --- dimensions and position of plot 
            hsp = subplot(1,1,1, 'Parent', CSD_fig1);
            set(hsp,'Position',[0.15 0.15 0.60 0.80]);    
            colorDepth = 1000;
            colormap(flipud(jet(colorDepth)));
%             pcolor(X2(1001:end), 1:1:size(CSD_matrix1,1), nrm_CSD_matrix);    
            imagesc(X2(1001:end), [], nrm_CSD_matrix);
            shading interp; % do not interpolate pixels    
            axis on; % display axis
            axis tight;% no white borders
                set(gca, ...
                    'Box'         , 'off'      , ...
                    'TickDir'     , 'in'      , ...
                    'Ydir'        , 'reverse', ...
                    'TickLength'  , [.01 .01] , ...
                    'XMinorTick'  , 'off'      , ...
                    'YMinorTick'  , 'off'     , ...
                    'XGrid'       , 'off'     , ...
                    'YGrid'       , 'off'     , ...
                    'XColor'      , [.0 .0 .0], ...
                    'YColor'      , [.0 .0 .0], ...
                    'LineWidth'   , 0.6        );             
            set(gca,'Xlim',[-25 225]);
            set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
            set(gca, 'yticklabel',1:1:size(CSD_matrix1,1), 'Ytick', 1:1:size(CSD_matrix1,1));                   
            xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
            yLabelText = 'Electrode number';  
            hXLabel = xlabel(xLabelText);
            hYLabel = ylabel(yLabelText);    
            fig_title=sprintf('%s','Shank 1 - Normalized');    
            yaxis=ylim;
            prestim_offset_y            = yaxis(1):1:yaxis(2);
            prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
            hold on;plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',1);        
            caxis([min(min(CSD_matrix1)) max(max(CSD_matrix1))]);    
            zLabelText = 'nA / mm^3';  % greek letters in LaTeX Syntax    
            hcb = colorbar('eastoutside');
            h_bar = findobj(gcf,'Tag','Colorbar');
            initpos = get(h_bar,'Position');
            set(h_bar, ...
            'Position',[initpos(1)+initpos(3)*2.5 initpos(2)+initpos(4)*0.3 ...
              initpos(3)*0.4 initpos(4)*0.4]);     
            hcLabel = ylabel(hcb,zLabelText);    
            set(hcb,'YTickLabel',{'Sink','Source'}, 'Ytick', [min(min(CSD_matrix1)) max(max(CSD_matrix1))])
            set(hcb, ...
             'Box'         , 'on'     , ...
             'TickDir'     , 'in'     , ...
             'TickLength'  , [.010 .010] , ...
             'LineWidth'   , 0.6);
            set([gca, hcb, hXLabel, hYLabel, hcLabel], ...
            'FontSize'   , FontSize    , ...
            'FontName'   , FontName);
            ylabh=get(hcb,'Ylabel');
            set(ylabh,'Position',get(ylabh,'Position')-[8 0 0]); 
            set(gca,'Layer', 'top');
            drawnow     
        end

    %     % superimpose ERPs    
    % ii=2;
    %     depth           = 1;
    %     depth_spacing   = 1;
    %     max_y           = 0;        
    %     hold all;        
    %     % for each channel
    %     chan_legends    = {};
    %  for j=1:length(channels{ii});    
    %     for i = channels{ii}(j)
    %         if ii==1 
    %             averaged_ERP= ERP_shk1(i,:);
    %         elseif ii==2;
    %             i=i-16;
    %             averaged_ERP= ERP_shk2(i,:);
    %         end
    %            plot(X2, averaged_ERP*depth_spacing*10 + depth,'LineWidth',2,'Color','k');
    %            max_y= max_y + max(averaged_ERP);            
    %            depth= depth + depth_spacing;
    %            chan_legends= [chan_legends, num2str(i)];
    %     end
    % end    
        %export_fig (fig_title, '-pdf')
        export_fig (fig_title, '-png','-r600','-zbuffer');
    end
%% Plot CSD traces (Megan addition)
% FontName = 'MyriadPro-Regular'; % or choose any other font
%     FontSize = 14;      
%     figure_width = 28;  
%     figure_height = 14;
%     figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
%     CSD_stacked=figure;% figure('units', 'normalized', 'outerposition', [0 0 1 1]);        
%     set(CSD_stacked, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
%     set(CSD_stacked, 'PaperPositionMode', 'auto');    
%     set(CSD_stacked, 'Color', [1 1 1]); % Sets figure background
%     set(CSD_stacked, 'Color', [1 1 1]); % Sets axes background
%     hsp = subplot(1,1,1, 'Parent', CSD_stacked);
%     set(hsp,'Position',[0.15 0.17 0.75 0.80]);  
% for ii = 1:size(channels,2)
%     subplot(1, 2, ii);
%     depth           = 0;
%     depth_spacing   = 500;
%     max_y           = 0;        
%     hold all;        
%     % for each channel
%     chan_legends    = {};
%  for j=1:length(channels{ii});    
%     for i = channels{ii}(j)
%         if ii==1 
%             CSD_trace = CSD_matrix1(i,:);
%         elseif ii==2;
%             i=i-16;
%             CSD_trace= CSD_matrix2(i,:);
%         end
%            plot(X2, CSD_trace/15 + depth,'LineWidth',2);
%            max_y= max_y + max(CSD_trace);            
%            depth= depth + depth_spacing;
%            chan_legends= [chan_legends, num2str(i)];
%     end
% end    
%         yaxis=ylim;
%         set(gca,'Ylim',[-depth_spacing depth_spacing*length(channels{ii})])
%         if ii==1
%             set(gca, 'ytick', [0:depth_spacing:(depth_spacing*length(channels{ii}))-depth_spacing],'tickdir','out','yticklabel',[left_channels]);   
%             axis on;      % display axis
%             set(gca, ...
%             'Box'         , 'off'      , ...
%             'TickDir'     , 'out'      , ...
%             'TickLength'  , [0 0] , ...
%             'XMinorTick'  , 'off'      , ...
%             'YMinorTick'  , 'off'     , ...
%             'XGrid'       , 'off'     , ...
%             'YGrid'       , 'off'     , ...
%             'XColor'      , [.0 .0 .0], ...
%             'YColor'      , [.0 .0 .0], ...
%             'LineWidth'   , 0.6        ); 
%         set(gca,'Xlim',[-25 225]);
%         set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
%         xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
%         yLabelText = 'Electrode number (Sup-->Deep)';  
%         % save handles to set up label properties
%         hXLabel = xlabel(xLabelText);
%         hYLabel = ylabel(yLabelText);    
%         set([gca, hXLabel, hYLabel], ...
%         'FontSize'   , FontSize    , ...
%         'FontName'   , FontName);
%         prestim_offset_y            = yaxis(1):1:yaxis(2);
%         prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
%         plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',2);        
%         % poststimulus onset
%         elseif ii==2;
%             set(gca, 'ytick', [0:depth_spacing:(depth_spacing*length(channels{ii}))-depth_spacing],'tickdir','out','yticklabel',[right_channels]);   
%             axis on;      % display axis
%             set(gca, ...
%             'Box'         , 'off'      , ...
%             'TickDir'     , 'out'      , ...
%             'TickLength'  , [0 0] , ...
%             'XMinorTick'  , 'off'      , ...
%             'YMinorTick'  , 'off'     , ...
%             'XGrid'       , 'off'     , ...
%             'YGrid'       , 'off'     , ...
%             'XColor'      , [.0 .0 .0], ...
%             'YColor'      , [.0 .0 .0], ...
%             'LineWidth'   , 0.6        ); 
%         set(gca,'Xlim',[-25 225]);
%         set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])
%         xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
%         yLabelText = 'Electrode number (Sup-->Deep)';  
%         % save handles to set up label properties
%         hXLabel = xlabel(xLabelText);
%         hYLabel = ylabel(yLabelText);    
%         set([gca, hXLabel, hYLabel], ...
%         'FontSize'   , FontSize    , ...
%         'FontName'   , FontName);  
%         prestim_offset_y            = yaxis(1):1:yaxis(2);
%         prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
%         plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',2);        
%         end 
% end
% fig_title=sprintf('%s','CSD Stacked ');
% set(gca,'Layer', 'top');
% drawnow

%% Determine the center of mass
   t1=find(X2>=-200 & X2<=500,1,'first');
   t2=find(X2>=-200 & X2<=500,1,'last');
   [mean_x1 mean_y1]=centroid_me(CSD_matrix1(:,t1:t2));
   mean_x1=X2((t1-1)+mean_x1);    
   sprintf ('%s%d%s%d','The centroid value is: ',round(mean_x1), ' ms at contact number ',mean_y1)
   if probetype ==1
       t1=find(X2>=-200 & X2<=500,1,'first');
       t2=find(X2>=-200 & X2<=500,1,'last');
       [mean_x2 mean_y2]=centroid_me(CSD_matrix2(:,t1:t2));
       mean_x2=X2((t1-1)+mean_x2);    
       sprintf ('%s%d%s%d','The centroid value is: ',round(mean_x2), ' ms at contact number ',mean_y2)
   end
%%
disp ('Look at the CSD and find the layers which contain the sink(red)')
st_sink1 = input('Shank 1 begining of the sink: ','s');
end_sink1 = input('Shank 1 Ending of the sink: ','s');
gran1=str2double(st_sink1):str2double(end_sink1);
%-------------------------------------%

if probetype ==1
    disp ('Look at the CSD and find the layers which contain the sink(red)')
    st_sink2 = input('Shank 2 begining of the sink: ','s');
    end_sink2 = input('Shank 2 Ending of the sink: ','s');
    gran2=str2double(st_sink2):str2double(end_sink2);
end
%%
%%% Now this and final section creates the average CSD across contacts
%%% given
%%% the user defined top and bottom of the sink(red) region in the CSD
%%% plots. The mean and the STD are calaucated for each layer. and the
%%% envelope of the std is ploted using the jbfill fx
axis_time=t1:t2;
if gran1(1)==2;
   SG_c=(CSD_matrix1(1,axis_time));    
   SG_std=std(CSD_matrix1(1,axis_time))./1;       
   SG_p=SG_c+SG_std;  SG_m=SG_c-SG_std;
else
    SG_c=mean(CSD_matrix1(1:(gran1(1)-1),axis_time),1);    
    SG_std=(std(CSD_matrix1((1:gran1(1)-1),axis_time),0,1))./size(CSD_matrix1(1:gran1(1)-1),2);    
    SG_p=SG_c+SG_std;  SG_m=SG_c-SG_std;
end
    G_c=mean(CSD_matrix1(gran1,axis_time),1);              
    G_std=(std(CSD_matrix1(gran1,axis_time),0,1))./size(CSD_matrix1(gran1),2);                  
    G_p=G_c+G_std;     G_m=G_c-G_std;
    
    IG_c=mean(CSD_matrix1((gran1(length(gran1))+1):size(CSD_matrix1,1),axis_time),1);   
    IG_std=(std(CSD_matrix1((gran1(length(gran1))+1):size(CSD_matrix1,1),axis_time),0,1))...
        ./(length((gran1(length(gran1))+1):size(CSD_matrix1)));
    IG_p=IG_c+IG_std;  IG_m=IG_c-IG_std;
%%
    figure_width = 12;  
    figure_height = 12;
    FontSize = 12;  
    FontName = 'MyriadPro-Regular'; % or choose any other font
    % --- setup plot windows
    figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
    Avg_CSD1 = figure;    
    set(Avg_CSD1,'Visible', figuresVisible)
    set(Avg_CSD1, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
    set(Avg_CSD1, 'PaperPositionMode', 'auto');    
    set(Avg_CSD1, 'Color', [1 1 1]); % Sets figure background
    set(Avg_CSD1, 'Color', [1 1 1]); % Sets axes background
    % --- dimensions and position of plot 
    hsp = subplot(1,1,1, 'Parent', Avg_CSD1);
    set(hsp,'Position',[0.10 0.15 0.80 0.80]);            
    x=X2(axis_time)';
    hold on;handle_vector(:,1) = plot(x,SG_c,'r','LineWidth',2);
    hold on; handle_vector(:,2) = jbfill(x,SG_p,SG_m,'r','r',1,.4);
    hold on; handle_vector(:,3) = plot(x,G_c,'b','LineWidth',2);
    hold on; handle_vector(:,4) = jbfill(x,G_p,G_m,'b','b',1,.4);
    hold on; handle_vector(:,5) = plot(x,IG_c,'color',[0 .5 0],'LineWidth',2);
    hold on; handle_vector(:,6) = jbfill(x,IG_p,IG_m,[0 .5 0],[0 .5 0],1,.4);
    % will remove the 3rd legend entry.
    hasbehavior(handle_vector(2),'legend',false);
    hasbehavior(handle_vector(4),'legend',false);
    hasbehavior(handle_vector(6),'legend',false);
    % will remove the 3rd legend entry.
    set(gca, ...
            'Box'         , 'off'      , ...
            'TickDir'     , 'out'      , ...
            'TickLength'  , [0 0] , ...
            'XMinorTick'  , 'off'      , ...
            'YMinorTick'  , 'off'     , ...
            'XGrid'       , 'off'     , ...
            'YGrid'       , 'off'     , ...
            'XColor'      , [.0 .0 .0], ...
            'YColor'      , [.0 .0 .0], ...
            'LineWidth'   , 0.6        );     
    set(gca,'Xlim',[-25 225]);
    axis off    
    %export_fig ('Avg1', '-png','-r600','-opengl') 
    axis on
    set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])   
    set(gca, 'ytick', [],'tickdir','out'); 
    set(gca, 'YTickLabel', num2str(get(gca, 'YTick')'))        
    yaxis=ylim;
    prestim_offset_y            = yaxis(1):1:yaxis(2);
    prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
    hold on;plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',1);                             
    xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
    yLabelText = 'nA / mm^3';      
    h=legend({'Supragranular','Granular','Infragranular'});
    set(h, 'Box', 'off','location', 'Best')    
    hXLabel = xlabel(xLabelText);
    hYLabel = ylabel(yLabelText);    
    fig_title=sprintf('%s','Avg1 ');
    set([gca, hXLabel, hYLabel, h], ...
    'FontSize'   , FontSize    , ...
    'FontName'   , FontName);  
    set(h, ...
    'FontSize'   , 10    , ...
    'FontName'   , FontName);  
    set(gca,'Layer', 'top');
    drawnow
    export_fig (fig_title, '-png','-r600','-opengl')
%%
%%% Now this and final section creates the average CSD across contacts given
%%% the user defined top and bottom of the sink(red) region in the CSD
%%% plots. The mean and the STD are calaucated for each layer. and the
%%% envelope of the std is ploted using the jbfill fx
axis_time=t1:t2;
if probetype ==1
    if gran2(1)==2;
       SG_c=(CSD_matrix2(1,axis_time));    
       SG_std=std(CSD_matrix2(1,axis_time))./1;       
       SG_p=SG_c+SG_std;  SG_m=SG_c-SG_std;
    else
        SG_c=mean(CSD_matrix2(1:(gran2(1)-1),axis_time),1);    
        SG_std=(std(CSD_matrix2((1:gran2(1)-1),axis_time),0,1))./sqrt(size(CSD_matrix2(1:gran2(1)-1),2));       % MK added square roots!
        SG_p=SG_c+SG_std;  SG_m=SG_c-SG_std;
    end
        G_c=mean(CSD_matrix2(gran2,axis_time),1);              
        G_std=(std(CSD_matrix2(gran2,axis_time),0,1))./sqrt(size(CSD_matrix2(gran2),2));                  
        G_p=G_c+G_std;     G_m=G_c-G_std;

        IG_c=mean(CSD_matrix2((gran2(length(gran2))+1):size(CSD_matrix2,1),axis_time),1);   
        IG_std=(std(CSD_matrix2((gran2(length(gran2))+1):size(CSD_matrix2,1),axis_time),0,1))...
            ./sqrt(length((gran1(length(gran1))+1):size(CSD_matrix2)));
        IG_p=IG_c+IG_std;  IG_m=IG_c-IG_std;
%%

    figure_width = 14;  
    figure_height = 12;
    FontSize = 12;  
    FontName = 'MyriadPro-Regular'; % or choose any other font
    % --- setup plot windows
    figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
    Avg_CSD2 = figure;    
    set(Avg_CSD2,'Visible', figuresVisible)
    set(Avg_CSD2, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
    set(Avg_CSD2, 'PaperPositionMode', 'auto');    
    set(Avg_CSD2, 'Color', [1 1 1]); % Sets figure background
    set(Avg_CSD2, 'Color', [1 1 1]); % Sets axes background
    % --- dimensions and position of plot 
    hsp = subplot(1,1,1, 'Parent', Avg_CSD2);
    set(hsp,'Position',[0.10 0.15 0.80 0.80]);            
    x=X2(axis_time)';
    hold on;handle_vector(:,1) = plot(x,SG_c,'r','LineWidth',2);
    hold on; handle_vector(:,2) = jbfill(x,SG_p,SG_m,'r','r',1,.4);
    hold on; handle_vector(:,3) = plot(x,G_c,'b','LineWidth',2);
    hold on; handle_vector(:,4) = jbfill(x,G_p,G_m,'b','b',1,.4);
    hold on; handle_vector(:,5) = plot(x,IG_c,'color',[0 .5 0],'LineWidth',2);
    hold on; handle_vector(:,6) = jbfill(x,IG_p,IG_m,[0 .5 0],[0 .5 0],1,.4);
    % will remove the 3rd legend entry.
    hasbehavior(handle_vector(2),'legend',false);
    hasbehavior(handle_vector(4),'legend',false);
    hasbehavior(handle_vector(6),'legend',false);
    % will remove the 3rd legend entry.
    set(gca, ...
            'Box'         , 'off'      , ...
            'TickDir'     , 'out'      , ...
            'TickLength'  , [0 0] , ...
            'XMinorTick'  , 'off'      , ...
            'YMinorTick'  , 'off'     , ...
            'XGrid'       , 'off'     , ...
            'YGrid'       , 'off'     , ...
            'XColor'      , [.0 .0 .0], ...
            'YColor'      , [.0 .0 .0], ...
            'LineWidth'   , 0.6        );     
    set(gca,'Xlim',[-25 225]);
    axis off  
    %export_fig ('Avg2', '-png','-r600','-opengl') 
    axis on
    set(gca,'XTickLabel',[0 200], 'Xtick', [0 200])   
    set(gca, 'ytick', [],'tickdir','out'); 
    set(gca, 'YTickLabel', num2str(get(gca, 'YTick')'))        
    yaxis=ylim;
    prestim_offset_y            = yaxis(1):1:yaxis(2);
    prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
    hold on; plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',1);                             
    xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
    yLabelText = 'nA / mm^3';      
    h=legend({'Supragranular','Granular','Infragranular'});
    set(h, 'Box', 'off','location', 'Best')    
    hXLabel = xlabel(xLabelText);
    hYLabel = ylabel(yLabelText);    
    fig_title=sprintf('%s','Avg2 ');
    set([gca, hXLabel, hYLabel, h], ...
    'FontSize'   , FontSize    , ...
    'FontName'   , FontName);  
    set(h, ...
    'FontSize'   , 10    , ...
    'FontName'   , FontName);  
    set(gca,'Layer', 'top');
    drawnow
    export_fig (fig_title, '-png','-r600','-opengl')
end
%%
    figure_width = 12;  
    figure_height = 10;
    FontSize = 10;  
    FontName = 'MyriadPro-Regular'; % or choose any other font
    % --- setup plot windows
    figuresVisible = 'on'; % 'off' for non displayed plots (will still be exported)
    CSD_fig2 = figure;
    set(CSD_fig2,'Visible', figuresVisible)
    set(CSD_fig2, 'units', 'centimeters', 'pos', [5 5 figure_width figure_height])   
    set(CSD_fig2, 'PaperPositionMode', 'auto');    
    set(CSD_fig2, 'Renderer','Zbuffer'); 
    set(CSD_fig2, 'Color', [1 1 1]); % Sets figure background
    set(CSD_fig2, 'Color', [1 1 1]); % Sets axes background
    % --- dimensions and position of plot 
    hsp = subplot(1,1,1, 'Parent', CSD_fig2);
    set(hsp,'Position',[0.25 0.15 0.35 0.80]);    
    colorDepth = 1000;
    colormap(flipud(jet(colorDepth)));
%     pcolor(X2, 1:1:size(CSD_matrix1,1), CSD_matrix1);    
    imagesc(X2,[],CSD_matrix1)
    shading interp; % do not interpolate pixels    
    axis on; % display axis
    axis tight;% no white borders
        set(gca, ...
            'Box'         , 'off'      , ...
            'TickDir'     , 'in'      , ...
            'Ydir'        , 'reverse', ...
            'TickLength'  , [.05 .05] , ...
            'XMinorTick'  , 'off'      , ...
            'YMinorTick'  , 'off'     , ...
            'XGrid'       , 'off'     , ...
            'YGrid'       , 'off'     , ...
            'XColor'      , [.0 .0 .0], ...
            'YColor'      , [.0 .0 .0], ...
            'LineWidth'   , 0.6        );             
    set(gca,'Xlim',[-25 225]);
    set(gca,'XTickLabel',[0 200], 'Xtick', [0 200],'TickLength',[0.01 0.01]);
    set(gca, 'yticklabel',1:1:size(CSD_matrix1,1), 'Ytick', 1:1:size(CSD_matrix1,1));                   
    xLabelText = 'Time from stimulus onset (ms)';  % greek letters in LaTeX Syntax
    yLabelText = 'Depth from intial sink (mm)';  
    hXLabel = xlabel(xLabelText);
    hYLabel = ylabel(yLabelText);    
    fig_title=sprintf('%s','Shank 1');    
    y_tick=1:.5:size(CSD_matrix1,1);        
%     c_y=find(y_tick==median(gran1));
%     contact_spacing = 150/spacing;
%     p_y=find(y_tick==median(gran1)+contact_spacing/2); %below
%     m_y=find(y_tick==median(gran1)-contact_spacing/2); %above  
%     infragran = find(y_tick==median(gran1)+contact_spacing*2);  % make line for bottom of L5
%     y_label(c_y)=0;
%     y_label(p_y)=0.100;
%     y_label(m_y)=0-.100;    
% %     set(gca, 'yticklabel',[y_label(m_y) y_label(c_y) y_label(p_y)], 'Ytick', [y_tick(m_y) y_tick(c_y) y_tick(p_y)]);                       
%     hold on;plot(get(gca,'xlim'),[median(gran1) median(gran1)],'-k','Linewidth',1.5);
%     xaxis=xlim;
%     hold on;plot(xaxis,[y_tick(p_y) y_tick(p_y)],'-k','Linewidth',.5);
%     hold on;plot(xaxis,[y_tick(m_y) y_tick(m_y)],'-k','Linewidth',.5);
%     hold on;plot(xaxis,[y_tick(infragran) y_tick(infragran)],'-k','Linewidth',.5);
% %     yaxis=ylim;

    bounds = define_layers(spacing,num_channels,exp_path,1);
    s_y = find(y_tick==bounds(1));
    p_y = find(y_tick==bounds(2));
    m_y = find(y_tick==bounds(3));
    infragran = find(y_tick==bounds(end)); 
%     set(gca, 'yticklabel',[y_label(m_y) y_label(c_y) y_label(p_y)], 'Ytick', [y_tick(m_y) y_tick(c_y) y_tick(p_y)]);                       
    hold on;plot(get(gca,'xlim'),[y_tick(s_y) y_tick(s_y)],'-k','Linewidth',.5);
    xaxis=xlim;
    hold on;plot(xaxis,[y_tick(p_y) y_tick(p_y)],'-k','Linewidth',.5);
    hold on;plot(xaxis,[y_tick(m_y) y_tick(m_y)],'-k','Linewidth',.5);
    hold on;plot(xaxis,[y_tick(infragran) y_tick(infragran)],'-k','Linewidth',.5);


%     prestim_offset_y            = yaxis(1):1:yaxis(2);
%     prestim_offset_t            = ones(1, length(prestim_offset_y))*0;
%     hold on;plot(prestim_offset_t, prestim_offset_y, 'k', 'linewidth',1);        
    caxis([min(min(CSD_matrix1)) max(max(CSD_matrix1))]);    
    zLabelText = 'nA / mm^3';  % greek letters in LaTeX Syntax    
    hcb = colorbar('eastoutside');
    h_bar = findobj(gcf,'Tag','Colorbar');
    initpos = get(h_bar,'Position');
    set(h_bar, ...
    'Position',[initpos(1)+initpos(3)*3.5 initpos(2)+initpos(4)*0.3 ...
      initpos(3)*0.4 initpos(4)*0.4]);     
    hcLabel = ylabel(hcb,zLabelText);    
    set(hcb,'YTickLabel',{'Sink','Source'}, 'Ytick', [min(min(CSD_matrix1)) max(max(CSD_matrix1))])
    set(hcb, ...
     'Box'         , 'on'     , ...
     'TickDir'     , 'in'     , ...
     'TickLength'  , [.010 .010] , ...
     'LineWidth'   , 0.6);
    set([gca, hXLabel, hYLabel], ...
    'FontSize'   , FontSize    , ...
    'FontName'   , FontName);
    set([hcb, hcLabel], ...
    'FontSize'   , 11    , ...
    'FontName'   , FontName);
    ylabh=get(hcb,'Ylabel');
    set(ylabh,'Position',get(ylabh,'Position')-[8 0 0]); 
    set(gca,'Layer', 'top');
    drawnow   
    export_fig (fig_title, '-png','-r600','-zbuffer');    
    print2eps(fig_title)
end
%%
savefile=sprintf('%s%s','FinalCSD','.mat');
save (savefile);

% define_layers(spacing,num_channels,exp_path)
% close all 
% clear all
% close all 
% clear all
% clc
end