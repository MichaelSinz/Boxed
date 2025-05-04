# Can't Wait to Try Boxed CycoD?

## What is Boxed CycoD?

Boxed CycoD combines the powerful AI-powered coding assistant CycoD with
a secure Docker container environment.  The "Boxed" part keeps the enthusiastic
"CycoD" (our coding-obsessed assistant) safely contained - think of it as
padded walls that protect both the psycho dev and you, the user!

This guide will get you up and running with minimal steps.  No need to clone
repositories or build images - we'll use pre-built images to get you coding
with AI assistance in minutes.  More advanced users may wish to go to the
[full readme](README.md) to learn more details and build their own specialized
CycoD-in-a-Box images for their needs.

## Quick Setup (3 Simple Steps)

### 1. Download and set up the boxed script

```bash
# Create bin directory if it doesn't exist
mkdir -p ~/bin

# Download the boxed script
curl -o ~/bin/boxed https://raw.githubusercontent.com/MichaelSinz/Boxed/refs/heads/main/boxed.sh

# Make it executable
chmod +x ~/bin/boxed

# Add to PATH if needed (may need to open a new terminal after this)
# Skip this step if ~/bin is already in your PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Set the boxed image source

```bash
# Use the pre-built images
export boxed_image=michaelsinz/boxed
```

### 3. Run boxed in your project directory

```bash
cd ~/your/project/directory
boxed
```

You're now inside the container with CycoD ready to use!

## Using CycoD Inside the Box

Once inside the boxed environment, you need to configure CycoD:

```bash
# First time setup: The easiest way is to log in with GitHub
cycod github login

# Alternatively, you can manually set your API key if you already have one
# cycod config set api-key your-api-key-here

# Start an interactive chat session (simply run cycod with no options)
cycod

# Or ask a question directly without entering a chat session
cycod --input "What files are in this directory and what do they do?"
```

### Common CycoD Commands

```bash
# Get help with CycoD
cycod --help

# Run a specific command and let CycoD analyze the output
cycod --input "Explain what this command does: grep -r 'function' ."

# Let CycoD help you write or modify code
cycod --input "Create a simple web server in Python"

# During a chat session, use special commands:
# /clear - Clear the conversation
# /save - Save the conversation
# /cost - Show token usage costs
# /file <filename> - View a file
# /search <pattern> - Search for patterns in code
```

## Choosing a Variant (Optional)

By default, you'll get the `large` variant which includes tools for multiple
languages.  If you need a smaller, language-specific variant:

```bash
# Example: For Python projects
boxed --variant python
```

For a complete list of available variants and their details, please refer to the
[Boxed README](README.md#container-variants).

## Exiting

To exit the boxed environment, simply type:

```bash
exit
```

## Troubleshooting

1. **API key issues**: If CycoD can't connect to the AI provider, verify your
   API key with `cycod config get api-key`

2. **Permission errors**: If you see permission issues, make sure the script is
   executable (`chmod +x ~/bin/boxed`)

3. **Docker errors**: Ensure Docker is installed and running on your system

4. **Path issues**: If `boxed` command isn't found, verify `~/bin` is in your
   PATH with `echo $PATH`

## Want More?

For more details:
- [Boxed README](README.md)
- [CycoD Documentation](https://github.com/robch/cycod/blob/master/README.md)

Enjoy having your very own (safely contained) coding assistant at your
fingertips!