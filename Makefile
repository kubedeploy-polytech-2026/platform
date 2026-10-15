SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER_NAME := kubedeploy
KUBE_CONTEXT := k3d-$(CLUSTER_NAME)
BACKEND_IMAGE ?= kubedeploy-backend:v0.1.0

.PHONY: help cluster-up cluster-status cluster-down backend-deploy backend-status backend-smoke argocd-up argocd-status argocd-ui

help:
	@printf '%s\n' \
		'Targets:' \
		'  cluster-up      Create the local k3d cluster' \
		'  cluster-status  Show cluster nodes' \
		'  cluster-down    Delete the local k3d cluster' \
		'  backend-deploy      Import and deploy the local backend image' \
		'  backend-status      Show the backend workload state' \
		'  backend-smoke       Check the backend health endpoint' \
		'  argocd-up       Install Argo CD in the local cluster' \
		'  argocd-status   Show Argo CD workloads' \
		'  argocd-ui       Forward the Argo CD UI to localhost'

cluster-up:
	@command -v docker >/dev/null
	@command -v k3d >/dev/null
	@command -v kubectl >/dev/null
	@docker info >/dev/null
	@if k3d cluster list --no-headers | awk '$$1 == "$(CLUSTER_NAME)" { found = 1 } END { exit !found }'; then \
		if ! kubectl --context $(KUBE_CONTEXT) get --raw=/readyz >/dev/null 2>&1; then \
			k3d cluster start $(CLUSTER_NAME); \
		fi; \
	else \
		k3d cluster create --config cluster/k3d.yaml; \
	fi
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

argocd-up:
	@bash scripts/argocd-up.sh

argocd-status:
	@kubectl --context $(KUBE_CONTEXT) --namespace argocd get deployment,statefulset,pod,service

argocd-ui:
	@bash scripts/argocd-ui.sh
