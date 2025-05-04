#!/bin/bash
# Copyright 2025 - Michael Sinz
#
# This script is the wrapper to the docker images that
# contain the ChatX coding agent and tools.  It lets you
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

   # This provides the plaform that Docker should be using
   # when it runs your container.  On the Mac, you can
   # have two different platforms:
   #    linux/amd64 - Intel CPU x86-64
   #    linux/arm64 - Apple Silicon (!!! Powershell fails)
   platform=linux/amd64

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
# This "if" is here just so we can fold
if true; then
   function _error() {
      echo >&2 ERROR: "$@"
   }

   # Set all of the defaults but only if the variable is not already set
   # This way a user can override the defaults by setting them in their environment
   for default in ${ARGS_AND_DEFAULTS[@]}; do
      key=${default/=*}
      # Validate that the key is a valid variable name - if not, error with details
      if [[ ! $key =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
         _error "Parameter '$key' should start with a letter and only contain letters, numbers, and underscores"
         exit 1
      fi
      [[ -n ${!key} ]] || declare ${default}
   done

   function show_help() {
      # If we want long help (--help), parse out the help text from
      # the script comments for each of the defaults.  A fun way to
      # get the comments to also be the detailed help text.  Thus they
      # are declarative and directly related to the code.
      if [[ ${1} == --help ]] && [[ -f ${BASH_SOURCE} ]]; then
         help_text=""
         in_help=0
         while read -r line; do
            if [[ ${line} == *"ARGS_AND_DEFAULTS=("* ]]; then
               in_help=1
            elif [[ ${line} == ")" ]]; then
               break
            elif [[ ${in_help} -eq 1 ]]; then
               # Trim leading whitespace
               line="${line#"${line%%[![:space:]]*}"}"
               if [[ ${line} == "# "* ]]; then
                  # The comments are the extended help text
                  help_text+=" ${line}\n"
               elif [[ ${line} == *"="* ]]; then
                  argument="${line/=*}"
                  # If the script's default is different show it:
                  [[ ${!argument} == ${line/*=} ]] || help_text=" # original: ${line/*=}\n${help_text}"
                  declare "_help_${argument}"="${help_text} #------------------------------------------------------\n"
                  help_text=""
               fi
            fi
         done < "${BASH_SOURCE}"
      fi

      if [[ ${EXTRA_ARGS} == true ]]; then
         echo "Usage: ${BASH_SOURCE} [--<override> value] [--help|-h] <positional args>"
      else
         echo "Usage: ${BASH_SOURCE} [--<override> value] [--help|-h]"
      fi
      {
         local arg_indent="       "
         for var in ${ARGS_AND_DEFAULTS[@]}; do
            key=${var/=*}
            echo "${arg_indent}--${key//_/-}# default: ${!key}"
            long_help="_help_${key}"
            echo -e "${!long_help}"
         done
         if [[ ${EXTRA_ARGS} == true ]]; then
            echo "${arg_indent}-- # pass remaining arguments"
         fi
         if [[ -n ${!long_help} ]]; then
            echo "${arg_indent}-h # for quick argument summary"
         else
            echo "${arg_indent}--help # for more complete help"
         fi
      } | column -t -s $'#'
   }

   # Now, process the command line arguments - This way we can override the
   # default values via command line arguments
   while [[ $# -gt 0 ]]; do
      arg="${1}"
      shift 1
      # Help is a spacial case
      if [[ ${arg} == --help || ${arg} == -h ]]; then
         show_help ${arg}
         exit 0
      fi
      if [[ ${arg} == -- ]] && [[ ${EXTRA_ARGS} == true ]]; then
         # This is a special case for when you want to pass
         # the remaining arguments to the extra_args array
         extra_args+=("${@}")
         break
      elif [[ ${arg} == --* ]] || [[ ! ${EXTRA_ARGS} == true ]]; then
         valid=false
         for var in ${ARGS_AND_DEFAULTS[@]}; do
            key=${var/=*}
            if [[ ${arg} == --${key//_/-} ]]; then
               # if there is no additional argument or it looks like a flag
               # then it is invalid - this does mean you can't have a value
               # that starts with a dash "-" but for what we use, that is fine.
               # This catches typos or mistakes in the command line options.
               if [[ $# -lt 1 || ${1} == -* ]]; then
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
   for var in ${ARGS_AND_DEFAULTS[@]}; do
      key=${var/=*}
      [[ -n ${!key} ]] || unset ${key}
   done

   # Log the effective command line options we are running with
   # such that it would be easy to reproduce even if you had set some
   # of the values in your environment or via the command line.
   [[ ${verbosity} -gt 1 ]] && echo >&2 -e "\nRunning with these effective options:\n\n$(
         echo -e -n "${BASH_SOURCE}"
         for var in ${ARGS_AND_DEFAULTS[@]}; do
            key=${var/=*}
            echo -n " --${key//_/-} \"${!key}\""
         done
      )\n"
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

[[ ${verbosity} -gt 0 ]] && set -x
exec docker run \
   --platform linux/amd64 \
   --rm \
   --interactive \
   --tty \
   --name "${boxed_name}" \
   --hostname "${boxed_name}" \
   --workdir "${boxed_home}/src" \
   --user ${_user_id}:${_user_group} \
   --env "USER=${_user_name}" \
   --env "HOME=${boxed_home}" \
   --volume "${misc_dir}/passwd:/etc/passwd:ro" \
   --volume "${misc_dir}/group:/etc/group:ro" \
   --volume "${cycod_dir}:${boxed_home}/.cycod" \
   ${git_config:+--volume "${git_config}:${boxed_home}/.gitconfig:ro"} \
   --volume "${dir}:${boxed_home}/${boxed_work}" \
   "${boxed_image}:${variant}" \
   "${extra_args[@]}"