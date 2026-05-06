FROM rocker/shiny:latest

# Install R packages
RUN R -e "install.packages(c('aws.s3', 'httr2', 'dplyr', 'DT', 'ggplot2', 'promises', 'future', 'bslib'), repos='https://cloud.r-project.org/')"

# Copy app code
COPY . /srv/shiny-server/

# Ensure permissions
RUN chown -R shiny:shiny /srv/shiny-server/

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
