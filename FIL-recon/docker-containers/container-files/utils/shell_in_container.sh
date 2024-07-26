#!/bin/bash
# container name suffix determined by most recent tag and number of subsequent commits
cV=$(./version.sh)  # container version

pkexec docker exec  -it fil_physicsc_${cV} bash
