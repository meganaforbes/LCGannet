function [MRSCont] = osp_processUnEdited(MRSCont)
%% [MRSCont] = osp_processUnEdited(MRSCont)
%   This function performs the following steps to process un-edited MRS
%   data (e.g. PRESS, STEAM, sLASER):
%       - Alignment of individual averages using robust spectral registration
%       - Averaging
%       - Removal of residual water using HSVD filtering
%       - Klose Eddy current correction (if a reference scan is provided)
%       - Correct referencing of the ppm frequency axis
%
%   USAGE:
%       [MRSCont] = osp_processUnEdited(MRSCont);
%
%   INPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   OUTPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-02-20)
%       goeltzs1@jhmi.edu
%
%   CREDITS:
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2019-02-20: First version of the code.

warning('off','all');

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
        raw                         = MRSCont.raw{kk};                                          % Get the kk-th dataset

        %%% 1B. GET MM DATA %%% re_mm
        % If there are reference scans, load them here to allow eddy-current re_mm
        % correction of the raw data. re_mm
        if MRSCont.flags.hasMM %re_mm
            raw_mm                         = MRSCont.raw_mm{kk};              % Get the kk-th dataset re_mm
            if raw_mm.averages > 1 && raw_mm.flags.averaged == 0 %re_mm
                [raw_mm,~,~]               = op_alignAverages(raw_mm, 1, 'n'); %re_mm
                raw_mm                     = op_averaging(raw_mm);            % Average re_mm
            else %re_mm
                raw_mm.flags.averaged  = 1; %re_mm
                raw_mm.dims.averages   = 0; %re_mm
            end
            [raw_mm,~]                     = op_ppmref(raw_mm,4.6,4.8,4.68);  % Reference to water @ 4.68 ppm  %re_mm            
        end  %re_mm
        
        
        %%% 2. GET REFERENCE DATA / EDDY CURRENT CORRECTION %%%
        % If there are reference scans, load them here to allow eddy-current
        % correction of the raw data.
        if MRSCont.flags.hasRef
            raw_ref                         = MRSCont.raw_ref{kk};              % Get the kk-th dataset
            if raw_ref.averages > 1 && raw_ref.flags.averaged == 0
                [raw_ref,~,~]               = op_alignAverages(raw_ref, 1, 'n');
                raw_ref                     = op_averaging(raw_ref);            % Average
            else
                raw_ref.flags.averaged  = 1;
                raw_ref.dims.averages   = 0;
            end
            temp_raw_ref = raw_ref;
            temp_raw = raw;
            [raw,raw_ref]                   = op_eccKlose(raw, raw_ref);        % Klose eddy current correction
             
            temp_raw_NAA=op_freqrange(temp_raw,1.8,2.2);
            raw_NAA=op_freqrange(raw,1.8,2.2);
            
            %Find the ppm of the maximum peak magnitude within the given range:
            temp_ppmindex_NAA=find(abs(temp_raw_NAA.specs(:,1))==max(abs(temp_raw_NAA.specs(:,1))));
            ppmindex_NAA=find(abs(raw_NAA.specs(:,1))==max(abs(raw_NAA.specs(:,1))));

            %now do automatic zero-order phase correction (Use Creatine Peak):
            temp_ph0_NAA=-phase(temp_raw_NAA.specs(temp_ppmindex_NAA,1))*180/pi;
            ph0_NAA=-phase(raw_NAA.specs(ppmindex_NAA,1))*180/pi;
            
            if 2*abs(temp_ph0_NAA) > abs(ph0_NAA)
                if MRSCont.flags.hasMM
                    [raw_mm,~]                   = op_eccKlose(raw_mm, temp_raw_ref);        % Klose eddy current correction
                end
            else
                raw = temp_raw;
            end
            [raw_ref,~]                     = op_ppmref(raw_ref,4.6,4.8,4.68);  % Reference to water @ 4.68 ppm
            MRSCont.processed.ref{kk}       = raw_ref;                          % Save back to MRSCont container
        end


        %%% 3. FREQUENCY/PHASE CORRECTION AND AVERAGING %%%
        if raw.averages > 1 && raw.flags.averaged == 0 
            % Automate determination whether the Cr peak has positive polarity.
            % For water suppression methods like MOIST, the residual water may
            % actually have negative polarity, but end up positive in the data, so
            % that the spectrum needs to be flipped.
            % Determine the polarity of the respective peak: if the absolute of the
            % maximum minus the absolute of the minimum is positive, the polarity
            % of the respective peak is positive; if the absolute of the maximum
            % minus the absolute of the minimum is negative, the polarity is negative.
            temp_A = op_averaging(raw);
            raw_A_Cr    = op_freqrange(temp_A,2.8,3.2);
            polResidCr  = abs(max(real(raw_A_Cr.specs))) - abs(min(real(raw_A_Cr.specs)));
            temp_rawA = raw;
            if polResidCr < 0        
                temp_rawA = op_ampScale(temp_rawA,-1);
            end
            % We will use a freqeuncy cross-correlation approach on the
            % Choline and Creatine singlets to generate a robust inital
            % frequency guess for the robust spectral registration. This is
            % esapacially useful for data with heavy freqeuncy drift. The
            % transients are averaged into packages inclduing 10% of the
            % averages of the whole spectra and referenced afterwards. For
            % these packages the same inital frequency guess is forwarded
            % to op_robustSpecReg.
            temp_proc = temp_rawA;
            temp_spec   = temp_proc;
            for av = 1 : round(temp_rawA.averages*0.1) :temp_rawA.averages-(round(temp_rawA.averages*0.1)-1)-mod(temp_rawA.averages,round(temp_rawA.averages*0.1)) % 10% packaging
                fids = temp_proc.fids(:,av:av+(round(temp_rawA.averages*0.1)-1)); 
                specs = temp_proc.specs(:,av:av+(round(temp_rawA.averages*0.1)-1));
                temp_spec.fids = mean(fids,2); % store average fid
                temp_spec.specs = mean(specs,2); % store average spectra
                [refShift, ~] = osp_CrChoReferencing(temp_spec); % determine frequency shift
                refShift_ind_ini(av : av+round(temp_rawA.averages*0.1)-1) = refShift; %save inital frequency guess 
            end
            if mod(temp_rawA.averages,round(temp_rawA.averages*0.1)) > 0 % remaining averages if data isn't a multiple of 10.
                fids = temp_proc.fids(:,end-(mod(temp_rawA.averages,round(temp_rawA.averages*0.1))-1):end); 
                specs = temp_proc.specs(:,end-(mod(temp_rawA.averages,round(temp_rawA.averages*0.1))-1):end); 
                temp_spec.fids = mean(fids,2); % store average fid 
                temp_spec.specs = mean(specs,2); % store average spectra
                [refShift, ~] = osp_CrChoReferencing(temp_spec);% determine frequency shift
                refShift_ind_ini(end-(mod(temp_rawA.averages,round(temp_rawA.averages*0.1))-1) : temp_rawA.averages) = refShift; %save inital frequency guess 
            end
            [raw, fs, phs, weights, driftPre, driftPost]     = op_robustSpecReg(raw, 'unedited', 0,refShift_ind_ini); % Align and average
            raw.specReg.fs              = fs; % save align parameters
            raw.specReg.phs             = phs; % save align parameters
            raw.specReg.weights         = weights{1}(1,:)'; % save align parameters);
            raw.specReg.weights         = raw.specReg.weights/max(raw.specReg.weights);
        else
            raw.flags.averaged  = 1;
            raw.dims.averages   = 0;
            raw.specReg.fs              = 0; % save align parameters
            raw.specReg.phs             = 0; % save align parameters
            raw.specReg.weights         = 1; % save align parameters
            driftPre = op_measureDrift(raw);
            driftPost = driftPre;
        end

        %%% 4. DETERMINE POLARITY OF SPECTRUM (EG FOR MOIST WATER SUPP) %%%
        % Automate determination whether the NAA peak has positive polarity.
        % For water suppression methods like MOIST, the residual water may
        % actually have negative polarity, but end up positive in the data, so
        % that the spectrum needs to be flipped.
        raw_NAA     = op_freqrange(raw,1.9,2.1);
        % Determine the polarity of the respective peak: if the absolute of the
        % maximum minus the absolute of the minimum is positive, the polarity
        % of the respective peak is positive; if the absolute of the maximum
        % minus the absolute of the minimum is negative, the polarity is negative.
        polResidNAA = abs(max(real(raw_NAA.specs))) - abs(min(real(raw_NAA.specs)));
        if polResidNAA < 0
            raw = op_ampScale(raw,-1);
            MRSCont.raw{kk} = op_ampScale(MRSCont.raw{kk},-1);
        end


        %%% 5. REMOVE RESIDUAL WATER %%%
        [raw_temp,~,~]   = op_removeWater(raw,[4.5 4.9],20,0.75*length(raw.fids),0); % Remove the residual water
        if isnan(real(raw_temp.fids))
            rr = 30;
            while isnan(real(raw_temp.fids))
                [raw_temp,~,~]   = op_removeWater(raw,[4.5 4.9],rr,0.75*length(raw.fids),0); % Remove the residual water
                rr = rr-1;
            end
        end
        raw     = raw_temp;
        raw     = op_fddccorr(raw,100);                                     % Correct back to baseline
        
        if MRSCont.flags.hasMM %re_mm
            [raw_temp_mm,~,~]   = op_removeWater(raw_mm,[4.5 4.9],20,0.75*length(raw.fids),0); % Remove the residual water
            if isnan(real(raw_temp_mm.fids))
                rr = 30;
                while isnan(real(raw_temp_mm.fids))
                    [raw_temp_mm,~,~]   = op_removeWater(raw_mm,[4.5 4.9],rr,0.75*length(raw.fids),0); % Remove the residual water
                    rr = rr-1;
                end
            end
            raw_mm     = raw_temp_mm;
            raw_mm     = op_fddccorr(raw_mm,100);                                     % Correct back to baseline
        end

        %%% 6. REFERENCE SPECTRUM CORRECTLY TO FREQUENCY AXIS AND PHASE SIEMENS
        %%% DATA
        [refShift, ~] = osp_CrChoReferencing(raw);
        [raw]             = op_freqshift(raw,-refShift);            % Reference spectra by cross-correlation     
        
        if MRSCont.flags.hasMM %re_mm
            [refShift_mm, ~] = fit_OspreyReferencingMM(raw_mm);
            [raw_mm]             = op_freqshift(raw_mm,-refShift_mm);            % Reference spectra by cross-correlation
            MRSCont.processed.mm{kk}       = raw_mm;                          % Save back to MRSCont container  %re_mm
        end

        
        % Save back to MRSCont container
        if strcmp(MRSCont.vendor,'Siemens')
            % Fit a double-Lorentzian to the Cr-Cho area, and phase the spectrum
            % with the negative phase of that fit
            [raw,globalPhase]       = op_phaseCrCho(raw, 1);
            raw.specReg.phs = raw.specReg.phs - globalPhase*180/pi;
        end
        MRSCont.processed.A{kk}     = raw;


        %%% 7. GET SHORT-TE WATER DATA %%%
        if MRSCont.flags.hasWater
            raw_w                           = MRSCont.raw_w{kk};                % Get the kk-th dataset
            if raw_w.averages > 1 && raw_w.flags.averaged == 0
                [raw_w,~,~]                 = op_alignAverages(raw_w, 1, 'n');
                raw_w                       = op_averaging(raw_w);              % Average
            else
                raw_w.flags.averaged    = 1;
                raw_w.dims.averages     = 0;
            end
            [raw_w,~]                       = op_eccKlose(raw_w, raw_w);        % Klose eddy current correction
            [raw_w,~]                       = op_ppmref(raw_w,4.6,4.8,4.68);    % Reference to water @ 4.68 ppm
            MRSCont.processed.w{kk}         = raw_w; % Save back to MRSCont container
        end


        %%% 8. QUALITY CONTROL PARAMETERS %%%
        % Calculate some spectral quality metrics here;
        MRSCont.QM.SNR.A(kk)    = op_getSNR(MRSCont.processed.A{kk}); % NAA amplitude over noise floor
        FWHM_Hz                 = op_getLW(MRSCont.processed.A{kk},1.8,2.2); % in Hz
        MRSCont.QM.FWHM.A(kk)   = FWHM_Hz./MRSCont.processed.A{kk}.txfrq*1e6; % convert to ppm
        MRSCont.QM.drift.pre.A{kk}  = driftPre;
        MRSCont.QM.drift.post.A{kk} = driftPost;
        MRSCont.QM.freqShift.A(kk)  = refShift;
        MRSCont.QM.drift.pre.AvgDeltaCr.A(kk) = mean(driftPre - 3.02);
        MRSCont.QM.drift.post.AvgDeltaCr.A(kk) = mean(driftPost - 3.02);
        if MRSCont.flags.hasMM
            MRSCont.QM.SNR.mm(kk)    = op_getSNR(MRSCont.processed.mm{kk},0.7,1.1); % water amplitude over noise floor
            FWHM_Hz                 = op_getLW(MRSCont.processed.mm{kk},0.7,1.1); % in Hz
            MRSCont.QM.FWHM.mm(kk)   = FWHM_Hz./MRSCont.processed.mm{kk}.txfrq*1e6; % convert to ppm
        end
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

%%% 9. SET FLAGS %%%
MRSCont.flags.avgsAligned       = 1;
MRSCont.flags.averaged          = 1;
MRSCont.flags.ECCed             = 1;
MRSCont.flags.waterRemoved      = 1;
MRSCont.runtime.Proc = time;
% Close any remaining open figures
close all;

end
