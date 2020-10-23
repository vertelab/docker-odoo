# #########################################
#
# Image for arbetsformedlingen CRM (Odoo)
# Made By: Peter Hammarstrom
# Date:  March 2020 
#
#-------------------------------------------------------
# Make new AF_CRM Image with additinal modules
# 

#FROM af-crm-baseimage:latest
#

#FROM PUSHED OPENSHIFT IMAGE
FROM localhost:32000/af-crm-baseimage:latest

# Argument can be used in docker build -> --build-arg branch=<branch>
ARG branch

# Use elevated priviliges
USER 0

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./af_init_projects.sh /
COPY ./af_init_modules.sh /
COPY ./odoo.conf /etc/odoo/
COPY ./installed_modules.conf /

# Make script executable
RUN chmod +x /af_init_projects.sh
RUN chmod +x /entrypoint.sh
RUN chmod +x /af_init_modules.sh

# Clone repos 
RUN /af_init_projects.sh ${branch}

# Expose Odoo services
EXPOSE 8069 8071

# Set default user when running the container
USER 1001190000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
