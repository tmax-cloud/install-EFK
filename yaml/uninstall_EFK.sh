echo "---Uninstallation Start---"
kubectl delete -f 03_fluentd_cri-o.yaml
timeout 5m kubectl -n kube-logging wait daemonset/fluentd --for=delete
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete Fluentd"
  exit 1
fi

kubectl delete -f 02_kibana.yaml
timeout 5m kubectl -n kube-logging wait deployment/kibana --for=delete
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete Kibana"
  exit 1
fi

kubectl delete -f 01_elasticsearch.yaml
timeout 5m kubectl -n kube-logging wait statefulset/es-cluster --for=delete
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete ElasticSearch"
  exit 1
fi

kubectl delete namespace kube-logging
timeout 5m kubectl -n kube-logging wait namespace/kube-logging --for=delete
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete namespace"
  exit 1
fi
echo "---Uninstallation Done---"
