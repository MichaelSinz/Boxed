# Creating a Custom Boxed Image

This guide explains how to create your own custom Docker image that effectively
Boxes CycoD in your specialized environment.  By following these instructions,
you can create specialized development environments that maintain compatibility
with keeping CycoD Boxed.

## Understanding Boxed Image Requirements

To properly Box CycoD, your custom image needs:

1. **Base Requirements**:
   - .NET SDK (required for running CycoD)
   - Common Unix tools, git, curl, and rsync
   - PowerShell (which CycoD prefers to use)
   - A `/workspace` directory for mounting work directories

2. **Structure** within [Dockerfile](Dockerfile)
   - Follows the multi-stage Docker build pattern used to Box CycoD properly
   - Should extend from the `base` target
   - Should include proper cleanup steps

Note that #2 is mainly if you want to use the [build.sh](build.sh) script to
build the image and want to leverage its features.  But it is also good
practice to do so.

## Example: Creating a PHP Development Environment

Below is a complete example of adding a PHP development environment to your
custom Boxed image:

```dockerfile
############ php #############################################
FROM base AS php
# This is a custom PHP development environment for running with CycoD
# It has dotnet (which CycoD needs) and PowerShell (which it wants)
# and then adds PHP and Composer for PHP development

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "PHP install"
    set -e
    set -x

    # For Ubuntu-based image (Dockerfile)
    apt-get -qq update
    apt-get install -y \
        php \
        php-cli \
        php-fpm \
        php-mysql \
        php-curl \
        php-gd \
        php-mbstring \
        php-xml \
        php-zip

    # Install Composer (PHP package manager)
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

    # Add any other PHP extensions or tools your development requires
    # For example, Xdebug for debugging:
    apt-get install -y php-xdebug

    # Install common PHP development tools
    composer global require phpunit/phpunit
    composer global require squizlabs/php_codesniffer

    # Make sure Composer's global bin directory is in the PATH
    echo 'export PATH="$PATH:/root/.composer/vendor/bin"' >> /etc/bash.bashrc

    # Cleanup if requested
    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/* /root/.composer/cache
INSTALL
```

### Using AzureLinux Instead

If you're using the Azure Linux-based Dockerfile (`Dockerfile.AzureLinux`), the
package installation would be different:

```dockerfile
############ php #############################################
FROM base AS php
# This is a custom PHP development environment for running with CycoD
# It has dotnet (which CycoD needs) and PowerShell (which it wants)
# and then adds PHP and Composer for PHP development

# If set to true, we try to clean up any temp items and build directories
# such that the image is smaller.
ARG CLEANUP=true

RUN <<INSTALL
    echo "PHP install"
    set -e
    set -x

    # For AzureLinux-based image (Dockerfile.AzureLinux)
    tdnf -y install \
        php \
        php-cli \
        php-fpm \
        php-mysqlnd \
        php-curl \
        php-gd \
        php-mbstring \
        php-xml \
        php-zip

    # Install Composer (PHP package manager)
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

    # Add any other PHP tools your development requires
    # Make sure Composer's global bin directory is in the PATH
    echo 'export PATH="$PATH:/root/.composer/vendor/bin"' >> /etc/bash.bashrc

    # Cleanup if requested
    [ "${CLEANUP}" != "true" ] || tdnf clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/log/* /var/cache/* /tmp/* /root/.composer/cache
INSTALL
```

## Step-by-Step Process for Creating a Custom Image

1. **Copy the existing Dockerfile**:
   ```bash
   cp Dockerfile Dockerfile.custom
   ```

2. **Add your custom variant** to the Dockerfile by appending your definition
   (like the PHP example above)

3. **Build your custom image**:
   ```bash
   ./build.sh --dockerfile Dockerfile.custom --variant php
   ```

4. **Run your custom image**:
   ```bash
   boxed --variant php
   ```

## Advanced: Creating a Complete Custom Image

If you want to create a completely custom image rather than just adding a
variant, follow these essential guidelines:

### Essential Elements

1. **Base Image with .NET SDK**:
   ```dockerfile
   FROM ubuntu:24.04

   # Install .NET SDK and essential tools
   ENV DEBIAN_FRONTEND=noninteractive
   RUN apt-get -qq update && \
       apt-get install -y \
           curl \
           lsb-release

   # Add Microsoft repository and install .NET
   RUN curl -L https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb && \
       dpkg -i /tmp/packages-microsoft-prod.deb && \
       rm /tmp/packages-microsoft-prod.deb

   # Install required packages
   RUN apt-get -qq update && \
       apt-get install -y \
           dotnet-sdk-9.0 \
           gdb \
           git \
           make \
           powershell \
           rsync

   # Create workspace directory
   RUN mkdir -m 777 -p /workspace
   ```

2. **Install CycoD**:
   ```dockerfile
   # Set our tool's bin directory and add it to the path
   ARG AI_TOOL_BIN=/opt/ai/bin
   ENV PATH=${AI_TOOL_BIN}:$PATH

   # Install CycoD
   RUN mkdir -m 755 -p ${AI_TOOL_BIN} && \
       dotnet tool install --tool-path ${AI_TOOL_BIN} CycoD --prerelease && \
       chmod -R a-w,a+r ${AI_TOOL_BIN}
   ```

3. **Add Your Custom Tools**:
   ```dockerfile
   # Install your specific tools
   RUN apt-get -qq update && \
       apt-get install -y \
           your-package1 \
           your-package2

   # Any additional setup required for your environment
   ```

## Important Considerations

1. **Consistent Structure**: Maintain the same directory structure and environment
   variables that Boxed expects.

2. **Package Management**: Use the appropriate package manager for your base image:
   - Ubuntu/Debian: `apt-get`
   - AzureLinux/RHEL/CentOS: `tdnf` or `yum`/`dnf`
   - Alpine: `apk`

3. **Cleanup**: Always include cleanup steps to reduce image size:
   ```dockerfile
   # Cleanup temporary files
   RUN apt-get clean all && \
       rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
   ```

4. **Testing**: Test your custom Box thoroughly to ensure CycoD is properly contained and functional.

## Example: Complete Custom Image for Data Science

Here's a more complete example of a custom image for data science work:

```dockerfile
FROM ubuntu:24.04 AS base

# If set to true, we try to clean up any temp items and build directories
ARG CLEANUP=true

# Install .NET SDK and essentials
ENV DEBIAN_FRONTEND=noninteractive
RUN <<INSTALL
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        curl \
        lsb-release
    curl -L https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm /tmp/packages-microsoft-prod.deb

    apt-get -qq update
    apt-get install -y \
        dotnet-sdk-9.0 \
        gdb \
        git \
        make \
        powershell \
        rsync

    # Create workspace directory
    mkdir -m 777 -p /workspace

    # Cleanup if requested
    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/*
INSTALL

# Set up CycoD
ARG AI_TOOL_BIN=/opt/ai/bin
ENV PATH=${AI_TOOL_BIN}:$PATH

RUN <<INSTALL_CYCOD
    set -e
    set -x
    mkdir -m 755 -p ${AI_TOOL_BIN}
    dotnet tool install --tool-path ${AI_TOOL_BIN} CycoD --prerelease
    chmod -R a-w,a+r ${AI_TOOL_BIN}
INSTALL_CYCOD

# Add Data Science tools
RUN <<INSTALL_DS
    set -e
    set -x
    apt-get -qq update
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv

    # Install common data science packages
    pip3 install --no-cache-dir \
        numpy \
        pandas \
        scikit-learn \
        matplotlib \
        jupyter \
        torch \
        tensorflow

    # Add R for statistical analysis
    apt-get install -y r-base r-base-dev

    # Cleanup if requested
    [ "${CLEANUP}" != "true" ] || apt-get clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/* /root/.cache
INSTALL_DS
```

## Example: Using Red Hat Enterprise Linux (RHEL) Base Image

This example demonstrates creating a custom Box using Red Hat Enterprise Linux
to properly contain CycoD.  This is particularly useful for organizations that
require Red Hat for compliance or support reasons.

```dockerfile
# Start with Red Hat Enterprise Linux 9 as base
FROM registry.access.redhat.com/ubi9/ubi AS base

# If set to true, we try to clean up any temp items and build directories
ARG CLEANUP=true

# Set up for .NET installation
RUN <<SETUP
    set -e
    set -x

    # Install basic utilities
    dnf install -y \
        curl \
        findutils \
        git \
        gdb \
        make \
        rsync \
        tar \
        which

    # Create workspace directory
    mkdir -m 777 -p /workspace
SETUP

# Install .NET SDK (from Microsoft's RHEL repositories)
RUN <<INSTALL_DOTNET
    set -e
    set -x

    # Add Microsoft repositories for .NET
    curl -fsSL https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm -O
    rpm -i packages-microsoft-prod.rpm
    rm packages-microsoft-prod.rpm

    # Install .NET SDK
    dnf install -y dotnet-sdk-9.0

    # Install PowerShell (optional but recommended for CycoD)
    dnf install -y https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/powershell-7.4.1-1.rh.x86_64.rpm

    # Cleanup if requested
    [ "${CLEANUP}" != "true" ] || dnf clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/cache/dnf/* /var/log/* /tmp/*
INSTALL_DOTNET

# Set up CycoD
ARG AI_TOOL_BIN=/opt/ai/bin
ENV PATH=${AI_TOOL_BIN}:$PATH

RUN <<INSTALL_CYCOD
    set -e
    set -x
    mkdir -m 755 -p ${AI_TOOL_BIN}
    dotnet tool install --tool-path ${AI_TOOL_BIN} CycoD --prerelease
    chmod -R a-w,a+r ${AI_TOOL_BIN}

    # Validate installation
    echo "CycoD version:"
    ${AI_TOOL_BIN}/cycodt --version
INSTALL_CYCOD

# Install development tools for Java development
FROM base AS java-rhel

RUN <<INSTALL_JAVA
    set -e
    set -x

    # Install OpenJDK from RHEL repositories
    dnf install -y \
        java-17-openjdk \
        java-17-openjdk-devel \
        maven

    # Install additional build tools commonly used with Java
    dnf install -y \
        gradle

    # Set JAVA_HOME environment variable
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' >> /etc/bashrc

    # Cleanup if requested
    [ "${CLEANUP}" != "true" ] || dnf clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/cache/dnf/* /var/log/* /tmp/*
INSTALL_JAVA

# Install development tools for C/C++ development
FROM base AS cpp-rhel

RUN <<INSTALL_CPP
    set -e
    set -x

    # Install C/C++ development tools
    dnf install -y \
        gcc \
        gcc-c++ \
        cmake \
        autoconf \
        automake \
        libtool

    # Install debugging and analysis tools
    dnf install -y \
        valgrind \
        strace \
        ltrace

    # Cleanup if requested
    [ "${CLEANUP}" != "true" ] || dnf clean all
    [ "${CLEANUP}" != "true" ] || rm -rf /var/cache/dnf/* /var/log/* /tmp/*
INSTALL_CPP
```

### Building and Using the RHEL-based Image

Save the above Dockerfile as `Dockerfile.rhel` and build it using the
[build.sh](build.sh) script:

```bash
# Build the base image or a specific variant
./build.sh --dockerfile Dockerfile.rhel --variant base
./build.sh --dockerfile Dockerfile.rhel --variant java-rhel
```

Alternatively, if you have your own container build process, you can use that
instead of the [build.sh](build.sh) script. The [build.sh](build.sh) script is
simply a convenience tool.

### Using Custom Images with [boxed.sh](boxed.sh)

All command-line arguments in the [boxed.sh](boxed.sh) script have matching
environment variable names.  This gives you two ways to configure Boxed:

1. **Environment variables** - Set persistent defaults
2. **Command-line arguments** - Override defaults for a specific run

Command-line arguments always take precedence over environment variables,
giving you flexibility in how you configure your environment.

For convenient access from any directory, it's recommended to copy the
[boxed.sh](boxed.sh) script to a directory in your PATH as `boxed`:

```bash
# Option 1: Personal bin directory (common for many users)
mkdir -p ~/bin
cp boxed.sh ~/bin/boxed
chmod +x ~/bin/boxed  # Ensure it's executable

# Option 2: Other common user locations depending on your distro
# cp boxed.sh ~/.local/bin/boxed
# chmod +x ~/.local/bin/boxed

# Option 3: System-wide installation (requires admin privileges)
# sudo cp boxed.sh /usr/local/bin/boxed
# sudo chmod a+x /usr/local/bin/boxed  # Make executable by all users
```

Choose the location that matches your system setup and preferences.  Once
installed in your PATH, you can simply use the `boxed` command from any work
directory:

```bash
cd /path/to/your/project
boxed
```

For using custom images, there are two key settings that must be specified
separately:

1. **boxed_image**: The base image name without the tag (matches the `--boxed-image` argument)
2. **variant**: The tag to apply to the image (matches the `--variant` argument)

#### Example: Using Environment Variables

Set these in your .bashrc or .zshrc for persistent configuration:

```bash
# Set both the base image name and variant
export boxed_image=boxed-rhel
export variant=java-rhel
```

Then simply run boxed from any work directory:

```bash
cd /path/to/your/project
boxed
```

#### Example: Using Command-line Arguments

Specify the settings directly on the command line for one-time use:

```bash
cd /path/to/your/project
boxed --boxed-image boxed-rhel --variant java-rhel
```

You can also override just one setting while keeping the other from your
environment variables:

```bash
# With boxed_image set in environment
export boxed_image=boxed-rhel

# Override just the variant
cd /path/to/your/project
boxed --variant cpp-rhel
```

> **Note**: The boxed_image and variant must be set separately - at this time,
  you cannot specify the full image name with tag in a single variable.

> **Important**: Always use the boxed script to run your CycoD.  The script
  handles critical security boundaries that are essential to keep CycoD properly
  Boxed and prevent it from escaping.  The script is likely to gain more
  controls in the future so it is best to use it rather that manually work
  around it.

### RHEL-Specific Considerations

1. **Subscription**: If you're using a full RHEL image (not UBI), you may need
   to register your system with Red Hat Subscription Manager.

2. **Repositories**: Some packages may require additional repositories like EPEL:
   ```dockerfile
   # Add EPEL repository for additional packages
   RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
   ```

3. **Security Policies**: RHEL has stricter security policies.  You may need
   to modify SELinux settings:
   ```dockerfile
   # Install SELinux tools
   RUN dnf install -y policycoreutils selinux-policy-targeted
   ```

## Conclusion

By following these guidelines, you can create custom Docker images that work
seamlessly with the Boxed CycoD solution.  Whether you're adding a new variant
to an existing Dockerfile or creating a completely custom image, maintaining
compatibility with keeping CycoD Boxed will ensure it stays safely contained in
your specialized development environment.