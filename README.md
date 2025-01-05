# Hydrocarbon Classification Using H2O

## Overview
This R script trains a machine learning model to classify samples as hydrocarbon-positive or hydrocarbon-negative based on ASV (amplicon sequence variant) data. It leverages the H2O AutoML library to test multiple algorithms and select the best-performing model based on metrics such as AUC-PR.

The pipeline is structured for genus-level classification but can be adapted for other taxonomic levels (e.g., family, order) with minor modifications. 

## Requirements
- R version >= 4.0
- R packages: `tidyverse`, `readxl`, `h2o`
- Two input Excel files:
  1. **ASV Taxonomic Table**
  2. **Metadata Table**

## Input File Structure

### 1. ASV Taxonomic Table
This table should include:
- **Columns**:
  - `ASVID`: Unique identifier for each ASV (can be excluded for downstream analysis).
  - `Domain`, `Phylum`, `Class`, `Order`, `Family`, `Genus`: Taxonomic annotations for each ASV.
  - Remaining columns: Sample names with corresponding read counts for each ASV.

| ASVID | Domain    | Phylum      | Class      | Order      | Family      | Genus      | Sample1 | Sample2 | ... |
|-------|-----------|-------------|------------|------------|-------------|------------|---------|---------|-----|
| ASV1  | Bacteria  | Proteobacteria | Gammaproteobacteria | Pseudomonadales | Pseudomonadaceae | Pseudomonas | 120     | 90      | ... |
| ASV2  | Bacteria  | Firmicutes  | Bacilli    | Bacillales | Bacillaceae | Bacillus   | 200     | 150     | ... |

### 2. Metadata Table
This table should include:
- **Columns**:
  - `Sample`: Names of the samples (must match the sample columns in the ASV Taxonomic Table).
  - `Gas`: Binary classification target indicating hydrocarbon-positive (`1`) or hydrocarbon-negative (`0`) samples.

| Sample  | Gas |
|---------|-----|
| Sample1 | 1   |
| Sample2 | 0   |
| Sample3 | 1   |

## Script Features
- **Data Validation**: Ensures sample consistency between ASV and metadata tables.
- **Filtering**: Removes ASVs with low read counts or prevalence.
- **Normalization**: Converts raw counts to relative abundances.
- **Genus Aggregation**: Aggregates read counts at the genus level.
- **H2O AutoML**: Automatically selects the best-performing model.
- **Output**:
  - Leaderboard of tested models.
  - Variable importance plot.
  - Predictions for the training dataset.
  - Saved model for future use.

## Modifying for Other Taxonomic Levels
To adapt the script for other levels (e.g., `Family`, `Order`):
1. **Change the Aggregation Step**:
   - Replace `Genus` with the desired level (e.g., `Family`) in the following section:
     ```r
     asv_tidy <- asv_table_norm %>%
       select("Number", metadata$Sample) %>%
       inner_join(tax_table %>% select("Number", "Family")) %>%
       filter(!str_detect(Family, "Unclassified")) %>%
       group_by(Family) %>%
       summarise(across(-Number, sum)) %>%
       pivot_longer(-Family, names_to = "Sample", values_to = "Value") %>%
       pivot_wider(names_from = Family, values_from = Value) %>%
       inner_join(metadata)
     ```
2. **Adjust the Taxonomic Table**:
   - Ensure that the selected taxonomic level has sufficient data for meaningful analysis.

## Outputs
1. `model_leaderboard.txt`: List of models ranked by performance.
2. `variable_importance.pdf`: Plot of feature importance.
3. `model_predictions.txt`: Predictions for the training dataset.
4. `final_model/`: Directory containing the saved model for future use.

## Future Predictions
To use the saved model for new datasets:
1. Initialize H2O:
   ```r
   h2o.init()
   ```
2. Load the saved model:
   ```r
   model <- h2o.loadModel("final_model/...")
   ```
3. Prepare the new dataset:
   ```r
   new_data <- as.h2o(new_dataset)
   ```
4. Predict outcomes:
   ```r
   predictions <- h2o.predict(model, newdata = new_data)
   ```

## Notes
- Ensure that sample names and taxonomic levels in the new dataset match the format of the training dataset.
- For large datasets, consider using a high-performance computing environment for efficient processing.
