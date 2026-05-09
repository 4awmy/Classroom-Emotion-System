# validation_test.R - Test the updated R modules
library(dplyr)
library(stats)

# Source the modules
source("shiny-app/modules/engagement_score.R")
source("shiny-app/modules/clustering.R")

# Mock data with 3 students
emotions_df <- data.frame(
  student_id = c("S01", "S01", "S02", "S02", "S03", "S03"),
  lecture_id = c("L1", "L1", "L1", "L1", "L1", "L1"),
  timestamp = as.POSIXct(rep(c("2026-04-28 09:00:00", "2026-04-28 09:10:00"), 3)),
  emotion = c("Focused", "Engaged", "Confused", "Confused", "Disengaged", "Disengaged"),
  engagement_score = c(1.0, 0.85, 0.55, 0.55, 0.0, 0.0),
  confidence = c(1.0, 0.85, 0.55, 0.55, 0.0, 0.0)
)

# Test cluster_student_behavior with 3 students and k=2
cat("\nTesting cluster_student_behavior with 3 students...\n")
clustered_students <- cluster_student_behavior(emotions_df, k = 2)
print(clustered_students)

cat("\nValidation complete.\n")
