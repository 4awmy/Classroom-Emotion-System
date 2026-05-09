# Database Connection Test Script
# Run this in RStudio to verify Supabase connectivity

library(DBI)
library(RPostgres)

# Configuration
# Using the Supabase Transaction Pooler (Port 6543) with Direct IP
# Username format: postgres.[project-ref]
db_host <- "18.198.30.239"
db_port <- 6543
db_user <- "postgres.asefcgykjadlekhwwzar"
db_pass <- "kdJTnejv0XYhud5C"
db_name <- "postgres"

cat("Connecting to:", db_host, "on port", db_port, "...\n")

tryCatch({
  con <- dbConnect(
    RPostgres::Postgres(),
    dbname = db_name,
    host = db_host,
    port = db_port,
    user = db_user,
    password = db_pass
  )
  
  tables <- dbListTables(con)
  cat("✓ SUCCESS! Connected to Supabase.\n")
  cat("Found", length(tables), "tables:\n")
  print(tables)
  
  dbDisconnect(con)
}, error = function(e) {
  cat("✗ FAILED to connect.\n")
  cat("Error message:", e$message, "\n")
  cat("\nTroubleshooting Tip:\n")
  cat("Ensure you are not on a restricted network (like a corporate/uni firewall).\n")
  cat("If DNS is the issue, using IP 18.198.30.239 should bypass it.\n")
})
