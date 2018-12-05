#!/bin/bash -ue

exec docker build -f Dockerfile -t fbthrift_perf:latest .
