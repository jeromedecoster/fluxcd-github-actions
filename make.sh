#!/bin/bash

#
# variables
#

# AWS variables
AWS_PROFILE=jerome
AWS_REGION=eu-west-3
# project name
PROJECT_NAME=fluxcd-github-actions


# the directory containing the script file
dir="$(cd "$(dirname "$0")"; pwd)"
cd "$dir"

log()   { echo -e "\e[30;47m ${1^^} \e[0m ${@:2}"; }        # $1 uppercase background white
info()  { echo -e "\e[48;5;28m ${1^^} \e[0m ${@:2}"; }      # $1 uppercase background green
warn()  { echo -e "\e[48;5;202m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background orange
error() { echo -e "\e[48;5;196m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background red

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

# install fluxctl if missing (no update)
install-fluxctl() {
    if [[ -z $(which fluxctl) ]]
    then
        log install fluxctl
        warn warn sudo is required
        cd /usr/local/bin
        sudo wget -q -O - https://api.github.com/repos/fluxcd/flux/releases \
            | jq --raw-output 'map( select(.prerelease==false) | .assets[].browser_download_url ) | .[]' \
            | grep inux \
            | head -n 1 \
            | sudo wget -q --show-progress -i - -O fluxctl
        sudo chmod +x fluxctl
    else
        log skip fluxctl already installed
    fi
}

# install eksctl if missing (no update)
install-eksctl() {
    if [[ -z $(which eksctl) ]]
    then
        log install eksctl
        warn warn sudo is required
        sudo wget -q -O - https://api.github.com/repos/weaveworks/eksctl/releases \
            | jq --raw-output 'map( select(.prerelease==false) | .assets[].browser_download_url ) | .[]' \
            | grep inux \
            | head -n 1 \
            | wget -q --show-progress -i - -O - \
            | sudo tar -xz -C /usr/local/bin

        # bash completion
        [[ -z $(grep eksctl_init_completion ~/.bash_completion 2>/dev/null) ]] \
            && eksctl completion bash >> ~/.bash_completion
    else
        log skip eksctl already installed
    fi
}

# install kubectl if missing (no update)
install-kubectl() {
    if [[ -z $(which kubectl) ]]
    then
        log install eksctl
        warn warn sudo is required
        VERSION=$(curl --silent https://storage.googleapis.com/kubernetes-release/release/stable.txt)
        cd /usr/local/bin
        sudo curl https://storage.googleapis.com/kubernetes-release/release/$VERSION/bin/linux/amd64/kubectl \
            --progress-bar \
            --location \
            --remote-name
        sudo chmod +x kubectl
    else
        log skip kubectl already installed
    fi
}


create-env() {
    # log install site npm modules
    cd "$dir/site"
    npm install

    [[ -f "$dir/.env" ]] && { log skip .env file already exists; return; }
    info create .env file

    # check if user already exists (return something if user exists, otherwise return nothing)
    local exists=$(aws iam list-user-policies \
        --user-name $PROJECT_NAME \
        --profile $AWS_PROFILE \
        2>/dev/null)
        
    [[ -n "$exists" ]] && { error abort user $PROJECT_NAME already exists; return; }

    # create a user named $PROJECT_NAME
    log create iam user $PROJECT_NAME
    aws iam create-user \
        --user-name $PROJECT_NAME \
        --profile $AWS_PROFILE \
        1>/dev/null

    aws iam attach-user-policy \
        --user-name $PROJECT_NAME \
        --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
        --profile $AWS_PROFILE

    local key=$(aws iam create-access-key \
        --user-name $PROJECT_NAME \
        --query 'AccessKey.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey}' \
        --profile $AWS_PROFILE \
        2>/dev/null)

    AWS_ACCESS_KEY_ID=$(echo "$key" | jq '.AccessKeyId' --raw-output)
    log AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID
    
    AWS_SECRET_ACCESS_KEY=$(echo "$key" | jq '.SecretAccessKey' --raw-output)
    log AWS_SECRET_ACCESS_KEY $AWS_SECRET_ACCESS_KEY

    # root account id
    ACCOUNT_ID=$(aws sts get-caller-identity \
        --query 'Account' \
        --profile $AWS_PROFILE \
        --output text)

    # create ECR repository
    local repo=$(aws ecr describe-repositories \
        --repository-names $PROJECT_NAME \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        2>/dev/null)
    if [[ -z "$repo" ]]
    then
        log ecr create-repository $PROJECT_NAME
        ECR_REPOSITORY=$(aws ecr create-repository \
            --repository-name $PROJECT_NAME \
            --region $AWS_REGION \
            --profile $AWS_PROFILE \
            --query 'repository.repositoryUri' \
            --output text)
        log ECR_REPOSITORY $ECR_REPOSITORY
    fi

    # create .env file
    sed --expression "s|{{AWS_ACCESS_KEY_ID}}|$AWS_ACCESS_KEY_ID|" \
        --expression "s|{{AWS_SECRET_ACCESS_KEY}}|$AWS_SECRET_ACCESS_KEY|" \
        --expression "s|{{PROJECT_NAME}}|$PROJECT_NAME|" \
        --expression "s|{{ACCOUNT_ID}}|$ACCOUNT_ID|" \
        --expression "s|{{ECR_REPOSITORY}}|$ECR_REPOSITORY|" \
        .env.sample \
        > .env

    info created file .env
}

# install eksctl + kubectl, create aws user + s3 bucket
setup() {
    install-fluxctl
    install-eksctl
    install-kubectl
    create-env
}

# build the production image
build() {
    cd "$dir/site"
    VERSION=$(jq --raw-output '.version' package.json)
    log build $PROJECT_NAME:$VERSION
    docker image build \
        --tag $PROJECT_NAME:latest \
        --tag $PROJECT_NAME:$VERSION \
        .
}

# run the latest built production image on localhost
run() {
    [[ -n $(docker ps --format '{{.Names}}' | grep $PROJECT_NAME) ]] \
        && { error error container already exists; return; }
    log run $PROJECT_NAME on http://localhost:3000
    docker run \
        --detach \
        --name $PROJECT_NAME \
        --publish 3000:3000 \
        $PROJECT_NAME
}

cluster-create() { # create the EKS cluster
    # check if cluster already exists (return something if the cluster exists, otherwise return nothing)
    local exists=$(aws eks describe-cluster \
        --name $PROJECT_NAME \
        --profile $AWS_PROFILE \
        --region $AWS_REGION \
        2>/dev/null)
        
    [[ -n "$exists" ]] && { error abort cluster $PROJECT_NAME already exists; return; }

    # create a cluster named $PROJECT_NAME
    log create eks cluster $PROJECT_NAME

    eksctl create cluster \
        --name $PROJECT_NAME \
        --region $AWS_REGION \
        --managed \
        --node-type t2.small \
        --nodes 1 \
        --profile $AWS_PROFILE
}

# k8s-template() {
#     source "$dir/.env"
#     sed --expression "s|{{AWS_ACCESS_KEY_ID}}|$AWS_ACCESS_KEY_ID|g" \
#         --expression "s|{{AWS_SECRET_ACCESS_KEY}}|$AWS_SECRET_ACCESS_KEY|g" \
#         --expression "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
#         --expression "s|{{ACCOUNT_ID}}|$ACCOUNT_ID|g" \
#         --expression "s|{{AWS_REGION}}|$AWS_REGION|g" \
#         --expression "s|{{WEBSITE_PORT}}|$WEBSITE_PORT|g" \
#         $1
# }

# cluster-deploy() { # deploy services to EKS
#     cd "$dir/k8s"
#     for f in namespace deployment service
#     do
#         k8s-template "$f.yaml" | kubectl apply --filename - 
#     done
# }

cluster-delete() { # delete the EKS cluster
    eksctl delete cluster \
        --name $PROJECT_NAME \
        --region $AWS_REGION \
        --profile $AWS_PROFILE
}

# remove the running container
rm() {
    [[ -z $(docker ps --format '{{.Names}}' | grep $PROJECT_NAME) ]]  \
        && { warn warn no running container found; return; }
    docker container rm \
        --force $PROJECT_NAME
}

# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info execute $1; eval $1; } || usage;
exit 0