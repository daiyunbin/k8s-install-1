#!/usr/bin/bash

chmod a+x ./scripts/*

cd scripts/ && \
    ./initialize.sh && \
    ./createCA.sh && \
    ./deployKubectl.sh && \ 
    ./deployEtcd.sh && \
    ./deployFlannel.sh && \
    ./kube-apiserver-nginx.sh && \
    ./deploy-kube-apiserver.sh && \
    ./deploy-kube-controller-manager.sh && \
    ./deploy-kube-scheduler.sh && \
    ./deployDocker.sh && \
    ./deployKubelet.sh && \
    ./deploy-kube-proxy.sh
