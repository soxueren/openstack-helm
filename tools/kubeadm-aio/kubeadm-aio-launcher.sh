#!/bin/bash

# Copyright 2017 The Openstack-Helm Authors.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
set -xe

# Setup shared mounts for kubelet
sudo mkdir -p /var/lib/kubelet
sudo mount --bind /var/lib/kubelet /var/lib/kubelet
sudo mount --make-shared /var/lib/kubelet

# Cleanup any old deployment
sudo docker rm -f kubeadm-aio || true
sudo docker rm -f kubelet || true
sudo docker ps -aq | xargs -l1 sudo docker rm -f || true
sudo rm -rfv \
    /etc/cni/net.d \
    /etc/kubernetes \
    /var/lib/etcd \
    /var/etcd \
    /var/lib/kubelet/* \
    /run/openvswitch \
    ${HOME}/.kubeadm-aio/admin.conf \
    /var/lib/nfs-provisioner || true

# Launch Container
sudo docker run \
    -dt \
    --name=kubeadm-aio \
    --net=host \
    --security-opt=seccomp:unconfined \
    --cap-add=SYS_ADMIN \
    --tmpfs=/run \
    --tmpfs=/run/lock \
    --volume=/etc/machine-id:/etc/machine-id:ro \
    --volume=${HOME}:${HOME}:rw \
    --volume=${HOME}/.kubeadm-aio:/root:rw \
    --volume=/etc/kubernetes:/etc/kubernetes:rw \
    --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro \
    --volume=/var/run/docker.sock:/run/docker.sock \
    --env KUBELET_CONTAINER=${KUBEADM_IMAGE} \
    --env KUBE_VERSION=${KUBE_VERSION} \
    ${KUBEADM_IMAGE}

# Wait for kubeconfig
while [[ ! -f ${HOME}/.kubeadm-aio/admin.conf ]]; do
  echo "Waiting for kubeconfig"
  sleep 2
done

# Set perms of kubeconfig and set env-var
sudo chown $(id -u):$(id -g) ${HOME}/.kubeadm-aio/admin.conf
export KUBECONFIG=${HOME}/.kubeadm-aio/admin.conf

# Wait for node to be ready before continuing
NODE_STATUS="Unknown"
while [[ $NODE_STATUS != "Ready" ]]; do
  NODE_STATUS=$(kubectl get nodes --no-headers=true | awk "{ print \$2 }" | head -1)
  echo "Current node status: ${NODE_STATUS}"
  sleep 2
done

# Initialize Helm
helm init

# Initialize Environment for Development
sudo docker exec kubeadm-aio openstack-helm-dev-prep

# Deploy NFS provisioner into enviromment
sudo docker exec kubeadm-aio openstack-helm-nfs-prep
