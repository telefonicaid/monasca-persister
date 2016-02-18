#!/bin/sh

if [ $# -ne 3 ]; then
    echo "Usage: $(basename $0) <monasca-common-version> <java-args-property> <goal> ..." 1>&2
    exit 1
fi

# Download maven 3 if the system maven isn't maven 3
VERSION=$(mvn -v 2>/dev/null | grep "Apache Maven 3")
MVN_PKG=apache-maven-3.2.1
if [ -z "${VERSION}" ]; then
    if [ ! -d "${MVN_PACKAGE}" ]; then
        echo "Downloading maven ${MVN_PKG##*-}..."
        curl -sL http://archive.apache.org/dist/maven/binaries/${MVN_PKG}-bin.tar.gz > ${MVN_PKG}-bin.tar.gz
        tar -xzf ${MVN_PKG}-bin.tar.gz
    fi
    MVN=${PWD}/${MVN_PKG}/bin/mvn
else
    MVN=mvn
fi

# Get the expected common version
COMMON_VERSION=$1; shift

# Get rid of the java property name containing the args
shift

# Check whether build of monasca-common is needed
RUN_BUILD=false
for ARG in $*; do
    if [ "$ARG" = "package" ]; then
        RUN_BUILD=true
    fi
    if [ "$ARG" = "install" ]; then
        RUN_BUILD=true
    fi
done

# Build monasca-common
if [ $RUN_BUILD = "true" ]; then
    echo "Building monasca-common ${COMMON_VERSION}..."
    ( cd common; ./build_common.sh ${MVN} ${COMMON_VERSION} )
    RC=$?
    if [ $RC != 0 ]; then
        exit $RC
    fi
fi

# Invoke the maven 3 on the real pom.xml
GIT_REV=$(git rev-list HEAD --max-count 1 --abbrev=0 --abbrev-commit)
( cd java; ${MVN} -DgitRevision="${GIT_REV}" $* )
RC=$?

# Copy the jars where the publisher will find them
if [ $RUN_BUILD = "true" ]; then
    if [ ! -L target ]; then
        ln -sf java/target target
    fi
fi

# Result artifact
if [ $RC -eq 0 -a -r target/*-shaded.jar ]; then
    ARTIFACT_JAR=$(ls -1rt target/*-shaded.jar | tail -1)
    ARTIFACT_VER=$(awk -F'[<>]' '/version/ { print $3; exit }' pom.xml)
    cp $ARTIFACT_JAR target/monasca-persister.jar
    printf "\nmonasca-persister $ARTIFACT_VER generated at target/monasca-persister.jar\n\n"
fi

# Cleanup and exit
rm -fr ${MVN_PKG}*
exit $RC
