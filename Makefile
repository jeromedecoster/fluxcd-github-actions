.SILENT:

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-22s\033[0m%s\n", $$1, $$2 }'

setup: # install eksctl + kubectl, create aws user + s3 bucket
	./make.sh setup

# dev: # local development with docker-compose
# 	./make.sh dev

# build-push: # build production images and push to ECR
# 	./make.sh build-push
	
# prod: # run production images locally
# 	./make.sh prod

# cluster-create: # create the EKS cluster
# 	./make.sh cluster-create

# cluster-deploy: # deploy services to EKS
# 	./make.sh cluster-deploy

# cluster-elb: # get the cluster ELB URI
# 	./make.sh cluster-elb

# cluster-log-convert: # get the convert logs
# 	./make.sh cluster-log-convert

# cluster-delete: # delete the EKS cluster
# 	./make.sh cluster-delete

# storage-dev: # storage service local development (on current machine, by calling npm script directly)
# 	./make.sh storage-dev

# storage-dev-docker: # storage service local development with docker
# 	./make.sh storage-dev-docker

# storage-test: # run storage service tests (on current machine, by calling npm script directly)
# 	./make.sh storage-test

# storage-test-docker: # run storage service tests with docker
# 	./make.sh storage-test-docker

# storage-prod-docker: # build then run storage service with docker (with .env vars, just to test if it runs correctly)
# 	./make.sh storage-prod-docker

# convert-dev: # convert service local development (on current machine, by calling npm script directly)
# 	./make.sh convert-dev

# convert-dev-docker: # convert service local development with docker
# 	./make.sh convert-dev-docker

# convert-test: # run convert service tests (on current machine, by calling npm script directly)
# 	./make.sh convert-test

# convert-test-docker: # run convert service tests with docker
# 	./make.sh convert-test-docker

# convert-prod-docker: # build then run convert service with docker (with .env vars, just to test if it runs correctly)
# 	./make.sh convert-prod-docker

# website-dev: # website service local development (on current machine, by calling npm script directly)
# 	./make.sh website-dev

# website-dev-docker: # website service local development with docker
# 	./make.sh website-dev-docker

