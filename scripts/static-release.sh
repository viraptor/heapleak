#!/bin/sh

docker build -t heapleak-release -f Dockerfile.release .
docker run -v $(pwd):/foo -w /foo heapleak-release shards build --release --static
