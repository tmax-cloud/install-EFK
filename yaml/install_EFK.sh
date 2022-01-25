#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $SCRIPTDIR

# Apply configuration
source ./efk.config

echo "ES_VERSION = $ES_VERSION"
echo "KIBANA_VERSION = $KIBANA_VERSION"
echo "GATEKEEPER_VERSION = $GATEKEEPER_VERSION"
echo "HYPERAUTH_URL = $HYPERAUTH_URL"
echo "KIBANA_CLIENT_SECRET = $KIBANA_CLIENT_SECRET"
echo "ENCRYPTION_KEY = $ENCRYPTION_KEY"
echo "CUSTOM_DOMAIN_NAME = $CUSTOM_DOMAIN_NAME"
echo "FLUENTD_VERSION = $FLUENTD_VERSION"
echo "BUSYBOX_VERSION = $BUSYBOX_VERSION"
if [ $STORAGECLASS_NAME != "{STORAGECLASS_NAME}" ]; then
  echo "STORAGECLASS_NAME = $STORAGECLASS_NAME"
else
  export STORAGECLASS_NAME=
  echo "STORAGECLASS_NAME = default-storage-class"
fi
if [ $REGISTRY != "{REGISTRY}" ]; then
  echo "REGISTRY = $REGISTRY"
fi

sed -i 's/{BUSYBOX_VERSION}/'${BUSYBOX_VERSION}'/g' 01_elasticsearch.yaml
sed -i 's/{ES_VERSION}/'${ES_VERSION}'/g' 01_elasticsearch.yaml
sed -i 's/{STORAGECLASS_NAME}/'${STORAGECLASS_NAME}'/g' 01_elasticsearch.yaml
sed -i 's/{KIBANA_VERSION}/'${KIBANA_VERSION}'/g' 02_kibana.yaml
sed -i 's/{GATEKEEPER_VERSION}/'${GATEKEEPER_VERSION}'/g' 02_kibana.yaml
sed -i 's/{HYPERAUTH_URL}/'${HYPERAUTH_URL}'/g' 02_kibana.yaml
sed -i 's/{KIBANA_CLIENT_SECRET}/'${KIBANA_CLIENT_SECRET}'/g' 02_kibana.yaml
sed -i 's/{ENCRYPTION_KEY}/'${ENCRYPTION_KEY}'/g' 02_kibana.yaml
sed -i 's/{CUSTOM_DOMAIN_NAME}/'${CUSTOM_DOMAIN_NAME}'/g' 02_kibana.yaml
sed -i 's/{FLUENTD_VERSION}/'${FLUENTD_VERSION}'/g' 03_fluentd.yaml
sed -i 's/{FLUENTD_VERSION}/'${FLUENTD_VERSION}'/g' 03_fluentd_cri-o.yaml

if [ $REGISTRY != "{REGISTRY}" ]; then
  sed -i 's/docker.io\/tmaxcloudck\/elasticsearch/'${REGISTRY}'\/tmaxcloudck\/elasticsearch/g' 01_elasticsearch.yaml
  sed -i 's/busybox/'${REGISTRY}'\/busybox/g' 01_elasticsearch.yaml
  sed -i 's/docker.elastic.co\/kibana\/kibana/'${REGISTRY}'\/kibana\/kibana/g' 02_kibana.yaml
  sed -i 's/quay.io\/keycloak\/keycloak-gatekeeper/'${REGISTRY}'\/keycloak\/keycloak-gatekeeper/g' 02_kibana.yaml
  sed -i 's/fluent\/fluentd-kubernetes-daemonset/'${REGISTRY}'\/fluentd-kubernetes-daemonset/g' 03_fluentd.yaml
  sed -i 's/fluent\/fluentd-kubernetes-daemonset/'${REGISTRY}'\/fluentd-kubernetes-daemonset/g' 03_fluentd_cri-o.yaml
fi

# 1. Install ElasticSearch
echo " "
echo "---Installation Start---"
kubectl create namespace kube-logging

echo " "
echo "---1. Install ElasticSearch---"
kubectl apply -f 01_elasticsearch.yaml
timeout 5m kubectl -n kube-logging rollout status statefulset/es-cluster
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install ElasticSearch"
  kubectl delete -f 01_elasticsearch.yaml
  exit 1
else
  echo "ElasticSearch pod running success" 
fi

# 2. Wait until Elasticsearch starts up
echo " "
echo "---2. Wait until Elasticsearch starts up---"
echo "It will take a couple of minutes"
sleep 5s
set +e
export ES_IP=`kubectl get svc -n kube-logging | grep elasticsearch | tr -s ' ' | cut -d ' ' -f3`
for ((i=0; i<11; i++))
do
  curl -XGET http://$ES_IP:9200/_cat/indices/
  is_success=`echo $?`
  if [ $is_success == 0 ]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Start uninstall"
    kubectl delete -f 01_elasticsearch.yaml
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "ElasticSearch starts up successfully"
set -e

# 3. Install Kibana
echo " "
echo "---3. Install Kibana---"
kubectl apply -f 02_kibana.yaml
timeout 5m kubectl -n kube-logging rollout status deployment/kibana
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install Kibana"
  kubectl delete -f 02_kibana.yaml
  exit 1
else
  echo "Kibana pod running success" 
fi

# 4. Install Fluentd
echo " "
echo "---4. Install Fluentd---"
if [ $FLUENTD_VERSION == v1.14.3-debian-elasticsearch7-1.0 ]; then
  kubectl apply -f 03_fluentd_cri-o_rollover.yaml
  echo "Fluentd rollover installing"
else
  kubectl apply -f 03_fluentd_cri-o.yaml
fi
timeout 10m kubectl -n kube-logging rollout status daemonset/fluentd
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install Fluentd"
  kubectl delete -f 03_fluentd_cri-o.yaml
  exit 1
else
  echo "Fluentd running success"
fi

# 5. Wait until Kibana makes an index and alias normally
echo " "
echo "---5. Wait until Kibana makes an index and alias normally---"
echo "It will take a couple of minutes"
sleep 5s
set +e
for ((i=0; i<11; i++))
do
  is_success=`curl -XGET http://$ES_IP:9200/_cat/indices/`

  if [[ "$is_success" == *".kibana"* ]]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Failed to make an kibana index"
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "Kibana made an index on Elasticsearch successfully"

echo " "
echo "---Wait until Kibana makes an alias normally---"
for ((i=0; i<11; i++))
do
  is_success=`curl -XGET http://$ES_IP:9200/_alias`
  is_kibana_normal=`kubectl get pod -n kube-logging | grep kibana | tr -s ' ' | cut -d ' ' -f4`

  if [[ "$is_success" == *".kibana_1"* ]]; then
    break
  elif [ $is_kibana_normal != 0 ]; then
    echo "make an index manually by curl command"
    curl -XPUT http://$ES_IP:9200/.kibana_1/_alias/.kibana
  elif [ $i == 10 ]; then
    echo "Timeout. Failed to make a alias for kibana index"
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "Kibana made an alias on Elasticsearch successfully"
set -e

# 6. Create default index 'logstash-*'
echo " "
echo "---6. Create default index 'logstash-*'---"
echo "It will take a couple of minutes"
set +e
export KIBANA_IP=`kubectl get svc -n kube-logging | grep kibana | tr -s ' ' | cut -d ' ' -f3`

for ((i=0; i<11; i++))
do
  is_success=`curl -XGET http://$ES_IP:9200/_cat/indices/`

  if [[ "$is_success" == *"logstash"* ]]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Failed to make a default index 'logstash-*'"
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "logstash index was made in ElasticSearch"

for ((i=0; i<11; i++))
do
  is_success=`curl -XGET http://$KIBANA_IP:5601/api/kibana/status -I`

  if [[ "$is_success" == *"200 OK"* ]]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Kibana status is not ready"
    exit 1
  else
    echo "waiting for Kibana starts up..."
    sleep 1m
  fi
done
echo "Kibana starts up successfully"
curl -f -XPOST -H 'Content-Type: application/json' -H 'kbn-xsrf: anything' http://$KIBANA_IP:5601/api/kibana/api/saved_objects/index-pattern/logstash-* '-d{"attributes":{"title":"logstash-*","timeFieldName":"@timestamp"}}' 
curl -XPOST -H "Content-Type: application/json" -H "kbn-xsrf: true" http://$KIBANA_IP:5601/api/kibana/api/kibana/settings/defaultIndex -d '{"value": "logstash-*"}'
set -e

echo " "
echo "---Installation Done---"
popd
