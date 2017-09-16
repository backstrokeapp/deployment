#!/bin/sh
set +x

cert="./backstroke.pem"
compose="./docker-compose.yml"
haproxy="./haproxy.conf"
postgres_certs="./postgres_certs"
ip="138.197.231.165"

# Create droplet.
if ! doctl compute droplet ls | grep backstroke 2>&1 > /dev/null; then
  echo "* Creating compute resources..."
  doctl compute droplet create backstroke \
    --enable-ipv6 \
    --enable-monitoring \
    --enable-private-networking \
    --image 27493072 \
    --region nyc1 \
    --size 1gb \
    --ssh-keys "$(doctl compute ssh-key ls | grep Backstroke | awk '{ print $3 }')" \
    --wait
else
  echo "* Compute resources already exist."
fi

# If the floating ip is not assigned to backstroke, reassign it to the droplet we just created.
if ! doctl compute floating-ip get $ip | grep backstroke 2>&1 > /dev/null; then
  if [ "$(doctl compute floating-ip get $ip --format DropletID --no-header | sed 's/\w//g')" != "" ]; then
    echo "* Unassigning floating ip..."
    doctl compute floating-ip-action unassign $ip
    sleep 3
  fi
  echo "* Assigning floating ip..."
  doctl compute floating-ip-action assign $ip "$(doctl compute droplet ls | grep backstroke | awk '{ print $1 }')"
  ssh-keygen -R $ip

  # Wait for the ip to point to something
  while true; do
    sleep 2
    echo "\n" | nc -w 1 $ip 22
    result=$(($?))
    if [ $result -eq 0 ]; then
      break
    else
      printf '.'
    fi
  done
  echo
  echo "* Compute resource contected via floating ip!"
else
  echo "* Floating ip already assigned."
fi

echo "* Copying docker compose file..."
scp -i $cert $compose root@$ip:/opt/docker-compose.yml
scp -i $cert $compose.production root@$ip:/opt/docker-compose.yml.production

echo "* Copying haproxy file..."
scp -i $cert $haproxy root@$ip:/opt/haproxy.conf

#echo "* Copying postgres certificates and setting permissions..."
#scp -r -i $cert $postgres_certs root@$ip:/opt/postgres_certs/
#ssh -i $cert root@$ip 'sudo chmod 600 /opt/postgres_certs/server.key && sudo chown postgres:postgres /opt/postgres_certs/server.key'

echo "* Stopping services..."
ssh -i $cert root@$ip "cd /opt && ls && docker-compose down"

echo "* Starting services..."
ssh -i $cert root@$ip "cd /opt && docker-compose -f docker-compose.yml -f docker-compose.yml.production pull && docker-compose -f docker-compose.yml -f docker-compose.yml.production up -d"

echo "* Done!"
