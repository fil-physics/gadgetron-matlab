#!/bin/bash
# container name suffix determined by most recent tag and number of subsequent commits
cV=$(git describe --tags --abbrev=1)    # container version
echo ${cV}
