# clustering.R - K-means clustering for lecturers and students
# Based on CLAUDE.md Section 12.1 (Lecturer clusters) and Section 12.2 (student subject clusters)

library(stats)

# Cluster lecturers by performance metrics (3 clusters: High/Consistent/Needs Support)
cluster_lecturers <- function(les_df, k = 3) {
  if (nrow(les_df) < k) {
    return(data.frame())
  }

  # Features: LES score (normalized), attendance consistency (std dev)
  # Handle zero variance for scale()
  les_scaled <- if(sd(les_df$LES, na.rm=TRUE) == 0) rep(0, nrow(les_df)) else scale(les_df$LES)[, 1]
  att_scaled <- if(sd(les_df$attendance_variance, na.rm=TRUE) == 0) rep(0, nrow(les_df)) else scale(les_df$attendance_variance)[, 1]

  features <- data.frame(
    LES_norm = les_scaled,
    attend_norm = att_scaled
  )

  # K-means clustering
  km <- stats::kmeans(features, centers = k, nstart = 10)

  # Assign labels by centroid LES value (deterministic, not by cluster index)
  centroid_les <- km$centers[, "LES_norm"]
  rank_order   <- rank(centroid_les, ties.method = "first")  # 1=lowest, k=highest
  label_map    <- character(k)
  label_map[rank_order == k]          <- "High Performers"
  label_map[rank_order == 1]          <- "Needs Support"
  label_map[rank_order != k & rank_order != 1] <- "Consistent"

  result <- les_df |>
    dplyr::mutate(
      cluster       = km$cluster,
      cluster_label = label_map[km$cluster]
    )

  result
}

# Cluster students by behavior (e.g., by engagement patterns)
cluster_student_behavior <- function(emotions_df, k = 3) {
  if (nrow(emotions_df) == 0) {
    return(data.frame())
  }

  # Aggregate emotions by student ID
  student_features <- emotions_df |>
    dplyr::mutate(
      focused_count = as.integer(.data$emotion == "Focused"),
      engaged_count = as.integer(.data$emotion == "Engaged"),
      confused_count = as.integer(.data$emotion == "Confused"),
      frustrated_count = as.integer(.data$emotion == "Frustrated"),
      anxious_count = as.integer(.data$emotion == "Anxious"),
      disengaged_count = as.integer(.data$emotion == "Disengaged")
    ) |>
    dplyr::group_by(.data$student_id) |>
    dplyr::summarise(
      avg_focused = mean(.data$focused_count, na.rm = TRUE),
      avg_engaged = mean(.data$engaged_count, na.rm = TRUE),
      avg_confused = mean(.data$confused_count, na.rm = TRUE),
      avg_frustrated = mean(.data$frustrated_count, na.rm = TRUE),
      avg_anxious = mean(.data$anxious_count, na.rm = TRUE),
      avg_disengaged = mean(.data$disengaged_count, na.rm = TRUE),
      avg_engagement_score = mean(.data$engagement_score, na.rm = TRUE),
      .groups = "drop"
    )

  if (nrow(student_features) < k) {
    return(student_features)
  }

  # Select numeric features for clustering
  features_matrix <- student_features |>
    dplyr::select(
      .data$avg_focused,
      .data$avg_engaged,
      .data$avg_confused,
      .data$avg_frustrated,
      .data$avg_anxious,
      .data$avg_disengaged
    ) |>
    as.matrix()

  # Scale features safely
  features_scaled <- apply(features_matrix, 2, function(x) {
    if(sd(x, na.rm=TRUE) == 0) return(rep(0, length(x)))
    scale(x)[,1]
  })

  # K-means
  km <- stats::kmeans(features_scaled, centers = k, nstart = 10)

  # Label clusters by average engagement score
  centers_eng <- aggregate(student_features$avg_engagement_score, list(km$cluster), mean)$x
  rank_order <- rank(centers_eng, ties.method = "first")

  label_map <- character(k)
  label_map[rank_order == k] <- "Highly Engaged"
  label_map[rank_order == 1] <- "Needs Support"
  label_map[rank_order != k & rank_order != 1] <- "Moderate Engagement"

  result <- student_features |>
    dplyr::mutate(
      cluster = km$cluster,
      cluster_label = label_map[km$cluster]
    )

  result
}

# PCA visualization data for lecturer clusters
get_lecturer_pca <- function(clustered_lecturers) {
  if (nrow(clustered_lecturers) == 0) {
    return(data.frame())
  }

  # Standardize features safely
  les_scaled <- if(sd(clustered_lecturers$LES, na.rm=TRUE) == 0) rep(0, nrow(clustered_lecturers)) else scale(clustered_lecturers$LES)[, 1]
  att_scaled <- if(sd(clustered_lecturers$attendance_variance, na.rm=TRUE) == 0) rep(0, nrow(clustered_lecturers)) else scale(clustered_lecturers$attendance_variance)[, 1]

  features <- data.frame(
    LES = les_scaled,
    attendance_variance = att_scaled
  )

  # PCA (2D projection for scatter plot)
  # If variance is zero for all, prcomp might fail or return constant
  pca_result <- tryCatch({
    stats::prcomp(features, scale. = FALSE, rank. = 2)
  }, error = function(e) {
    list(x = matrix(0, nrow=nrow(features), ncol=2))
  })

  data.frame(
    lecturer_id = clustered_lecturers$lecturer_id,
    PC1 = pca_result$x[, 1],
    PC2 = if(ncol(pca_result$x) > 1) pca_result$x[, 2] else 0,
    cluster_label = clustered_lecturers$cluster_label
  )
}
