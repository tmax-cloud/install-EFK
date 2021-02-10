# Create namespace & insert version info

export ES_VERSION=7.2.0
export KIBANA_VERSION=7.2.0
export FLUENTD_VERSION=v1.4.2-debian-elasticsearch-1.1
export BUSYBOX_VERSION=1.32.0
if [ -z $2 ]; then
  export STORAGECLASS_NAME=csi-cephfs-sc
else
  export STORAGECLASS_NAME=$2
fi


echo "ES_VERSION = $ES_VERSION"
echo "KIBANA_VERSION = $KIBANA_VERSION"
echo "FLUENTD_VERSION = $FLUENTD_VERSION"
echo "BUSYBOX_VERSION = $BUSYBOX_VERSION"
echo "STORAGECLASS_NAME = $STORAGECLASS_NAME"
echo "ContainerRuntime = $1"

sed -i 's/{busybox_version}/'${BUSYBOX_VERSION}'/g' 01_elasticsearch.yaml
sed -i 's/{es_version}/'${ES_VERSION}'/g' 01_elasticsearch.yaml
sed -i 's/{storageclass_name}/'${STORAGECLASS_NAME}'/g' 01_elasticsearch.yaml
sed -i 's/{kibana_version}/'${KIBANA_VERSION}'/g' 02_kibana.yaml
sed -i 's/{fluentd_version}/'${FLUENTD_VERSION}'/g' 03_fluentd.yaml
sed -i 's/{fluentd_version}/'${FLUENTD_VERSION}'/g' 03_fluentd_cri-o.yaml

# Install EFK
echo "---Installation Start---"
kubectl create ns kube-logging

kubectl apply -f 01_elasticsearch.yaml
kubectl apply -f 02_kibana.yaml
if [ -z $1 ] || [ "docker" == $1 ]; then
  kubectl apply -f 03_fluentd.yaml
elif [ "crio" == $1 ] || [ "cri-o" == $1 ]; then 
  kubectl apply -f 03_fluentd_cri-o.yaml  
else
  echo "Unknown Container Runtime Error"
fi

echo "---Installation Done---"
