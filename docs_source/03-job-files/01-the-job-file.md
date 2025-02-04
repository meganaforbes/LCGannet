# The Osprey job file

Every **Osprey** analysis requires the user to provide a job file. The **Osprey** job file is the only direct point of contact between the user and the analysis. It contains paths to MRS data files and structural images, defines processing and modelling options, and determines whether (and where) output files are being saved.

The job file system ensures that all processing, modeling, and quantification steps are performed in an operator-independent, reproducible way.

## Example job file

The following collapsible box contains the [example job file `jobSDAT.m`](https://github.com/schorschinho/osprey/blob/develop/exampledata/sdat/jobSDAT.m) defining a batched analysis of the two Philips PRESS (TE = 30 ms) datasets that are included in the `exampledata/sdat/` directory of the [**Osprey** repository](https://github.com/schorschinho/osprey). You can click on the dropdown arrow on the right to take a look through the file, and then read on for a detailed description of each job file item.

??? note "Example job file `jobSDAT.m`:"
    ```matlab
    %% jobSDAT.m
    %   This function describes an Osprey job defined in a MATLAB script.
    %
    %   A valid Osprey job contains four distinct classes of items:
    %       1. basic information on the MRS sequence used
    %       2. several settings for data handling and modeling
    %       3. a list of MRS (and, optionally, structural imaging) data files
    %          to be loaded
    %       4. an output folder to store the results and exported files
    %
    %   The list of MRS and structural imaging files is provided in the form of
    %   cell arrays. They can simply be provided explicitly, or from a more
    %   complex script that automatically determines file names from a given
    %   folder structure.
    %
    %   Osprey distinguishes between four sets of data:
    %       - metabolite (water-suppressed) data
    %           (MANDATORY)
    %           Defined in cell array "files"
    %       - water reference data acquired with the SAME sequence as the
    %           metabolite data, just without water suppression RF pulses. This
    %           data is used to determine complex coil combination
    %           coefficients, and perform eddy current correction.
    %           (OPTIONAL)
    %           Defined in cell array "files_ref"
    %       - additional water data used for water-scaled quantification,
    %           usually from short-TE acquisitions due to reduced T2-weighting
    %           (OPTIONAL)
    %           Defined in cell array "files_w"
    %       - Structural image data used for co-registration and tissue class
    %           segmentation (usually a T1 MPRAGE). These files need to be
    %           provided in the NIfTI format (*.nii) or, for GE data, as a
    %           folder containing DICOM Files (*.dcm).
    %           (OPTIONAL)
    %           Defined in cell array "files_nii"
    %
    %   Files in the formats
    %       - .7 (GE)
    %       - .SDAT, .DATA/.LIST, .RAW/.SIN/.LAB (Philips)
    %       - .DAT (Siemens)
    %   usually contain all of the acquired data in a single file per scan. GE
    %   systems store water reference data in the same .7 file, so there is no
    %   need to specify it separately under files_ref.
    %
    %   Files in the formats
    %       - .DCM (any)
    %       - .IMA, .RDA (Siemens)
    %   may contain separate files for each average. Instead of providing
    %   individual file names, please specify folders. Metabolite data, water
    %   reference data, and water data need to be located in separate folders.
    %
    %   In the example script at hand the MATLAB functions strrep and which are
    %   used to generate a relative path, which allows you to run the examples
    %   on your machine directly. To set up your own Osprey job supply the
    %   specific locations as described above.
    %
    %   AUTHOR:
    %       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-07-15)
    %       goeltzs1@jhmi.edu
    %   
    %   HISTORY:
    %       2019-07-15: First version of the code.



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% 1. SPECIFY SEQUENCE INFORMATION %%%

    % Specify sequence type
    seqType = 'unedited';           % OPTIONS:    - 'unedited' (default)
                                    %             - 'MEGA'
                                    %             - 'HERMES'
                                    %             - 'HERCULES'

    % Specify editing targets
    editTarget = {'none'};            % OPTIONS:    - {'none'} (default if 'unedited')
                                    %             - {'GABA'}, {'GSH'}  (for 'MEGA')
                                    %             - {'GABA, 'GSH}, {'GABA, GSH, EtOH'} (for 'HERMES')
                                    %             - {'HERCULES1'}, {'HERCULES2'} (for 'HERCULES')

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% 2. SPECIFY DATA HANDLING AND MODELING OPTIONS %%%

    % Save LCModel-exportable files for each spectrum?
    opts.saveLCM                = 1;                % OPTIONS:    - 0 (no, default)
                                                    %             - 1 (yes)
    % Save jMRUI-exportable files for each spectrum?
    opts.saveJMRUI              = 1;                % OPTIONS:    - 0 (no, default)
                                                    %             - 1 (yes)

    % Save processed spectra in vendor-specific format (SDAT/SPAR, RDA, P)?
    opts.saveVendor             = 1;                % OPTIONS:    - 0 (no, default)
                                                    %             - 1 (yes)

    % Choose the fitting algorithm
    opts.fit.method             = 'Osprey';       % OPTIONS:    - 'Osprey' (default)
                                                    %           - 'AQSES' (planned)
                                                    %           - 'TARQUIN' (planned)

    % Choose the fitting style for difference-edited datasets (MEGA, HERMES, HERCULES)
    % (only available for the Osprey fitting method)
    opts.fit.style              = 'Concatenated';   % OPTIONS:  - 'Concatenated' (default) - will fit DIFF and SUM simultaneously)
                                                    %           - 'Separate' - will fit DIFF and OFF separately

    % Determine fitting range (in ppm) for the metabolite and water spectra
    opts.fit.range              = [0.2 4.2];        % [ppm] Default: [0.2 4.2]
    opts.fit.rangeWater         = [2.0 7.4];        % [ppm] Default: [2.0 7.4]

    % Determine the baseline knot spacing (in ppm) for the metabolite spectra
    opts.fit.bLineKnotSpace     = 0.4;              % [ppm] Default: 0.4.

    % Add macromolecule and lipid basis functions to the fit?
    opts.fit.fitMM              = 1;                % OPTIONS:    - 0 (no)
                                                    %             - 1 (yes, default)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% 3. SPECIFY MRS DATA AND STRUCTURAL IMAGING FILES %%
    % When using single-average Siemens RDA or DICOM files, specify their
    % folders instead of single files!

    % Specify metabolite data
    % (MANDATORY)
    files       = {which('exampledata/sdat/sub-01/mrs/sub-01_press/sub-01_PRESS_35_act.sdat'),...
                   which('exampledata/sdat/sub-02/mrs/sub-02_press/sub-02_PRESS_35_act.sdat')};

    % Specify water reference data for eddy-current correction (same sequence as metabolite data!)
    % (OPTIONAL)
    % Leave empty for GE P-files (.7) - these include water reference data by
    % default.
    files_ref   = {which('exampledata/sdat/sub-01/mrs/sub-01_press-ref/sub-01_PRESS_35_ref.sdat'),...
                   which('exampledata/sdat/sub-02/mrs/sub-02_press-ref/sub-02_PRESS_35_ref.sdat')};

    % Specify water data for quantification (e.g. short-TE water scan)
    % (OPTIONAL)
    files_w     = {which('exampledata/sdat/sub-01/mrs/sub-01_press-ref/sub-01_PRESS_35_ref.sdat'),...
                   which('exampledata/sdat/sub-02/mrs/sub-02_press-ref/sub-02_PRESS_35_ref.sdat')};

    % Specify T1-weighted structural imaging data
    % (OPTIONAL)
    % Link to single NIfTI (*.nii) files for Siemens and Philips data
    % Link to DICOM (*.dcm) folders for GE data
    files_nii   = {which('exampledata/sdat/sub-01/anat/sub-01_T1w.nii'),...
                   which('exampledata/sdat/sub-02/anat/sub-02_T1w.nii')};

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% 4. SPECIFY OUTPUT FOLDER %%
    % The Osprey data container will be saved as a *.mat file in the output
    % folder that you specify below. In addition, any exported files (for use
    % with jMRUI, TARQUIN, or LCModel) will be saved in sub-folders.

    % Specify output folder
    % (MANDATORY)
    outputFolder = strrep(which('exampledata/sdat/jobSDAT.m'),'jobSDAT.m','derivatives');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ```

### 1. Sequence Information

In this section of the job file, you determine basic information on the type of sequence you used.

#### Sequence Type

!!! info "MANDATORY"
    The `seqType` variable is a describes the sequence type, and is a required input in the form of a string.
    `seqType` determines whether the supplied datasets have been acquired with spectral editing experiments.

```matlab
% Specify sequence type
seqType = 'unedited';           % OPTIONS:    - 'unedited' (default)
                                %             - 'MEGA'
                                %             - 'HERMES'
                                %             - 'HERCULES'
```

#### Editing Targets

!!! info "MANDATORY"
    The `editTarget` variable describes the sequence type, and is a required input in the form of a cell array.
    `editTarget` determines the target spin system(s) of spectral editing experiments. If no spectral editing has been performed, enter `{'none'}`.

```matlab
% Specify editing targets
editTarget = {'none'};          % OPTIONS:    - {'none'} (default if 'unedited')
                                %             - {'GABA'}, {'GSH'}  (for 'MEGA')
                                %             - {'GABA, 'GSH}, {'GABA, GSH, EtOH'} (for 'HERMES')
                                %             - {'HERCULES1'}, {'HERCULES2'} (for 'HERCULES')
```

### 2. Data handling and modeling options

In this section of the job file, you provide information on whether you would like to save the processed data in externally usable file formats (for example, if you want to interface your analysis with LCModel), and specify options for the modelling.

#### Saving data to external formats

!!! info "OPTIONAL"
    The `opts.save` variable set determines whether **Osprey** saves the processed data in formats that can be interfaced with external analysis software.

    By setting `opts.saveLCM` to `1`, LCModel-readable `.RAW` files are produced.

    By setting `opts.saveJMRUI` to `1`, jMRUI/Tarquin-readable `.TXT` files are produced.

    By setting `opts.saveVendor` to `1`, single vendor-specific files are created, i.e. `.SDAT/.SPAR` files for Philips data, and `.RDA` files for Siemens data, regardless of the raw data format.

```matlab
% Save LCModel-exportable files for each spectrum?
opts.saveLCM                = 1;                % OPTIONS:    - 0 (no, default)
                                                %             - 1 (yes)
% Save jMRUI-exportable files for each spectrum?
opts.saveJMRUI              = 1;                % OPTIONS:    - 0 (no, default)
                                                %             - 1 (yes)

% Save processed spectra in vendor-specific format (SDAT/SPAR, RDA, P)?
opts.saveVendor             = 1;                % OPTIONS:    - 0 (no, default)
                                                %             - 1 (yes)
```

LCModel `.RAW` files can be loaded via the `Other` option in the LCModel file type selection menu.

Please be aware that LCModel may prompt you to enter the number of FID data points (a positive integer number, e.g. `2048`), dwell time (in seconds, e.g. `0.0005`), and the static magnetic field strength in MHz (e.g. `123.26` for a Siemens 2.89 T magnet).

In addition to the `.RAW` files, Osprey also creates the corresponding  `.CONTROL` files. These files can be used for LCModel batch processing.

```
for file in /storage/LCModelControlFiles/*;
do /usr/local/.lcmodel/bin/lcmodel < $file;
done 
```

!!! info "MANDATORY"
    To create working `.CONTROL` files you have to specify the following mandatory variables in the `osp_lcmcontrol_params()` function located in the process folder: `key`, `FILBAS`, `FOLDER`, and `DOECC`. 
    
```
key = 0; %Your LCM key goes here
FILBAS = '/storage/myBasisSet_30ms_PRESS.BASIS'; % Location of .BASIS file used in LCModel
FOLDER = '/storage/LCMoutput'; %Output folder (Create this on your linux machine first)
DOECC= 'F'; % No eddy current correction in LCModel as this is already performed in Osprey.
```
    
!!! info "OPTIONAL"
    The other parameters are optional and are described in the `osp_lcmcontrol_params()` function.

When loading `.TXT` files with Tarquin, you will probably need to enter the echo time in seconds (e.g. `0.03` for a `TE = 30 ms` acquisition).

The `opts.saveVendor` switch has been introduced to sidestep these problems with `.RAW` and `.TXT` files. LCModel, TARQUIN and jMRUI accept the `.SDAT/.SPAR` and `.RDA` file formats, and should be able to read the header information correctly.

All exported third-party format files are stored in sub-directories of the output folder specified further down in the job file.

#### Specifying fitting options

!!! info "MANDATORY"
    The `opts.fit.method` variable set determines the modelling algorithm used to fit the processed spectra.

    Currently, the only available option is the default **Osprey** model. We are planning to implement other algorithms in the future.

```matlab
% Choose the fitting algorithm
opts.fit.method             = 'Osprey';       % OPTIONS:  - 'Osprey' (default)
                                              %           - 'AQSES' (planned)
                                              %           - 'TARQUIN' (planned)
```

!!! info "MANDATORY"
    The `opts.fit.style` variable set determines how difference-edited data are modeled.

    By setting `opts.fit.style` to `Concatenated`, the difference and sum spectra in MEGA, HERMES and HERCULES datasets will be modeled simultaneously, i.e. with common metabolite amplitude parameters across these spectra.

    By setting `opts.fit.style` to `Separate`, the difference and edit-OFF spectra in MEGA, HERMES and HERCULES datasets will be modeled independently. In this case, the creatine reference signal will be determined from the edit-OFF spectrum.

```matlab
% Choose the fitting style for difference-edited datasets (MEGA, HERMES, HERCULES)
% (only available for the Osprey fitting method)
opts.fit.style              = 'Concatenated';   % OPTIONS:  - 'Concatenated' (default) - will fit DIFF and SUM simultaneously)
                                                %           - 'Separate' - will fit DIFF and OFF separately
```

!!! info "MANDATORY"
    The `opts.fit.range` and  `opts.fit.rangeWater` variables determine the fitting range (in ppm) of the metabolite and water spectra, respectively.

```matlab    
% Determine fitting range (in ppm) for the metabolite and water spectra
opts.fit.range              = [0.2 4.2];        % [ppm] Default: [0.2 4.2]
opts.fit.rangeWater         = [2.0 7.4];        % [ppm] Default: [2.0 7.4]
```

!!! info "MANDATORY"
    The `opts.fit.bLineKnotSpace` variable determines the spacing (in ppm) between two adjacent knots of the cubic B-spline baseline. This parameter is equivalent to the `DKNTMN` parameter in LCModel.

    Higher values correspond to a stiffer baseline, while lower values will produce a larger number of spline knots, allowing for greater flexibility of the baseline.

```matlab
% Determine the baseline knot spacing (in ppm) for the metabolite spectra
opts.fit.bLineKnotSpace     = 0.4;              % [ppm] Default: 0.4.
```

Choosing lower values for the `bLineKnotSpace` variable will improve the fit quality at the expense of overparametrization of the model. LCModel uses a default knot spacing of `DKNTMN = 0.15`, i.e. 0.15 ppm, which likely allows too much flexibility. In the absence of baseline regularization in the current stage of the **Osprey** model development, we chose to restrict baseline flexibility by opting for a default value of 0.4 ppm.

!!! info "MANDATORY"
    The `opts.fit.fitMM` variable determines whether simulated Gaussian signals representing broad macromolecular and lipid signals are included in the basis set.

    By default, **Osprey** includes these basis functions. If you want to use an experimentally measured MM/lipid basis function, or operate at long echo times where the MM and lipid resonances have decayed, you can set `opts.fit.fitMM = 0` to exclude them.

```matlab
% Add macromolecule and lipid basis functions to the fit?
opts.fit.fitMM              = 1;                % OPTIONS:    - 0 (no)
                                                %             - 1 (yes, default)
```

### 3. Specifying MRS data and structural imaging files

In this section of the job file, you specify the full paths to the MRS data and structural imaging files that you would like to process and analyze.

**Osprey** is designed for the batch analysis of multiple datasets in one session. Each dataset corresponds to an element of a cell array. The cell arrays for metabolite data, water reference data, short-TE water data, and structural imaging files need to have the same number of elements. For example, if you have MRS data from two voxels in the same subject, you need to enter the path to the `.NII` structural twice into the `files_nii` cell array.

At the current stage of implementation, you can only analyze one type of sequence per job file, i.e. if you have MEGA-PRESS and PRESS data for each subject, you will have to design two separate job files for MEGA-PRESS and PRESS data.

#### Metabolite data

!!! info "MANDATORY"
    The `files` variable is defined as a cell array of full paths to the raw MRS data files containing your metabolite (water-suppressed) data.

```matlab
% Specify metabolite data
% (MANDATORY)
files       = {which('exampledata/sdat/sub-01/mrs/sub-01_press/sub-01_PRESS_35_act.sdat'),...
               which('exampledata/sdat/sub-02/mrs/sub-02_press/sub-02_PRESS_35_act.sdat')};
```

In the job files in the `exampledata` folder of the **Osprey** repository, the `which` function ensures that the paths are correctly defined regardless of where you put your **Osprey** folder. When designing your own job file, you will have to provide the full paths to your raw data, e.g.:

```matlab
% Specify metabolite data
% (MANDATORY)
files       = {'/Users/Georg/Documents/MRSData/study-01/sub-01/mrs/sub-01_press/sub-01_PRESS_35_act.sdat',...
               '/Users/Georg/Documents/MRSData/study-01/sub-02/mrs/sub-02_press/sub-02_PRESS_35_act.sdat',};
```

Instead of writing out the full paths explicitly, you can also create a procedure that is tailored to your local file organization, as long as you end up with a `files` cell array containing an element for each file you want to analyze.

!!! warning "Single-average DICOM and Siemens RDA datasets"
    MRS raw data can be exported in DICOM and Siemens RDA format, where each average is saved as a separate `.DCM` or `.RDA` file. In this case, you have to enter the full path to the **folder** containing all single-average files belong to **one acquisition**.

    Please refer to the [data organization chapter](/01-getting-started/03-organize-data/) of this documentation for best practices on creating a useful folder structure for your raw data.

#### Lineshape reference data

!!! info "OPTIONAL"
    The `files_ref` variable is defined as a cell array of full paths to the raw MRS data files to your lineshape (water-unsuppressed) reference data.

    These are an optional input, acquired with the same sequence as the metabolite data, but without water suppression, and used to perform eddy-current correction of the metabolite data.

```matlab    
% Specify water reference data for eddy-current correction (same sequence as metabolite data!)
% (OPTIONAL)
% Leave empty for GE P-files (.7) - these include water reference data by
% default.
files_ref   = {which('exampledata/sdat/sub-01/mrs/sub-01_press-ref/sub-01_PRESS_35_ref.sdat'),...
               which('exampledata/sdat/sub-02/mrs/sub-02_press-ref/sub-02_PRESS_35_ref.sdat')};
```

If only lineshape reference data are provided, this signal is also used to calculate water-scaled concentration estimates.

#### Short-TE water data

!!! info "OPTIONAL"
    The `files_w` variable is defined as a cell array of full paths to the raw MRS data files to short-TE water data.

    These are another optional input, and can be used to derive water-scaled concentration estimates (while lineshape reference data are only used for eddy-current correction). Using short-TE water as the concentration reference standard reduces T2-weighting of the water reference signal (and associated correction errors) compared to long-TE water data.

```matlab     
% Specify water data for quantification (e.g. short-TE water scan)
% (OPTIONAL)
files_w     = {which('exampledata/sdat/sub-01/mrs/sub-01_press-ref/sub-01_PRESS_35_ref.sdat'),...
               which('exampledata/sdat/sub-02/mrs/sub-02_press-ref/sub-02_PRESS_35_ref.sdat')};
```

#### Structural images

!!! info "OPTIONAL"
    The `files_nii` variable is defined as a cell array of full paths to T1-weighted structural images used for co-registration and segmentation purposes.

    **Osprey** requires NIfTI (`.nii`) files to be supplied. For GE files, you may also provide the full path to a directory containing the DICOM folders corresponding to the T1 acquisition.

```matlab
% Specify T1-weighted structural imaging data
% (OPTIONAL)
% Link to single NIfTI (.nii) files for Siemens and Philips data
% Link to DICOM (.dcm) folders for GE data
files_nii   = {which('exampledata/sdat/sub-01/anat/sub-01_T1w.nii'),...
               which('exampledata/sdat/sub-02/anat/sub-02_T1w.nii')};
```

**Osprey** uses **SPM12** functions to load and process structural images. Please refer to the [installation instructions](/01-getting-started/02-installing-osprey/) for information on how to set up SPM12.

### 4. Specifying the output folder

In this section of the job file, you specify the full paths to an output folder where the **Osprey** data container is saved in `.mat` format. In addition, any exported files (for use with jMRUI, TARQUIN, or LCModel) will be saved in separate sub-folders of the output folder.

!!! info "MANDATORY"
    The `outputFolder` variable specifies a full path to the output folder.

    If the output folder does not exist yet, it will be created.

```matlab
% Specify output folder
% (MANDATORY)
outputFolder = strrep(which('exampledata/sdat/jobSDAT.m'),'jobSDAT.m','derivatives');
```

In the job files in the `example` folder of the **Osprey** repository, the `which` and `strrep` functions ensures that an output folder `derivatives` in the folder where the job file `jobSDAT` resides. When designing your own job file, you will have to provide the full path to your desired output folder.

Note that **Osprey** detects if the output folder already exists and contains data from a previous analysis. In this case, you will be prompted whether you would like to overwrite the existing output.
