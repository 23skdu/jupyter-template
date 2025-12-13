[![Build](https://github.com/23skdu/jupyter-template/actions/workflows/build.yml/badge.svg)](https://github.com/23skdu/jupyter-template/actions/workflows/build.yml)
[![Lint](https://github.com/23skdu/jupyter-template/actions/workflows/lint.yml/badge.svg)](https://github.com/23skdu/jupyter-template/actions/workflows/lint.yml)

# Jupyter Notebook template
## pull
```
$ docker pull ghcr.io/23skdu/jupyter-template:latest
```
## run
```
$ docker run --user root -e GRANT_SUDO=yes -e GEN_CERT=yes -e NB_GID=100 -p 8888:8888 ghcr.io/23skdu/jupyter-template:latest
```
