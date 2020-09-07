.SILENT:

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-22s\033[0m%s\n", $$1, $$2 }'

setup: # install eksctl + kubectl, create aws user + s3 bucket
	./make.sh setup

build: # build the production image
	./make.sh build
	
run: # run the built production image
	./make.sh run

rm: # remove the running container built production
	./make.sh rm

cluster-create: # create the EKS cluster
	./make.sh cluster-create

cluster-delete: # delete the EKS cluster
	./make.sh cluster-delete