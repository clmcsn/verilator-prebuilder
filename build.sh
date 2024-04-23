#!/bin/sh

show_usage()
{
    echo "Verilator builder v0.1"
    echo "Usage: [[--file|-f=<dockerfile>] [--help]]"
}

#exit on error
set -e

SCRIPT_DIR=$(dirname "$0")
DOCKER_FILE=0
#TODO: Allow generation for any version
VERILATOR_VERSION=v4.228

for i in "$@"
do
case $i in
    -f=*|--file=*)
    DOCKER_FILE="${i#*=}"
    shift
    ;;
    --help)
    show_usage
    exit 0
    ;;
    *)
    show_usage
    exit 1
    ;;
esac
done

if [ ! -f "$DOCKER_FILE" ]; then
    echo "Dockerfile not found: $DOCKER_FILE"
    exit 1
fi
#Extracting OS and version from dockerfile
#Format is Dockerfile.<OS>.<version>
OS=$(echo $DOCKER_FILE | cut -d'.' -f2)
VERSION=$(echo $DOCKER_FILE | cut -d'.' -f3)
PREBUILT_DIR=$SCRIPT_DIR/prebuilt/$OS/$VERSION

DOCKER=0
if docker -h >& /dev/null; then
    DOCKER=docker
elif podman -h >& /dev/null; then
    DOCKER=podman
else
    echo "Error: Docker or Podman not found"
    exit 1
fi

# Build the docker image
$DOCKER build -f $DOCKER_FILE -t verilator $SCRIPT_DIR 

# Create a tmp container
CONT_ID=$($DOCKER create verilator)

# Copy the verilator binary
$DOCKER cp $CONT_ID:/verilator .

# Remove the container
$DOCKER rm $CONT_ID

# Remove the image
$DOCKER rmi verilator

# Make archive
tar -cjf verilator-$VERILATOR_VERSION.tar.bz2 verilator
split -b 50M verilator-$VERILATOR_VERSION.tar.bz2 "verilator-$VERILATOR_VERSION.tar.bz2.part"
mkdir -p $PREBUILT_DIR
mv verilator-$VERILATOR_VERSION.tar.bz2.part* $PREBUILT_DIR
rm -f verilator-$VERILATOR_VERSION.tar.bz2
rm -rf verilator