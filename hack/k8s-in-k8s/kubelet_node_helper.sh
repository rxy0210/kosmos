#!/usr/bin/env bash

source "env.sh"

# args
DNS_ADDRESS=${2:-10.237.0.10}
LOG_NAME=${2:-kubelet}
JOIN_HOST=$2
JOIN_TOKEN=$3
JOIN_CA_HASH=$4

function unjoin() {
    # before unjoin, you need delete node by kubectl
    echo "exec(1/2): kubeadm reset...."
    echo "y" | kubeadm reset
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "exec(2/3): restart cotnainerd...."
    systemctl restart containerd
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "exec(3/3): delete cni...."
    if [ -d "/etc/cni/net.d" ]; then   
        mv /etc/cni/net.d '/etc/cni/net.d.kosmos.back'`date +%Y_%m_%d_%H_%M_%S`
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
}

function revert() {
    echo "exec(1/4): update kubeadm.cfg..."
    if [ ! -f "$PATH_KUBEADM_CONFIG/kubeadm.cfg" ]; then
        GenerateKubeadmConfig  $JOIN_TOKEN $PATH_FILE_TMP
    else
      sed -e "s|token: .*$|token: $JOIN_TOKEN|g" -e "w $PATH_FILE_TMP/kubeadm.cfg.current" "$PATH_KUBEADM_CONFIG/kubeadm.cfg"
    fi

    
    # add taints
    echo "exec(2/4): update kubeadm.cfg tanits..."
    sed -i "/kubeletExtraArgs/a \    register-with-taints: node.kosmos.io/unschedulable:NoSchedule"  "$PATH_FILE_TMP/kubeadm.cfg.current" 
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    echo "exec(3/4): execute join cmd...."
    kubeadm join --config "$PATH_FILE_TMP/kubeadm.cfg.current"
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "exec(4/4): restart cotnainerd...."
    systemctl restart containerd
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

# before join, you need upload ca.crt and kubeconfig to tmp dir!!!
function join() {
    echo "exec(1/8): stop containerd...."
    systemctl stop containerd
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "exec(2/8): copy ca.crt...."
    cp "$PATH_FILE_TMP/ca.crt" "$PATH_KUBERNETES_PKI/ca.crt"
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "exec(3/8): copy kubeconfig...."
    cp "$PATH_FILE_TMP/$KUBELET_KUBE_CONFIG_NAME" "$PATH_KUBERNETES/$KUBELET_KUBE_CONFIG_NAME"
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "exec(4/8): set core dns address...."
    sed -e "s|__DNS_ADDRESS__|$DNS_ADDRESS|g" -e "w ${PATH_KUBELET_CONF}/${KUBELET_CONFIG_NAME}" "$PATH_FILE_TMP"/"$KUBELET_CONFIG_NAME"
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "exec(5/8): copy kubeadm-flags.env...."
    cp "$PATH_FILE_TMP/kubeadm-flags.env" "$PATH_KUBELET_LIB/kubeadm-flags.env"
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "exec(6/8): delete cni...."
    if [ -d "/etc/cni/net.d" ]; then   
        mv /etc/cni/net.d '/etc/cni/net.d.back'`date +%Y_%m_%d_%H_%M_%S`
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi

    echo "exec(7/8): start containerd"
    systemctl start containerd
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "exec(8/8): start kubelet...."
    systemctl start kubelet
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

function health() {
    result=`systemctl is-active containerd`
    if [[ $result != "active" ]]; then
        echo "health(1/2): containerd is inactive"
        exit 1
    else
        echo "health(1/2): containerd is active"
    fi

    result=`systemctl is-active kubelet`
    if [[ $result != "active" ]]; then
        echo "health(2/2): kubelet is inactive"
        exit 1
    else
        echo "health(2/2): containerd is active"
    fi
}

function log() {
    systemctl status $LOG_NAME
}

# check the environments
function check() {
    # TODO: create env file
    echo "check(1/2): try to create $PATH_FILE_TMP"
    if [ ! -d "$PATH_FILE_TMP" ]; then   
        mkdir -p "$PATH_FILE_TMP"
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
    
    echo "check(2/2): copy  kubeadm-flags.env  to create $PATH_FILE_TMP , remove args[cloud-provider] and taints"
    sed -e "s| --cloud-provider=external | |g" -e "w ${PATH_FILE_TMP}/kubeadm-flags.env" "$PATH_KUBELET_LIB/kubeadm-flags.env"
    sed -i "s| --register-with-taints=node.kosmos.io/unschedulable:NoSchedule||g" "${PATH_FILE_TMP}/kubeadm-flags.env"
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "environments is ok"
}

function version() {
    echo "$SCRIPT_VERSION"
}

# See how we were called.
case "$1" in
    unjoin)
    unjoin
    ;;
    join)
    join
    ;;
    health)
    health
    ;;
    check)
    check
    ;;
    log)
    log
    ;;
    revert)
    revert
    ;;
    version)
    version
    ;;
    *)
    echo $"usage: $0 unjoin|join|health|log|check|version|revert"
    exit 1
esac