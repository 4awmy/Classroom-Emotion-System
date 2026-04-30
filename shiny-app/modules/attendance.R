# modules/attendance.R — Attendance helper functions
#
# Pure R utility functions used by both lecturer_server.R (manual entry)
# and admin_server.R (panel 1 overview table).
# No Shiny or httr2 dependencies — testable in isolation.

library(dplyr)

# ── summarise_attendance ──────────────────────────────────────────────────────
# Input:  attendance_df — data frame from exports/attendance.csv
#           columns: student_id, lecture_id, timestamp, status, method
# Output: data frame with one row per lecture showing:
#           lecture_id, total_students, present, absent, attendance_rate
summarise_attendance <- function(attendance_df) {
  if (is.null(attendance_df) || nrow(attendance_df) == 0) {
    return(data.frame(
      lecture_id      = character(),
      total_students  = integer(),
      present         = integer(),
      absent          = integer(),
      attendance_rate = numeric()
    ))
  }

  attendance_df |>
    group_by(lecture_id) |>
    summarise(
      total_students  = dplyr::n(),
      present         = sum(status == "Present", na.rm = TRUE),
      absent          = sum(status == "Absent",  na.rm = TRUE),
      attendance_rate = round(present / total_students, 3),
      .groups = "drop"
    ) |>
    as.data.frame()
}


# ── mark_absent ───────────────────────────────────────────────────────────────
# Given the set of student_ids in the roster and those already marked Present
# in attendance_df for a given lecture, returns a data frame of absent rows
# ready to POST to /attendance/manual.
mark_absent <- function(all_student_ids, attendance_df, lecture_id) {
  present_ids <- attendance_df$student_id[
    attendance_df$lecture_id == lecture_id &
    attendance_df$status     == "Present"
  ]
  absent_ids <- setdiff(all_student_ids, present_ids)
  if (length(absent_ids) == 0) return(data.frame())
  data.frame(
    student_id = absent_ids,
    lecture_id = lecture_id,
    status     = "Absent",
    method     = "Manual",
    stringsAsFactors = FALSE
  )
}


# ── attendance_rate_over_time ─────────────────────────────────────────────────
# Returns weekly attendance rate for trend plotting.
attendance_rate_over_time <- function(attendance_df) {
  if (is.null(attendance_df) || nrow(attendance_df) == 0 ||
      !"timestamp" %in% names(attendance_df)) {
    return(data.frame(week = character(), attendance_rate = numeric()))
  }
  attendance_df |>
    mutate(week = format(lubridate::floor_date(
      as.POSIXct(timestamp), "week"), "%Y-W%V")) |>
    group_by(week) |>
    summarise(
      attendance_rate = round(mean(status == "Present", na.rm = TRUE), 3),
      .groups = "drop"
    ) |>
    as.data.frame()
}
