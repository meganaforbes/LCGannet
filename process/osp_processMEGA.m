function [MRSCont] = osp_processMEGA(MRSCont, target)
%% [MRSCont] = osp_processMEGA(MRSCont, target)
%   This function performs the following steps to process MEGA-edited
%   (2-step) MRS data (e.g. MEGA-PRESS, MEGA-sLASER):
%       - Alignment of individual averages using robust spectral registration
%       - Averaging
%       - Removal of residual water using HSVD filtering
%       - Klose Eddy current correction (if a reference scan is provided)
%       - Automated zero-order phase correction
%       - Correct referencing of the ppm frequency axis
%
%   USAGE:
%       [MRSCont] = osp_processMEGA(MRSCont, 'target');
%
%   INPUTS:
%       MRSCont     = Osprey MRS data container.
%       target      = String. Can be 'GABA' or 'GSH'. Default: 'GABA'
%
%   OUTPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-02-22)
%       goeltzs1@jhmi.edu
%   
%   CREDITS:    
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2019-08-20: First public version of the code.


warning('off','all');

% Parse input arguments
if nargin < 2
    target = MRSCont.opts.editTarget{1}; % GABA editing as default
end

%% Loop over all datasets
refProcessTime = tic;
reverseStr = '';
if MRSCont.flags.isGUI
    progressText = MRSCont.flags.inProgress;
end
fileID = fopen(fullfile(MRSCont.outputFolder, 'LogFile.txt'),'a+');
for kk = 1:MRSCont.nDatasets
    msg = sprintf('Processing data from dataset %d out of %d total datasets...\n', kk, MRSCont.nDatasets);
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    fprintf(fileID,[reverseStr, msg]);
    if MRSCont.flags.isGUI        
        set(progressText,'String' ,sprintf('Processing data from dataset %d out of %d total datasets...\n', kk, MRSCont.nDatasets));
        drawnow
    end    
    
    if ((MRSCont.flags.didProcess == 1 && MRSCont.flags.speedUp && isfield(MRSCont, 'processed') && (kk > length(MRSCont.processed.A))) || ~isfield(MRSCont.ver, 'Pro') || ~strcmp(MRSCont.ver.Pro,MRSCont.ver.CheckPro))    
        %%% 1. GET RAW DATA %%%
        raw         = MRSCont.raw{kk};                                          % Get the kk-th dataset

        % Perform robust spectral correction with weighted averaging.
        % This can obviously only be done, if the spectra have not been 
        % pre-averaged, i.e. in some older RDA and DICOM files (which should, 
        % generally, not be used).
        if raw.averages > 1 && raw.flags.averaged == 0
    %         raw_A   = op_robustSpecReg(raw_A, 'MEGA', 0);
    %         raw_B   = op_robustSpecReg(raw_B, 'MEGA', 0);   
            [raw, fs, phs, weights, driftPre, driftPost]   = op_robustSpecReg(raw, 'MEGA', 0);
            raw.specReg.fs              = fs; % save align parameters
            raw.specReg.phs             = phs; % save align parameters
            raw.specReg.weights         = weights; % save align parameters
        else
            raw.flags.averaged  = 1;
            raw.dims.averages   = 0;
            raw.specReg.fs              = zeros(1,2); % save align parameters
            raw.specReg.phs             = zeros(1,2); % save align parameters
            raw.specReg.weights{1}         = ones(1,1); % save align parameters
            raw.specReg.weights{2}         = ones(1,1); % save align parameters
            driftPre{1} = 0;
            driftPre{2} = 0;
            driftPost = driftPre;
        end

        % Get sub-spectra, depending on whether they are stored as such
        if raw.subspecs == 2
            raw_A   = op_takesubspec(raw,1);                    % Get first subspectrum
            raw_B   = op_takesubspec(raw,2);                    % Get second subspectrum
        else
            raw_A   = op_takeaverages(raw,1:2:raw.averages);    % Get first subspectrum
            raw_B   = op_takeaverages(raw,2:2:raw.averages);    % Get second subspectrum
        end

        %%% 2. GET REFERENCE DATA / EDDY CURRENT CORRECTION %%%
        % If there are reference scans, perform the same operations
        if MRSCont.flags.hasRef
            raw_ref                     = MRSCont.raw_ref{kk};              % Get the kk-th dataset

            % Some formats end up having subspectra in their reference scans
            % (e.g. Philips), as well as empty lines. Intercept these cases
            % here.
            if raw_ref.subspecs > 1
                raw_ref_A               = op_takesubspec(raw_ref,1);
                [raw_ref_A]             = op_rmempty(raw_ref_A);            % Remove empty lines
                raw_ref_B               = op_takesubspec(raw_ref,2);
                [raw_ref_B]             = op_rmempty(raw_ref_B);            % Remove empty lines
                raw_ref                 = op_concatAverages(raw_ref_A,raw_ref_B);
            end
            if ~raw_ref.flags.averaged
                [raw_ref,~,~]           = op_alignAverages(raw_ref,1,'n');  % Align averages
                raw_ref                 = op_averaging(raw_ref);            % Average
            end

    %         % The following IF only for Big GABA dataset - a few Siemens datasets
    %         % have been accidentally acquired with the water suppression switched
    %         % on for the water reference scan. In that case, don't do ECC, but
    %         % rather leave it to the phase correction in step 5.
    %         if strcmp(MRSCont.vendor,'Siemens') && kk >= 37 && kk <= 42
    %         else
                [raw_A,~]               = op_eccKlose(raw_A, raw_ref);
                [raw_B,raw_ref]         = op_eccKlose(raw_B, raw_ref);        % Klose eddy current correction
    %         end

            [raw_ref,~]                 = op_ppmref(raw_ref,4.6,4.8,4.68);  % Reference to water @ 4.68 ppm
            MRSCont.processed.ref{kk}   = raw_ref;                          % Save back to MRSCont container
        end


        %%% 3. DETERMINE POLARITY OF SPECTRUM (EG FOR MOIST WATER SUPP) %%%
        % Automate determination whether the Cr peak has positive polarity.
        % For water suppression methods like MOIST, the residual water may
        % actually have negative polarity, but end up positive in the data, so
        % that the spectrum needs to be flipped.
        raw_A_Cr    = op_freqrange(raw_A,2.8,3.2);
        % Determine the polarity of the respective peak: if the absolute of the
        % maximum minus the absolute of the minimum is positive, the polarity 
        % of the respective peak is positive; if the absolute of the maximum 
        % minus the absolute of the minimum is negative, the polarity is negative.
        polResidCr  = abs(max(real(raw_A_Cr.specs))) - abs(min(real(raw_A_Cr.specs)));
        if polResidCr < 0
            raw_A = op_ampScale(raw_A,-1);
            raw_B = op_ampScale(raw_B,-1);
        end


        %%% 4. DETERMINE ON/OFF STATUS
        % Classify the two sub-spectra such that the OFF spectrum is stored to
        % field A, and the ON spectrum is stored to field B.
        [raw_A, raw_B, switchOrder]  = osp_onOffClassifyMEGA(raw_A, raw_B, target);

        raw_A.specReg.fs     = raw.specReg.fs(:,1); % save align parameters
        raw_B.specReg.fs     = raw.specReg.fs(:,2);
        raw_A.specReg.phs     = raw.specReg.phs(:,1);
        raw_B.specReg.phs     = raw.specReg.phs(:,2);
        raw_A.specReg.weights 	= raw.specReg.weights{1}(1,:);
        raw_B.specReg.weights    = raw.specReg.weights{2}(1,:);
        raw_A.specReg.weights = raw_A.specReg.weights'/(max(raw_A.specReg.weights));
        raw_B.specReg.weights = raw_B.specReg.weights'/(max(raw_B.specReg.weights));
        % Generate the frequency and phase plots for the entire experiment in
        % the correct order
        fs = [raw_A.specReg.fs, raw_B.specReg.fs]';
        fs = reshape(fs, [raw.rawAverages, 1]);
        phs = [raw_A.specReg.phs, raw_B.specReg.phs]';
        phs = reshape(phs, [raw.rawAverages, 1]);
        weights = [raw_A.specReg.weights, raw_B.specReg.weights]';
        weights = reshape(weights, [raw.rawAverages, 1]);
        MRSCont.raw{kk}.specReg.fs              = fs; % save align parameters
        MRSCont.raw{kk}.specReg.phs             = phs; % save align parameters
        MRSCont.raw{kk}.specReg.weights             = weights; % save align parameters 

        %%% 5. BUILD SUM AND DIFF SPECTRA %%%
        % Correct the frequency axis so that Cr appears at 3.027 ppm
        temp_spec   = op_addScans(raw_A,raw_B);  
        [refShift_SubSpecAlign, ~] = osp_CrChoReferencing(temp_spec);
        % Apply initial referencing shift
        raw_A = op_freqshift(raw_A, -refShift_SubSpecAlign);
        raw_B = op_freqshift(raw_B, -refShift_SubSpecAlign);
        % Fit a double-Lorentzian to the Cr-Cho area, and phase the spectrum
        % with the negative phase of that fit
        [raw_A,~]       = op_phaseCrCho(raw_A, 1);
        % Align the sub-spectra to one another by minimizing the difference
        % between the common 'reporter' signals.
        [raw_A, raw_B]  = osp_editSubSpecAlign(raw_A, raw_B, target);
        % Create the sum spectrum
        sum             = op_addScans(raw_A,raw_B);
        if switchOrder
            sum.flags.orderswitched = 1;
        else
            sum.flags.orderswitched = 0;
        end
        sum.specReg.fs = fs;
        sum.specReg.phs = phs;
        sum.specReg.weights = weights;
        % Create the GABA-edited difference spectrum
        diff1           = op_addScans(raw_B,raw_A,1);
        if switchOrder
            diff1.flags.orderswitched = 1;
        else
            diff1.flags.orderswitched = 0;
        end
        diff1.target = target;
        diff1.specReg.fs = fs;
        diff1.specReg.phs = phs;
        diff1.specReg.weights = weights;
        %%% 6. REMOVE RESIDUAL WATER %%%
        % Remove water and correct back to baseline.
        % The spectra sometimes become NaNs after filtering with too many
        % components. Loop over decreasing numbers of components here.
        [raw_A_temp,~,~]           = op_removeWater(raw_A,[4.5 4.9],20,0.75*length(raw_A.fids),0); % Remove the residual water
        if isnan(real(raw_A_temp.fids))
            rr = 30;
            while isnan(real(raw_A_temp.fids))
                [raw_A_temp,~,~]   = op_removeWater(raw_A,[4.5 4.9],rr,0.75*length(raw_A.fids),0); % Remove the residual water
                rr = rr-1;
            end
        end
        raw_A   = raw_A_temp;
        raw_A   = op_fddccorr(raw_A,100);                                 % Correct back to baseline

        [raw_B_temp,~,~]           = op_removeWater(raw_B,[4.5 4.9],20,0.75*length(raw_B.fids),0); % Remove the residual water
        if isnan(real(raw_B_temp.fids))
           rr = 30;
           while isnan(real(raw_B_temp.fids))
               [raw_B_temp,~,~]    = op_removeWater(raw_B,[4.5 4.9],rr,0.75*length(raw_B.fids),0); % Remove the residual water
                rr = rr-1;
           end
        end
        raw_B   = raw_B_temp;
        raw_B   = op_fddccorr(raw_B,100);                                 % Correct back to baseline

        [diff1_temp,~,~]           = op_removeWater(diff1,[4.5 4.9],20,0.75*length(diff1.fids),0); % Remove the residual water
        if isnan(real(diff1_temp.fids))
            rr = 30;
            while isnan(real(diff1_temp.fids))
                [diff1_temp,~,~]   = op_removeWater(diff1,[4.5 4.9],rr,0.75*length(diff1.fids),0); % Remove the residual water
                rr = rr-1;
            end
        end
        diff1   = diff1_temp;
        diff1   = op_fddccorr(diff1,100);                                 % Correct back to baseline

        [sum_temp,~,~]           = op_removeWater(sum,[4.5 4.9],20,0.75*length(sum.fids),0); % Remove the residual water
        if isnan(real(sum_temp.fids))
            rr = 30;
            while isnan(real(sum_temp.fids))
                [sum_temp,~,~]   = op_removeWater(sum,[4.5 4.9],rr,0.75*length(sum.fids),0); % Remove the residual water
                rr = rr-1;
            end
        end
        sum     = sum_temp;
        sum     = op_fddccorr(sum,100);


        %%% 7. REFERENCE SPECTRUM CORRECTLY TO FREQUENCY AXIS 
        % Reference resulting data correctly and consistently
        [refShift_final, ~] = osp_CrChoReferencing(sum);
        [raw_A]             = op_freqshift(raw_A,-refShift_final);            % Apply same shift to edit-OFF
        [raw_B]             = op_freqshift(raw_B,-refShift_final);            % Apply same shift to edit-OFF
        [diff1]             = op_freqshift(diff1,-refShift_final);            % Apply same shift to diff1
        [sum]               = op_freqshift(sum,-refShift_final);              % Apply same shift to sum


        %%% 8. SAVE BACK TO MRSCONT CONTAINER
        MRSCont.processed.A{kk}     = raw_A;                                    % Save edit-OFF back to MRSCont container
        MRSCont.processed.B{kk}     = raw_B;                                    % Save edit-ON back to MRSCont container
        MRSCont.processed.diff1{kk} = diff1;                                    % Save diff1 back to MRSCont container
        MRSCont.processed.sum{kk}   = sum;                                      % Save sum back to MRSCont container


        %%% 9. GET SHORT-TE WATER DATA %%%
        if MRSCont.flags.hasWater
            % Some formats end up having subspectra in their reference scans
            % (e.g. Philips), as well as empty lines. Intercept these cases
            % here.
            raw_w                       = MRSCont.raw_w{kk};                % Get the kk-th dataset
            if raw_w.subspecs > 1
                raw_w_A                 = op_takesubspec(raw_w,1);
                [raw_w_A]               = op_rmempty(raw_w_A);              % Remove empty lines
                raw_w_B                 = op_takesubspec(raw_w,2);
                [raw_w_A]               = op_rmempty(raw_w_A);              % Remove empty lines
                raw_w                   = op_concatAverages(raw_w_A,raw_w_B);
            end
            if ~raw_w.flags.averaged
                [raw_w,~,~]             = op_alignAverages(raw_w,1,'n');    % Align averages
                raw_w                   = op_averaging(raw_w);              % Average
            end
            [raw_w,~]                   = op_eccKlose(raw_w, raw_w);        % Klose eddy current correction
            [raw_w,~]                   = op_ppmref(raw_w,4.6,4.8,4.68);    % Reference to water @ 4.68 ppm
            MRSCont.processed.w{kk}     = raw_w;                            % Save back to MRSCont container
        end


        %%% 10. QUALITY CONTROL PARAMETERS %%%
        % Calculate some spectral quality metrics here;
        MRSCont.QM.SNR.A(kk)    = op_getSNR(MRSCont.processed.A{kk}); % NAA amplitude over noise floor
        FWHM_Hz                 = op_getLW(MRSCont.processed.A{kk},1.8,2.2); % in Hz
        MRSCont.QM.FWHM.A(kk)   = FWHM_Hz./MRSCont.processed.A{kk}.txfrq*1e6; % convert to ppm
        MRSCont.QM.drift.pre.A{kk}  = driftPre{1};
        MRSCont.QM.drift.post.A{kk} = driftPost{1};
        MRSCont.QM.freqShift.A(kk)  = refShift_SubSpecAlign + refShift_final;;
        MRSCont.QM.drift.pre.AvgDeltaCr.A(kk) = mean(driftPre{1} - 3.02);
        MRSCont.QM.drift.post.AvgDeltaCr.A(kk) = mean(driftPost{1} - 3.02);

        MRSCont.QM.SNR.B(kk)    = op_getSNR(MRSCont.processed.B{kk},2.8,3.2); % Cr amplitude over noise floor
        FWHM_Hz                 = op_getLW(MRSCont.processed.B{kk},2.8,3.2); % in Hz
        MRSCont.QM.FWHM.B(kk)   = FWHM_Hz./MRSCont.processed.B{kk}.txfrq*1e6; % convert to ppm
        MRSCont.QM.drift.pre.B{kk}  = driftPre{2};
        MRSCont.QM.drift.post.B{kk} = driftPost{2};
        MRSCont.QM.freqShift.B(kk)  = refShift_SubSpecAlign + refShift_final;;
        MRSCont.QM.drift.pre.AvgDeltaCr.B(kk) = mean(driftPre{2} - 3.02);
        MRSCont.QM.drift.post.AvgDeltaCr.B(kk) = mean(driftPost{2} - 3.02);

        MRSCont.QM.SNR.diff1(kk)    = op_getSNR(MRSCont.processed.diff1{kk},2.8,3.2); % GABA amplitude over noise floor
        FWHM_Hz                 = op_getLW(MRSCont.processed.diff1{kk},2.8,3.2); % in Hz
        MRSCont.QM.FWHM.diff1(kk)   = FWHM_Hz./MRSCont.processed.diff1{kk}.txfrq*1e6; % convert to ppm
        MRSCont.QM.drift.pre.diff1{kk}  = reshape([driftPre{1}'; driftPre{2}'], [], 1)';
        MRSCont.QM.drift.post.diff1{kk} = reshape([driftPost{1}'; driftPost{2}'], [], 1)';
        MRSCont.QM.freqShift.diff1(kk)  = refShift_SubSpecAlign + refShift_final;;
        MRSCont.QM.drift.pre.AvgDeltaCr.diff1(kk) = mean(MRSCont.QM.drift.pre.diff1{kk} - 3.02);
        MRSCont.QM.drift.post.AvgDeltaCr.diff1(kk) = mean(MRSCont.QM.drift.post.diff1{kk} - 3.02);

        MRSCont.QM.SNR.sum(kk)    = op_getSNR(MRSCont.processed.sum{kk}); % Cr amplitude over noise floor
        FWHM_Hz                     = op_getLW(MRSCont.processed.sum{kk},2.8,3.2); % in Hz
        MRSCont.QM.FWHM.sum(kk)   = FWHM_Hz./MRSCont.processed.sum{kk}.txfrq*1e6; % convert to ppm
        MRSCont.QM.drift.pre.sum{kk}  =  MRSCont.QM.drift.pre.diff1{kk};
        MRSCont.QM.drift.post.sum{kk} = MRSCont.QM.drift.post.diff1{kk};
        MRSCont.QM.freqShift.sum(kk)  = refShift_SubSpecAlign + refShift_final;;
        MRSCont.QM.drift.pre.AvgDeltaCr.sum(kk) = mean(MRSCont.QM.drift.pre.sum{kk} - 3.02);
        MRSCont.QM.drift.post.AvgDeltaCr.sum(kk) = mean(MRSCont.QM.drift.post.sum{kk} - 3.02);

        if MRSCont.flags.hasRef
            MRSCont.QM.SNR.ref(kk)  = op_getSNR(MRSCont.processed.ref{kk},4.2,5.2); % water amplitude over noise floor
            FWHM_Hz                 = op_getLW(MRSCont.processed.ref{kk},4.2,5.2); % in Hz
            MRSCont.QM.FWHM.ref(kk) = FWHM_Hz./MRSCont.processed.ref{kk}.txfrq*1e6; % convert to ppm
        end
        if MRSCont.flags.hasWater
            MRSCont.QM.SNR.w(kk)    = op_getSNR(MRSCont.processed.w{kk},4.2,5.2); % water amplitude over noise floor
            FWHM_Hz                 = op_getLW(MRSCont.processed.w{kk},4.2,5.2); % in Hz
            MRSCont.QM.FWHM.w(kk)   = FWHM_Hz./MRSCont.processed.w{kk}.txfrq*1e6; % convert to ppm
        end
    end         
end
fprintf('... done.\n');
time = toc(refProcessTime);
if MRSCont.flags.isGUI        
    set(progressText,'String' ,sprintf('... done.\n Elapsed time %f seconds',time));
    pause(1);
end
fprintf(fileID,'... done.\n Elapsed time %f seconds\n',time);
fclose(fileID);

%%% 11. SET FLAGS %%%
MRSCont.flags.avgsAligned   = 1;
MRSCont.flags.averaged      = 1;
MRSCont.flags.ECCed         = 1;
MRSCont.flags.waterRemoved  = 1;
MRSCont.runtime.Proc = time;
% Close any remaining open figures
close all;

end