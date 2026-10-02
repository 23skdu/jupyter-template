# syntax=docker/dockerfile:1

# The Jupyter Docker Stacks moved their publishing target from Docker Hub to
# Quay.io in 2023. The Docker Hub copy of this repository is frozen at
# 2023-10-20 and no longer receives security updates, so always pull from
# quay.io. Override with --build-arg to track a different tag, e.g.:
#   --build-arg BASE_TAG=spark-4.2.0
ARG BASE_IMAGE=quay.io/jupyter/all-spark-notebook
ARG BASE_TAG=2026-09-29

FROM ${BASE_IMAGE}:${BASE_TAG}

# ARG values declared before FROM are only in scope for the FROM instruction,
# so they must be redeclared to be referenced below.
ARG BASE_IMAGE
ARG BASE_TAG

LABEL org.opencontainers.image.title="jupyter-template" \
      org.opencontainers.image.description="JupyterLab + Apache Spark (PySpark/R) notebook image for devcontainers and Kubernetes" \
      org.opencontainers.image.authors="23skdu@users.noreply.github.com" \
      org.opencontainers.image.source="https://github.com/23skdu/jupyter-template" \
      org.opencontainers.image.url="https://github.com/23skdu/jupyter-template" \
      org.opencontainers.image.documentation="https://github.com/23skdu/jupyter-template#readme" \
      org.opencontainers.image.licenses="BSD-3-Clause" \
      org.opencontainers.image.base.name="${BASE_IMAGE}:${BASE_TAG}" \
      org.opencontainers.image.vendor="23skdu"

# Options consumed by the upstream start.sh entrypoint / jupyter config.
#
# The base image already sets USER 1000, so the container starts unprivileged.
# start.sh only applies NB_UID / NB_GID / CHOWN_HOME / GRANT_SUDO when it is
# given --user root, in which case it re-execs as ${NB_USER} via sudo. That is
# why the README passes `--user root`; without it, GRANT_SUDO and NB_GID below
# are inert. GEN_CERT is the exception: jupyter_server_config.py reads it as a
# plain env var, so HTTPS works at any uid.
#
# - GRANT_SUDO: passwordless sudo for jovyan, needed to `apt install` OS
#              packages. Only takes effect together with `--user root`, and
#              should only be enabled for users you trust.
# - GEN_CERT:   generate a self-signed cert so the server serves HTTPS.
# - NB_GID:     gid 100 (`users`), which owns /home/jovyan and /opt/conda so
#              volumes using that gid stay writable. Already the image default.
ENV GRANT_SUDO=yes \
    GEN_CERT=yes \
    NB_GID=100

# 8888 -> Jupyter Server. 4040 -> Spark UI (each extra Spark context gets its
# own incrementing port: 4040, 4041, ...).
#
# PySpark note: this image ships Spark as a distribution under /usr/local/spark
# with pyspark.zip rather than as an installed package, so notebooks need
#   PYTHONPATH=/usr/local/spark/python:/usr/local/spark/python/lib/py4j-<ver>-src.zip
# before `import pyspark` works. `spark-submit` works without it. See the README.
EXPOSE 8888 4040

CMD ["start-notebook.py"]
