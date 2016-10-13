# We need four params: (1) PASSWORD (2) MASTERFQDN (3) MASTERPRIVATEIP (4) SLEEP

echo $(date) " - Starting Script"

PASSWORD=$1
MASTERFQDN=$2
MASTERPRIVATEIP=$3
SLEEP=$4

# System Update and docker version update
DEBIAN_FRONTEND=noninteractive apt-get -y update
apt-get install -y apt-transport-https ca-certificates
#apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#echo 'deb https://apt.dockerproject.org/repo ubuntu-trusty main' >> /etc/apt/sources.list.d/docker.list
curl -s 'https://sks-keyservers.net/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e' | apt-key add --import
echo 'deb https://packages.docker.com/1.12/apt/repo ubuntu-trusty main' >> /etc/apt/sources.list.d/docker.list
apt-cache policy docker-engine
DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Implement delay timer to stagger joining of Agent Nodes to cluster

echo $(date) "Sleeping for $SLEEP"
sleep $SLEEP

# Retrieve Fingerprint from Master Controller
#curl --insecure https://$MASTERFQDN/ca > ca.pem
#FPRINT=$(openssl x509 -in ca.pem -noout -sha256 -fingerprint | awk -F= '{ print $2 }' )
#echo $FPRINT

# Load the downloaded Tar File

#echo $(date) " - Loading docker install Tar"
#cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz
#docker load < ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz

# Start installation of UCP and join agent Nodes to cluster
#echo $(date) " - Loading complete.  Starting UCP Install of agent node"
#docker run --rm -i \
#    --name ucp \
#    -v /var/run/docker.sock:/var/run/docker.sock \
#    -e UCP_ADMIN_USER=admin \
#    -e UCP_ADMIN_PASSWORD=$PASSWORD \
#    docker/ucp:2.0.0-beta1 \
#    join --san $MASTERFQDN --fresh-install --url https://${MASTERFQDN}:443 --fingerprint "${FPRINT}"

#if [ $? -eq 0 ]
#then
# echo $(date) " - UCP installed and started on the agent node"
#else
#echo $(date) " -- UCP installation failed on agent node"
#fi

# Configure NginX

echo $(date) " - Initiating NginX configuration on the agent node"

docker run -d \
--label interlock.ext.name=nginx \
--restart=always \
-p 80:80 \
-p 443:443 \
nginx \
nginx -g "daemon off;" -c /etc/nginx/nginx.conf

if [ $? -eq 0 ]
then
 echo $(date) " - NginX Install complete"
else
 echo $(date) " -- NginX Install failed"
fi
echo $(date) " - Staring Swarm Join as worker UCP Controller"
apt-get -y update && apt-get install -y curl jq
# Create an environment variable with the user security token
AUTHTOKEN=$(curl -sk -d '{"username":"admin","password":"'"$PASSWORD"'"}' https://10.2.0.6/auth/login | jq -r .auth_token)
echo "$AUTHTOKEN"
# Download the client certificate bundle
curl -k -H "Authorization: Bearer ${AUTHTOKEN}" https://10.2.0.6/api/clientbundle -o bundle.zip
unzip bundle.zip && chmod 755 env.sh && source env.sh
docker swarm join-token worker|sed '1d'|sed '1d'|sed '$ d'>swarmjoin.sh
unset DOCKER_TLS_VERIFY
unset DOCKER_CERT_PATH
unset DOCKER_HOST
chmod 755 swarmjoin.sh
source swarmjoin.sh
