# Boxed - a safer way to run [CycoD](https://github.com/robch/cycod/)

Boxed is a containerization solution that keeps the CycoD AI coding tool safely
contained in a controlled Docker environment.  CycoD is an AI-powered tool that
can write, compile, and test code, and Boxed provides a secure "box" to
prevent accidental damage to your system while allowing CycoD to function.

This directory has a [build script](build.sh), a multi-target [Dockerfile](Dockerfile),
and the [boxed script](boxed.sh) that runs a docker container with your work
directory in it and your selected tools, ready for the CycoD tool to start
coding/debugging.

## Prerequisites

- Docker (latest stable version recommended)
- Bash shell environment
- Git (for building from source or version control integration)
- Internet connection (for building containers and accessing the AI)

## Quick Start

**TL;DR**? go to [FAST_START.md](FAST_START.md)

1. Build the boxed container by running the [build.sh](build.sh) script:
   ```bash
   ./build.sh
   ```

2. Copy the [boxed.sh](boxed.sh) script to a directory in your PATH for easier
   access from any directory:
   ```bash
   # Option 1: Personal bin directory (common for many users)
   mkdir -p ~/bin  # Create bin directory if it doesn't exist
   cp boxed.sh ~/bin/boxed
   chmod +x ~/bin/boxed  # Ensure it's executable

   # Ensure the directory is in your PATH
   # For bash users, add to ~/.bashrc or ~/.profile if needed:
   # export PATH="$HOME/bin:$PATH"

   # Option 2: Other common user locations depending on your distro
   # cp boxed.sh ~/.local/bin/boxed
   # chmod +x ~/.local/bin/boxed

   # Option 3: System-wide installation (requires admin privileges)
   # sudo cp boxed.sh /usr/local/bin/boxed
   # sudo chmod a+x /usr/local/bin/boxed  # Make executable by all users
   ```

3. Navigate to your work directory where you want CycoD to operate:
   ```bash
   cd /path/to/your/project
   ```

4. Run the boxed environment:
   ```bash
   boxed
   ```

5. You will be placed in a directory in the container that has your work
   directory mounted in it.

6. At this point you can run the `cycod` tool as you wish.

## Container Variants

The default boxed image is a relatively large one that has many tools and
languages in it.  It is flexible enough for most project types, but you can
build smaller variants specialized for particular development needs.

In the provided Dockerfile, we have every image getting dotnet SDK since it
is basically needed for the AI tool itself.  We also have some common Unix
tools plus git, curl, make, and Powershell (which the AI agent likes to use)

### Available Variants

| Variant     | Description                                          | Included Languages & Tools                                               |  Size     |
|-------------|------------------------------------------------------|--------------------------------------------------------------------------|-----------|
| `large`     | Complete development environment with many languages | C#, C/C++, Rust, Java, Go, Node.js, TypeScript, Python, Ruby, PowerShell | 3.15 GB   |
| `c-cpp`     | C/C++ development environment                        | C, C++, gcc, g++, gdb                                                    | 1.29 GB   |
| `c-sharp`   | C# development environment                           | C#, .NET SDK, PowerShell                                                 | 0.98 GB   |
| `go`        | Go development environment                           | Go                                                                       | 1.46 GB   |
| `java`      | Java development environment                         | OpenJDK                                                                  | 1.69 GB   |
| `nodejs`    | Node.js development environment                      | Node.js, npm                                                             | 1.69 GB   |
| `python`    | Python development environment                       | Python3, pip                                                             | 1.32 GB   |
| `ruby`      | Ruby development environment                         | Ruby                                                                     | 1.04 GB   |
| `rust`      | Rust development environment                         | Rust, Cargo, rustfmt, clippy                                             | 1.58 GB   |
| `typescript`| TypeScript development environment                   | Node.js, npm, TypeScript                                                 | 1.89 GB   |

More variants are bound to be added and sizes are variable based on platform
and updates to those tools over time.

>**NOTE:**  Powershell is currently only available on x86_64 platforms

### Selecting a Variant

To see what variants are available, run:
```bash
./build.sh --variant help
```

You can select a variant in two ways:

1. **Using environment variables (recommended for frequent use):**
   ```bash
   # Set this in your .bashrc or .zshrc for persistent configuration
   export variant=c-sharp

   # Then simply run the scripts without specifying variant
   ./build.sh
   ./boxed.sh
   ```

2. **Using command-line arguments (for one-time use):**
   ```bash
   # For building
   ./build.sh --variant c-sharp

   # For running
   ./boxed.sh --variant c-sharp
   ```

### Using your own Dockerfile

The [build.sh](build.sh) script takes a parameter as to the Dockerfile to use.
The default is our [Dockerfile](Dockerfile) but it can use others, such as
the example alternative version that based on Microsoft's official dotnet Azure
Linux 3.0 image.  See [Dockerfile.AzureLinux](Dockerfile.AzureLinux)

You can also use your own image, as long as it has the tool installed in it.
The [boxed.sh](boxed.sh) script does not care as long as it is a Linux/Unix-like
image and is prepared with the right path and tools.  If you need a special
programming environment and unique tools, just make that image.  Either with
your own Dockerfile or by adding a variant to our example Dockerfile.

We would actually welcome additional variants or updates to our variants to
improve the example, but you are not constrained to our specific configurations
or even our specific [build.sh](build.sh) script to build them.

For more detailed information on [custom images](CUSTOM_IMAGES.md), see
the [CUSTOM_IMAGES.md](CUSTOM_IMAGES.md) document.

### Azure Linux dotnet SDK - Available Variants

If you build with `--dockerfile Dockerfile.AzureLinux` we currently get image
sizes as seen below.  Note that the exact versions of the various tools will be
different as this is based on Azure Linux and not Ubuntu.

| Variant     | Description                                          | Included Languages & Tools                                               |  Size     |
|-------------|------------------------------------------------------|--------------------------------------------------------------------------|-----------|
| `large`     | Complete development environment with many languages | C#, C/C++, Rust, Java, Go, Node.js, TypeScript, Python, Ruby, PowerShell | 2.75 GB   |
| `c-cpp`     | C/C++ development environment                        | C, C++, gcc, g++, gdb                                                    | 1.53 GB   |
| `c-sharp`   | C# development environment                           | C#, .NET SDK, PowerShell                                                 | 1.22 GB   |
| `go`        | Go development environment                           | Go                                                                       | 1.48 GB   |
| `java`      | Java development environment                         | OpenJDK                                                                  | 1.62 GB   |
| `nodejs`    | Node.js development environment                      | Node.js, npm                                                             | 1.30 GB   |
| `python`    | Python development environment                       | Python3, pip                                                             | 1.24 GB   |
| `ruby`      | Ruby development environment                         | Ruby                                                                     | 1.27 GB   |
| `rust`      | Rust development environment                         | Rust, Cargo, rustfmt, clippy                                             | 1.89 GB   |
| `typescript`| TypeScript development environment                   | Node.js, npm, TypeScript                                                 | 1.32 GB   |


## Advanced Usage

### Environment Variables

All script arguments can be set via environment variables.  This is especially
useful for the `variant` value if you consistently use a specialized variant.

For example, if you only do C# development:
```bash
export variant=c-sharp
```

Then both [build.sh](build.sh) and [boxed.sh](boxed.sh) will use that value as
its default.

### Platform Auto-Detection

Both `build.sh` and `boxed.sh` now automatically detect some CPU architectures and sets the appropriate platform default:

- On ARM64 machines (including Apple Silicon): Defaults to `linux/arm64`
- On x86-64 machines (Intel/AMD) or any unrecognized architecture: Defaults to `linux/amd64`

This auto-detection improves performance by selecting the native architecture for your system, but you can still override it with the `--platform` option or the `platform` environment variable:

```bash
# Force using AMD64 architecture even on ARM machines
./build.sh --platform linux/amd64
./boxed.sh --platform linux/amd64
```
or
```bash
# Force using AMD64 architecture even on ARM machines
export platform=linux/amd64
./build.sh
./boxed.sh
```


### Building Options

The build script offers several important options to customize your container:

```bash
# Show quick help
./build.sh -h

# Show long help
./build.sh --help

# Build a specific variant
./build.sh --variant python

# Build from a specific git branch
./build.sh --git-branch develop

# Build from a specific git commit
./build.sh --git-hash ea5221bb786c2c67be73601046f8391d656a56cc

# Build from local source
./build.sh --from source --cycod-source /path/to/cycod/source

# Keep source code in container for debugging (increases image size)
./build.sh --cleanup false --from git
```

When using `--cleanup false` with `--from git` or `--from source`, the CycoD
source code will be preserved in the container.  This is useful for debugging
CycoD itself but will increase the container size significantly.

For the [boxed](boxed.sh) script: (assuming you installed it in the path)
```bash
# Show quick help
boxed -h

# Show long help
boxed --help

# Use a specific variant
boxed --variant python

# Use a specific working directory
boxed --dir /path/to/project

# Run a command non-interactively
boxed -- cycod --help

# Specify a custom name for the container
boxed --boxed-name my-project-container
```

### Running Commands in the Container

You can run commands directly in the container instead of entering an
interactive shell:

```bash
boxed -- cycod create-project --type console-app
```

This will start the container, run the specified command, and exit.

## Networking

By default, the container has the same network access as your host machine.
This allows CycoD to access external resources like package repositories and
documentation.

Restricting network access is a bit more complicated as the AI agent needs
the network to get access to the AI services.  Thus this is left for future
work.

## Project Structure

- **[build.sh](build.sh)**: Script to build the Docker image with various options
- **[boxed.sh](boxed.sh)**: Script to run the Docker container with your work directory mounted
- **[Dockerfile](Dockerfile)**: Multi-target Dockerfile defining different variants
- **README.md**: This documentation file

The scripts use a declarative argument parser that makes them flexible and
extensible.

## Security Considerations

Boxed provides several security benefits to keep CycoD properly contained:

1. **Isolation**: CycoD is Boxed into a container, separated from your host system
2. **Limited access**: CycoD can only access files in your work directory and
   the mounted .cycod directory
3. **User permissions**: The container runs with your user ID, preventing
   privilege escalation

The containment ensures that CycoD:
- Cannot accidentally damage anything outside of the files you mapped into
  the container
- Cannot see, expose, or upload anything outside of the container
- Is constrained in what it can modify even if it gets "lost in its own little
  source tree"

This makes it much safer to let CycoD write and execute code, even potentially
risky operations like writing C code and running debuggers like gdb.

Since the user's home directory is not exposed (just the .cycod directory and
a read-only .gitconfig if it exists) we limit the exposure of other potential
sensitive information that would be otherwise visible from the user's home
directory, including browsing history, cookies, tokens, etc.

However, it's important to understand that Docker containers are not perfect
security boundaries:

- Container escape vulnerabilities are occasionally discovered
- Volume mounts still allow access to those specific directories
- The container runs with the same network access as the host by default

More advanced namespace controls for running the container are possible but
not yet implemented.  As tools like CycoD get more powerful, mechanisms like
Boxed will continue to evolve to help constrain and enable them.

Keeping CycoD Boxed significantly reduces risk compared to letting it run free
on your system, but you should still exercise caution with the code it generates
and executes.

## Troubleshooting

### Common Issues

**Container fails to build:**
- Ensure Docker is installed and running
- Check internet connectivity for downloading dependencies
- Try running with `--verbosity 3` for more detailed output

**Cannot access files from inside the container:**
- Verify the correct directory is mounted (check the `--dir` option)
- Ensure file permissions allow the container to access the files

**CycoD fails to run inside the container:**
- Verify CycoD was properly installed during build
- Try rebuilding with `--cleanup false` to preserve logs
- Check if you're using an appropriate variant for your project type

### Docker-Related Issues

**Docker permission errors:**
- Add your user to the docker group: `sudo usermod -aG docker $USER`
- Log out and back in for group changes to take effect

**Docker fails with "no space left on device":**
- Clean up unused Docker images: `docker system prune`
- Increase Docker's storage allocation in Docker Desktop settings

## Windows Support

Currently, Boxed is primarily designed for Linux, macOS, and Unix-like
environments.  On Windows, you need git installed in its default location
and Docker Desktop for Windows set up to run Linux containers.

There are two wrapper scripts, [build.cmd](build.cmd) and [boxed.cmd](boxed.cmd)
that need to be in the same directory as their respective [build.sh](build.sh)
and [boxed.sh](boxed.sh) counterparts.  As with Linux systems, you may wish to
copy the [boxed.cmd](boxed.cmd) and [boxed.sh](boxed.sh) scripts (both together)
to a directory that is in your path such that you can run the boxed command from
anywhere.

## Version Compatibility

Boxed has been tested with:
- CycoD versions: latest public releases
- Docker versions: 20.10 and newer
- Operating Systems:
  - Linux: Most modern distributions with Docker support (Ubuntu, Debian, Fedora, CentOS, etc.)
  - macOS: 12+ (Monterey and newer)
  - Unix-like systems: Any that support Docker
  - Windows: Windows 10/11 with WSL2

## Future Work

As tools like CycoD become more powerful, properly Boxing them will be
increasingly important to both constrain and enable them.  Planned improvements
include:

- Advanced namespace controls for additional security
- Windows-native support improvements
- Support for more specialized development environments
- Integration with container orchestration for multi-container scenarios

Note that building your own images to be used with Boxed should be rather
straightforward.  The [Dockerfile](Dockerfile) is both a useful set of
images and an example of how to do this.

## Why Was Boxed Created?

The key reason was to enable safe experimentation with CycoD and its ability to
write, compile, and test code in a controlled environment, reducing the risk to
the host system.

Additionally, Boxed allows using tools like .NET and PowerShell without
installing them directly on the host system, keeping your environment clean.

It also provides cross-platform compatibility, working cleanly on Mac and Linux
environments, with work in progress for Windows.

This was originally created for a tool called "ChatX" which has since been
refactored and renamed to "CycoD" (a rather fun pun).  The core motivation was
to be able to let the AI write, compile, and test code (including running
debuggers like gdb) without risking damage to the host system due to bugs in
the AI or just random "run-away" behavior that could happen.  In other words,
keeping it in a box.

## Interesting Note

The [build.sh](build.sh) and [boxed.sh](boxed.sh) scripts use a "declarative"
argument parser for bash scripts.  This is a particularly elegant pattern where
arguments are defined in one place and just work automatically.

I have written these kinds of declarative parsers in the past for Java, C#, and
C but each had their own extra bit of twists based on the language.  I also
really like the way the Rust clap crate does this and the Swift
'swift-argument-parser' mechanism.

This approach makes the scripts highly maintainable and extensible, as all
arguments are defined in a single place with their defaults and documentation,
similar to modern CLI frameworks in higher-level languages.

See more about this in my [ArguBASH](https://github.com/MichaelSinz/ArguBash) GitHub project.