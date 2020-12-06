#!/bin/bash
os="$(uname -s)"
if [ ${os} = "Linux" ]; then
    echo "Linux OS detected"
    SCRIPT_DIR=$(dirname $(readlink -f $0))
elif [ ${os} = "Darwin" ]; then
    echo "MacOS detected"
    SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
fi
ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")
export HOST_PATH=${ROOT_DIR}

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --clean)
        CLEAN=true
        shift
        ;;
    esac
done
PACKAGES="${ROOT_DIR}/packages/*"
for dir in ${PACKAGES}; do
    DOCKER_COMPOSE_FILES=""
    if [ -d "${dir}" ]; then
        for docker_compose_file in ${dir}/.docker/docker-compose*; do
            [ -f ${docker_compose_file} ] || continue
            DOCKER_COMPOSE_FILES="${DOCKER_COMPOSE_FILES} -f ${docker_compose_file}"
        done       
        # DOCKER_COMPOSE_FILES="-f ${dir}/.docker/docker-compose.yml"
        # temporary workaround, checking if we have an env.template. All projects should have one.
        [ -f "${dir}/.docker/.env.template" ] || continue
        cp "${dir}/.docker/.env.template" "${dir}/.docker/.env"
        DOCKER_ENV_FILES="--env-file ${dir}/.docker/.env"
        SUBPROJECT=$( cat ${dir}/.docker/.env.template | grep "PROJECT_ID" | awk -F "=" '{print $2}' )
        # check if the environment is already up, if not create it
        if [ -z "$(docker ps | grep -w \"${SUBPROJECT}\" | awk '{print $1}')" ]
        then
            COMMANDS+=("PROJECT_ID=${SUBPROJECT} PROJECT_PATH=${dir} docker-compose ${DOCKER_COMPOSE_FILES} ${DOCKER_ENV_FILES} down" )
        fi
    fi
done

# join the commands in a string and execute
COMMAND_STRING=$(printf " && %s" "${COMMANDS[@]}")
COMMAND_STRING=${COMMAND_STRING:3}

# docker-compose -f "${SCRIPT_DIR}/docker-compose.yml" -p "${PROJECT_ID}" down
if [ -n "${DEBUG}" ]; then
    echo "${COMMAND_STRING}";
fi
echo "${COMMAND_STRING}";
eval "${COMMAND_STRING}"