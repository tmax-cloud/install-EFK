echo "---Uninstallation Start---"
kubectl apply -f 03_fluentd_cri-o.yaml
timeout 5m kubectl -n kube-logging wait daemonset/fluentd --for=delete

kubectl apply -f 02_kibana.yaml
timeout 5m kubectl -n kube-logging wait deployment/kibana --for=delete

kubectl apply -f 01_elasticsearch.yaml
timeout 5m kubectl -n kube-logging wait statefulset/es-cluster --for=delete

kubectl delete namespace kube-logging
timeout 5m kubectl -n kube-logging wait namespace/kube-logging --for=delete
echo "---Uninstallation Done---"
