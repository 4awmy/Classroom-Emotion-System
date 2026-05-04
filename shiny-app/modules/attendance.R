# attendance.R - Helper functions for attendance tracking and visualization

# Calculate attendance percentage by student and lecture
calculate_attendance_pct <- function(attendance_df) {
  if (nrow(attendance_df) == 0) {
    return(data.frame())
  }

  attendance_df |>
    dplyr::mutate(status = toupper(.data$status)) |>
    dplyr::group_by(.data$student_id, .data$lecture_id) |>
    dplyr::mutate(
      attendance_pct = dplyr::case_when(
        .data$status == "PRESENT" ~ 1.0,
        .data$status == "ABSENT" ~ 0.0,
        TRUE ~ 0.5  # Late/Excused treated as 50%
      )
    ) |>
    dplyr::ungroup()
}

# Aggregate attendance by course/department
aggregate_attendance <- function(attendance_df) {
  if (nrow(attendance_df) == 0) {
    return(data.frame())
  }

  attendance_df |>
    calculate_attendance_pct() |>
    dplyr::group_by(.data$course, .data$lecturer_id) |>
    dplyr::summarise(
      total_lectures = dplyr::n_distinct(.data$lecture_id),
      attendance_rate = round(mean(.data$attendance_pct, na.rm = TRUE), 3),
      present_count = sum(.data$status == "PRESENT", na.rm = TRUE),
      absent_count = sum(.data$status == "ABSENT", na.rm = TRUE),
      method_ai = sum(.data$method == "AI", na.rm = TRUE),
      method_manual = sum(.data$method == "Manual", na.rm = TRUE),
      method_qr = sum(.data$method == "QR", na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      attendance_status = dplyr::case_when(
        .data$attendance_rate >= 0.9 ~ "Excellent",
        .data$attendance_rate >= 0.75 ~ "Good",
        .data$attendance_rate >= 0.60 ~ "Fair",
        TRUE ~ "Poor"
      )
    )
}

# Per-student attendance summary
student_attendance_summary <- function(attendance_df, student_id_filter = NULL) {
  if (nrow(attendance_df) == 0) {
    return(data.frame())
  }

  data <- attendance_df |>
    calculate_attendance_pct()

  if (!is.null(student_id_filter)) {
    data <- data |> dplyr::filter(.data$student_id == !!student_id_filter)
  }

  data |>
    dplyr::group_by(.data$student_id, .data$lecture_id) |>
    dplyr::summarise(
      status = dplyr::first(.data$status),
      method = dplyr::first(.data$method),
      timestamp = dplyr::first(.data$timestamp),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$student_id, .data$timestamp)
}

# Identify chronic absentees (>30% absence rate)
identify_absentees <- function(attendance_df, threshold = 0.3) {
  if (nrow(attendance_df) == 0) {
    return(data.frame())
  }

  attendance_df |>
    calculate_attendance_pct() |>
    dplyr::group_by(.data$student_id) |>
    dplyr::summarise(
      total_lectures_assigned = dplyr::n_distinct(.data$lecture_id),
      attendance_rate = round(mean(.data$attendance_pct, na.rm = TRUE), 3),
      absences = sum(.data$status == "ABSENT", na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::filter(.data$attendance_rate < (1 - threshold)) |>
    dplyr::arrange(.data$attendance_rate)
}

# Method breakdown (AI vs Manual vs QR)
attendance_method_breakdown <- function(attendance_df) {
  if (nrow(attendance_df) == 0) {
    return(data.frame())
  }

  attendance_df |>
    dplyr::group_by(.data$method, .data$status) |>
    dplyr::summarise(
      count = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      percentage = round(.data$count / sum(.data$count) * 100, 1)
    )
}

# AI vs Manual accuracy comparison (for QA)
ai_vs_manual_accuracy <- function(attendance_df) {
  if (nrow(attendance_df) == 0) {
    return(data.frame())
  }

  # Group by student + lecture to compare AI and Manual entries
  attendance_df |>
    dplyr::pivot_wider(
      id_cols = c(.data$student_id, .data$lecture_id),
      names_from = .data$method,
      values_from = .data$status
    ) |>
    dplyr::filter(!is.na(.data$AI) & !is.na(.data$Manual)) |>
    dplyr::mutate(
      match = .data$AI == .data$Manual,
      agreement = dplyr::if_else(.data$match, "Match", "Mismatch")
    ) |>
    dplyr::group_by(.data$agreement) |>
    dplyr::summarise(count = dplyr::n(), .groups = "drop")
}
