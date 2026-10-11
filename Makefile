SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER_NAME := kubedeploy
KUBE_CONTEXT := k3d-$(CLUSTER_NAME)
BACKEND_IMAGE ?= kubedeploy-backend:v0.1.0

.PHONY: help cluster-up cluster-status cluster-down backend-deploy backend-status backend-smoke

help:
	@printf '%s\n' \
		'Targets:' \
		'  cluster-up      Create the local k3d cluster' \
		'  cluster-status  Show cluster nodes' \
		'  cluster-down    Delete the local k3d cluster' \
		'  backend-deploy      Import and deploy the local backend image' \
		'  backend-status      Show the backend workload state' \
		'  backend-smoke       Check the backend health endpoint'

cluster-up:
	@command -v docker >/dev/null
	@command -v k3d >/dev/null
	@command -v kubectl >/dev/null
	@docker info >/dev/null
	@k3d cluster create --config cluster/k3d.yaml
	@kubectl --context $(KUBE_CONTEXT) wait --for=condition=Ready nodes --all --timeout=180s
	@kubectl --context $(KUBE_CONTEXT) label nodes \
		-l '!node-role.kubernetes.io/control-plane' \
		node-role.kubernetes.io/worker=true --overwrite >/dev/null
	@kubectl --context $(KUBE_CONTEXT) get nodes -o wide

cluster-status:
	@kubectl --context $(KUBE_CONTEXT) get nodes -o wide

cluster-down:
	@k3d cluster delete $(CLUSTER_NAME)

backend-deploy:
	@docker image inspect $(BACKEND_IMAGE) >/dev/null
	@k3d image import --cluster $(CLUSTER_NAME) $(BACKEND_IMAGE)
	@kubectl --context $(KUBE_CONTEXT) apply -f backend/backend.yaml
	@kubectl --context $(KUBE_CONTEXT) --namespace kubedeploy-backend \
		rollout status deployment/backend --timeout=180s

backend-status:
	@kubectl --context $(KUBE_CONTEXT) --namespace kubedeploy-backend get deployment,pod,service

backend-smoke:
	@bash scripts/smoke.sh
