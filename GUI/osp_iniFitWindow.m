function osp_iniFitWindow(gui)
%% osp_iniFitWindow
%   This function creates the inital fitting window in the gui.
%
%
%   USAGE:
%       osp_iniFitWindow(gui);
%
%   INPUT:      gui      = gui class containing all handles and the MRSCont 
%
%   OUTPUT:     Changes in gui parameters and MRSCont are written into the
%               gui class
%
%
%   AUTHORS:
%       Dr. Helge Zoellner (Johns Hopkins University, 2020-01-16)
%       hzoelln2@jhmi.edu
%
%   CREDITS:
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2020-01-16: First version of the code.
%%% 1. GET HANDLES %%%
% This function initializes the fit tab 
        MRSCont = getappdata(gui.figure,'MRSCont'); % Get MRSCont from hidden container in gui class
        gui.layout.tabs.TabEnables{3} = 'on';
        gui.layout.tabs.Selection  = 3;
        gui.layout.EmptyFitPlot = 0;
%%% 2. CREATING SUB TABS FOR THIS TAB %%%%
% In this case one tab fo each fit (off,sum,diff1,diff2,ref,water)
         gui.layout.fitTab.TabWidth   = 115;
         for t = 1 : gui.fit.Number %Create tabs depending on the number of fits
                gui.layout.(['fitTab' gui.fit.Names{t}]) = uix.VBox('Parent', gui.layout.fitTab,...
                                                            'BackgroundColor',gui.colormap.Background,'Spacing',5);
                gui.layout.fitTabhandles{t} = ['fitTab' gui.fit.Names{t}];
         end
        gui.layout.fitTab.TabTitles  = gui.fit.Names;

%%% 3. FILLING INFO PANEL FOR THIS TAB %%%%
% All the information from the Raw data is read out here
        for t = 1 : gui.fit.Number %Loop over fits
            Selection = gui.fit.Names{t};
            % Parameter shown in the info panel on top
            gui.upperBox.fit.box = uix.HBox('Parent', gui.layout.(gui.layout.fitTabhandles{t}),'BackgroundColor',gui.colormap.Background,'Spacing',5);
            gui.upperBox.fit.Info = uix.Panel('Parent',  gui.upperBox.fit.box, ...
                                    'Padding', 5, 'Title', ['Actual file: ' MRSCont.files{gui.controls.Selected}],...
                                    'FontName', 'Arial','HighlightColor', gui.colormap.Foreground,'BackgroundColor',...
                                    gui.colormap.Background,'ForegroundColor',gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground);
            gui.upperBox.fit.upperButtons = uix.Panel('Parent', gui.upperBox.fit.box, ...
                                     'Padding', 5, 'Title', ['Save'],...
                                     'FontName', 'Arial', 'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground,...
                                     'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground);
            gui.controls.b_save_fitTab = uicontrol('Parent',gui.upperBox.fit.upperButtons,'Style','PushButton');
            [img, ~, ~] = imread('Printer.png', 'BackgroundColor', gui.colormap.Background);
            [img2] = imresize(img, 0.1);
            set(gui.controls.b_save_fitTab,'CData', img2, 'TooltipString', 'Create EPS figure from current file');
            set(gui.controls.b_save_fitTab,'Callback',{@osp_onPrint,gui});
            set(gui.upperBox.fit.box, 'Width', [-0.9 -0.1]);                                 
            % Creates layout for plotting and data control
            gui.Plot.fit = uix.HBox('Parent', gui.layout.(gui.layout.fitTabhandles{t}), ...
                                   'Padding', 5,'BackgroundColor',gui.colormap.Background);
            set(gui.layout.(gui.layout.fitTabhandles{t}), 'Heights', [-0.1 -0.9]);
            if  ~strcmp (MRSCont.opts.fit.style, 'Concatenated') ||  strcmp(gui.fit.Names{t}, 'ref') || strcmp(gui.fit.Names{t}, 'w') %Is not concateneted or is reference/water fit 
                gui.fit.Style = gui.fit.Names{t};
            else %Is concatenated and not water/reference
                gui.fit.Style = 'conc';
            end
            RawAmpl = MRSCont.fit.results.(gui.fit.Style).fitParams{1,gui.controls.Selected}.ampl .* MRSCont.fit.scale{gui.controls.Selected};
            ph0 = MRSCont.fit.results.(gui.fit.Style).fitParams{1,gui.controls.Selected}.ph0;
            ph1 = MRSCont.fit.results.(gui.fit.Style).fitParams{1,gui.controls.Selected}.ph1;
            if ~strcmp(gui.fit.Names{t}, 'ref') && ~strcmp(gui.fit.Names{t}, 'w')
                refShift = MRSCont.fit.results.(gui.fit.Style).fitParams{1,gui.controls.Selected}.refShift;
                refFWHM = MRSCont.fit.results.(gui.fit.Style).fitParams{1,gui.controls.Selected}.refFWHM; 
            end
            % Get parameter from file to fill the info panel
            if  ~strcmp (Selection, 'ref') && ~strcmp (Selection, 'w') %Metabolite data?
                StatText = ['Metabolite Data -> Sequence: ' gui.load.Names.Seq '; Fitting algorithm: ' MRSCont.opts.fit.method  '; Fitting Style: ' MRSCont.opts.fit.style '; Selected subspecs: ' gui.fit.Names{t},...
                        '\nFitting range: ' num2str(MRSCont.opts.fit.range(1)) ' to ' num2str(MRSCont.opts.fit.range(2)) ' ppm; Baseline knot spacing: ' num2str(MRSCont.opts.fit.bLineKnotSpace) ' ppm; ph0: ' num2str(ph0,'%1.2f'),...
                        'deg; ph1: ' num2str(ph1,'%1.2f') 'deg; refShift: ' num2str(refShift,'%1.2f') ' Hz; refFWHM: ' num2str(refFWHM,'%1.2f')...
                        ' ppm\nNumber of metabolites: ' num2str(MRSCont.fit.basisSet.nMets) '; Number of macro moclecules: ' num2str(MRSCont.fit.basisSet.nMM) ...
                        ' scale: '  num2str(MRSCont.fit.scale{gui.controls.Selected})];
            else if strcmp (Selection, 'ref') %Reference data?
            StatText = ['Reference Data -> Sequence: ' gui.load.Names.Seq '; Fitting algorithm: ' MRSCont.opts.fit.method  '; Fitting Style: ' MRSCont.opts.fit.style '; Selected subspecs: ' gui.fit.Names{t},...
                        '\nFitting range: ' num2str(MRSCont.opts.fit.rangeWater(1)) ' to ' num2str(MRSCont.opts.fit.rangeWater(2)) ' ppm'];
                else %Is water data
                    StatText = ['Water Data -> Sequence: ' gui.load.Names.Seq '; Fitting algorithm: ' MRSCont.opts.fit.method  '; Fitting Style: ' MRSCont.opts.fit.style '; Selected subspecs: ' gui.fit.Names{t},...
                        '\nFitting range: ' num2str(MRSCont.opts.fit.rangeWater(1)) ' to ' num2str(MRSCont.opts.fit.rangeWater(2)) ' ppm'];
                end
            end
 %%% 4. FILLING FITTED AMPLITUDE PANEL %%%
 % Creates the panel on the right side with the fitted ammplitudes
            gui.InfoText.fit  = uicontrol('Parent',gui.upperBox.fit.Info,'style','text',...
                                        'FontSize', 12, 'FontName', 'Arial','HorizontalAlignment', 'left', 'String', sprintf(StatText),...
                                        'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground);
            gui.Results.fit = uix.Panel('Parent', gui.Plot.fit,...
                                       'Title', ['Raw Amplitudes'],'FontName', 'Arial','HighlightColor', gui.colormap.Foreground,...
                                       'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground);

            if ~(MRSCont.flags.hasRef || MRSCont.flags.hasWater) %Raw amplitudes are reported as no water/reference fitting was performed
                if ~(strcmp(gui.fit.Style, 'ref') || strcmp(gui.fit.Style, 'w')) %Metabolite fit
                    NameText = [''];
                    RawAmplText = [''];
                    for m = 1 : length(RawAmpl) %Names and Amplitudes
                        NameText = [NameText, [MRSCont.fit.resBasisSet.(gui.fit.Style){1,MRSCont.info.A.unique_ndatapoint_indsort(gui.controls.Selected)}.name{m} ': \n']];
                        RawAmplText = [RawAmplText, [num2str(RawAmpl(m),'%1.2e') '\n']];
                    end
                else %Water/reference fit but this should never happen in this loop
                   NameText = ['Water: ' ];
                   RawAmplText = [num2str(RawAmpl,'%1.2e')];
                end
                set(gui.Results.fit, 'Title', ['Raw Amplitudes']);
                    gui.Results.FitText = uix.HBox('Parent', gui.Results.fit, 'Padding', 5,'BackgroundColor',gui.colormap.Background);
                    gui.Results.FitTextNames  = uicontrol('Parent',gui.Results.FitText,'style','text',...
                    'FontSize', 11, 'FontName', 'Arial','HorizontalAlignment', 'left', 'String', sprintf(NameText),...
                    'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground);
                    gui.Results.FitTextAmpl  = uicontrol('Parent',gui.Results.FitText,'style','text',...
                    'FontSize', 11, 'FontName', 'Arial','HorizontalAlignment', 'left', 'String', sprintf(RawAmplText),...
                    'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground);
            else %If water/reference data is fitted Raw amplitudes are calculated with regard to water
                if ~(strcmp(gui.fit.Style, 'ref') || strcmp(gui.fit.Style, 'w')) %Metabolite fit
                    if MRSCont.flags.hasRef %Calculate Raw Water Scaled amplitudes
                        RawAmpl = RawAmpl ./ (MRSCont.fit.results.ref.fitParams{1,gui.controls.Selected}.ampl .* MRSCont.fit.scale{gui.controls.Selected});
                    else
                        RawAmpl = RawAmpl ./ (MRSCont.fit.results.w.fitParams{1,gui.controls.Selected}.ampl .* MRSCont.fit.scale{gui.controls.Selected});
                    end
                    NameText = [''];
                    RawAmplText = [''];
                    for m = 1 : length(RawAmpl) %Names and Amplitudes
                        NameText = [NameText, [MRSCont.fit.resBasisSet.(gui.fit.Style){1,MRSCont.info.A.unique_ndatapoint_indsort(gui.controls.Selected)}.name{m} ': \n']];
                        RawAmplText = [RawAmplText, [num2str(RawAmpl(m),'%1.2e') '\n']];
                    end
                    set(gui.Results.fit, 'Title', ['Raw Water Ratio']);
                    gui.Results.FitText = uix.HBox('Parent', gui.Results.fit, 'Padding', 5,'BackgroundColor',gui.colormap.Background);
                    gui.Results.FitTextNames  = uicontrol('Parent',gui.Results.FitText,'style','text',...
                    'FontSize', 11, 'FontName', 'Arial','HorizontalAlignment', 'left', 'String', sprintf(NameText),...
                    'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground);
                    gui.Results.FitTextAmpl  = uicontrol('Parent',gui.Results.FitText,'style','text',...
                    'FontSize', 11, 'FontName', 'Arial','HorizontalAlignment', 'left', 'String', sprintf(RawAmplText),...
                    'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground);
                else %Water/reference fit
                   NameText = ['Water: ' ];
                   RawAmplText = [num2str(RawAmpl,'%1.2e')];
                   set(gui.Results.fit, 'Title', ['Raw Amplitudes']);
                   gui.Results.FitText = uix.HBox('Parent', gui.Results.fit, 'Padding', 5,'BackgroundColor',gui.colormap.Background);
                   gui.Results.FitTextNames  = uicontrol('Parent',gui.Results.FitText,'style','text',...
                   'FontSize', 11, 'FontName', 'Arial','HorizontalAlignment', 'left', 'String', sprintf(NameText),...
                   'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground);
                   gui.Results.FitTextAmpl  = uicontrol('Parent',gui.Results.FitText,'style','text',...
                   'FontSize', 11, 'FontName', 'Arial','HorizontalAlignment', 'left', 'String', sprintf(RawAmplText),...
                   'BackgroundColor',gui.colormap.Background,'ForegroundColor', gui.colormap.Foreground);
                end
            end
%%%  5. VISUALIZATION PART OF THIS TAB %%%
%osp_plotFit is used to visualize the fits (off,diff1,diff2,sum,ref,water)
            temp = figure( 'Visible', 'off' );
            temp = osp_plotFit(MRSCont, gui.controls.Selected,gui.fit.Style,gui.fit.Names{t});
            ViewAxes = gca();
            set(ViewAxes, 'Parent', gui.Plot.fit );
            close( temp );

            set(gui.Plot.fit,'Widths', [-0.16 -0.84]);
            set(gui.Plot.fit.Children(2), 'Units', 'normalized');
            set(gui.Plot.fit.Children(2), 'OuterPosition', [0.17,0.02,0.75,0.98])
        end
    setappdata(gui.figure,'MRSCont',MRSCont); % Write MRSCont into hidden container in gui class
end