#!/bin/sh

set -e

TF_VERSION=${TF_VERSION:-0.12.29}
ARCH=${ARCH:-amd64}

fail()
{
    printf >&2 "${1}\n"
    exit 1
}

warn()
{
    printf >&2 "${1}\n"
    return 1
}

usage()
{
    msg="Usage: ${0} -i <instance-name> -p <project-id> -s <subnetwork> [-P <subnetwork-project-id>] [-r <region>] [-y] [-d] [-h]\n"
    msg="${msg}    -i <instance-name>         (Required) Name given to AWX instance.\n"
    msg="${msg}    -p <project-id>            (Required) ID of GCP project.\n"
    msg="${msg}    -s <subnetwork>            (Required) Subnetwork in which AWX instance is created.\n"
    msg="${msg}    -P <subnetwork-project-id> (Optional) ID of subnetwork project, if using a shared VPC.\n"
    msg="${msg}    -r <region>                (Optional) GCP region, defaults to us-central1.\n"
    msg="${msg}    -y                         (Optional) Answer yes to proceed to create or destroy resources.\n"
    msg="${msg}    -d                         (Optional) Destroy an instance which was previously\n"
    msg="${msg}                                          created with the same parameters.\n"
    msg="${msg}    -h                         (Optional) Help message.\n"

    fail "${msg}"
}

retrieve_terraform()
{
    local os=`uname -s | tr [:upper:] [:lower:]`
    local tf_archive="terraform_${TF_VERSION}_${os}_${ARCH}.zip"
    local url="https://releases.hashicorp.com/terraform/${TF_VERSION}/${tf_archive}"

    echo >&2 "Downloading Terraform archive ${tf_archive}..."
    curl -sLOf ${url} || fail "Failed to download Terraform archive ${tf_archive}..."

    echo >&2 "Extracting ${tf_archive} to ./terraform..."
    rm -f ./terraform
    unzip -qq ${tf_archive} terraform || fail "Failed to extract ${tf_archive}..."
    rm -f ${tf_archive}
}

check_terraform_version()
{
    local tf_exec=${1}
    local tf_version=`${tf_exec} version | head -n 1`
    if [ "${tf_version}" = "Terraform v${TF_VERSION}" ]; then
	echo >&2 "Terraform executable ${tf_exec} version matches v${TF_VERSION}..."
        echo "${tf_exec}"
        return
    fi
    warn "Terraform executable ${tf_exec} has version ${tf_version}, wanted v${TF_VERSION}..."
}

find_terraform()
{
    if [ -x ./terraform ]; then
        check_terraform_version ./terraform && return
    fi
    local tf_exec=`which terraform || true`
    if [ -n "${tf_exec}" ]; then
        check_terraform_version "${tf_exec}" && return
    fi
}

run_terraform()
{
    local instance_name=${1}
    local project_id=${2}
    local subnetwork=${3}
    local subnetwork_project_id=${4}
    local region=${5}
    local proceed=${6}
    local destroy=${7}

    local tf_exec=`find_terraform`
    if [ -z "${tf_exec}" ]; then
	retrieve_terraform
	tf_exec=./terraform
    fi

    ${tf_exec} init
    ${tf_exec} plan -out plan.out \
        -var instance_name="${instance_name}" \
        -var project_id="${project_id}" \
        -var subnetwork="${subnetwork}" \
        -var subnetwork_project_id="${subnetwork_project_id}" \
        -var region="${region}" \
        ${destroy}

    if [ "${proceed}" != 1 ]; then
        printf "Please review any changes above. Do you want to continue (y/N)?  "
        read input
        echo "${input}" | grep -qE '[Yy]([Ee][Ss])?' && proceed=1
    fi

    if [ "${proceed}" = 1 ]; then
        ${tf_exec} apply plan.out
    else
        echo "No changes will be made, exiting."
    fi
}

find_credentials()
{
    local credentials_file=application_default_credentials.json
    for directory in "${HOME}/.config/gcloud" "${CLOUDSDK_CONFIG}"; do
        if [ -r "${directory}/${credentials_file}" ]; then
            echo "${directory}/${credentials_file}"
            return
        fi
    done
}

ensure_auth()
{
    local credentials=`find_credentials`
    if [ -z "${credentials}" ]; then
        echo >&2 "Retrieving GCP credentials..."
        gcloud --quiet auth application-default login
    fi
    credentials=`find_credentials`
    if [ -z "${credentials}" ]; then
       echo >&2 "No GCP credentials found..."
       return 1
    fi
    export GOOGLE_APPLICATION_CREDENTIALS=${credentials}
}

while getopts "i:p:s:P:r:ydh" flag; do
    case ${flag} in
      i) instance_name=${OPTARG}
        ;;
      p) project_id=${OPTARG}
        ;;
      s) subnetwork=${OPTARG}
        ;;
      P) subnetwork_project_id=${OPTARG}
        ;;
      r) region=${OPTARG}
        ;;
      y) proceed=1
        ;;
      d) destroy="-destroy"
        ;;
      ?) usage
        ;;
    esac
done

[ -n "${instance_name}" ] || usage
[ -n "${project_id}" ]    || usage
[ -n "${subnetwork}" ]    || usage
[ -n "${region}" ]        || region="us-central1"

which curl 1>/dev/null    || fail "curl is required"
which gcloud 1>/dev/null  || fail "gcloud is required"
which unzip 1>/dev/null   || fail "unzip is required"

ensure_auth && run_terraform \
    "${instance_name}" \
    "${project_id}" \
    "${subnetwork}" \
    "${subnetwork_project_id}" \
    "${region}" \
    "${proceed}" \
    "${destroy}"
