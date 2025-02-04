function [MRSCont] = OspreyFit(MRSCont)
%% [MRSCont] = OspreyFit(MRSCont)
%   This function performs spectral fitting on MRS data loaded previously
%   using OspreyLoad.
%
%   The method of fit, fitting range, included metabolites and other 
%   settings are set in the job file.
%
%   USAGE:
%       MRSCont = OspreyFit(MRSCont);
%
%   INPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   OUTPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-02-24)
%       goeltzs1@jhmi.edu
%   
%   CREDITS:    
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2019-02-24: First version of the code.

outputFolder = MRSCont.outputFolder;
fileID = fopen(fullfile(outputFolder, 'LogFile.txt'),'a+');
% Check that OspreyLoad has been run before
if ~MRSCont.flags.didLoadData
    msg = 'Trying to fit data, but raw data has not been loaded yet. Run OspreyLoad first.';
    fprintf(fileID,msg);
    error(msg);
end

% Check that OspreyProcess has been run before
if ~MRSCont.flags.didProcess
    msg = 'Trying to fit data, but loaded data has not been process yet. Run OspreyProcess first.';
    fprintf(fileID,msg);
    error(msg);
end

%% Load fit settings, prepare data and pass it on to the fitting algorithm

% Version, toolbox check and updating log file
MRSCont.ver.CheckFit       = '1.0.0 Fit';
fprintf(fileID,['Timestamp %s ' MRSCont.ver.Osp '  ' MRSCont.ver.CheckFit '\n'], datestr(now,'mmmm dd, yyyy HH:MM:SS'));
[~] = osp_Toolbox_Check ('OspreyFit',MRSCont.flags.isGUI);
MRSCont.runtime.Fit = 0;

% Initialise the fit - this step includes:
% - Parse the correct basis set
% - Apply settings on which metabolites/MM/lipids to include in the fit
% - Check for inconsistencies between basis set and data
[MRSCont] = osp_fitInitialise(MRSCont);
MRSCont.opts.fit.outputFolder = outputFolder;
% Call the fit functions (depending on sequence type)
if MRSCont.flags.isUnEdited
    [MRSCont] = osp_fitUnEdited(MRSCont);
elseif MRSCont.flags.isMEGA
    [MRSCont] = osp_fitMEGA(MRSCont);
elseif MRSCont.flags.isHERMES
    [MRSCont] = osp_fitHERMES(MRSCont);
elseif MRSCont.flags.isHERCULES
    % For now, fit HERCULES like HERMES data
    [MRSCont] = osp_fitHERCULES(MRSCont);
else
    msg = 'No flag set for sequence type!';
    fprintf(fileID,msg);
    error(msg);
end

%% Perform water reference and short-TE water fit
if MRSCont.flags.isGUI
    progressText = MRSCont.flags.inProgress;
end
fileID = fopen(fullfile(outputFolder, 'LogFile.txt'),'a+');
% If water reference exists, fit it
if MRSCont.flags.hasRef
    refFitTime = tic;
    reverseStr = '';
    % Loop over all the datasets here
    for kk = 1:MRSCont.nDatasets
        msg = sprintf('\nFitting water reference from dataset %d out of %d total datasets...\n', kk, MRSCont.nDatasets);
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        fprintf(fileID,[reverseStr, msg]);
        if MRSCont.flags.isGUI        
            set(progressText,'String' ,sprintf('Fitting water reference from dataset %d out of %d total datasets...\n', kk, MRSCont.nDatasets));
            drawnow
        end
        if ((MRSCont.flags.didFit == 1 && MRSCont.flags.speedUp && isfield(MRSCont, 'fit') && (kk > length(MRSCont.fit.results.ref.fitParams))) || ~isfield(MRSCont.ver, 'Fit') || ~strcmp(MRSCont.ver.Fit,MRSCont.ver.CheckFit))
            [MRSCont] = osp_fitWater(MRSCont, kk, 'ref');
        end
    end
    fprintf('... done.\n');
    fprintf(fileID,'... done.\n');
    time = toc(refFitTime);
    if MRSCont.flags.isGUI        
        set(progressText,'String' ,sprintf('... done.\n Elapsed time %f seconds',time));
        pause(1);
    end
    fprintf(fileID,'... done.\n Elapsed time %f seconds\n',time);
    MRSCont.runtime.FitRef = time;
    MRSCont.runtime.Fit = MRSCont.runtime.Fit + time;
end

% If short TE water reference exists, fit it
if MRSCont.flags.hasWater
    waterFitTime = tic;
    reverseStr = '';   
    % Loop over all the datasets here
    for kk = 1:MRSCont.nDatasets
        msg = sprintf('\nFitting short-TE water from dataset %d out of %d total datasets...\n', kk, MRSCont.nDatasets);
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        fprintf(fileID,[reverseStr, msg]);
        if MRSCont.flags.isGUI        
            set(progressText,'String' ,sprintf('Fitting short-TE water from dataset %d out of %d total datasets...\n', kk, MRSCont.nDatasets));
            drawnow
        end
        if ((MRSCont.flags.didFit == 1 && MRSCont.flags.speedUp && isfield(MRSCont, 'fit') && (kk > length(MRSCont.fit.results.w.fitParams))) || ~isfield(MRSCont.ver, 'Fit') || ~strcmp(MRSCont.ver.Fit,MRSCont.ver.CheckFit))
            [MRSCont] = osp_fitWater(MRSCont, kk, 'w');
        end
    end
    fprintf('... done.\n');
    fprintf(fileID,'... done.\n');
    time = toc(waterFitTime);
    if MRSCont.flags.isGUI        
        set(progressText,'String' ,sprintf('... done.\n Elapsed time %f seconds',time));
        pause(1);
    end
    fprintf(fileID,'... done.\n Elapsed time %f seconds\n',time);
    MRSCont.runtime.FitWater = time;
    MRSCont.runtime.Fit = MRSCont.runtime.Fit + time;
end
MRSCont.runtime.Fit = MRSCont.runtime.Fit + MRSCont.runtime.FitMet;
fprintf(fileID,'Full fit time %f seconds\n',MRSCont.runtime.Fit);
fclose(fileID); %close log file
%% Clean up and save
% Set exit flags and version
MRSCont.flags.didFit           = 1;
MRSCont.ver.Fit            = '1.0.0 Fit';
% Delete redundant resBasiset entries
% FitNames = fieldnames(MRSCont.fit.results);
% NoFit = length(fieldnames(MRSCont.fit.results));
% for sf = 1 : NoFit
%     if iscell(MRSCont.fit.resBasisSet.(FitNames{sf}))
%         MRSCont.fit.resBasisSet.(FitNames{sf}) = MRSCont.fit.resBasisSet.(FitNames{sf})(MRSCont.info.A.unique_ndatapoint_ind);
%     else
%         MRSCont.fit.resBasisSet.(FitNames{sf}).water = MRSCont.fit.resBasisSet.(FitNames{sf}).water(MRSCont.info.(FitNames{sf}).unique_ndatapoint_ind); 
%     end
% end

% Save the output structure to the output folder
% Determine output folder
outputFolder    = MRSCont.outputFolder;
outputFile      = MRSCont.outputFile;
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

% Optional:  Create all pdf figures
if MRSCont.opts.savePDF
    if strcmp(MRSCont.opts.fit.style, 'Concatenated')
    temp = fieldnames(MRSCont.fit.results);
    if MRSCont.flags.isUnEdited
        Names = fieldnames(MRSCont.fit.results);
    end
    if MRSCont.flags.isMEGA
        Names = {'diff1','sum'};
        if length(temp) == 2
            Names{3} = temp{2};
        else if length(temp) == 3
            Names{3} = temp{2};
            Names{4} = temp{3};
            end
        end
    end
    if (MRSCont.flags.isHERMES || MRSCont.flags.isHERCULES)
        Names = {'diff1','diff2','sum'};
        if length(temp) == 2
            Names{4} = temp{2};
        else if length(temp) == 3
            Names{4} = temp{2};
            Names{5} = temp{3};
            end
        end
    end
    else
        Names = fieldnames(MRSCont.fit.results);  
    end
    for kk = 1 : MRSCont.nDatasets
        for ss = 1 : length(Names)
            osp_plotModule(MRSCont, 'OspreyFit', kk, Names{ss});
        end
    end
end

if MRSCont.flags.isGUI
    MRSCont.flags.isGUI = 0;
    save(fullfile(outputFolder, outputFile), 'MRSCont');
    MRSCont.flags.isGUI = 1;
else
   save(fullfile(outputFolder, outputFile), 'MRSCont');
end

end