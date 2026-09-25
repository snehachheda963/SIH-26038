# SIH26038 — Project Starter Kit (dataset-ready)

## What's in this folder

| File | Purpose |
|---|---|
| `setupProjectFolders.m` | Run once — creates the exact folders the code expects |
| `checkImageQuality.m` | Module 1 — image quality check + enhancement |
| `segmentStructures.m` | Module 2 — vessel/lesion/optic disc segmentation |
| `gradeDR.m` | Module 3 — DR severity classification (0-4) |
| `explainResult.m` | Module 4 — Grad-CAM heatmap + report text |
| `runPipeline.m` | Runs Modules 1-4 in order on a single image |
| `loadTrainedModel.m` | Helper — loads the trained model from disk (used by gradeDR.m and explainResult.m) |
| `trainDRModel.m` | Trains the classifier once your dataset is sorted into folders |
| `testPipeline.m` | Runs the full pipeline on every image in `sample_images/` at once |

## Right now (before you have a dataset)

1. Put all these files in one project folder in MATLAB.
2. Run `setupProjectFolders.m` once — it creates:
   ```
   data/train/0/   data/train/1/   data/train/2/   data/train/3/   data/train/4/
   models/
   sample_images/
   ```
3. Everything else already runs safely without any data — `gradeDR.m` and
   `explainResult.m` automatically detect that no trained model exists yet
   (via `loadTrainedModel.m`) and return placeholder results instead of crashing.
4. You can keep coding/testing the TODOs inside `checkImageQuality.m` and
   `segmentStructures.m` right now — they don't need the classifier to be trained.

## The moment your dataset is ready

1. Sort images by DR grade into `data/train/0` ... `data/train/4`
   (0 = No DR, 1 = Mild, 2 = Moderate, 3 = Severe, 4 = Proliferative).
   - APTOS2019 and IDRiD both come with a CSV telling you the grade per image —
     write a tiny script to copy each image into the right numbered folder based
     on that CSV (ask for this script when you're ready — it's a 10-line job).
2. Drop 3-5 separate test images into `sample_images/` (images not used for training).
3. Run `trainDRModel.m`. This trains a ResNet-18 on your data and saves the result
   to `models/dr_model.mat`. Takes anywhere from a few minutes to a couple of hours
   depending on dataset size and whether you have a GPU (MATLAB uses it automatically
   if available).
4. Run `testPipeline.m`. It automatically picks up the newly trained model
   (no code changes needed anywhere), runs the full pipeline on every image in
   `sample_images/`, shows the heatmaps, and saves a results table to
   `pipeline_test_results.csv`.

That's the whole "upload data then run" flow — nothing else in the code needs to
change when the dataset arrives.
