# Jeff 1.1 for JevBench: jeff-serve v1.4.0 (the release we tested) with the settings we submit: reasoning when unsure,
# with the JevBench limits (every decision within 8.5 s) and the reasoning settings in settings/. The reasoning is
# written by transformers from the release's own weights and adapter, in a step compiled at startup (with a second copy
# of the base weights when the GPU has room for it); requests are served one at a time.
# The CUDA runtime comes with the torch wheel; the host needs an NVIDIA driver for CUDA 13.0 (R580 or newer).
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 TOKENIZERS_PARALLELISM=false
# gcc: Triton (used by torch) compiles a small helper on the first request; git: to install the pinned release.
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt entrypoint.sh ./
COPY settings/ ./settings/
# readable and executable for any user the container runs as (the build folder's modes may be stricter)
RUN chmod 755 entrypoint.sh && chmod -R a+rX settings
COPY wheels/ /wheels/
# The server release (or a local wheel: put it in wheels/ and build with --build-arg JEFF=/wheels/<the wheel>).
ARG JEFF="jeff @ git+https://github.com/j-geuter/Jeff@v1.4.0"
RUN pip install -r requirements.txt && pip install --no-deps "$JEFF" && jeff-serve --help > /dev/null
EXPOSE 8013
# Serves the model folder mounted at /model on port 8013 (weights fetched beforehand; works offline).
ENTRYPOINT ["/app/entrypoint.sh"]
