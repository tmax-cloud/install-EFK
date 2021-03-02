# Export variables

export ES_VERSION=7.2.0
export KIBANA_VERSION=7.2.0
export FLUENTD_VERSION=v1.4.2-debian-elasticsearch-1.1
export BUSYBOX_VERSION=1.32.0
if [ -z $2 ]; then
  export STORAGECLASS_NAME=
  echo "STORAGECLASS_NAME = Default-StorageClass"
else
  export STORAGECLASS_NAME=$2
  echo "STORAGECLASS_NAME = $STORAGECLASS_NAME"
fi

if [ -z $1 ]; then
  echo "Error : REGISTRY information is missing"
  exit 1
else
  export REGISTRY=$1
fi

echo "ES_VERSION = $ES_VERSION"
echo "KIBANA_VERSION = $KIBANA_VERSION"
echo "FLUENTD_VERSION = $FLUENTD_VERSION"
echo "BUSYBOX_VERSION = $BUSYBOX_VERSION"
echo "REGISTRY = $REGISTRY"

sed -i 's/{busybox_version}/'${BUSYBOX_VERSION}'/g' 01_elasticsearch.yaml
sed -i 's/{es_version}/'${ES_VERSION}'/g' 01_elasticsearch.yaml
sed -i 's/{storageclass_name}/'${STORAGECLASS_NAME}'/g' 01_elasticsearch.yaml
sed -i 's/{kibana_version}/'${KIBANA_VERSION}'/g' 02_kibana.yaml
sed -i 's/{fluentd_version}/'${FLUENTD_VERSION}'/g' 03_fluentd.yaml
sed -i 's/{fluentd_version}/'${FLUENTD_VERSION}'/g' 03_fluentd_cri-o.yaml

sed -i 's/docker.elastic.co\/elasticsearch\/elasticsearch/'${REGISTRY}'\/elasticsearch\/elasticsearch/g' 01_elasticsearch.yaml
sed -i 's/docker.elastic.co\/kibana\/kibana/'${REGISTRY}'\/kibana\/kibana/g' 02_kibana.yaml
sed -i 's/fluent\/fluentd-kubernetes-daemonset/'${REGISTRY}'\/fluentd-kubernetes-daemonset/g' 03_fluentd.yaml
sed -i 's/fluent\/fluentd-kubernetes-daemonset/'${REGISTRY}'\/fluentd-kubernetes-daemonset/g' 03_fluentd_cri-o.yaml

# Install EFK
echo "---Installation Start---"
kubectl create namespace kube-logging

kubectl apply -f 01_elasticsearch.yaml
timeout 5m kubectl -n kube-logging rollout status statefulset/es-cluster
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install ElasticSearch"
  ./uninstall_EFK.sh
  exit 1
else
  echo "ElasticSearch running success" 
  sleep 1m
fi

kubectl apply -f 02_kibana.yaml
timeout 5m kubectl -n kube-logging rollout status deployment/kibana
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install Kibana"
  ./uninstall_EFK.sh
  exit 1
else
  echo "Kibana running success" 
fi

kubectl apply -f 03_fluentd_cri-o.yaml
timeout 10m kubectl -n kube-logging rollout status daemonset/fluentd
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install Fluentd"
  ./uninstall_EFK.sh
  exit 1
else
  echo "Fluentd running success" 
fi

echo "---Installation Done---"