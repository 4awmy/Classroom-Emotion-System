# clustering.R - K-means clustering for lecturers and students
# Based on CLAUDE.md Section 12.1 (Lecturer clusters) and Section 12.2 (student subject clusters)

library(stats)

# Cluster lecturers by performance metrics (3 clusters: High/Consistent/Needs Support)
cluster_lecturers <- function(les_df, k = 3) {
  if (nrow(les_df) < k) {
    return(data.frame())
  }

  # Features: LES score (normalized), attendance consistency (std dev)
  features <- les_df |>
    dplyr::select(.data$lecturer_id, .data$LES, .data$attendance_variance) |>
    dplyr::mutate(
      LES_norm = scale(.data$LES)[, 1],
      attend_norm = scale(.data$attendance_variance)[, 1]
    ) |>
    dplyr::select(.data$LES_norm, .data$attend_norm)

  # K-means clustering
  km <- stats::kmeans(features, centers = k, nstart = 10)

  result <- les_df |>
    dplyr::mutate(cluster = km$cluster) |>
    dplyr::mutate(
      cluster_label = dplyr::case_when(
        .data$cluster == 1 ~ "High Performers",
        .data$cluster == 2 ~ "Consistent",
        .data$cluster == 3 ~ "Needs Support",
        TRUE ~ "Unclassified"
      )
    )

  result
}

# Cluster students by subject (e.g., by department/course)
cluster_student_subject <- function(emotions_df, k = 3) {
  if (nrow(emotions_df) == 0) {
    return(data.frame())
  }

  # Aggregate emotions by student ID and subject
  subject_features <- emotions_df |>
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

  if (nrow(subject_features) < k) {
    return(subject_features)
  }

  # Select numeric features for clustering
  features_matrix <- subject_features |>
    dplyr::select(
      .data$avg_focused,
      .data$avg_engaged,
      .data$avg_confused,
      .data$avg_frustrated,
      .data$avg_anxious,
      .data$avg_disengaged
    ) |>
    as.matrix()

  # K-means
  km <- stats::kmeans(features_matrix, centers = k, nstart = 10)

  result <- subject_features |>
    dplyr::mutate(
      cluster = km$cluster,
      cluster_label = dplyr::case_when(
        .data$cluster == 1 ~ "Highly Engaged",
        .data$cluster == 2 ~ "Moderate Engagement",
        .data$cluster == 3 ~ "Needs Support",
        TRUE ~ "Unclassified"
      )
    )

  result
}

# PCA visualization data for lecturer clusters
get_lecturer_pca <- function(clustered_lecturers) {
  if (nrow(clustered_lecturers) == 0) {
    return(data.frame())
  }

  # Standardize features
  features <- clustered_lecturers |>
    dplyr::select(.data$LES, .data$attendance_variance) |>
    scale()

  # PCA (2D projection for scatter plot)
  pca_result <- stats::prcomp(features, scale. = FALSE, rank. = 2)

  data.frame(
    lecturer_id = clustered_lecturers$lecturer_id,
    PC1 = pca_result$x[, 1],
    PC2 = pca_result$x[, 2],
    cluster_label = clustered_lecturers$cluster_label
  )
}
