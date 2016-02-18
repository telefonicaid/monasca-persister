#!/bin/sh

MVN=$1
VERSION=$2
if [ -z "$MVN" -o -z "$VERSION" ]; then
    echo "Usage: $(basename $0) <mvn> <version>" 1>&2
    exit 1
fi

check_user() {
    local me=$(whoami)
    local ci_user=${CI_USER:-jenkins}
    if [ "$me" != "$ci_user" ]; then
        echo "ERROR: monasca-common artifacts not found in maven repository" 1>&2
        echo "This script is being run by ${me} user" 1>&2
        echo "Only ${ci_user} user will have monasca-common artifacts built" 1>&2
        exit 1
    fi
}

# Check whether monasca-common artifacts are already installed
BUILD_COMMON=false
POM_FILE=${M2_REPO:-~/.m2}/repository/monasca-common/monasca-common/${VERSION}/monasca-common-${VERSION}.pom
if [ ! -r "${POM_FILE}" ]; then
    check_user
    BUILD_COMMON=true
    PATH=$(dirname $MVN):$PATH
fi

# Release of monasca-common to be downloaded
case "$VERSION" in
1.1.0)  TAG=0.0.6;;
1.0.0)  TAG=2015.1;;
*)      TAG=master;;
esac

# This should only be done on the stack forge system by $CI_USER ("jenkins")
if [ "${BUILD_COMMON}" = "true" ]; then
    if [ ! -d monasca-common-$TAG ]; then
        curl -sL https://github.com/openstack/monasca-common/archive/${TAG}.tar.gz -o monasca-common.tar.gz
        tar -xzf monasca-common.tar.gz
    fi
    cd monasca-common-$TAG
    ${MVN} clean
    ${MVN} install
fi
