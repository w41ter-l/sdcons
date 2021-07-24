#!/bin/bash

ERROR() {
  /bin/echo -e "\e[101m\e[97m[ERROR]\e[49m\e[39m" "$@"
}

WARNING() {
  /bin/echo -e "\e[101m\e[97m[WARNING]\e[49m\e[39m" "$@"
}

INFO() {
  /bin/echo -e "\e[104m\e[97m[INFO]\e[49m\e[39m" "$@"
}

mkdir -p secret
mkdir -p run

INFO "Generating ./secret/node.env"
{
  echo "# generated by jepsen/docker/build.sh"
  echo "ROOT_PASS=root"
  echo "AUTHORIZED_KEYS=$(cat ~/.ssh/id_rsa.pub)"
} >>./secret/node.env

INFO "Running \`docker-compose build\`"
docker-compose -f docker-compose.yml build

INFO "Running \`docker-compose up\`"
docker-compose -f docker-compose.yml up -d

INFO "Dump containers addresses to file hosts"
H1=$(docker inspect --format '{{ .NetworkSettings.Networks.docker_jepsen.IPAddress }}' sdcons-jepsen-n1)
H2=$(docker inspect --format '{{ .NetworkSettings.Networks.docker_jepsen.IPAddress }}' sdcons-jepsen-n2)
H3=$(docker inspect --format '{{ .NetworkSettings.Networks.docker_jepsen.IPAddress }}' sdcons-jepsen-n3)
H4=$(docker inspect --format '{{ .NetworkSettings.Networks.docker_jepsen.IPAddress }}' sdcons-jepsen-n4)
H5=$(docker inspect --format '{{ .NetworkSettings.Networks.docker_jepsen.IPAddress }}' sdcons-jepsen-n5)

cat >hosts <<EOF
1 $H1
2 $H2
3 $H3
4 $H4
5 $H5
EOF

kv_port=8000
cons_port=8001
snapshot_port=8002

cat >run/kv_named_file <<EOF
{
  "1": "${H1}:${kv_port}",
  "2": "${H2}:${kv_port}",
  "3": "${H3}:${kv_port}",
  "4": "${H4}:${kv_port}",
  "5": "${H5}:${kv_port}"
}
EOF

cat >run/cons_named_file <<EOF
{
  "1": "${H1}:${cons_port}",
  "2": "${H2}:${cons_port}",
  "3": "${H3}:${cons_port}",
  "4": "${H4}:${cons_port}",
  "5": "${H5}:${cons_port}"
}
EOF

cat >run/snapshot_named_file <<EOF
{
  "1": "${H1}:${snapshot_port}",
  "2": "${H2}:${snapshot_port}",
  "3": "${H3}:${snapshot_port}",
  "4": "${H4}:${snapshot_port}",
  "5": "${H5}:${snapshot_port}"
}
EOF

for id in {1..5}; do
  mkdir -p run/server/$id/data
  mkdir -p run/server/$id/wal
  cat >run/server/$id/config.toml <<EOF
id=${id}
kv_port=${kv_port}
cons_port=${cons_port}
snapshot_port=${snapshot_port}
named_file="/root/run/cons_named_file"
snapshot_named_file="/root/run/snapshot_named_file"
data_dir="/root/run/server/${id}/data"
wal_dir="/root/run/server/${id}/wal"
EOF
done

binary_dir=`pwd`
binary_dir=${binary_dir%"/examples/jepsen/docker"}
cp -f ${binary_dir}/target/debug/kv-server `pwd`/run/kv-server

INFO "All containers started, run \`docker ps\` to view"
INFO "Finished."
