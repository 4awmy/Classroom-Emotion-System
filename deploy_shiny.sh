#!/bin/bash

# Deployment script for AAST Classroom Emotion System - Shiny Portal
# This script verifies prerequisites and provides the deployment command.

echo "--- AAST Shiny Portal Deployment Verification ---"

# Check if R is installed
if ! command -v R &> /dev/null
then
    echo "Error: R is not installed or not in PATH."
    exit 1
fi

# Check for required R packages
echo "Checking R packages..."
Rscript -e "
packages <- c('rsconnect', 'config', 'shiny', 'shinydashboard', 'httr2')
missing <- packages[!(packages %in% installed.packages()[,'Package'])]
if(length(missing) > 0) {
  cat('Missing packages:', paste(missing, collapse=', '), '\n')
  quit(status=1)
} else {
  cat('All required packages are installed.\n')
}
"

if [ $? -ne 0 ]; then
    echo "Please install missing packages in R before deploying."
    exit 1
fi

# Check if config.yml exists
if [ ! -f "shiny-app/config.yml" ]; then
    echo "Error: shiny-app/config.yml not found."
    exit 1
fi

echo "Verification successful."
echo ""
echo "To deploy to shinyapps.io, run the following in your R console:"
echo "------------------------------------------------------------"
echo "library(rsconnect)"
echo "rsconnect::deployApp('shiny-app', appName = 'aast-lms')"
echo "------------------------------------------------------------"
echo ""
echo "Ensure you have set up your account info using rsconnect::setAccountInfo() first."
