#!/bin/bash
set -e

apt-get update -y
apt-get install -y docker.io git
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

%{ if deploy_type == "docker_run" ~}
docker pull ${docker_image}
docker run -d \
  --name target-app \
  --restart unless-stopped \
  -p 80:${container_port} \
  ${docker_image}
%{ endif ~}

%{ if deploy_type == "compose" ~}
apt-get install -y docker-compose
git clone ${git_repo} /opt/target-app
cd /opt/target-app
sed -i 's/"${container_port}:${container_port}"/"80:${container_port}"/' docker-compose.yml
docker-compose up -d --build
%{ endif ~}

wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E amazon-cloudwatch-agent.deb

cat << 'CFG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "metrics": {
        "namespace":"CWAgent",
        "metrics_collected": {
        "mem":{"measurement":["mem_used_percent"]},
        "disk":{"measurement":["used_percent"],
                "resources":["/"]}
        }
    }
}
CFG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
