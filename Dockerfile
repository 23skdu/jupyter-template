FROM jupyter/all-spark-notebook:x86_64-python-3.11

LABEL author="23skdu@users.noreply.github.com"

USER root

# Environment variables
ENV GRANT_SUDO=yes \
    GEN_CERT=yes \
    NB_GID=100

# Install system updates and clean up to reduce image size
# hadolint ignore=DL3009
RUN apt-get update && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the notebook user
USER ${NB_UID}

EXPOSE 8888

CMD ["start-notebook.py"]
