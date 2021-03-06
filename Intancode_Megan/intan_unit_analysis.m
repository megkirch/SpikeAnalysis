function [unitinfo,FRs,tuning,waveforms] = intan_unit_analysis(unit,field_trials,time_index,spike_times,clusters,params,normalizing,makeplots)

% trial info from params
exp_name = params.exp_name;         % e.g. 'T22_ramp'
exp_type = params.exp_type;
amp_sr = params.amp_sr;
trial_type = params.trial_type;     % nxm matrix, n=number of trials, m=number of IVs
IVs = params.IVs;                   % independent variables
prestim = params.prestim;
stimtime = params.stimtime;
poststim = params.poststim;
total_time = prestim+stimtime+poststim;
onset = params.onset;               % amount of time from start of visual stimulus considered "onset"
all_light = params.all_light;
pulse_dur = params.pulse_dur;       % duration of light (only different from lighttime during trains experiments
lighttime = params.lighttime;       % duration of light stimulation (e.g. 1sec)
av_light_start = params.av_light_start;     % average time the light turned on across trials


%% extract spike times 
spike_times_ds = floor(spike_times/(amp_sr/1000));   % change sample #s to account for downsampling
spike_times_ds = spike_times_ds + 1; % has to be +1 because spike_times starts at 0, but the min possible field_trials value could be 1
unit_times = spike_times_ds(find(clusters==unit)); % timestamps of unit's spikes
spiketimes = spikes_by_trial(unit_times,field_trials,250,time_index); % cell array of spike times during each trial
    
%% make raster from spike times
spike_raster = make_raster(spiketimes,1000,total_time);

%% count spikes during periods of interest
num_trials = length(spiketimes);

% count spikes during prestim, stim, and onset periods
for t = 1:num_trials
    spikes_all(t) = length(spiketimes{t});
    spikes_prestim(t) = length(find(spiketimes{t}<prestim));
    spikes_ev(t) = length(find((spiketimes{t}>=av_light_start)&(spiketimes{t}<=av_light_start+lighttime)));
    spikes_ev_half(t) = length(find((spiketimes{t}>=av_light_start)&(spiketimes{t}<=av_light_start+lighttime/2)));  % spikes during first half of light stimulus (since light so powerfully turns off TLx cells)
    spikes_onset(t) = length(find((spiketimes{t}>=prestim)&(spiketimes{t}<prestim+onset)));
    spikes_prestim_onsettime(t) = length(find((spiketimes{t}>=prestim-onset)&(spiketimes{t}<prestim)));       % for kruskal-wallis test of visual modulation
end

%% Calculate firing rates
% first, separately for each condition of each variable during prestim,
% evoked, and onset periods
for v = 1:length(IVs)       % for each variable
    levs = unique(trial_type(:,v));         % for each level of the variable
    for i = 1:length(levs)                  % get firing rate, across all other variables
        [spikerate_prestim{v}(i), spikerateSE_prestim{v}(i)] = calc_firing_rates(spikes_prestim,find(trial_type(:,v) == levs(i)),prestim); 
        [spikerate_ev{v}(i), spikerateSE_ev{v}(i)] = calc_firing_rates(spikes_ev,find(trial_type(:,v) == levs(i)),lighttime);
        [spikerate_ev_half{v}(i), spikerateSE_ev_half{v}(i)] = calc_firing_rates(spikes_ev_half,find(trial_type(:,v) == levs(i)),lighttime/2);
        [spikerate_onset{v}(i), spikerateSE_onset{v}(i)] = calc_firing_rates(spikes_onset,find(trial_type(:,v) == levs(i)),onset);
    end
end

% second, make 3D matrix of evoked FRs according to ori, lightcond, and run
% variables
orivar = find(strcmp(IVs,'ori'));
oriconds = unique(trial_type(:,orivar));     % get different orientations, including blank
oriinds = oriconds<=360;          % get different orientations, EXCLUDING blanks (which are indicated by 999)
oris = oriconds(oriinds);
lightvar = find(strcmp(IVs,'light_bit'));
lightconds = unique(trial_type(:,lightvar));     % get different levels of light variable
runvar = find(strcmp(IVs,'running'));
runconds = unique(trial_type(:,runvar));        % and running vs stationary (should always be two levels)
for lc = 1:length(lightconds)    
    lc_trials{lc} = find(trial_type(:,lightvar) == lightconds(lc));     % make cell in case number of trials per lightcond were unequal
    for o = 1:length(oriconds)
        oricond_trials = find(trial_type(:,orivar) == oriconds(o));    % create matrix of which trials were at given orientation
        trials_per_ori(lc,o) = length(intersect(oricond_trials,lc_trials{lc}));   
        for r = 1:length(runconds)
            run_trials = find(trial_type(:,runvar) == runconds(r));
            [spikerate_bycond(o,lc,r), spikerateSE_bycond(o,lc,r)] = calc_firing_rates(spikes_ev_half,intersect(intersect(lc_trials{lc},oricond_trials),run_trials),lighttime/2);   % currently using FIRST HALF of light period
        end
    end
end

% finally, normalize firing rates (by 'prestim','blanks',or 'none')
if strcmp(normalizing,'prestim')
    baseline = calc_firing_rates(spikes_prestim,find(trial_type(:,runvar)==0),prestim);      % across all STATIONARY trials
elseif strcmp(normalizing,'blanks')
    baseline = spikerate_bycond(find(isnan(oriconds)),find(lightconds==0),find(runconds==0));   % baseline FR defined as evoked FR from BLANK,STATIONARY,NOLIGHT trials
else
    baseline = 0;
end
spikerate_bycond_norm = spikerate_bycond - baseline;

%% get tuning curves and OSI and DSI
for lc = 1:length(lightconds)
    tuning_curve(lc,:) = spikerate_bycond(oriinds,lc,find(runconds==0));
    tuning_curve_norm(lc,:) = spikerate_bycond_norm(oriinds,lc,find(runconds==0));          % baseline subtracted
%     if isempty(find(abs(tuning_curve(lc,:))>= 1))    % if all average firing rates are under 1Hz, don't consider this unit for tuning
%         tuningcount = 0;
%         OSI(lc) = nan;
%         OSI_CV(lc) = nan;
%         DSI(lc) = nan;
%         DSI_CV(lc) = nan;
%     else
        tuningcount = 1;
        [OSI(lc),OSI_CV(lc),DSI(lc),DSI_CV(lc)] = calcOSIDSI(tuning_curve(lc,:),oris');       % using only STATIONARY trials (NOT baseline-subtracted, but check whether this is correct!!!!)
%     end
end

%% do some stats
% useful trial indicators:
vis_trials = find(trial_type(:,1)==1);
blank_trials = find(trial_type(:,1)==0);
nolight_trials = find(trial_type(:,lightvar)==0);
for lc=2:length(lightconds)
    light_trials{lc-1} = find(trial_type(:,lightvar)==lightconds(lc));
    vislight_trials{lc-1} = find((trial_type(:,1)==1)&(trial_type(:,lightvar)==lightconds(lc)));
    blanklight_trials{lc-1} = find((trial_type(:,1)==0)&(trial_type(:,lightvar)==lightconds(lc)));
end
visnolight_trials = find((trial_type(:,1)==1)&(trial_type(:,lightvar)==0));     % assumes first column of trial_type indicates visual vs. blank!
blanknolight_trials = find((trial_type(:,1)==0)&(trial_type(:,lightvar)==0));
run_trials = find(trial_type(:,runvar) == 1);
stat_trials = find(trial_type(:,runvar) == 0);

% kruskal-wallis test to test for significant and visual- and light-modulation
vis_sig = kruskalwallis([spikes_onset(visnolight_trials)' spikes_prestim_onsettime(visnolight_trials)'],[],'off');    % significance of visual response (testing using ONSET vs PRESTIM)
vis_sig2 = kruskalwallis([spikes_prestim(visnolight_trials)' spikes_ev_half(visnolight_trials)'],[],'off');         % significance of visual response (testing using 500-1000ms after stim onset vs PRESTIM)

for lc = 1:length(lightconds)-1    % exclude nolight condition
    ev_spikes = [spikes_ev(visnolight_trials) spikes_ev(vislight_trials{lc})];  % test for each light condition separately, first in VISUAL trials
    ev_spikes_group = [ones(1,length(visnolight_trials)) 2*ones(1,length(vislight_trials{lc}))];
    vislight_sig(lc) = kruskalwallis(ev_spikes,ev_spikes_group,'off');
    ev_spikes_blanks = [spikes_ev(blanknolight_trials) spikes_ev(blanklight_trials{lc})];  % test for each light condition separately in BLANK trials
    blank_spikes_group = [ones(1,length(blanknolight_trials)) 2*ones(1,length(blanklight_trials{lc}))];
    blanklight_sig(lc) = kruskalwallis(ev_spikes_blanks,blank_spikes_group,'off');
end

% test for significant orientation tuning
% but first, check on number of trials (T2Hot1 requires equal numbers of
% trials per orientation)
% ** using running AND stationary trials for now...too hard to equate trial
% numbers among running and stationary trials at each orientation...

for lc = 1:length(lightconds)
    if length(unique(trials_per_ori(lc,oriinds)))> 1        % if there are unequal numbers of trials at different orientations within a particular light condition
        min_trials = min(trials_per_ori(lc,oriinds));
        for o = 1:length(oris)
            ori_trials{o}= find(trial_type(:,orivar) == oris(o));
            ori_lc_trials = intersect(ori_trials{o},lc_trials{lc});
            trials2use = randperm(trials_per_ori(lc,o),min_trials);    % randomly select min_trials number of trials to use for each orientation within particular lightcond
            trialsbyori{lc}(:,o) = spikes_ev(ori_lc_trials(sort(trials2use)))./lighttime;   % creates trials x oris matrix of FRs for Hotellings tsquare test for each lightcond 
        end
    else
        for o = 1:length(oris)
            ori_trials{o} = find(trial_type(:,orivar) == oris(o));
            ori_lc_trials = intersect(ori_trials{o},lc_trials{lc});
            trialsbyori{lc}(:,o) = spikes_ev(ori_lc_trials)./lighttime;
        end
    end

    % get measure of OSI_CV by trial (for two-sample ttest, below)
    for t = 1:size(trialsbyori{lc},1)
        [~,OSICV_by_trial{lc}(t),~,~] = calcOSIDSI(trialsbyori{lc}(t,:),oris');     % for now, only using OSICV to measure change in tuning
    end

    for o = 1:length(oris)/2
        tuning_curve_nodir{lc}(:,o)   = mean([trialsbyori{lc}(:,o) trialsbyori{lc}(:,o+length(oris)/2)],2)-baseline;         % average evoked FR of same orientations but different directions in NO LIGHT condition
    end
%     if tuningcount              % only do for cells with sufficient tuning curves
%         tuned_sig(lc) = T2Hot1(tuning_curve_nodir{lc},0.05);     % if tuned_sig(lc) < .05, significantly tuned  
%     else
%         tuned_sig(lc) = nan;
%     end
    tuned_sig(lc) = T2Hot1(tuning_curve_nodir{lc},0.05,zeros(1,length(oris)/2));     % if tuned_sig(lc) < .05, significantly tuned  
    tuned_sig_2(lc) = T2Hot1(tuning_curve_nodir{lc},0.05,mean(tuning_curve_nodir{lc}(:))*ones(1,length(oris)/2));
%     [warnmsg, msgid] = lastwarn;        % if there was a warning with T2Hot1 (covariance matrix close to singular)
%     if exist('warnmsg','var')
%         tuned_sig(lc) = nan;
%     end
    
end

% % try a different way...
% for lc = 1:length(lightconds)
%     oridom_rad = oris'.*pi/180;      % convert to radians
%     oridom_rad = oridom_rad(1:2:end);
%     Xs = tuning_curve_nodir{lc}.*repmat(cos(oridom_rad),size(tuning_curve_nodir{lc},1),1);
%     Ys = tuning_curve_nodir{lc}.*repmat(sin(oridom_rad),size(tuning_curve_nodir{lc},1),1);
%     Rx = sum(Xs,2);
%     Ry = sum(Ys,2);
%     R = sqrt(Rx.^2+ Ry.^2);
%     ang = atan(Ry./Rx);          % in radians                                      % CHECK!!!!
%     if tuningcount              % only do for cells with sufficient tuning curves
%         tuned_sig_2(lc) = T2Hot1([ang R],.05);
%     else
%         tuned_sig_2(lc) = nan;
%     end
% end


% test for sig tuning change (two-sample ttest, recommended by Mazurek
% et al. 2014
for lc = 1:length(lightconds)-1    
    if tuningcount              % only do for cells with sufficient tuning curves
        [~,tuningchange_sig(lc)] = ttest2(OSICV_by_trial{1}, OSICV_by_trial{lc+1});     % returns P value
    else
        tuningchange_sig(lc) = nan;
    end
end

% %add multivariate T2 hotellings
% % first, need to vertically concatenate tuning curve matrices from each
% % light condition, but to do that, there need to be equal numbers of trials
% % per orientation across light conditions
% if length(unique(cellfun(@(x) size(x,1),tuning_curve_nodir,'UniformOutput',1))) > 1     % if there are unequal numbers of trials per orientation between different light conditions
%     min_trials = min(cellfun(@(x) size(x,1),tuning_curve_nodir,'UniformOutput',1));
% else
%     min_trials = unique(cellfun(@(x) size(x,1),tuning_curve_nodir,'UniformOutput',1));
% end
%      
% for lc = 1:length(lightconds)-1     % hotelling's test only works for two samples, so need to separately compare nolight condition with each light condition
%     cat_tuningcurve{lc} = [tuning_curve_nodir{lc}; tuning_curve_nodir{lc+1}];        % vertically-concatenated tuning curve matrix
%     % use appropriate  whether covariance structures in different light conditions are
%     % equal
%     cat_tuningcurve{lc} = [[ones(min_trials,1);2*ones(min_trials,1)] cat_tuningcurve{lc}];      % first column indicates group
%     if MBoxtest(cat_tuningcurve{lc},0.05) < 0.05    % covariance structures are unequal
%         tuningchange_sig{lc} = T2Hot2ihe(cat_tuningcurve{lc},0.05);         %***sample sizes may be too small for this
%     else                                            % covariance structures are equal
%         tuningchange_sig{lc} = T2Hot2iho(cat_tuningcurve{lc},0.05);
%     end
% end

% if it was NOT a ramp experiment, use SALT test to whether light changed activity within a given window of time (here, using 5 and 10ms)    
if ~strcmp(exp_type,'ramp')
    baseline_rast = spike_raster(visnolight_trials,floor(av_light_start*1000+1):floor(av_light_start*1000+1)+999);        % using visually-evoked activity in nolight trials as baseline
    for lc = 1:length(lightconds)-1         % currently calculating separately for each light condition - may not be necessary
        ev_rast = spike_raster(vislight_trials{lc},floor(av_light_start*1000+1):floor(av_light_start*1000+1)+999);
        [p_10(lc) I_10(lc)] = salt(baseline_rast,ev_rast,1/1000,.01);   % within 10ms window
        [p_5(lc) I_5(lc)] = salt(baseline_rast,ev_rast,1/1000,.005);    % within 5ms window
        [p_2(lc) I_2(lc)] = salt(baseline_rast,ev_rast,1/1000,.002);    % within 2ms window
    end
else
    p_10 = [];
    I_10 = [];
    p_5 = [];
    I_5 = [];
    p_2 = [];
    I_2 = [];
end

%% get waveform information
exp_path = cd;          % assuming CD was set in intan_unit_master
if exist(sprintf('Cluster_%s_waveforms.mat',num2str(unit)),'file');
    load(sprintf('Cluster_%s_waveforms.mat',num2str(unit)));
else
    [waveforms_microV, max_ch] = readWaveformsFromDat(sprintf('%s\\amplifier.dat',exp_path),32,spike_times(find(clusters==unit)),[-16 16],[],4);
    save(sprintf('Cluster_%s_waveforms.mat',num2str(unit)),'waveforms_microV','max_ch');
end
% determine layer
if exist('layers.mat','file')           % in current path
    layers = importdata('layers.mat');
else
    define_layers(25,32,exp_path,1);        %** currently hard-coded for 32ch NN probes - need to change!!
    layers = importdata('layers.mat');
end
layer = layers(max_ch);

% get trough-to-peak time, trough-to-peak ratio, and
% full-width-half-maximum
[t2p_t,t2p_r,fwhm] = get_waveform_props(waveforms_microV,amp_sr);

%% save results
% firing rate stuff
FRs.prestim = [spikerate_prestim{lightvar} spikerateSE_prestim{lightvar}];
FRs.ev = [spikerate_ev{lightvar} spikerateSE_ev{lightvar}];
FRs.evstart = [spikerate_ev_half{lightvar} spikerateSE_ev_half{lightvar}];
FRs.onset = [spikerate_onset{lightvar} spikerateSE_onset{lightvar}];
FRs.baseline = baseline;
FRs.baselinedef = normalizing;
FRs.SALT10ms = [p_10 I_10];
FRs.SALT5ms = [p_5 I_5];
FRs.SALT2ms = [p_2 I_2];

% tuning stuff
tuning.curve = tuning_curve;
tuning.normcurve = tuning_curve_norm;
tuning.OSI = OSI;
tuning.OSI_CV = OSI_CV;
tuning.DSI = DSI;
tuning.DSI_CV = DSI_CV;
tuning.sig_Hot = tuned_sig;
tuning.sig_Hot2 = tuned_sig_2;

% general unit info
unitinfo.name = sprintf('%s_%d',exp_name,unit);
unitinfo.layer = layer;
unitinfo.vissig = vis_sig;
unitinfo.vissig2 = vis_sig2;
unitinfo.lightsig_vis = vislight_sig;
unitinfo.lightsig_blnk = blanklight_sig;
unitinfo.numspikes = length(unit_times);

% waveforms
waveforms.microV = waveforms_microV;
waveforms.t2p_t = t2p_t;
waveforms.t2p_r = t2p_r;
waveforms.fwhm = fwhm;
    

%% plot stuff!
if makeplots
    
    % make appropriate figure legends
    if strcmp(exp_type,'trains')
        for i = 2:length(lightconds)        % for graphing purposes
            legend_labels{i-1} = sprintf('%dHz',lightconds(i));
        end
    elseif strcmp(exp_type,'intensities')
        legend_labels = {'Low light','Medium light','High light'};
        full_legend_labels = {'Light OFF','Low light','Medium light','High light'};
    else
        legend_labels = {'Light ON'};
    end
    
    % make 2-by-4 figure array containing raster plot, PSTHs for visual and
    % blank trials, zoom-in of PSTH, running v. stationary barplot, prestim
    % v evoked v blanks barplot, orientation tuning curve, and waveform
    fig_title = ['Cluster_' num2str(unit)];
    clust_fig = figure('name', fig_title); 
    [type,idx] = sort(all_light);    % sort trials by light conditions
    
    % 1) Raster plot
    subplot(241)
    make_raster_plot(spiketimes,1000,prestim,total_time,all_light,av_light_start,pulse_dur)
    set(gca,'FontSize',14);
    title('Raster plot')
    
    % 2) PSTH - visual trials
    subplot(242)
    binsize = .025;         % 25 ms
    make_psth_plot(binsize,spiketimes,ismember(1:num_trials,vis_trials),prestim,stimtime,total_time,trial_type(:,lightvar),av_light_start,lighttime)
    title('PSTH plot - visual trials','FontSize',14)
    set(gca,'FontSize',14);
    
    % 3) PSTH - blank trials
    subplot(243)
    make_psth_plot(binsize,spiketimes,ismember(1:num_trials,blank_trials),prestim,stimtime,total_time,trial_type(:,lightvar),av_light_start,lighttime)
    title('PSTH plot - blank trials','FontSize',14)
    set(gca,'FontSize',14);
    
    % 4) PSTH - zoom
    subplot(244)
    make_raster_plot(spiketimes,1000,prestim,total_time,all_light,av_light_start,pulse_dur)
    xlim([.4 .8])
    title('Raster plot (zoom)','FontSize',14)
    set(gca,'FontSize',14);
    
    % 5) running v stationary
    subplot(245)
    color_mat = [0 0 0; 0 .8 1; 0 0 1; 0 0.5 .4; 0 .7 .2]; % for graphing purposes (first is black, last is green)
    for lc = 1:length(lightconds)
        if lightconds(lc)
            [spikerate_run(lc) spikerateSE_run(lc)] = calc_firing_rates(spikes_ev,intersect(run_trials,light_trials{lc-1}),lighttime);
            [spikerate_stat(lc) spikerateSE_stat(lc)] = calc_firing_rates(spikes_ev,intersect(stat_trials,light_trials{lc-1}),lighttime);
        else
            [spikerate_run(lc) spikerateSE_run(lc)] = calc_firing_rates(spikes_ev,intersect(run_trials,nolight_trials),lighttime);
            [spikerate_stat(lc) spikerateSE_stat(lc)] = calc_firing_rates(spikes_ev,intersect(stat_trials,nolight_trials),lighttime);
        end
    end
    runbar = bargraph([spikerate_run; spikerate_stat],...
        [spikerateSE_run; spikerateSE_stat]);
    set(get(gca,'YLabel'),'String','Mean FR (spikes/s)','Fontsize',14)
    set(gca,'XTicklabel','Running| Stationary')
    for i = 1:length(lightconds)
%         if i == length(lightconds)
%             set(runbar(i),'FaceColor',color_mat(end,:),'EdgeColor',color_mat(end,:)); % make sure last lightcond is bright blue
%         else
            set(runbar(i),'FaceColor',color_mat(i,:),'EdgeColor',color_mat(i,:));
%         end
    end
    title('Firing rate - running vs. stationary','FontSize',14)
    legend off
    set(gca,'FontSize',14);
    
    % 6) prestim vs evoked vs blank FRs
    subplot(246)
    FR = [spikerate_prestim{lightvar}; spikerate_onset{lightvar}; spikerate_ev{lightvar}];
    SE = [spikerateSE_prestim{lightvar}; spikerateSE_onset{lightvar}; spikerateSE_ev{lightvar}];
    if length(unique(trial_type(:,1))) > 1          % if blank trials
        for lc = 1:length(lightconds)
            if lightconds(lc)
                [spikerate_blank(lc) spikerateSE_blank(lc)] = calc_firing_rates(spikes_ev,intersect(blank_trials,light_trials{lc-1}),lighttime);
            else
                [spikerate_blank(lc) spikerateSE_blank(lc)] = calc_firing_rates(spikes_ev,intersect(blank_trials,nolight_trials),lighttime);
            end
        end
        FR = [FR; spikerate_blank];
        SE = [SE; spikerateSE_blank];
        xcondslabel = 'Prestim| Onset| Evoked| Blanks';
    else
        xcondslabel = 'Prestim| Onset| Evoked';
    end
    evokedbar = bargraph(FR,SE);
    set(get(gca,'YLabel'),'String','Mean FR (spikes/sec)','Fontsize',14)
    set(gca,'XTicklabel',xcondslabel,'Fontsize',13)
    for i = 1:length(lightconds)
%         if i == length(lightconds)
%             set(evokedbar(i),'FaceColor',color_mat(end,:),'EdgeColor',color_mat(end,:)); % make sure last lightcond is bright blue
%         else
            set(evokedbar(i),'FaceColor',color_mat(i,:),'EdgeColor',color_mat(i,:));
%         end
    end
    title('Firing rate','FontSize',14)
    legend off
    
    % 7) Tuning curves (stationary trials, baseline subtracted)
    subplot(247)
    for lc = 1:length(lightconds)
        shadedErrorBar(oris,tuning_curve_norm(lc,:),spikerateSE_bycond(oriinds,lc,find(runconds==0)),{'Color',color_mat(lc,:),'linewidth',2},1);  % plot ori tuning in NO RUN trials
        hold on
    end
    ylabel('Firing rate (baseline-subtracted) (Hz)','FontSize',14)
    xlabel('Orientation (degrees)','FontSize',14)
    xlim([0 max(oris)])
    title('Orientation tuning during light period','FontSize',14)
    set(gca,'FontSize',14);

    % 8) Plot waveforms

    subplot(248)
    t = linspace(0,(size(waveforms_microV,1)-1)/20,size(waveforms_microV,1));    % convert to ms
    plot(t,waveforms_microV,'LineWidth',2);
    xlim([0 max(t)])
    hold on 
    title(sprintf('Average waveform of spikes (Max ch: %d)',max_ch),'FontSize',14)
    ylabel('Amplitude (uV)','FontSize',14)
    xlabel('Time (ms)','FontSize',14)
    set(gca,'FontSize',14);

     % save figs
     all_fig_dir = sprintf('H:\\Tlx3project\\Augustresults\\%s\\Figures',exp_name);
    if ~exist(all_fig_dir)
        mkdir(all_fig_dir);
    end
    xSize = 24; ySize = 11;
    xLeft = (21-xSize)/2; yTop = (30-ySize)/2;
    set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
    set(gcf,'Position',[0 0 xSize*50 ySize*50])
    if layer == 5
        layer_name = 'L5A';
    elseif layer == 5.5
        layer_name = 'L5B';
    elseif layer == 2.5
        layer_name = 'L23';
    else
        layer_name = sprintf('L%s',num2str(layer));
    end
    save_clust_name= sprintf('%s\\%s_Cluster%d_%s',all_fig_dir,exp_name,unit,layer_name);
    print(clust_fig,'-dpng',save_clust_name)
    print2eps(save_clust_name,clust_fig)
    close all
end

return



function [spikerate, spikerate_SE] = calc_firing_rates(spikes,...
    which_trials,period)

% spikes = column vector of number of spikes by trial for unit of interest
% which_trials = vector of which trials you want to include
% period = length of period (in seconds) that number of spikes was counted 
    % from (e.g. evoked: 1.8s)

spikerate = mean(spikes(which_trials)/period);
spikerate_SE = std(spikes(which_trials)/period)/sqrt(length(which_trials));

return
