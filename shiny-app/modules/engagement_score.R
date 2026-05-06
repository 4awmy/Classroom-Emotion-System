# modules/engagement_score.R — Core engagement metric computation
#
# Implements the LOCKED formulas from CLAUDE.md §8.
# Called by both admin_server.R and lecturer_server.R.
#
# Input:  emotions_df — data frame with columns:
#           student_id, lecture_id, timestamp, emotion, confidence, engagement_score
# Output: list(by_lecture = <data.frame>, by_student = <data.frame>)

library(dplyr)

compute_engagement <- function(emotions_df) {

  # Guard: return empty structure on empty input
  if (is.null(emotions_df) || nrow(emotions_df) == 0) {
    empty <- data.frame(
      student_id = character(), lecture_id = character(),
      engagement_score = numeric(), dominant_emotion = character(),
      confusion_rate = numeric(), frustration_rate = numeric(),
      anxiety_rate = numeric(), disengaged_rate = numeric(),
      focused_rate = numeric(), engaged_rate = numeric(),
      n_observations = integer(),
      cognitive_load = numeric(), class_valence = numeric(),
      engagement_level = character()
    )
    return(list(by_lecture = empty,
                by_student = data.frame(student_id = character(),
                                         avg_engagement = numeric(),
                                         avg_cognitive_load = numeric(),
                                         trend_slope = numeric(),
                                         lectures_attended = integer())))
  }

  # ── Per-lecture per-student summary ─────────────────────────────────────────
  by_lecture <- emotions_df |>
    group_by(student_id, lecture_id) |>
    summarise(
      engagement_score  = round(mean(engagement_score, na.rm = TRUE), 3),
      dominant_emotion  = names(which.max(table(emotion))),
      confusion_rate    = round(mean(emotion == "Confused",    na.rm = TRUE), 3),
      frustration_rate  = round(mean(emotion == "Frustrated",  na.rm = TRUE), 3),
      anxiety_rate      = round(mean(emotion == "Anxious",     na.rm = TRUE), 3),
      disengaged_rate   = round(mean(emotion == "Disengaged",  na.rm = TRUE), 3),
      focused_rate      = round(mean(emotion == "Focused",     na.rm = TRUE), 3),
      engaged_rate      = round(mean(emotion == "Engaged",     na.rm = TRUE), 3),
      n_observations    = dplyr::n(),
      .groups = "drop"
    ) |>
    mutate(
      # §8.4: cognitive load — indicates lecture pace too fast when > 0.50
      cognitive_load   = round(confusion_rate + frustration_rate, 3),

      # §8.4: class valence — positive = healthy; negative = intervention needed
      class_valence    = round(
        (focused_rate + engaged_rate) -
        (frustration_rate + disengaged_rate + anxiety_rate),
        3
      ),

      # §8.3: engagement level thresholds
      engagement_level = dplyr::case_when(
        engagement_score >= 0.75 ~ "High",
        engagement_score >= 0.45 ~ "Moderate",
        engagement_score >= 0.25 ~ "Low",
        TRUE                     ~ "Critical"
      )
    )

  # ── Per-student aggregate across lectures ────────────────────────────────────
  by_student <- by_lecture |>
    group_by(student_id) |>
    summarise(
      avg_engagement     = round(mean(engagement_score, na.rm = TRUE), 3),
      avg_cognitive_load = round(mean(cognitive_load,   na.rm = TRUE), 3),
      # Trend slope: negative means engagement is declining across lectures.
      # Guard: lm() requires at least 2 observations; single-lecture students get NA.
      trend_slope        = if (dplyr::n() >= 2) {
        tryCatch(
          coef(lm(engagement_score ~ seq_along(engagement_score)))[2],
          error = function(e) NA_real_
        )
      } else {
        NA_real_
      },
      lectures_attended  = dplyr::n(),
      .groups = "drop"
    )

  list(by_lecture = as.data.frame(by_lecture),
       by_student = as.data.frame(by_student))
}
