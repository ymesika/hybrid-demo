SHELL := /bin/zsh

HUB := gcr.io/istio-release
TAG := release-0.8-20180504-18-37

CLUSTER_A :="gke_zack-butcher_us-west1-a_a"
CLUSTER_A_DIR :=./cluster-a

CLUSTER_B :="gke_zack-butcher_us-west1-b_b"
CLUSTER_B_DIR :=./cluster-b

ISTIO_FILE_NAME := istio.yaml
APP_FILE_NAME := app.yaml
CROSS_CLUSTER_CONFIG_FILE_NAME := cross-cluster.yaml
CORE_DNS_FILE_NAME := coredns.yaml

##############

cluster-roles:
	kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(shell gcloud config get-value core/account) --context=${CLUSTER_A}
	kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(shell gcloud config get-value core/account) --context=${CLUSTER_B}

##############

ctxa:
	kubectl config use-context ${CLUSTER_A}

deploy-a:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ${CLUSTER_A_DIR}/${APP_FILE_NAME} |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_A}
deploy-a.istio:
	kubectl apply -f ${CLUSTER_A_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_A}
deploy-a.istio.cross-cluster.dns:
	kubectl apply -f ${CLUSTER_A_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_A}
deploy-a.istio.cross-cluster:
	$(eval CORE_DNS_IP := $(shell kubectl get svc core-dns -n istio-system -o jsonpath='{.spec.clusterIP}' --context=${CLUSTER_A}))
	$(eval INGRESS_B_IP := $(shell kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CLUSTER_B}))
	sed -e "s/INGRESS_IP_ADDRESS/${INGRESS_B_IP}/g" \
		-e "s/CORE_DNS_IP/${CORE_DNS_IP}/g" \
		${CLUSTER_A_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} | \
	kubectl  --context=${CLUSTER_A} apply -f -

deploy-a.addons:
	kubectl apply -f ${CLUSTER_A_DIR}/addons --context=${CLUSTER_A}

delete-a:
	kubectl delete -f ${CLUSTER_A_DIR}/${APP_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.istio:
	kubectl delete -f ${CLUSTER_A_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.istio.cross-cluster:
	kubectl delete -f ${CLUSTER_A_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.istio.cross-cluster.dns:
	kubectl delete -f ${CLUSTER_A_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.addons:
	kubectl delete -f ${CLUSTER_A_DIR}/addons --context=${CLUSTER_A} || true

##############

ctxb:
	kubectl config use-context ${CLUSTER_B}

deploy-b:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ${CLUSTER_B_DIR}/${APP_FILE_NAME} |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_B}
deploy-b.istio:
	kubectl apply -f ${CLUSTER_B_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_B}
deploy-b.istio.cross-cluster.dns:
	kubectl apply -f ${CLUSTER_B_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_B}
deploy-b.istio.cross-cluster:
	$(eval CORE_DNS_IP := $(shell kubectl get svc core-dns -n istio-system -o jsonpath='{.spec.clusterIP}' --context=${CLUSTER_B}))
	$(eval INGRESS_A_IP := $(shell kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CLUSTER_A}))
	sed -e "s/INGRESS_IP_ADDRESS/${INGRESS_A_IP}/g" \
		-e "s/CORE_DNS_IP/${CORE_DNS_IP}/g" \
		${CLUSTER_B_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} | \
	kubectl  --context=${CLUSTER_B} apply -f -

deploy-b.addons:
    kubectl apply -f ${CLUSTER_B_DIR}/addons --context=${CLUSTER_A}
	
delete-b:
	kubectl delete -f ${CLUSTER_B_DIR}/${APP_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.istio:
	kubectl delete -f ${CLUSTER_B_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.istio.cross-cluster:
	kubectl delete -f ${CLUSTER_B_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.istio.cross-cluster.dns:
	kubectl delete -f ${CLUSTER_B_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.addons:
	kubectl delete -f ${CLUSTER_B_DIR}/addons --context=${CLUSTER_A} || true

##############

deploy: deploy-a deploy-b
deploy.istio: deploy-a.istio deploy-b.istio
deploy.istio.cross-cluster.dns: deploy-a.istio.cross-cluster.dns deploy-b.istio.cross-cluster.dns
deploy.istio.cross-cluster: deploy-a.istio.cross-cluster deploy-b.istio.cross-cluster
deploy.addons: deploy-a.addons deploy-b.addons

delete: delete-a delete-b
delete.istio: delete-a.istio delete-b.istio
delete.istio.cross-cluster: delete-a.istio.cross-cluster delete-b.istio.cross-cluster
delete.istio.cross-cluster.dns: delete-a.istio.cross-cluster.dns delete-b.istio.cross-cluster.dns
delete.addons: delete-a.addons delete-b.addons

deploy-all: deploy.istio deploy.istio.cross-cluster.dns deploy deploy.istio.cross-cluster
delete-all: delete.istio.cross-cluster delete delete.istio.cross-cluster.dns delete.istio