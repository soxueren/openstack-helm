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

#NOTE: Deploy command
: ${OSH_INFRA_PATH:="../openstack-helm-infra"}
helm install ${OSH_INFRA_PATH}/nfs-provisioner \
    --namespace=nfs \
    --name=nfs-provisioner \
    --set storageclass.name=general

#NOTE: Wait for deploy
./tools/deployment/common/wait-for-pods.sh nfs

#NOTE: Display info
helm status nfs-provisioner