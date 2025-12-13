[![Lint](https://github.com/23skdu/jupyter-template/actions/workflows/lint.yml/badge.svg)](https://github.com/23skdu/jupyter-template/actions/workflows/lint.yml)

# Jupyter Notebook template
## build
```
$ docker build -t myjupyternotes:0.1 .
```
## run
```
$ docker run --user root -e GRANT_SUDO=yes -e GEN_CERT=yes -e NB_GID=100 -p 8888:8888 myjupyternotes:0.1
```
