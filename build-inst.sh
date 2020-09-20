#!/bin/bash

INSTALL_PCKG_SUFFIX="my_project"

if [ $# -lt 1 ] # Check if enough arguments are specified.
then
  echo "Usage: "
  echo "$(basename "$0") BUILD_VERSION"
  echo " "
  exit 65
fi

BUILD_VERSION=$1


# Build install package version

echo "Try to build for $BUILD_VERSION:"

if tar -czf "${BUILD_VERSION}_${INSTALL_PCKG_SUFFIX}.tgz" --exclude="CI" ./*
then
  echo "OK: Build successfully."
else
  echo "ERROR: Can't create build." && exit 1
fi

exit 0