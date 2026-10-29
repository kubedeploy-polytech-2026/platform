SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER_NAME := kubedeploy
KUBE_CONTEXT := k3d-$(CLUSTER_NAME)

.PHONY: help cluster-up cluster-status cluster-down argocd-up argocd-status argocd-ui bootstrap platform-status gateway-status gateway-smoke policies-check policies-smoke

help:
	@printf '%s\n' \
		'Targets:' \
		'  cluster-up      Create the local k3d cluster' \
		'  cluster-status  Show cluster nodes' \
		'  cluster-down    Delete the local k3d cluster' \
		'  argocd-up       Install Argo CD in the local cluster' \
		'  argocd-status   Show Argo CD workloads' \
		'  argocd-ui       Forward the Argo CD UI to localhost' \
		'  bootstrap       Create the root Application and system layer' \
		'  platform-status Show managed Applications and Envoy Gateway' \
		'  gateway-status  Show the shared HTTP Gateway' \
		'  gateway-smoke   Check Gateway readiness and the Envoy HTTP listener'

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

argocd-up:
	@bash scripts/argocd-up.sh

argocd-status:
	@kubectl --context $(KUBE_CONTEXT) --namespace argocd get deployment,statefulset,pod,service

argocd-ui:
	@bash scripts/argocd-ui.sh

bootstrap:
	@bash scripts/bootstrap.sh

platform-status:
	@kubectl --context $(KUBE_CONTEXT) --namespace argocd get applications
	@kubectl --context $(KUBE_CONTEXT) --namespace envoy-gateway-system \
		get deployment,pod,service

gateway-status:
	@kubectl --context $(KUBE_CONTEXT) get gatewayclass kubedeploy-envoy
	@kubectl --context $(KUBE_CONTEXT) --namespace kubedeploy-gateway get gateway kubedeploy
	@kubectl --context $(KUBE_CONTEXT) --namespace envoy-gateway-system \
		get deployment,service -l gateway.envoyproxy.io/owning-gateway-name=kubedeploy,gateway.envoyproxy.io/owning-gateway-namespace=kubedeploy-gateway

gateway-smoke:
	@bash scripts/gateway-smoke.sh

policies-check:
	@bash scripts/install-gator.sh
	@python3 -m unittest discover -s tests -v

policies-smoke:
	@python3 tests/test_policies.py --live
