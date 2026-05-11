FROM rocker/shiny:latest

# System deps for RPostgres, curl, openxlsx
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install all required R packages
RUN R -e "install.packages(c( \
    'shiny', 'shinydashboard', 'shinyalert', 'shinyjs', 'shinyWidgets', \
    'DT', 'plotly', 'ggplot2', 'dplyr', 'lubridate', \
    'httr2', 'curl', 'base64enc', 'openxlsx', 'rmarkdown', \
    'bslib', 'config', 'DBI', 'RPostgres', \
    'promises', 'future' \
  ), repos='https://cloud.r-project.org/')"

# Copy app code
COPY . /srv/shiny-server/

# Ensure permissions
RUN chown -R shiny:shiny /srv/shiny-server/

EXPOSE 3838

# CAPTURE ENV VARS FOR R
# This script runs at startup and saves all env vars to .Renviron
CMD ["/bin/bash", "-c", "env | grep -E 'DATABASE_URL|API_URL|JWT_SECRET|GEMINI_API_KEY' >> /srv/shiny-server/.Renviron && chown shiny:shiny /srv/shiny-server/.Renviron && exec /usr/bin/shiny-server"]
