# Neurorobotics - Assignment 1: Motor Imagery BCI Pipeline

## Project Overview

This repository contains the MATLAB implementation for the first assignment of the Neurorobotics course (2025/2026). The project focuses on the analysis of Electroencephalography (EEG) data collected from 8 healthy subjects during a Motor Imagery (MI) Brain-Computer Interface (BCI) experiment.

The objective is to develop a complete processing pipeline to classify two distinct motor imagery tasks: **Both Hands** vs **Both Feet**. The pipeline includes data organisation, signal preprocessing, feature extraction, classifier training, online evaluation, and metrics visualisation.

## Repository Structure

The project is organised into a modular structure to ensure flexibility and maintainability.

```bash
/
├── main.m                         # Entry point of the pipeline. Orchestrates all phases.
├── src/                           # Source code for all processing functions.
│   ├── organize_dataset.m         # Sorts raw GDF files into Subject/Run-type folders.
│   ├── convert_gdf2mat.m          # Converts GDF files to MATLAB format.
│   ├── compute_psd.m              # Computes Power Spectral Density (PSD) and Spectrograms.
│   ├── compute_stats.m            # Computes ERD, Fisher score and Lateralization
│   ├── extract_trials.m           # Segments full trials (Fixation to Feedback).
│   ├── select_features.m          # Feature selection using Fisher Score.
│   ├── train_classifier.m         # Trains the LDA classifier on offline data.
│   ├── test_classifier.m          # Evaluates the model on online data (Evidence Accumulation).
│   ├── visualize_erd_ers.m        # Generates Time-Frequency maps for single subjects.
│   ├── analyze_eeg.m              # Computes global band power (Mu/Beta) per channel.
│   ├── print_metrics.m            # Prints the Grand Average metrics.
│   ├── preprocessing.m            # Extracts trials and compute the 4D activity matrix.
│   ├── visualize_features.m       # Generate images of the preprocessed data.
│   └── get_config.m               # Centralised configuration (paths, constants, parameters).
├── data/                          # Data storage (excluded from version control).
│   ├── downloads/                 # Place raw GDF files here.
│   ├── raw/                       # Automatically structured raw data.
│   └── preprocessed/              # Intermediate Activity matrices.
└── results/                       # Output figures, trained models, and evaluation metrics.
```

## Prerequisites

**BioSig Toolbox:** Required for reading GDF files (`sload` function). Please ensure BioSig is installed and added to your MATLAB path.
**EEGLAB:** Required for generating topographic plots (`topoplot` function). Please ensure it is installed and added to your MATLAB path.

## Installation and Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/MicheleBrigandi/neurorobotics-first-assignment.git
   cd neurorobotics-first-assignment
   ```
2. **Download the dataset:** Download the dataset folder and place it into the `data` folder (if not present, create it). Rename the dataset folder as `downloads`.

3. **Configure BioSig:** Ensure the BioSig toolbox is in your MATLAB path to allow GDF reading.

4. **Configure EEGLAB:** Ensure the EEGLAB toolbox is in your MATLAB path to allow topographic plotting.

## Usage

The entire analysis is controlled via the `main.m` script. We have implemented a flag-based system to selectively run specific parts of the pipeline without re-computing previous steps.

1. Open `main.m` in MATLAB.

2. Adjust the **Control Flags** section at the top of the script according to your needs:

   ```Matlab
   %% CONTROL FLAGS
   DO_SETUP    = true;  % Organize raw files
   DO_PREPROC  = true;  % Convert and extract trials
   DO_ANALYSIS = true;  % Compute stats & visualization
   DO_TRAINING = true;  % Train LDA model
   DO_TESTING  = true;  % Test on online data
   ```

3. Run the script.

4. Results (figures and `.mat` files) will be generated in the `results` directory, organised by subject ID.

## Pipeline Description

### 1. Data Organisation & Preprocessing

The raw data is first sorted into a structured hierarchy (`raw/SubjectID/offline` and `raw/SubjectID/online`).

- **Laplacian Filter:** A spatial Laplacian filter (16 channels) is applied to each individual recording to enhance the signal-to-noise ratio.

- **PSD Computation:** Power Spectral Density is computed independently for every file using a sliding window spectrogram (Window: 0.5s, Shift: 0.0625s).

- **Trial Extraction and Concatenation:** Trials are segmented from the **Fixation Cross** to the end of the **Continuous Feedback**. Finally, all trials from the same session (offline/online) are concatenated into a single matrix per subject to be used in the training and evaluation parts.

### 2. Model Calibration (Offline)

- **Feature Selection:** The Fisher Score algorithm is used to select the top discriminant features (Frequency-Channel pairs) from the offline runs.

- **Classification:** A Linear Discriminant Analysis (LDA) classifier is trained on the selected features.

### 3. Evaluation (Online)

The trained model is tested on the online runs. We implemented an **Evidence Accumulation Framework** to smooth the posterior probabilities over time, simulating the real-time control strategy used during the experiment. Metrics reported include:

- Single Sample Accuracy.
- Trial Accuracy.
- Average Latency (Time to Command).
- Cohen's Kappa.

### 4. Visualisation

- **Single Subject:**

  - **ERD/ERS Maps:** Time-Frequency maps are generated for C3, Cz, and C4 to analyse the desynchronisation in the Mu/Beta bands.
  - **Global Band Power:** A global spectral analysis is computed to visualise the power distribution across all channels, identifying the regions with the strongest activity in the Mu (8-13 Hz) and Beta (13-30 Hz) bands.
  - **Topoplot:** Topoplot visualization of both hands ERD, feet ERD, and Fisher score
  - **Spectrogram:** Spectrogram of the fisher score results.
  - **Training Results:** Training accuracy bars and training confusion matrix.

- **Grand Average:** A population-level analysis is performed by aligning and averaging the ERD curves of all subjects to identify common neurophysiological patterns. Three topoplot images are also created representing the avg feet ERD, hands ERD and Fisher score

## Configuration

All global parameters are centralised in `src/get_config.m`. You can modify this file to change:

- Frequency bands (Mu/Beta).
- Spectrogram window settings.
- Number of features to select.
- Channel mapping and event codes.
