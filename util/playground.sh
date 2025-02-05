#!/usr/bin/env bash

# Copyright (C) 2023 Jingli Chen (Wine93), NetEase Inc.

# see also: https://github.com/Burnett01/rsync-deployments/issues/21

############################  GLOBAL VARIABLES
g_obm_cfg=".obm.cfg"
g_worker_dir="/curve"
g_container_name="curve-build-playground.master"
g_container_image="opencurvedocker/curve-base:build-debian11"
g_init_script=$(cat << EOF
useradd -m -s /bin/bash -N -u $UID $USER
echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers
chmod 0440 /etc/sudoers
chmod g+w /etc/passwd
echo 'alias ls="ls --color"' >> /home/${USER}/.bashrc
EOF
)
g_install_script=$(cat << EOF
apt-get update
apt-get -y install tree rsync golang jq vim python3-pip maven >/dev/null
curl -sSL https://bit.ly/install-xq | sudo bash >/dev/null 2>&1
pip3 install cpplint >/dev/null 2>/dev/null
EOF
)

############################  BASIC FUNCTIONS
parse_cfg() {
    local args=`getopt -o v: --long version: -n "playground.sh" -- "$@"`
    eval set -- "${args}"
    if [ ! -f "${g_obm_cfg}" ]; then
        die "${g_obm_cfg} not found\n"
    fi
    g_container_name=$(cat < "${g_obm_cfg}" | grep -oP '(?<=container_name: ).*')
    g_container_image=$(cat < "${g_obm_cfg}" | grep -oP '(?<=container_image: ).*')
}

create_container() {
    id=$(docker ps --all --format "{{.ID}}" --filter name=${g_container_name})
    if [ -n "${id}" ]; then
        return
    fi

    docker run -v "$(pwd)":${g_worker_dir} \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -dt \
        --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined \
        --restart always \
        --env "UID=$(id -u)" \
        --env "USER=${USER}" \
        --env "TZ=Asia/Shanghai" \
        --hostname "playground" \
        --name "${g_container_name}" \
        --workdir ${g_worker_dir} \
        "${g_container_image}"
    docker exec "${g_container_name}" bash -c "${g_init_script}"
    docker exec "${g_container_name}" bash -c "${g_install_script}"
    success "create ${g_container_name} (${g_container_image}) success :)"
}

enter_container() {
    docker exec \
        -u "$(id -u):$(id -g)" \
        -it \
        --env "TERM=xterm-256color" \
        "${g_container_name}" /bin/bash
}


main() {
    source "util/basic.sh"
    parse_cfg "$@"
    create_container
    enter_container
}

############################  MAIN()
main "$@"
