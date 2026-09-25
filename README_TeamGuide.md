# ChakshuAI — Explainable AI for Diabetic Retinopathy Screening
**SIH 2026 | Problem Statement: SIH26038**  
**Sponsored by MathWorks**

A complete MATLAB-based screening pipeline designed for rural India.  
It grades diabetic retinopathy severity (0–4), detects clinically relevant lesions, generates Grad-CAM explanations, and produces a doctor-readable report — all from a single fundus image.

---

## Pipeline Overview

| Module | File | Responsibility |
|--------|------|----------------|
| 1. Quality Gate | `checkImageQuality.m` | Rejects blurry / poorly framed images; enhances borderline ones |
| 2. Structure Segmentation | `segmentStructures.m` | Vessels, optic disc, microaneurysms, hemorrhages, exudates |
| 3. DR Grading | `gradeDR.m` | 5-class severity (0–4) + confidence + referable flag |
| 4. Explainability | `explainResult.m` | Grad-CAM heatmap + clinical-style report |
| 5. Integration | `runPipeline.m` | End-to-end orchestration |
| Frontend | `retinaScreeningApp.m` | Simple, responsive App Designer GUI |

**Referable DR** is defined as Grade ≥ 2 (Moderate, Severe, or Proliferative).

---

## Quick Start

### 1. One-time setup
```matlab
setupProjectFolders   % creates data/train/0…4, models/, sample_images/
2. Prepare training data
Sort fundus images into the five grade folders:
textdata/train/0/   → No DR
data/train/1/   → Mild
data/train/2/   → Moderate
data/train/3/   → Severe
data/train/4/   → Proliferative
Helper scripts are included:

sortIDRiDDataset.m
sortAPTOSDataset.m

3. Train the model
matlabtrainDRModel

Uses transfer learning (ResNet-18) when available, otherwise a custom CNN.
Applies class weighting + referable-DR boost to hit the problem-statement targets (>90% sensitivity, >85% specificity).
Saves models/dr_model.mat.

4. Test the full pipeline
matlab% Single image
result = runPipeline('path/to/image.jpg');

% Batch test on sample_images/
testPipeline
5. Launch the GUI
matlabretinaScreeningApp

Key Features

Quality-first design — rejects unusable images with clear guidance for the operator.
Adaptive lesion detection — thresholds are computed per-image (mean + k·std) so the system is robust across different cameras and lighting conditions.
Explainable output — Grad-CAM heatmap + structured clinical report that counts lesions and states the referral recommendation.
Referable vs Non-referable metric — the primary evaluation target matches the SIH problem statement.
District rollout model — Simulink model (DistrictRolloutModel.slx) for planning screening campaigns.


Project Structure
text├── checkImageQuality.m
├── segmentStructures.m
├── gradeDR.m
├── explainResult.m
├── runPipeline.m
├── retinaScreeningApp.m
├── trainDRModel.m
├── loadTrainedModel.m
├── testPipeline.m
├── setupProjectFolders.m
├── sortIDRiDDataset.m / sortAPTOSDataset.m
├── calibrateLesionThresholds.m / calibrateSharpness.m
├── evalLesionDetection.m / evalVesselSegmentation.m
├── createDistrictRolloutModel.m
├── DistrictRolloutModel.slx
├── SIH26038.prj
└── README.md

Requirements

MATLAB R2023b or later (recommended)
Image Processing Toolbox
Deep Learning Toolbox
(Optional) Pretrained Networks support package for ResNet-18 transfer learning
(Optional) Statistics and Machine Learning Toolbox for ROC/AUC


Evaluation Targets (SIH26038)

MetricTargetSensitivity (Referable DR)> 90%Specificity (Referable DR)> 85%ExplainabilityGrad-CAM + lesion-level report

