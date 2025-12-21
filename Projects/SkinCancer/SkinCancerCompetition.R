# Skin Cancer Competition - 

library(caret)
library(dplyr)
library(ranger)
library(DescTools)
library(ggplot2)

# Set up from HW4
cancer_train <- read.csv("CSVs/SkinCancerTrain (5).csv", header = TRUE)
cancer_test  <- read.csv("CSVs/SKinCancerTestNoY.csv", header = TRUE)

cat("Train Dim:", dim(cancer_train), "\n")
cat("Test Dim:", dim(cancer_test))

# b) numerical predictors
num_vars <- names(cancer_train)[sapply(cancer_train, is.numeric)]
cat("Number of numerical predictors:", length(num_vars), "\n\n")
cat("Numerical predictors:\n")
print(num_vars)

# c) categorical predictors (character)
cat_vars <- names(cancer_train)[sapply(cancer_train, is.character)]
cat("Number of categorical predictors:", length(cat_vars), "\n\n")
cat("Categorical predictors:\n")
print(cat_vars)

# d) missingness summaries
train_missing_freq <- colSums(is.na(cancer_train))
train_missing_percent <- (train_missing_freq / nrow(cancer_train)) * 100
train_missing_summary <- data.frame(
  Missing = train_missing_freq,
  Percent = train_missing_percent
)
train_missing_summary

test_missing_freq <- colSums(is.na(cancer_test))
test_missing_percent <- (test_missing_freq / nrow(cancer_test)) * 100
test_missing_summary <- data.frame(
  Missing = test_missing_freq,
  Percent = test_missing_percent
)
test_missing_summary

# e) impute numeric with median (train median applied to test)
num_vars <- names(cancer_train)[sapply(cancer_train, is.numeric)]
for (x in num_vars) {
  cancer_train[[x]][is.na(cancer_train[[x]])] <- median(cancer_train[[x]], na.rm = TRUE)
  cancer_test[[x]][is.na(cancer_test[[x]])]  <- median(cancer_train[[x]], na.rm = TRUE)
}

# f) impute categorical with mode (exclude target)
cat_vars <- names(cancer_train)[sapply(cancer_train, is.character)]
cat_vars <- setdiff(cat_vars, "Cancer")
for (x in cat_vars) {
  mode_value <- names(sort(table(cancer_train[[x]]), decreasing = TRUE))[1]
  cancer_train[[x]][is.na(cancer_train[[x]]) | cancer_train[[x]] == ""] <- mode_value
  cancer_test[[x]][is.na(cancer_test[[x]])  | cancer_test[[x]] == ""]  <- mode_value
}

# g) re-check missingness after imputation
train_missing_freq <- colSums(is.na(cancer_train))
train_missing_percent <- (train_missing_freq / nrow(cancer_train)) * 100
train_missing_summary <- data.frame(
  Missing = train_missing_freq,
  Percent = train_missing_percent
)
train_missing_summary

test_missing_freq <- colSums(is.na(cancer_test))
test_missing_percent <- (test_missing_freq / nrow(cancer_test)) * 100
test_missing_summary <- data.frame(
  Missing = test_missing_freq,
  Percent = test_missing_percent
)
test_missing_summary

# Convert character vars to factors, aligning test levels to train levels
char_vars <- names(cancer_train)[sapply(cancer_train, is.character)]
char_vars <- intersect(char_vars, names(cancer_test)) # key fix
for (v in char_vars) {
  cancer_train[[v]] <- factor(cancer_train[[v]])
  cancer_test[[v]]  <- factor(cancer_test[[v]], levels = levels(cancer_train[[v]]))
}

# Recompute predictor lists
cat_vars <- names(cancer_train)[sapply(cancer_train, is.factor)]
num_vars <- names(cancer_train)[sapply(cancer_train, is.numeric)]
cat_vars <- names(cancer_train)[sapply(cancer_train, is.factor)]
cat_vars <- setdiff(cat_vars, "Cancer")
num_vars <- names(cancer_train)[sapply(cancer_train, is.numeric) | sapply(cancer_train, is.integer)]

length(num_vars)
length(cat_vars)

# --- Cramer's V for categorical predictors
cramers_v <- sapply(cat_vars, function(v) {
  tbl <- table(cancer_train[[v]], cancer_train$Cancer)
  CramerV(tbl, bias.correct = TRUE)
})

cramers_df <- data.frame(
  variable = names(cramers_v),
  cramersV = as.numeric(cramers_v)
)
cramers_df <- cramers_df[order(-cramers_df$cramersV), ]
cramers_df$rank <- seq_len(nrow(cramers_df))
head(cramers_df, 15)

top_cat_vars <- cramers_df$variable[1:10]
top_cat_vars

ggplot(cramers_df, aes(x = rank, y = cramersV)) +
  geom_line() +
  geom_point() +
  labs(
    x = "Predictor Rank (categorical)",
    y = "Cramér's V",
    title = "Ranked Association of Categorical Predictors with Cancer"
  )

# Point-biserial (correlation with binary outcome) for numeric predictors
sapply(cancer_train, class)

y_train <- ifelse(cancer_train$Cancer == "Malignant", 1, 0)
pb <- sapply(num_vars, function(v) {
  cor(cancer_train[[v]], y_train, use = "complete.obs")
})

pb_sorted <- sort(abs(pb), decreasing = TRUE)
pb_sorted
length(pb_sorted)

pb_df <- data.frame(
  variable = names(pb_sorted),
  assoc = as.numeric(pb_sorted)
)
pb_df$rank <- seq_len(nrow(pb_df))
head(pb_df, 21)

top_num_vars <- names(pb_sorted)[1:21]
top_num_vars

ggplot(pb_df, aes(x = rank, y = assoc)) +
  geom_line() +
  geom_point() +
  labs(
    x = "Predictor Rank (numerical)",
    y = "Absolute Point-Biserial Correlation",
    title = "Ranked Association of Numerical Predictors with Cancer"
  )

# Reduced dataset
cancer_train_sel <- cancer_train[, c(top_num_vars, top_cat_vars, "Cancer")]
cancer_test_sel  <- cancer_test[,  c(top_num_vars, top_cat_vars)]
length(cancer_test_sel)

# Elastic net (glmnet) via caret
ctrl <- trainControl(
  method = "cv",
  number = 5,
  classProbs = TRUE,
  summaryFunction = twoClassSummary,
  savePredictions = "final"
)

enet_grid <- expand.grid(
  alpha = 0.8,
  lambda = seq(0.0001, 0.05, length = 50) # reasonable range
)

enet_fit <- train(
  Cancer ~ .,
  data = cancer_train_sel,
  method = "glmnet",
  trControl = ctrl,
  preProcess = c("center", "scale"),
  tuneGrid = enet_grid,
  metric = "ROC"
)

enet_fit$bestTune

# Threshold tuning (note: final below uses 0.5 in the PDF)
train_probs <- enet_fit$pred
thresholds <- seq(0.4, 0.6, by = 0.01)

accs <- sapply(thresholds, function(t) {
  preds <- ifelse(train_probs$Malignant >= t, "Malignant", "Benign")
  mean(preds == train_probs$obs)
})

best_threshold <- thresholds[which.max(accs)]
best_threshold

# Predict on test and write submission
test_probs <- predict(enet_fit, newdata = cancer_test_sel, type = "prob")

final_preds <- ifelse(
  test_probs$Malignant >= 0.5,
  "Malignant",
  "Benign"
)

submission <- data.frame(ID = 1:nrow(cancer_test_sel), Cancer = final_preds)
write.csv(submission, "final_cancertest_31pred.csv", row.names = FALSE)
