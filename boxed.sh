#!/bin/bash
# Copyright 2025 - Michael Sinz
#
# This script is the wrapper to the docker images that
# contain the CycoD coding agent and tools.  It lets you
# run the agent in a relatively safe environment while still
# allowing it to make changes, compile, test, and even debug
# the code.  (Within reason)
#
# The image definitions can be found in the docker directory.
# There are various images that can be made, from very focused
# images to those that are very powerful and diverse.
#
# This script has a number of command line options that are
# handled via the declarative argument parser I have written
# for bash scripts.
#
# We define this to get the default cpu type for the
# platform argument.  I did not want to in-line this into
# the default itself so I made a local function that it uses.
_ARCH() { [[ ${HOSTTYPE:-$(uname -m)} =~ arm64|aarch64|armv8|arm.*64 ]] && echo 'arm64' || echo 'amd64'; }
#
#################################################################
# ARGUMENT DEFINITION
#
# Turn this on if you want to collect positional arguments
# into the "extra_args" array.  This includes support for
# passing the remainder of the command line via "--"
# If not set to true, then the script will only accept
# the arguments that are defined in the ARGS_AND_DEFAULTS
EXTRA_ARGS=true
# This is a list of arguments that are not
# tied to an option.  Useful if you want positionals.
extra_args=()
# Arrays to hold environment variables and volume mounts
declare -a env_vars=()
declare -a volume_mounts=()
ARGS_AND_DEFAULTS=(
   # The directory you want to mount into
   # the boxed workspace to work on.
   dir=${PWD}

   # This is the variant of the boxed image
   # that will be used.  Note that this will
   # be used in the tag of the image.
   variant=large

   # This is the docker image name to use for
   # what we build - the tag will be the variant
   boxed_image=boxed

   # This provides the platform that Docker should be using
   # when it pulls/runs the container. The default is set
   # to the CPU architecture detected:
   #    linux/arm64 - If running on ARM64/Apple Silicon
   #    linux/amd64 - If running on x86-64/Intel or others
   platform=linux/$(_ARCH)

   # This is the directory where cycod will
   # store its token, history, etc
   cycod_dir=${HOME}/.cycod

   # This is the name of the workspace in
   # the container that we will have for
   # our home.  You likely do not wish to
   # change this.
   boxed_home=/workspace

   # The name of the directory within the
   # workspace that will be mounted
   boxed_work=src

   # Name of the running container
   boxed_name=boxed-$$

   # The network to use in Docker for the box.
   # The default is normally perfect but if you
   # need host network, set it to host.
   boxed_network=default

   # This is the user's gitconfig file
   # Can be replaced with a different file
   # if you want to have a specific one for
   # cycod interactions.  Will not be used
   # if it does not exist.
   git_config=${HOME}/.gitconfig

   # The verbosity level of script output
   # 0 = minimal output (quiet)
   # 1 = show docker run command line (recommended)
   # 2 = log effective command line parameters
   # 3 = trace almost everything
   verbosity=1
)
# END of ARGUMENT DEFINITION
##################################################################

##################################################################
# ARGUMENT PARSER
#
# Data driven argument parser - Using bash trickery...
# This "if" is here just so we can fold it away in many editors
if true; then
   # Note that this argument parser is designed to be used in a script
   # directly such that the script is fully self-contained.
   # Also, by using the structure seen in this file, the ArguBASH-completion
   # definition can be sourced into your bash environment to provide tab
   # completion for the arguments defined by this parser.

   function _error() {
      echo >&2 ERROR: "$@"
   }

   # We compute max arg length here while checking for defaults.
   # We start at 4 as "help" is 4 characters and we always support help.
   ARGS_AND_DEFAULTS_MAX_LEN=4

   # Set all of the defaults but only if the variable is not already set
   # This way a user can override the defaults by setting them in their environment
   for default in "${ARGS_AND_DEFAULTS[@]}"; do
      key=${default%=*}
      # Validate that the key is a valid variable name - if not, error with details
      if [[ ! $key =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
         _error "Parameter '$key' should start with a letter and only contain letters, numbers, and underscores"
         exit 1
      fi
      [[ ${#key} -le ${ARGS_AND_DEFAULTS_MAX_LEN} ]] || ARGS_AND_DEFAULTS_MAX_LEN=${#key}
      [[ -n ${!key} ]] || declare ${key}="${default#*=}"
   done

   function show_help() {
      # If we want long help (--help), parse out the help text from
      # the script comments for each of the defaults.  A fun way to
      # get the comments to also be the detailed help text.  Thus they
      # are declarative and directly related to the code.
      local arg_indent="    "
      ARGS_AND_DEFAULTS_MAX_LEN=$(( ARGS_AND_DEFAULTS_MAX_LEN + 2 ))
      if [[ ${1} == --help ]] && [[ -f ${BASH_SOURCE} ]]; then
         local help_text=""
         local left_blank=$(printf "${arg_indent}%-*s" ${ARGS_AND_DEFAULTS_MAX_LEN} "")
         local in_help=0
         while read -r line; do
            if [[ ${line} == "ARGS_AND_DEFAULTS=("* ]]; then
               in_help=1
            elif [[ ${line} == ")" ]]; then
               break
            elif [[ ${in_help} -eq 1 ]]; then
               # Trim leading whitespace
               line="${line#"${line%%[![:space:]]*}"}"
               if [[ ${line} == "# "* ]]; then
                  # The comments are the extended help text
                  help_text+="${left_blank} ${line###}\n"
               elif [[ ${line} == *"="* ]]; then
                  argument="${line%=*}"
                  # If the script's default is different show it:
                  [[ ${!argument} == ${line#*=} ]] || help_text="${left_blank}  original: ${line#*=}\n${help_text}"
                  declare "_help_${argument}"="${help_text}${left_blank} ------------------------------------------------------"
                  help_text=""
               fi
            fi
         done < "${BASH_SOURCE}"
      fi

      if [[ ${EXTRA_ARGS} == true ]]; then
         echo "Usage: ${BASH_SOURCE} [--<override> value] [-e ENV=VALUE] [-v HOST_PATH:CONTAINER_PATH] [--help|-h] <positional args>"
      else
         echo "Usage: ${BASH_SOURCE} [--<override> value] [-e ENV=VALUE] [-v HOST_PATH:CONTAINER_PATH] [--help|-h]"
      fi
      {
         for var in "${ARGS_AND_DEFAULTS[@]}"; do
            key=${var%=*}
            printf "${arg_indent}--%-*s" ${ARGS_AND_DEFAULTS_MAX_LEN} "${key//_/-}"
            echo "default: ${!key}"
            long_help="_help_${key}"
            [[ ! -n ${!long_help} ]] || echo -e "${!long_help}"
         done
         echo "${arg_indent}-e, --env ENV=VALUE # set environment variable (can be used multiple times)"
         echo "${arg_indent}-v, --volume HOST_PATH:CONTAINER_PATH # add volume mount (can be used multiple times)"
         if [[ ${EXTRA_ARGS} == true ]]; then
            printf "${arg_indent}--%-*s" ${ARGS_AND_DEFAULTS_MAX_LEN} ""
            echo "pass remaining arguments"
         fi
         if [[ -n ${!long_help} ]]; then
            printf "${arg_indent}-%-*s " ${ARGS_AND_DEFAULTS_MAX_LEN} "h"
            echo "for quick argument summary"
         else
            printf "${arg_indent}--%-*s" ${ARGS_AND_DEFAULTS_MAX_LEN} "help"
            echo "for more complete help"
         fi
      }
   }

   # Now, process the command line arguments - This way we can override the
   # default values via command line arguments
   while [[ $# -gt 0 ]]; do
      arg="${1}"
      shift 1
      # Help is a special case
      if [[ ${arg} == --help || ${arg} == -h ]]; then
         show_help ${arg}
         exit 0
      fi
      # Handle environment variables
      if [[ ${arg} == --env || ${arg} == -e ]]; then
         if [[ $# -lt 1 ]]; then
            _error "Argument '${arg}' requires a value"
            exit 1
         fi
         env_vars+=("--env" "${1}")
         shift 1
         continue
      fi
      # Handle volume mounts
      if [[ ${arg} == --volume || ${arg} == -v ]]; then
         if [[ $# -lt 1 ]]; then
            _error "Argument '${arg}' requires a value"
            exit 1
         fi
         volume_mounts+=("--volume" "${1}")
         shift 1
         continue
      fi
      if [[ ${arg} == -- ]] && [[ ${EXTRA_ARGS} == true ]]; then
         # This is a special case for when you want to pass
         # the remaining arguments to the extra_args array
         extra_args+=("${@}")
         break
      elif [[ ${arg} == --* ]] || [[ ! ${EXTRA_ARGS} == true ]]; then
         valid=false
         for var in "${ARGS_AND_DEFAULTS[@]}"; do
            key=${var%=*}
            if [[ ${arg} == --${key//_/-} ]]; then
               # if there is no additional argument or it looks like a flag
               # then it is invalid - this does mean you can't have a value
               # that starts with a dash "-" but for what we use, that is fine.
               # This catches typos or mistakes in the command line options.
               if [[ $# -lt 1 || ${1} == --* ]]; then
                  _error "Argument '${arg}' requires a value"
                  exit 1
               fi
               valid=true
               declare ${key}="${1}"
               shift 1
               break
            fi
         done
         if [[ ${valid} == false ]]; then
            _error "Unknown argument: '${arg}'"
            show_help -h >&2
            exit 1
         fi
      else
         # Most likely a positional argument
         extra_args+=("${arg}")
      fi
   done

   # Unset any that are blank (trick used later)
   for var in "${ARGS_AND_DEFAULTS[@]}"; do
      key=${var%=*}
      [[ -n ${!key} ]] || unset ${key}
   done

   # Log the effective command line options we are running with
   # such that it would be easy to reproduce even if you had set some
   # of the values in your environment or via the command line.
   # The trick to get the command line arguments to be printed with whatever
   # escaping needed to get them to turn out correctly for the shell is to
   # let the shell log it for us and we just clean it up.
   readonly RUNNING_WITH_OPTIONS=$(
      declare -a effective_cmd_args=("${BASH_SOURCE}")
      for var in "${ARGS_AND_DEFAULTS[@]}"; do
         key=${var%=*}
         effective_cmd_args+=("--${key//_/-}" "${!key}")
      done
      
      # Add environment variables and volume mounts to the effective command
      for ((i=0; i<${#env_vars[@]}; i+=2)); do
         effective_cmd_args+=("${env_vars[i]}" "${env_vars[i+1]}")
      done
      for ((i=0; i<${#volume_mounts[@]}; i+=2)); do
         effective_cmd_args+=("${volume_mounts[i]}" "${volume_mounts[i+1]}")
      done

      [[ ${#extra_args} -lt 1 ]] || effective_cmd_args+=("--" "${extra_args[@]}")
      effective_cmd_line=$( (set -x; : "${effective_cmd_args[@]}") 2>&1 )
      echo "${effective_cmd_line/*+ : }"
   )
   [[ ${verbosity-0} -lt 2 ]] || echo >&2 -e "\nRunning with these effective options:\n\n${RUNNING_WITH_OPTIONS}\n"
fi
# END of ARGUMENT PARSER
##################################################################

# The real work starts here - with the variables set as per the
# defaults (or user provided options to replace the defaults)

# This check is only really to validate that the directory exists
# and only when the user overrides the default value.
if [[ ! -d ${dir} ]]; then
   _error "Directory '${dir}' does not exist (given as the --dir argument)"
   exit 1
fi

# If we are above level 2 verbosity, turn on tracing here...
[[ ${verbosity} -gt 2 ]] && set -x

mkdir -p "${cycod_dir}"
if [[ ! -d ${cycod_dir} ]]; then
   _error "Could not find or create directory '${cycod_dir}'"
   exit 1
fi

# Normalize the directory name so we can use it reliably
cycod_dir=$(cd "${cycod_dir}"; pwd)

# We will use this directory to make some files for the user's
# definition within the container.  This way they have the same
# UID/GID as externally without the need for full UID mapping.
# (which not all versions of docker support)
misc_dir="${cycod_dir}/.misc"
mkdir -p "${misc_dir}"

_user_id=${UID-$(id -u)}
_user_name=${USER-$(id -u -n)}
_user_group=$(id -g)

cat >"${misc_dir}/passwd" << PASSWD
root:x:0:0:root:/root:/bin/false
${_user_name}:x:${_user_id}:${_user_group}:${_user_name}:${boxed_home}:/bin/bash
PASSWD

cat >"${misc_dir}/group" << GROUP
root:x:0:
${_user_name}:x:${_user_group}:
GROUP

# If the gitconfig file does not exist, unset the git_config variable
[[ -f ${git_config} ]] || unset git_config

# This MSYS_NO_PATHCONV is needed when running in MINGW bash (native on
# windows, such as the bash that comes with Windows GIT)  It is totally
# inert on Linux, even WSL.  The problem is that without this, arguments
# that look like paths are converted to "Windows" paths, which is not
# good when it is a path within the container or a path to an image.
#
# Note that this has been tested with GIT's bash and Docker Desktop
# on Windows.
export MSYS_NO_PATHCONV=1

# Baseline environment variables
base_env_args=(
   "--env" "USER=${_user_name}"
   "--env" "HOME=${boxed_home}"
)

# Baseline volume mounts
base_volume_args=(
   "--volume" "${misc_dir}/passwd:/etc/passwd:ro"
   "--volume" "${misc_dir}/group:/etc/group:ro"
   "--volume" "${cycod_dir}:${boxed_home}/.cycod"
   "--volume" "${dir}:${boxed_home}/${boxed_work}"
)

# Add git config if provided
if [[ -n "${git_config}" ]]; then
   base_volume_args+=("--volume" "${git_config}:${boxed_home}/.gitconfig:ro")
fi

[[ ${verbosity} -gt 0 ]] && set -x
exec docker run \
   --platform ${platform} \
   --rm \
   --interactive \
   --tty \
   --name "${boxed_name}" \
   --hostname "${boxed_name}" \
   --network "${boxed_network}" \
   --workdir "${boxed_home}/src" \
   --user ${_user_id}:${_user_group} \
   "${base_env_args[@]}" \
   "${env_vars[@]}" \
   "${base_volume_args[@]}" \
   "${volume_mounts[@]}" \
   "${boxed_image}:${variant}" \
   "${extra_args[@]}"