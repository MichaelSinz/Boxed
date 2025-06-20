#!/bin/bash
# Copyright 2025 - Michael Sinz
#
# This script is the build script to help build the docker
# image / images for our AI coding tool.
#
# The image definitions can be found in the dockerfiles directory.
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
EXTRA_ARGS=false
# This is a list of arguments that are not
# tied to an option.  Useful if you want positionals.
extra_args=()
ARGS_AND_DEFAULTS=(
   # This is the variant of the boxed image
   # that we will build.  Note that this will
   # be used in the tag of the image.
   # Special 'ALL' variant for build will build all
   # of the available variants in the Dockerfile
   variant=large

   # A suffix to add to the variant tag for the image.
   # Useful when wishing to have the same Dockerfile
   # produce different variants due to, for example,
   # the changed git branch or hash to build from.
   variant_suffix=""

   # This is the docker image name to use for
   # what we build - the tag will be the variant
   boxed_image=boxed

   # During the image build, clean up any temporary data
   # in the image such as the apt cache or the source
   # code of CycoD when building from source.  This makes
   # smaller images if you need/want.
   cleanup=true

   # Install/build cycod from:
   #    package - From published tool package
   #    git     - From source from git
   #    source  - From local source
   from=git

   # The build type when installing from source
   # Valid types:  "release" and "debug"
   build_type=release

   # When building from git, this is the branch/tag that
   # is initially cloned.  If the hash is not set to "any"
   # then the actual commit will be changed to that hash.
   git_branch=master

   # When building from git, this specifies the specific
   # git hash to use.  If set to "any" it will use the
   # branch/tag that was cloned.
   git_hash=any

   # Docker build output type - this is passed to docker
   # build.  Set it to empty string to show in whatever
   # the docker build default is.
   progress=plain

   # If this is set to true, try to push the image after
   # it builds.  Warning:  You likely need to set the
   # image name to include your repository information
   # such that this works
   push=false

   # This provides the platform that Docker should be using
   # when it builds your container. The default is set to
   # the CPU architecture detected:
   #    linux/arm64 - If running on ARM64/Apple Silicon
   #    linux/amd64 - If running on x86-64/Intel or others
   platform=linux/$(_ARCH)

   # This is the Dockerfile to use
   dockerfile=$(cd "$(dirname "${BASH_SOURCE}")"; pwd)/Dockerfile

   # The path to the cycod local source tree for building
   # from the source tree.  Not used if building from git
   # or installing from source
   cycod_source=$(cd "$(dirname "${BASH_SOURCE}")/.."; pwd)

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
         echo "Usage: ${BASH_SOURCE} [--<override> value] [--help|-h] <positional args>"
      else
         echo "Usage: ${BASH_SOURCE} [--<override> value] [--help|-h]"
      fi
      {
         for var in "${ARGS_AND_DEFAULTS[@]}"; do
            key=${var%=*}
            printf "${arg_indent}--%-*s" ${ARGS_AND_DEFAULTS_MAX_LEN} "${key//_/-}"
            echo "default: ${!key}"
            long_help="_help_${key}"
            [[ ! -n ${!long_help} ]] || echo -e "${!long_help}"
         done
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
      [[ ${#extra_args} -lt 1 ]] || effective_cmd_args+=("--" "${extra_args[@]}")
      effective_cmd_line=$( (set -x; : "${effective_cmd_args[@]}") 2>&1 )
      echo "${effective_cmd_line/*+ : }"
   )
   [[ ${verbosity-0} -lt 2 ]] || echo >&2 -e "\nRunning with these effective options:\n\n${RUNNING_WITH_OPTIONS}\n"
fi
# END of ARGUMENT PARSER
##################################################################

# If we are above level 2 verbosity, turn on tracing here...
[[ ${verbosity} -gt 1 ]] && set -x

# Check if the docker file has the variant
if [ -f "${dockerfile}" ]; then
   variants=${variant}
   if [ "${variant}" = "ALL" ]; then
      variants=$(awk '/^FROM .* AS /{ print $4 }' "${dockerfile}")
   else
      if ! grep -q "^FROM .* AS ${variant}" "${dockerfile}"; then
         [ "${variant}" = "help" ] || _error "Variant '${variant}' not found!"
         echo >&2 "Available variants:"
         awk '/^FROM .* AS /{ print "  " $4 }' "${dockerfile}" | sort >&2
         exit 1
      fi
   fi
else
   _error "Could not find Dockerfile: '${dockerfile}'"
   exit 1
fi

# Check that the git hash is a valid hash or "all"
# This means at least 7 hex characters (short hash) and up to 40 (full hash)
if [[ ! ${git_hash} =~ ^[0-9A-Fa-f]{7,40}$ ]] && [[ ! ${git_hash} == any ]]; then
   _error "Invalid git hash:  '${git_hash}'"
   exit 1
fi

# If we are not building from local source, we change the build context to here
[ "${from}" = "source" ] || cycod_source=$(dirname "${dockerfile}")

# If we are above level 0 verbosity, turn on tracing here...
[[ ${verbosity} -gt 0 ]] && set -x
for variant in $variants; do
   docker build \
      --build-arg "CLEANUP=${cleanup}" \
      --build-arg "CYCOD_FROM=${from}" \
      --build-arg "CYCOD_BUILD=${build_type}" \
      --build-arg "CYCOD_BRANCH=${git_branch}" \
      --build-arg "CYCOD_HASH=${git_hash}" \
      ${progress+--progress ${progress}} \
      ${platform+--platform ${platform}} \
      --target ${variant} \
      --file "${dockerfile}" \
      --tag ${boxed_image}:${variant}${variant_suffix} \
      "${cycod_source}" || exit 1
   [[ ${push} == 'true' ]] && docker push ${boxed_image}:${variant}${variant_suffix}
done