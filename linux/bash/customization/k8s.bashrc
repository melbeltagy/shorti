function _k_get() {
		if [ -z "$1" ]; then
			echo "Usage: k get <resource> [pattern ...]"
			return
		fi
		local RESOURCE="$1"
		shift
		if [ -z "$1" ]; then
			kubectl get "$RESOURCE" --all-namespaces --output=wide
		else
			local PATTERN="$(IFS="|"; echo "$*")"
			kubectl get "$RESOURCE" | grep -E "$PATTERN" --all-namespaces --output=wide
		fi
}

function _k_describe() {
		if [ -z "$1" ]; then
			echo "Usage: k desc <resource> <name/pattern>"
			return
		fi
		local RESOURCE="$1"
		shift
		if [ -z "$1" ]; then
			kubectl describe "$RESOURCE"
		else
			local PATTERN="$(IFS="|"; echo "$*")"
			local NAMES=$(kubectl get "$RESOURCE" -o name | grep -E "$PATTERN")
			if [ -z "$NAMES" ]; then
				echo "No $RESOURCE match the pattern."
				return
			fi
			for n in $NAMES; do
				kubectl describe "$n"
			done
		fi
}

function _k_logs() {
		if [ -z "$2" ]; then
			echo "Usage: k logs <pod> [container]"
			return
		fi
		if [ -z "$3" ]; then
			kubectl logs "$2"
		else
			kubectl logs "$2" -c "$3"
		fi
}

function _k_exec() {
		if [ -z "$2" ]; then
			echo "Usage: k exec <pod> [container] [cmd]"
			return
		fi
		if [ -z "$3" ]; then
			kubectl exec -it "$2" -- /bin/sh
		elif [[ "$3" == /* || "$3" == "sh" || "$3" == "bash" ]]; then
			# If command is specified
			shift 2
			kubectl exec -it "$1" -- "${@:2}"
		else
			kubectl exec -it "$2" -c "$3" -- /bin/sh
		fi
}

function _k_bash() {
		if [ -z "$2" ]; then
			echo "Usage: k bash <pod> [container]"
			return
		fi
		if [ -z "$3" ]; then
			kubectl exec -it "$2" -- /bin/bash
		else
			kubectl exec -it "$2" -c "$3" -- /bin/bash
		fi
}

function _k_sh() {
		if [ -z "$2" ]; then
			echo "Usage: k sh <pod> [container]"
			return
		fi
		if [ -z "$3" ]; then
			kubectl exec -it "$2" -- /bin/sh
		else
			kubectl exec -it "$2" -c "$3" -- /bin/sh
		fi
}

function _k_apply() {
		shift
		if [ -z "$1" ]; then
			echo "Usage: k apply <file>"
			return
		fi
		kubectl apply -f "$1"
}

function _k_delete() {
		shift
		if [ -z "$1" ] || [ -z "$2" ]; then
			echo "Usage: k del <resource> <name/pattern>"
			return
		fi
		local RESOURCE="$1"
		shift
		local PATTERN="$(IFS="|"; echo "$*")"
		local NAMES=$(kubectl get "$RESOURCE" -o name | grep -E "$PATTERN")
		if [ -z "$NAMES" ]; then
			echo "No $RESOURCE match the pattern."
			return
		fi
		echo "Deleting:"
		echo "$NAMES"
		read -p "Continue? (y/N): " confirm
		if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
			echo "$NAMES" | xargs kubectl delete
		else
			echo "Operation cancelled."
		fi
}

function _k_cp() {
		shift
		if [ $# -ne 2 ]; then
			echo "Usage: k cp <src> <dest>"
			return
		fi
		kubectl cp "$1" "$2"
}

function _k_edit() {
		shift
		if [ -z "$1" ] || [ -z "$2" ]; then
			echo "Usage: k edit <resource> <name>"
			return
		fi
		kubectl edit "$1" "$2"
}

function _k_port_forward() {
		shift
		if [ $# -ne 2 ]; then
			echo "Usage: k pf <pod/svc> <local>:<remote>"
			return
		fi
		kubectl port-forward "$1" "$2"
}

function _k_types() {
		echo "Listing all resource types available to kubectl (all namespaces):"
		kubectl api-resources --verbs=list
}

function _k_ls() {
	if [ "$1" = "help" ] || [ "$1" = "--help" ]; then
		echo "Usage: k ls [types] [filter ...]"
		echo "  types: comma-separated resource types (e.g. po,svc,deploy,ns)"
		echo "  filter: one or more patterns to grep/filter the output"
		echo ""
		echo "Supported resource types:"
		echo "  ns, namespace, namespaces"
		echo "  po, pod, pods"
		echo "  svc, service, services"
		echo "  deploy, deployment, deployments"
		echo "  sts, statefulset, statefulsets"
		echo "  ing, ingress, ingresses"
		echo "  cm, configmap, configmaps"
		echo "  pvc, persistentvolumeclaim, persistentvolumeclaims"
		echo "  pv, persistentvolume, persistentvolumes"
		echo "  sc, storageclass, storageclasses"
		echo "  ip, ipaddress, ipaddresses"
		echo "  endpointslices"
		echo ""
		echo "Note: 'k ls' lists resources in ALL namespaces."
		echo "      To list resources of a specific type in specific namespace, use 'k ns <namespace>' then use 'k get <type>' instead."
		echo ""
		echo "Examples:"
		echo "  k ls"
		echo "  k ls po,svc,deployment pod_name_to_filter"
		echo "  k ls ns"
		return
	fi
	if [ -z "$1" ]; then
		echo "Listing common resources in all namespaces:"
		echo ""
		echo "==============         namespaces          =============="
		kubectl get namespaces --output=wide
		echo ""
		echo "==============          pods (po)           =============="
		kubectl get pods --all-namespaces --output=wide
		echo ""
		echo "==============      ipaddresses (ip)        =============="
		kubectl get ip --all-namespaces --output=wide
		echo ""
		echo "==============       services (svc)         =============="
		kubectl get svc --all-namespaces --output=wide
		echo ""
		echo "==============    deployments (deploy)      =============="
		kubectl get deploy --all-namespaces --output=wide
		echo ""
		echo "==============     statefulsets (sts)       =============="
		kubectl get sts --all-namespaces --output=wide
		echo ""
		echo "==============       ingresses (ing)        =============="
		kubectl get ing --all-namespaces --output=wide
		echo ""
		echo "==============       configmaps (cm)        =============="
		kubectl get cm --all-namespaces --output=wide
		echo ""
		echo "============== persistentvolumeclaims (pvc) =============="
		kubectl get pvc --all-namespaces --output=wide
		echo ""
		echo "==============     persistentvolumes (pv)   =============="
		kubectl get pv --all-namespaces --output=wide
		echo ""
		echo "==============      storageclasses (sc)     =============="
		kubectl get sc --all-namespaces --output=wide
		echo ""
		echo "==============        endpointslices        =============="
		kubectl get endpointslices --all-namespaces --output=wide
	else
		local TYPES="$1"
		shift
		local FILTERS="$*"
		IFS=',' read -ra TYPE_ARR <<< "$TYPES"
		for TYPE in "${TYPE_ARR[@]}"; do
			if [ "$TYPE" = "ns" ] || [ "$TYPE" = "namespace" ] || [ "$TYPE" = "namespaces" ]; then
				if [ -z "$FILTERS" ]; then
					kubectl get namespaces --output=wide
				else
					kubectl get namespaces --output=wide | grep -E "$(IFS="|"; echo "$FILTERS")"
				fi
			else
				if [ -z "$FILTERS" ]; then
					kubectl get "$TYPE" --all-namespaces --output=wide
				else
					kubectl get "$TYPE" --all-namespaces --output=wide | grep -E "$(IFS="|"; echo "$FILTERS")"
				fi
			fi
		done
	fi
}

function _k_ns() {
	if [ "$1" = "help" ] || [ "$1" = "--help" ]; then
		echo "Usage: k ns [namespace]"
		echo "  Switch active namespace for kubectl context."
		echo "  If no namespace is given, resets to 'default'."
		echo ""
		echo "Examples:"
		echo "  k ns my-namespace"
		echo "  k ns           # reset to default namespace"
		return
	fi
	if [ -z "$1" ]; then
		echo "Switching to default namespace..."
		kubectl config set-context --current --namespace=default
		echo "Namespace set to 'default'."
	else
		echo "Switching to namespace '$1'..."
		kubectl config set-context --current --namespace="$1"
		echo "Namespace set to '$1'."
	fi
}

function _k_help() {
		echo "Usage: k <command> [args...]"
		echo "Commands:"
		echo "  get <resource> [pattern ...]         		List resources (pods, svc, deploy, etc.) in all namespaces"
		echo "  desc <resource> <name/pattern>   			Describe resource(s)"
		echo "  logs <pod> [container]               		Show logs for pod (optionally for container)"
		echo "  exec <pod> [container] [cmd]         		Exec into pod (optionally specify container and command)"
		echo "  bash <pod> [container]               		Exec bash in pod"
		echo "  sh <pod> [container]                 		Exec sh in pod"
		echo "  apply <file>                         		Apply manifest file"
		echo "  del <resource> <name/pattern>     			Delete resource(s)"
		echo "  cp <src> <dest>                      		Copy files to/from pods"
		echo "  edit <resource> <name>               		Edit resource"
		echo "  pf <pod/svc> <local>:<remote>  				Port forward"
		echo "  types                                		List all resource types available to kubectl"
		echo "  ls [types] [filter ...]               		List resources by type (comma-separated), optionally filter output"
		echo "      k ls help                               	Show usage and supported types for k ls"
		echo "  ns [namespace]                       		Switch active namespace (empty to reset to default)"
		echo "      k ns help                               	Show usage for k ns"
		echo ""
		echo "Examples:"
		echo "  k get pods"
		echo "  k get svc myapp"
		echo "  k desc pod mypod"
		echo "  k logs mypod"
		echo "  k exec mypod"
		echo "  k bash mypod"
		echo "  k del pod mypod"
		echo "  k apply ./deploy.yaml"
		echo "  k cp ./file.txt mypod:/tmp/file.txt"
		echo "  k edit deployment myapp"
		echo "  k pf svc/myapp 8080:80"
		echo "  k types"
		echo "  k ls"
		echo "  k ls po,svc,deployment pod_name_to_filter"
		echo "  k ls help"
		echo "  k ns my-namespace"
		echo "  k ns help"
}
function k() {
    case "$1" in
        get) shift; _k_get "$@";;
        desc) shift; _k_describe "$@";;
        logs) shift; _k_logs "$@";;
        exec) shift; _k_exec "$@";;
        bash) shift; _k_bash "$@";;
        sh) shift; _k_sh "$@";;
        apply) shift; _k_apply "$@";;
        del) shift; _k_delete "$@";;
        cp) shift; _k_cp "$@";;
        edit) shift; _k_edit "$@";;
        pf) shift; _k_port_forward "$@";;
        types) _k_types;;
        ls) shift; _k_ls "$@";;
        ns) shift; _k_ns "$@";;
        help|"" ) _k_help;;
        *) echo "Unknown command: $1. Use 'k help' for usage.";;
    esac
}
