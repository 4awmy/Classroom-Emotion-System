# engagement_score.R - Compute engagement metrics per student and lecture
# Based on CLAUDE.md Section 8.2-8.5

compute_engagement <- function(emotions_df) {
  if (nrow(emotions_df) == 0) {
    return(list(by_lecture = data.frame(), by_student = data.frame()))
  }

  # ========================================================================
  # By Lecture Metrics
  # ========================================================================

  by_lecture <- emotions_df |>
    dplyr::group_by(.data$student_id, .data$lecture_id) |>
    dplyr::summarise(
      engagement_score = round(mean(.data$engagement_score, na.rm = TRUE), 3),
      dominant_emotion = names(which.max(table(.data$emotion))),
      confusion_rate = round(mean(.data$emotion == "Confused", na.rm = TRUE), 3),
      frustration_rate = round(mean(.data$emotion == "Frustrated", na.rm = TRUE), 3),
      anxiety_rate = round(mean(.data$emotion == "Anxious", na.rm = TRUE), 3),
      disengaged_rate = round(mean(.data$emotion == "Disengaged", na.rm = TRUE), 3),
      focused_rate = round(mean(.data$emotion == "Focused", na.rm = TRUE), 3),
      engaged_rate = round(mean(.data$emotion == "Engaged", na.rm = TRUE), 3),
      n_observations = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      cognitive_load = round(.data$confusion_rate + .data$frustration_rate, 3),
      class_valence = round(
        (.data$focused_rate + .data$engaged_rate) -
          (.data$frustration_rate + .data$disengaged_rate + .data$anxiety_rate),
        3
      ),
      engagement_level = dplyr::case_when(
        .data$engagement_score >= 0.75 ~ "High",
        .data$engagement_score >= 0.45 ~ "Moderate",
        .data$engagement_score >= 0.25 ~ "Low",
        TRUE ~ "Critical"
      )
    )

  # ========================================================================
  # By Student Metrics (aggregate across lectures)
  # ========================================================================

  by_student <- by_lecture |>
    dplyr::group_by(.data$student_id) |>
    dplyr::summarise(
      avg_engagement = round(mean(.data$engagement_score, na.rm = TRUE), 3),
      avg_cognitive_load = round(mean(.data$cognitive_load, na.rm = TRUE), 3),
      trend_slope = if (dplyr::n() > 1) {
        coef(lm(.data$engagement_score ~ seq_along(.data$engagement_score)))[2]
      } else {
        0
      },
      lectures_attended = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      trend_slope = round(.data$trend_slope, 4),
      engagement_level = dplyr::case_when(
        .data$avg_engagement >= 0.75 ~ "High",
        .data$avg_engagement >= 0.45 ~ "Moderate",
        .data$avg_engagement >= 0.25 ~ "Low",
        TRUE ~ "Critical"
      )
    )

  list(by_lecture = by_lecture, by_student = by_student)
}

# Aggregate by class (all students, single lecture)
compute_class_metrics <- function(emotions_df, lecture_id) {
  lecture_data <- emotions_df |>
    dplyr::filter(.data$lecture_id == !!lecture_id)

  if (nrow(lecture_data) == 0) {
    return(NULL)
  }

  data.frame(
    lecture_id = lecture_id,
    avg_engagement = round(mean(lecture_data$engagement_score, na.rm = TRUE), 3),
    confusion_rate = round(mean(lecture_data$emotion == "Confused", na.rm = TRUE), 3),
    frustration_rate = round(mean(lecture_data$emotion == "Frustrated", na.rm = TRUE), 3),
    cognitive_load = round(
      mean(lecture_data$emotion == "Confused", na.rm = TRUE) +
        mean(lecture_data$emotion == "Frustrated", na.rm = TRUE),
      3
    ),
    n_students = length(unique(lecture_data$student_id)),
    n_observations = nrow(lecture_data)
  )
}
