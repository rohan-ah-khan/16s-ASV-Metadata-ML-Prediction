# Hydrocarbon Classification Using ASV Data with H2O

# Clear Environment and Setup
rm(list = ls())  # Remove all objects from the environment
try(dev.off(dev.list()), silent = TRUE)  # Close all graphical devices
gc()  # Trigger garbage collection

# Set working directory (adjust as necessary)
setwd("C:/Desktop/EGM")

# Required Packages Installation and Loading
cran_packages <- c('tidyverse', 'readxl', 'h2o')
installed <- cran_packages %in% installed.packages()
if (any(!installed)) {
  install.packages(cran_packages[!installed])
}
lapply(cran_packages, require, character.only = TRUE)

# Set Seed for Reproducibility
set.seed(100)

# Load Input Data
# Ensure your working directory contains the following files:
# 1. ASV Taxonomic Table (e.g., "asv_table.xlsx")
# 2. Metadata Table (e.g., "metadata.xlsx")
file_list <- list.files(pattern = '\\.(xlsx)$')
if (length(file_list) < 2) {
  stop("Ensure two Excel files are present: ASV table and metadata table.")
}

# Read and Process ASV Table
raw_asv_table <- readxl::read_xlsx(file_list[1])
asv_table <- raw_asv_table %>% select(-"ASVID")
asv_table_notax <- asv_table %>% select(-c("Domain", "Phylum", "Class", "Order", "Family", "Genus"))
tax_table <- asv_table %>% select(c("Number", "Domain", "Phylum", "Class", "Order", "Family", "Genus"))

# Read and Process Metadata Table
metadata <- readxl::read_xlsx(file_list[2]) %>% select("Sample", "Gas")

# Validate Consistency of Samples
samples_asv_table <- colnames(asv_table_notax)[-1]
samples_metadata <- metadata$Sample
if (!identical(samples_asv_table, samples_metadata)) {
  stop("Sample mismatch: Check consistency between ASV and metadata tables.")
}

# Filter and Normalize ASV Data
asv_table_filt <- asv_table_notax %>%
  filter(rowSums(across(-1)) >= 10, rowSums(across(-1) > 0) >= ncol(.) * 0.05) %>%
  select(which(colSums(.) >= 100))
asv_table_norm <- sweep(asv_table_filt, 2, colSums(asv_table_filt), "/")
asv_table_norm$Number <- asv_table_filt$Number

# Restructure ASV Data for Analysis
asv_tidy <- asv_table_norm %>%
  select(c("Number", metadata$Sample)) %>%
  inner_join(tax_table %>% select("Number", "Genus")) %>%
  filter(!str_detect(Genus, "Unclassified")) %>%
  group_by(Genus) %>%
  summarise(across(-Number, sum)) %>%
  pivot_longer(-Genus, names_to = "Sample", values_to = "Value") %>%
  pivot_wider(names_from = Genus, values_from = Value) %>%
  inner_join(metadata)

# Initialize H2O and Prepare Data for Modeling
h2o.init(ip = "localhost", nthreads = -1)
h2o.no_progress()
seeds_data_hf <- as.h2o(asv_tidy, destination_frame = "seeds_data_hf")
y <- "Gas"
x <- setdiff(colnames(seeds_data_hf), y)
seeds_data_hf[, y] <- as.factor(seeds_data_hf[, y])

# Train Models Using H2O AutoML
automl_model <- h2o.automl(
  x = x,
  y = y,
  training_frame = seeds_data_hf,
  nfolds = 10,
  balance_classes = TRUE,
  sort_metric = "AUCPR",
  seed = 42
)

# Evaluate Model Performance
leaderboard <- automl_model@leaderboard
write.table(leaderboard, file = "model_leaderboard.txt", row.names = FALSE)
leader_model <- automl_model@leader

# Save Variable Importance Plot
pdf("variable_importance.pdf", width = 16, height = 9)
h2o.varimp_plot(leader_model, num_of_features = 20)
dev.off()

# Predictions Using Final Model
predictions <- h2o.predict(leader_model, newdata = seeds_data_hf)
write.table(predictions, file = "model_predictions.txt", row.names = FALSE)

# Export Final Model for Future Use
h2o.saveModel(leader_model, path = "final_model", force = TRUE)

# Instructions for Using Final Model
# 1. Load H2O and Initialize:
#    h2o.init()
# 2. Load the Saved Model:
#    model <- h2o.loadModel("final_model/...")
# 3. Prepare New Data:
#    new_data <- as.h2o(new_dataset)
# 4. Predict:
#    predictions <- h2o.predict(model, newdata = new_data)

# Shut Down H2O
h2o.shutdown(prompt = FALSE)
