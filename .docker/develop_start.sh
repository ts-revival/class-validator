#!/usr/bin/env bash
set "-x"
set "-e"

# define the script and root dir
os="$(uname -s)"
if [ ${os} = "Linux" ]; then
    echo "Linux OS detected"
    SCRIPT_DIR="$(dirname $(readlink -f $0))"
elif [ ${os} = "Darwin" ]; then
    echo "MacOS detected"
    SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"
fi
ROOT_DIR="$(realpath "${SCRIPT_DIR}/..")"


# get our arguments
POSITIONAL=()
COMMANDS=()
BUILD=""
SUBPROJECT=""

# check we have the required .env file otherwise create them from the template
# if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
#     cp ${SCRIPT_DIR}/.env.template ${SCRIPT_DIR}/.env
# fi

# source those files
# set -o allexport
# source ${SCRIPT_DIR}/.env
# set +o allexport

export HOST_PATH=${ROOT_DIR}/

CLUSTER_ID="global_billing"
DOCKER_COMPOSE_FILES=""
DOCKER_ENV_FILES=""
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --build)
        BUILD="--build --remove-orphans --force-recreate"
        POSITIONAL+=("$1")
        shift # past argument
        ;;

        -c|--command)
        shift # past argument
        SHELL_COMMAND=$1
        shift # past argument
        ;;

        --services)
        shift # past argument
        SERVICES=$1
        shift # past argument
        ;;

        --no-tty)
        TTY=" "
        shift # past argument
        ;;

        --debug)
        DEBUG=true
        shift # past argument
        ;;

        *) # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ -z "${TTY}" ]; then
    TTY="-it"
fi

if [ ! -f "${ROOT_DIR}/.docker/.env" ]; then
    cp "${ROOT_DIR}/.docker/.env.template" "${ROOT_DIR}/.docker/.env"
fi

SUBPROJECT=$( cat "${ROOT_DIR}/.docker/.env.template" | grep "PROJECT_ID" | awk -F "=" '{print $2}' )
# check if the environment is already up, if not create it
if [ -z "$(docker ps | grep -w \"${SUBPROJECT}\" | awk '{print $1}')" ]
then
    COMMANDS+=("PROJECT_ID=\"${SUBPROJECT}\" PROJECT_PATH=\"${ROOT_DIR}\" docker-compose -f \"${ROOT_DIR}/.docker/docker-compose.yml\" --env-file \"${ROOT_DIR}/.docker/.env\" up -d ${BUILD} ${SERVICES}" )
fi

if [ ! -z ${SUBPROJECT} ]; then
    # if we have no command (like for instance passed by the CI) just run zsh
    if [ -z "${SHELL_COMMAND}" ]; then
        echo "No command passed";
        COMMANDS+=("docker exec ${TTY} ${SUBPROJECT}-development zsh")
    # otherwise execute the command
    else
        # add the up and exec
        COMMANDS+=("docker exec ${TTY} ${SUBPROJECT}-development zsh -c \"${SHELL_COMMAND}\"")
    fi
fi

# join the commands in a string and execute
COMMAND_STRING=$(printf " && %s" "${COMMANDS[@]}")
COMMAND_STRING=${COMMAND_STRING:3}

if [ -n "${DEBUG}" ]; then
    echo "${COMMAND_STRING}";
fi

eval "${COMMAND_STRING}"