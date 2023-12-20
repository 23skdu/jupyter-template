#FROM jupyter/tensorflow-notebook
#FROM jupyter/pytorch-notebook
#FROM jupyter/all-spark-notebook
FROM jupyter/minimal-notebook
LABEL author=23skdu@users.noreply.github.com
EXPOSE 8888/tcp
CMD ["start-notebook.py"]
