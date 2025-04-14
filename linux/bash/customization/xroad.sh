
export NIIS_HOME=/media/xrduser/niis
export XROAD_HOME=/media/xrduser/niis/X-Road
export XROAD_UTILS_HOME=/media/xrduser/niis/x-road-utils
export XROAD_METRICS_PATH=/media/xrduser/niis/X-Road-Metrics
export XROAD_CATALOG_HOME=/media/xrduser/niis/x-road-catalog
export XROAD_TOOLKIT_HOME=/media/xrduser/niis/X-Road-Security-Server-toolkit

alias c='cd $XROAD_CATALOG_HOME'
alias niis='cd $NIIS_HOME'
alias x='cd $XROAD_HOME'
alias u='cd $XROAD_UTILS_HOME'
alias m='cd $XROAD_METRICS_PATH'
alias m2='cd /media/xrduser/goa/metrics'
alias t='cd $XROAD_TOOLKIT_HOME'
alias xs='cd $XROAD_HOME/src'
alias ssui='cd $XROAD_HOME/src/security-server/admin-service/ui'
alias dep='$XROAD_UTILS_HOME/docker/dev/tools/deploy.sh'
# alias dc='$XROAD_UTILS_HOME/docker/dev/tools/setup_dev_containers.sh -c e2e'
# alias dconf='$XROAD_UTILS_HOME/docker/dev/tools/configure_ss1.sh'
alias mld='cd $XROAD_UTILS_HOME/xroad-ext-opmon/docker/local-dev'
alias xld='cd $XROAD_HOME/Docker/xrd-dev-stack'
alias ui='pnpm dev'
alias umd='cd $XROAD_UTILS_HOME/xroad-ext-opmon/docker/local-dev/'
alias md='cd $XROAD_METRICS_PATH/docker'

alias ss-st='./gradlew :security-server:system-test:systemTest -PsystemTestSsPackageHost=https://s3-eu-west-1.amazonaws.com/niis-xroad-development'
alias cj='./gradlew clean build -x intTest -x systemTest'

# cx = Curl (or Call :D) X-road as a client
function cx() {
  local count=${1}  # count of requests, mandatory
  local url=${2}  # No default value for URL, mandatory
                  # sample URL: http://localhost:4310/r1/DEV/COM/1234/TestService/pets/123
  local client=${3:-DEV/COM/4321/TestClient}  # Default to DEV/COM/4321/TestClient, optional

  echo "{\"Count\": \"$count\", \"URL\": \"$url\", \"Client\": \"$client\"}" | jq

  if [ -z "$url" ]; then
    echo "What URL?"
  else
    for i in $(seq 1 $count); do
      echo "$url"
    done | xargs -t -I {} curl -H "accept: application/json" -H "X-Road-Client: $client" '{}' -k
  fi
}

# cpr = CoPy x-road metrics Reports
function cpr() {
  if [ -z $1 ]; then
    echo "Which container?";
  else
    d ls | grep $1 | awk '{print $1}' | xargs -I {}  docker cp {}:/home/xroad-metrics/reports/ .
  fi
}
