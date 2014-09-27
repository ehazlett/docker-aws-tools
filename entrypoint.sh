#!/bin/bash
set -e
ACTION=${1:-}
# provision docker host in aws
if [ "$ACTION" = "docker-host" ]; then
    if [ -z "$2" ]; then
        echo "Usage: docker-host <keypair> [security-groups-comma-separated] [region] [instance-type] [root-size] [zone] [number-of-instances]"
        exit 1
    fi
    KEYPAIR=$2
    SG=${3:-default}
    REGION=${4:-us-east-1}
    INSTANCE_TYPE=${5:-t2.micro}
    ROOT_SIZE=${6:-8}
    ZONE=${7:-us-east-1a}
    COUNT=${8:-1}
    IFS=',' read -ra SGROUPS <<< "$SG"
    SECURITY_GROUPS=""
    for GRP in "${SGROUPS[@]}"; do
        GRP_ID=`ec2-describe-group $GRP | head -1 | awk '{ print $2; }'`
        SECURITY_GROUPS="$SECURITY_GROUPS -g $GRP_ID "
    done
    cat << EOF > /tmp/provision
#!/bin/bash
apt-get update
apt-get install -y curl
curl get.docker.io | sh -
echo "DOCKER_OPTS=\"-H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375\"" >> /etc/default/docker
service docker restart
EOF
    if [ "$REGION" = "us-east-1" ]; then
        AMI=ami-0070c468
    elif [ "$REGION" = "us-west-1" ]; then
        AMI=ami-478d8502
    elif [ "$REGION" = "us-west-2" ]; then
        AMI=ami-33db9803
    elif [ "$REGION" = "eu-west-1" ]; then
        AMI=ami-2c90315b
    elif [ "$REGION" = "sa-east-1" ]; then
        AMI=ami-931bb18e
    elif [ "$REGION" = "cn-north-1" ]; then
        AMI=ami-645ecc5d
    elif [ "$REGION" = "ap-northeast-1" ]; then
        AMI=ami-0185ac00
    elif [ "$REGION" = "ap-southeast-1" ]; then
        AMI=ami-da4d6a88
    elif [ "$REGION" = "ap-aoutheast-2" ]; then
        AMI=ami-95d7b4af
    fi
    ec2-run-instances --region $REGION $AMI --block-device-mapping "/dev/sda1=:$ROOT_SIZE:true:standard" -f /tmp/provision $SECURITY_GROUPS -k $KEYPAIR -n $COUNT -t $INSTANCE_TYPE -z $ZONE --associate-public-ip-address true
else
    # if no 'known' action, try to execute command
    exec $*
fi
exit 0
