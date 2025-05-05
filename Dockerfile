# Copyright 2025 - Michael Sinz

# This is a multi-target Dockerfile - it is actually multiple build steps
# but related in that you may wish specific variations of the image.
# What this allows is for us to good build caching of common parts and also
# have reasonably good decomposition of the larger bits.

############ Base toolset install #############################################
FROM ubuntu:24.04 AS base
# The base tool install requires dotnet and then the tool itself.
# Note that this is basically a C-Sharp environment so we will be able to
# use it as such too.  We also include git & rsync such that we can build CycoD
# and Powershell as SycoD likes to use it.  Plus, we install make and gdb as
# they are useful in most all environments.

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

# We need to install .Net SDK which requires curl and lsb-release to get
# the Microsoft repo added to the apt repos.  The SDK is needed for AI tool.
# It also happens to give us C# development capabilities.
ENV DEBIAN_FRONTEND=noninteractive
RUN <<INSTALL
    echo "Base install"
    set -e
    set -x

    # Now get ready for installing dotnet (since the tool needs it)
    apt-get -qq update
    apt-get install -y \
        curl \
        lsb-release
    curl -L https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm /tmp/packages-microsoft-prod.deb

    # Now install:
    #     dotnet (required)
    #     git (required to build from git and to make local git commits)
    #     powershell (useful)
    #     rsync (required when building from source)
    apt-get -qq update
    apt-get install -y \
        dotnet-sdk-8.0 \
        gdb \
        git \
        make \
        powershell \
        rsync

    # This is where we default mount our work - just have it ready for use
    # We really should make some way to do this a bit more "controlled"
    mkdir -m 777 -p /workspace

    # Cleanup the temporary stuff that is not actually needed
    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL

# Set our tool's bin directory and add it to the path
ARG AI_TOOL_BIN=/opt/ai/bin
ENV PATH=${AI_TOOL_BIN}:$PATH

# Set this to release, debug, git, or install.  If "install" we
# will install the formal package rather than build from source/git.
# If "git" we will build from git branch/hash.  If "release" or
# "debug" we build from the local source as a "release" or "debug" form.
ARG CYCOD_FROM=git
ARG CYCOD_BUILD=release

# Build cycod from source
ARG CYCOD_GIT=https://github.com/robch/cycod.git

# Set this to the branch you want to build from
ARG CYCOD_BRANCH=master

# Set hash to "any" to get the latest commit on the above branch
# Set hash to the hash you want to get a specific git commit point
#ARG CYCOD_HASH=ea5221bb786c2c67be73601046f8391d656a56cc
ARG CYCOD_HASH=any

RUN --mount=type=bind,source=./,target=/source/ \
    <<BUILD
    mkdir -m 755 -p ${AI_TOOL_BIN}
    case "${CYCOD_FROM}" in
        "package")
            echo 'Installing from package ...'
            dotnet tool install --tool-path ${AI_TOOL_BIN} CycoD --prerelease
            ;;
        "git")
            echo 'Building from git ...'
            mkdir -p /build
            cd /build
            git clone --branch ${CYCOD_BRANCH} ${CYCOD_GIT} .
            [ "${CYCOD_HASH}" = "any" ] || git checkout ${CYCOD_HASH}
            dotnet build -c ${CYCOD_BUILD}
            # This gathers up all of the build artifacts and puts them into the ${AI_TOOL_BIN}
            rsync --verbose --checksum --ignore-existing --perms src/*/bin/*/net*/* ${AI_TOOL_BIN}/
            cd /
            ;;
        "source")
            echo 'Building from local source ...'
            mkdir -p /build
            cp -a /source/. /build/.
            cd /build
            dotnet build -c ${CYCOD_BUILD}
            # This gathers up all of the build artifacts and puts them into the ${AI_TOOL_BIN}
            rsync --verbose --checksum --ignore-existing --perms src/*/bin/*/net*/* ${AI_TOOL_BIN}/
            cd /
            ;;
        *)
            echo "Unknown CYCOD_FROM type: '${CYCOD_FROM}'"
            exit 1
            ;;
    esac
    [ "${CLEANUP}" != "true" ] || rm -rf /build /root/.dotnet /root/.nuget /root/.local /tmp/* /tmp/.dotnet
    chmod -R a-w,a+r ${AI_TOOL_BIN}
    cycodt --version
BUILD

############ Base toolset install =============================================


############ c-sharp #############################################
FROM base AS c-sharp
# Not much to do here other than being here...


############ c-cpp #############################################
FROM base AS c-cpp
# This is effectively an example C/C++ boxed container for cycod
# It has dotnet (which cycod needs) and PowerShell (which it wants)
# and then gcc, g++, gdb, make, cmake, etc.  With this you can use cycod
# and develop/test C, C++ (C# and PowerShell due to it being here for cycod)

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "c-cpp install"
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        cmake \
        g++ \
        gcc

    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL


############ rust ################################
FROM c-cpp AS rust
# This is effectively an example Rust boxed container for cycod
# It has dotnet (which cycod needs) and PowerShell (which it wants)
# and then rustc, cargo, rustfmt, clippy, etc.  With this you can use cycod
# and develop/test Rust (C# and PowerShell due to it being here for cycod)
# Rust also needs C and the linker

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

# Install rust - we want to use rustup for this as it gets newer rust versions
# We also skip installing rust documentation as it is large and not needed here.
# This happens to work in all Linux distros, so does not depend on if base image
# is a specific distro or not.
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH=/usr/local/cargo/bin:$PATH
RUN <<INSTALL_RUST
    echo "Rust install"
    set -e
    set -x
    cd /root
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /root/rust-install.sh
    chmod +x /root/rust-install.sh
    CARGO_HOME=/usr/local/cargo /root/rust-install.sh -y --profile minimal --component cargo,clippy,rust-std,rustc,rustfmt
    [ "${CLEANUP}" != "true" ] || rm /root/rust-install.sh
INSTALL_RUST


############ nodejs #############################################
FROM base AS nodejs
# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "Node.js install"
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        nodejs \
        npm

    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL


############ typescript #############################################
FROM nodejs AS typescript
# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

# We may want typescript too!
RUN <<INSTALL_TYPESCRIPT
    echo "Typescript install"
    set -e
    set -x
    npm install -g typescript
    [ "${CLEANUP}" != "true" ] || rm -rf /root/.npm
INSTALL_TYPESCRIPT


############ java #############################################
FROM base AS java
# This is effectively an example Java boxed container for cycod
# It has dotnet (which cycod needs) and PowerShell (which it wants)
# and then the Java SDK (and make).  With this you can use cycod
# and develop/test Java (C# and PowerShell due to it being here for cycod)

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "Java install"
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        openjdk-21-jdk

    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL


############ python #############################################
FROM base AS python
# This is effectively an example Python boxed container for cycod
# It has dotnet (which cycod needs) and PowerShell (which it wants)
# and then Python3 and pip (and make).  With this you can use cycod
# and develop/test Python (C# and PowerShell due to it being here for cycod)

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "Python install"
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        pip \
        python3

    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL


############ go #############################################
FROM base AS go
# This is effectively an example Go boxed container for cycod
# It has dotnet (which cycod needs) and PowerShell (which it wants)
# and then the Go sdk.  With this you can use cycod
# and develop/test Go (C# and PowerShell due to it being here for cycod)

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "Go install"
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        golang

    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL


############ ruby #############################################
FROM base AS ruby
# This is effectively an example Ruby boxed container for cycod
# It has dotnet (which cycod needs) and PowerShell (which it wants)
# and then Ruby.  With this you can use cycod
# and develop/test Ruby (C# and PowerShell due to it being here for cycod)

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "Ruby install"
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        ruby-full

    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL


############ large #############################################
FROM rust AS large
# This is the "large" Docker image for AI coding agent - it has many languages
# installed starting with the C# needd for the CycoD tools but then
# adding: C, C++, Rust, Java, golang, JavaScipt (nodejs), TypeScript, Perl,
# Python3, Ruby, and PowerShell (because CycoD uses it sometimes).  We also
# include gdb for debugging, make and cmake for build coordination, file,
# rsync, git, and the normal Unix/Linux tools such as grep, sed, awk, etc.
#
# This is my go to contain - it is a bit big but I have it cached locally and
# I don't have to think about which type of tool or coding I need to work with
# as it supports many of them.  (Yes, I skipped many too but these are top of
# mind these days.)  We really don't need all of these but this
# container is the "Swiss Army Knife" of AI coding containers.
#
# We start from the rust image as it already has rust and C/C++ in it.
# Now we add the rest of the stuff.

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "Large install"
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        cmake \
        file \
        g++ \
        gcc \
        golang \
        less \
        nodejs \
        npm \
        openjdk-21-jdk \
        pip \
        python3 \
        ruby-full \
        vim

    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL

# We may want typescript too!
RUN <<INSTALL_TYPESCRIPT
    echo "Typescript install"
    set -e
    set -x
    npm install -g typescript
    [ "${CLEANUP}" != "true" ] || rm -rf /root/.npm
INSTALL_TYPESCRIPT
