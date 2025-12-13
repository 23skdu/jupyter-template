FROM jupyter/all-spark-notebook:latest

LABEL author="23skdu@users.noreply.github.com"

USER root

# Environment variables
ENV GRANT_SUDO=yes \n    GEN_CERT=yes \n    NB_GID=100

# Install system updates and clean up to reduce image size
RUN apt-get update && \n    apt-get -y upgrade && \n    apt-get clean && \n    rm -rf /var/lib/apt/lists/*

# Switch back to the notebook user
USER {NB_UID}

EXPOSE 8888

CMD ["start-notebook.py"]
