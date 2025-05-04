# Boxed - a safer way to run CycoD

Boxed is a containerization solution for running the CycoD AI coding tool in a
safer, controlled Docker environment.  CycoD is an AI-powered tool that can
write, compile, and test code, and Boxed provides a secure sandbox to prevent
accidental damage to your system while allowing CycoD to function fully.

This directory has a [build script](build.sh), a multi-target [Dockerfile](Dockerfile),
and the [boxed script](boxed.sh) that runs a docker container with your work
directory in it and your selected tools, ready for the CycoD tool to start
coding/debugging.

## Prerequisites

- Docker (latest stable version recommended)
- Bash shell environment
- Git (for building from source or version control integration)
- Internet connection for initial container build

## Quick Start

1. Build the boxed container by running the [build.sh](build.sh) script:
   ```bash
   ./build.sh
   ```

2. Copy the [boxed.sh](boxed.sh) script to your local path for easier access:
   ```bash
   cp boxed.sh ~/bin/boxed
   chmod +x ~/bin/boxed
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

### Available Variants

| Variant     | Description                                          | Included Languages & Tools                                               |  Size     |
|-------------|------------------------------------------------------|--------------------------------------------------------------------------|-----------|
| `large`     | Complete development environment with many languages | C#, C/C++, Rust, Java, Go, Node.js, TypeScript, Python, Ruby, PowerShell | 3.15 GB   |
| `c-sharp`   | C# development environment                           | C#, .NET SDK, PowerShell                                                 | 0.92 GB   |
| `c-cpp`     | C/C++ development environment                        | C, C++, gcc, g++, gdb                                                    | 1.29 GB   |
| `rust`      | Rust development environment                         | Rust, Cargo, rustfmt, clippy                                             | 1.52 GB   |
| `nodejs`    | Node.js development environment                      | Node.js, npm                                                             | 1.66 GB   |
| `typescript`| TypeScript development environment                   | Node.js, npm, TypeScript                                                 | 1.68 GB   |
| `java`      | Java development environment                         | OpenJDK                                                                  | 1.65 GB   |
| `python`    | Python development environment                       | Python3, pip                                                             | 1.28 GB   |

More variants are bound to be added and sizes are variable based on platform
and updates to those tools over time.

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

### Building Options

The build script offers several important options to customize your container:

```bash
# Show help
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

For the boxed script:
```bash
# Show help
./boxed.sh --help

# Use a specific variant
./boxed.sh --variant python

# Use a specific working directory
./boxed.sh --dir /path/to/project

# Run a command non-interactively
./boxed.sh -- cycod --help

# Specify a custom name for the container
./boxed.sh --boxed-name my-project-container
```

### Running Commands in the Container

You can run commands directly in the container instead of entering an
interactive shell:

```bash
./boxed.sh -- cycod create-project --type console-app
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

Boxed provides several security benefits:

1. **Isolation**: CycoD operates in a container isolated from your host system
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

However, it's important to understand that Docker containers are not perfect
security boundaries:

- Container escape vulnerabilities are occasionally discovered
- Volume mounts still allow access to those specific directories
- The container runs with the same network access as the host by default

More advanced namespace controls for running the container are possible but
not yet implemented.  As tools like CycoD get more powerful, mechanisms like
Boxed will continue to evolve to help constrain and enable them.

Boxed significantly reduces risk compared to running CycoD directly on your
system, but you should still exercise caution with the code it generates and
executes.

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
environments.  Windows support that does not depend on WSL is still in
development but since it works well with WSL2 and Docker (Docker desktop
for Windows integration or native Linux Docker in WSL2 both work)

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

As tools like CycoD become more powerful, mechanisms like Boxed will be needed
to help constrain and enable them.  Planned improvements include:

- Advanced namespace controls for additional security
- Windows-native support improvements
- Support for more specialized development environments
- Integration with container orchestration for multi-container scenarios

Note that building your own images to be used with Boxed should be rather
straight forward.  The [Dockerfile](Dockerfile) is both a useful set of
images and an example of how to do this.

## Why Was Boxed Created?

The key reason was to enable safe experimentation with CycoD and its ability to
write, compile, and test code in a controlled environment, reducing the risk to
the host system.

Additionally, Boxed allows using tools like .NET and PowerShell without
installing them directly on the host system, keeping your environment clean.

It also provides cross-platform compatibility, working cleanly on Mac and Linux
environments, with work in progress for Windows.

Originally created for a tool called "ChatX" which has since been refactored
and renamed to "CycoD" (a rather fun pun).  The core motivation was to be able
to let the AI write, compile, and test code (including running debuggers like
gdb) without risking damage to the host system due to bugs in the AI or just
random "run away" behavior that could happen.

## Interesting Note

The build.sh and boxed.sh scripts use a "declarative" argument parser for bash
scripts.  This is a particularly elegant pattern where arguments are defined in
one place and just work automatically.

I have written these kinds of declarative parsers in the past for Java, C#, and
C but each had their own extra bit of twists based on the language.  I also
really like the way the Rust clap crate does this and the Swift
'swift-argument-parser' mechanism.

This approach makes the scripts highly maintainable and extensible, as all
arguments are defined in a single place with their defaults and documentation,
similar to modern CLI frameworks in higher-level languages.