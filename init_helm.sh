#!/bin/bash
set -e

init_helm_env () {
    
    KUBECONFIG_ORIGIN_FOLDER="/srv/kubeconfig"
    KUBECONFIG_FOLDER="/root/.kube"
    KUBECONFIG_DEFAULT_PATH="$KUBECONFIG_FOLDER/config"
    KUBECONFIG_OVERRIDE_PATH="$KUBECONFIG_FOLDER/config.override"
    mkdir -p $KUBECONFIG_FOLDER
    cp $KUBECONFIG_ORIGIN_FOLDER/*config* $KUBECONFIG_FOLDER

    if [[ $KUBECONFIG_OVERRIDE ]]; then
        echo $KUBECONFIG_OVERRIDE | yq r - > $KUBECONFIG_OVERRIDE_PATH
    fi

    KUBECONFIG=""
    for i in $KUBECONFIG_FOLDER/*config*; do
        KUBECONFIG="$KUBECONFIG:$i"
    done

    export KUBECONFIG=$KUBECONFIG
    KUBECONTEXT_LIST=`kubectl config get-contexts -o name`
    if [[ -z $KUBECONTEXT_LIST ]]; then
        printerror "Aucun context kubernetes trouvé: la configuration d'accès au cluster kubernetes doit être renseignée (on recherche des fichiers contenant le mot clef config)"
        printerror "- soit en montant et associant le volume $KUBECONFIG_FOLDER au container (ex: -v ~/.kube:$KUBECONFIG_FOLDER)"
        printerror "- soit en renseignant la variable d'environnement KUBECONFIG_OVERRIDE (les guillements doivent être échappés)"
        exit 1
    fi

    declare -A KUBE_CONTEXT_MAPPING_RULES
    if [[ $BRANCH_KUBE_CONTEXT_MAPPING  ]]; then
        while read name value; do
            KUBE_CONTEXT_MAPPING_RULES[$name]=$value
        done < <(<<<"$BRANCH_KUBE_CONTEXT_MAPPING" awk -F= '{print $1,$2}' RS=',|\n')
    fi

    declare -A NAMESPACE_MAPPING_RULES
    NAMESPACE_MAPPING_RULES[master]=default
    if [[ $BRANCH_NAMESPACE_MAPPING  ]]; then
        while read name value; do
            NAMESPACE_MAPPING_RULES[$name]=$value
        done < <(<<<"$BRANCH_NAMESPACE_MAPPING" awk -F= '{print $1,$2}' RS=',|\n')
    fi

    if [[ -z $BRANCH_NAME ]]; then
    if [[ ! $(git status | grep "Initial commit")  ]]; then
        BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
    fi
        BRANCH_NAME=${BRANCH_NAME:-"master"}
    fi

    if [[ -z $KUBE_CONTEXT ]]; then
        DEFAULT_KUBE_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
        KUBE_CONTEXT=${KUBE_CONTEXT_MAPPING_RULES[$BRANCH_NAME]:-$DEFAULT_KUBE_CONTEXT}
    fi
    if [[ -z $NAMESPACE ]]; then
        NAMESPACE=${NAMESPACE_MAPPING_RULES[$BRANCH_NAME]:-$BRANCH_NAME}
    fi    
}