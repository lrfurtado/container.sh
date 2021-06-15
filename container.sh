#!/bin/bash
# Prior art https://blog.nicolasmesa.co/posts/2018/08/container-creation-using-namespaces-and-bash/
set -eu
set -o pipefail
progname=$0

cleanup() {
    rm -rf $tmpdir
    log "Exiting"
}

trap cleanup SIGINT EXIT SIGHUP

update_time() {
    NOW=$(date +"%m-%d-%Y %H:%M:%S")
}

die() {
    update_time
    if [ -t 0 ]; then
        echo "${NOW}":$'\e[31mDIED\e[0m'": $*" >&2
    else
        echo "${NOW}:DIED: $*" >&2
    fi
    echo . >&2
    echo . >&2
    echo . >&2
    logger "${progname}: DIED"
    exit 1
}

log() {
    update_time
    echo "${NOW}:INFO: $*"
}

log_system() {
    log "$*"
    logger "${progname} $*"
}

usage() {
    echo
}

extract_image() {
    [ ! -d /tmp/debian_cache ] && debootstrap stretch /tmp/debian_cache http://deb.debian.org/debian
    tmpdir=$(mktemp -d)
    cp -a /tmp/debian_cache/* $tmpdir
}

create_container() {
    local cgrp
    cgrp=/sys/fs/cgroup/container.sh
    log_system "started container"
    mkdir -p $tmpdir/proc
    mount -t proc proc $tmpdir/proc
    (
        mkdir -p $cgrp
        echo $BASHPID >$cgrp/cgroup.procs
        #TODO(lrfurtado): need to implement overlafs support instead of relying image contents being copied to new location
        unshare --mount --user --map-root-user --mount-proc=$tmpdir/proc --fork --pid /sbin/chroot $tmpdir
        umount $tmpdir/proc
    )
    rmdir $cgrp
    log_system "exited from container"
}

main() {
    exec > >(tee /tmp/${progname}.$$.log) 2>&1
    while getopts ":h" opt; do
        case ${opt} in
        h)
            usage
            ;;
        \?)
            echo "Invalid Option: -$OPTARG" 1>&2
            exit 1
            ;;
        esac
    done
    shift $((OPTIND - 1))
    extract_image
    create_container
}

main "$@"
