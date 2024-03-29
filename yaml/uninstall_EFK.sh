#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $SCRIPTDIR

echo "---Uninstallation Start---"
timeout 5m kubectl delete -f 03_fluentd_cri-o.yaml 
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete Fluentd"
  #exit 1
fi

timeout 5m kubectl delete -f 02_kibana.yaml 
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete Kibana"
  #exit 1
fi

timeout 5m kubectl delete -f 01_elasticsearch.yaml
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete ElasticSearch"
  #exit 1
fi

timeout 5m kubectl delete namespace kube-logging
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete namespace"
  #exit 1
fi
echo "---Uninstallation Done---"
popd
