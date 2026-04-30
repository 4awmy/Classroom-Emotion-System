# modules/clustering.R — K-means clustering for Admin Panel 7
#
# CLAUDE.md §12.1 Panel 7: cluster lecturers by avg_LES × attendance_variance
# CLAUDE.md §12.1 mentions student-subject clusters (for future use).
#
# K = 3 (fixed).  Labels: "High Performer" | "Consistent" | "Needs Support"

library(dplyr)

# ── cluster_lecturers ─────────────────────────────────────────────────────────
# Input:  by_lecture data frame produced by compute_engagement()
#         (expected columns: student_id/lecture_id/engagement_score/confusion_rate)
# Output: data frame with lecturer_id, avg_LES, attendance_variance, cluster_label
#
# NOTE: In Phase 1 there is no lecturer_id column in the emotion export — the
# function returns an empty frame gracefully so Panel 7 renders a "no data" state.
cluster_lecturers <- function(by_lecture_df) {
  K <- 3

  if (is.null(by_lecture_df) || nrow(by_lecture_df) < K) {
    return(data.frame(
      lecturer_id        = character(),
      avg_LES            = numeric(),
      attendance_variance = numeric(),
      cluster_label      = character()
    ))
  }

  # Derive LES per lecture row (same formula as Admin Panel 5)
  df <- by_lecture_df |>
    mutate(
      attendance_rate = 1,   # placeholder until attendance join is available
      LES = 0.5 * engagement_score +
            0.3 * (1 - confusion_rate) +
            0.2 * attendance_rate
    )

  # Aggregate per lecturer (using lecture_id as proxy if lecturer_id not present)
  lec_col <- if ("lecturer_id" %in% names(df)) "lecturer_id" else "lecture_id"
  df[[".lec_key"]] <- df[[lec_col]]

  agg <- df |>
    group_by(.lec_key) |>
    summarise(
      avg_LES             = round(mean(LES,             na.rm = TRUE), 3),
      attendance_variance = round(var(attendance_rate,  na.rm = TRUE), 3),
      .groups = "drop"
    )
  agg$attendance_variance[is.na(agg$attendance_variance)] <- 0

  if (nrow(agg) < K) {
    agg$cluster_label <- "Insufficient data"
    agg$lecturer_id   <- agg$.lec_key
    return(as.data.frame(agg[, c("lecturer_id","avg_LES","attendance_variance","cluster_label")]))
  }

  # K-means (set.seed for reproducibility in Shiny)
  set.seed(42)
  km <- kmeans(agg[, c("avg_LES","attendance_variance")], centers = K, nstart = 20)
  agg$cluster <- km$cluster

  # Assign human-readable labels based on cluster centroid ranks
  centroids   <- as.data.frame(km$centers)
  rank_order  <- order(centroids$avg_LES, decreasing = TRUE)
  label_map   <- setNames(c("High Performer", "Consistent", "Needs Support"), rank_order)
  agg$cluster_label <- label_map[as.character(agg$cluster)]

  agg$lecturer_id <- agg$.lec_key
  as.data.frame(agg[, c("lecturer_id","avg_LES","attendance_variance","cluster_label")])
}


# ── cluster_students (Phase 2+) ───────────────────────────────────────────────
# Placeholder for future student-subject clustering.
# Returns empty frame so callers don't break during Phase 1.
cluster_students <- function(by_student_df) {
  data.frame(
    student_id    = character(),
    cluster_label = character()
  )
}
