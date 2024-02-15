#FROM jupyter/tensorflow-notebook:latest
#FROM jupyter/pytorch-notebook:latest
#FROM jupyter/minimal-notebook:latest
FROM jupyter/all-spark-notebook:latest
LABEL author=23skdu@users.noreply.github.com
USER root
ENV GRANT_SUDO=yes GEN_CERT=yes NB_GID=100
RUN sudo apt update && sudo apt -y upgrade 
EXPOSE 8888/tcp
CMD ["start-notebook.py"]
