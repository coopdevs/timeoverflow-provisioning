#!/bin/bash

# Flags
# set -e

# External files
# Get cfg values
source "$PWD/scripts/config/lxc.cfg"

RETRIES=5

# Check config file
echo "Checking config file"
if [ ! -e "$LXC_CONFIG" ] ; then
  echo "Creating config file: $LXC_CONFIG"
  network_link="$(brctl show | awk '{if ($1 != "bridge")  print $1 }')"
  cat >"$LXC_CONFIG" <<EOL
# Network configuration
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = $network_link
EOL
fi

# Print configuration
echo "* CONFIGURATION:"
echo "  - Name: $NAME"
echo "  - Template: $TEMPLATE"
echo "  - LXC Configuration: $LXC_CONFIG"
echo "  - Release: $RLS"
echo "  - Host: $HOST"
echo "	- Project Name: $PROJECT_NAME"
echo "	- Project Directory: $PROJECT_PATH"
echo

echo
echo

# Check container
exist_container="$(sudo lxc-ls "$NAME")"
if [ -z "${exist_container}" ] ; then
  echo "Creating container $NAME"
  sudo lxc-create --name "$NAME" -f "$LXC_CONFIG" -t "$TEMPLATE" -l INFO --logfile "./log/$NAME-create.log" -- --release "$RLS"
fi
echo "Container ready"

# Check if container is running, if not start
count="0"
while [ "$count" -lt $RETRIES ] && [ -z "$is_running" ]; do
  is_running=$(sudo lxc-ls --running -f | grep "$NAME")
  if [ -z "$is_running" ] ; then
    echo "Starting container"
    sudo lxc-start -n "$NAME" -d -l INFO --logfile "./log/$NAME-start.log"
    ((count++))
  fi
done

# If not is running stop execution
if [ -z "$is_running" ]; then
  echo "Container not started..."
  echo "STOP EXECUTION"
  exit 0
fi

echo "Container is running..."
# Wait to start container and check the ip
count="0"
ip_container="$( sudo lxc-info -n "$NAME" -iH )"
while [ "$count" -lt $RETRIES ] && [ -z "$ip_container" ] ; do
  sleep 2
  echo "waiting for container ip..."
  ip_container="$( sudo lxc-info -n "$NAME" -iH )"
  ((count++))
done
echo "Container IP: $ip_container"
echo

# ADD IP TO HOSTS
echo "Removing old host $HOST from /etc/hosts"
sudo sed -i '/'"$HOST"'/d' /etc/hosts
host_entry="$ip_container       $HOST"
echo "Add '$host_entry' to /etc/hosts"
sudo -- sh -c "echo $host_entry >> /etc/hosts"
echo
# SSH Key

echo "Removing old $HOST from  ~/.ssh/know_hosts"
ssh-keygen -R "$HOST"
echo
sudo lxc-ls -f "$NAME"
echo

# Create app user and set password
echo "Create user $APP_USER"
sudo lxc-attach -n "$NAME" -- useradd -m "$APP_USER"
echo "Setting password of $APP_USER..."
sudo lxc-attach -n "$NAME" -- passwd "$APP_USER"
echo
echo "Copy ssh key for $APP_USER"
ssh-copy-id "$APP_USER@$HOST"

# Mount project folder
echo "Mounting project folder..."
mount_entry="lxc.mount.entry = $PROJECT_PATH /var/lib/lxc/$NAME/rootfs/home/$APP_USER/$PROJECT_NAME none bind,create=dir 0.0"
echo "$mount_entry" | sudo tee -a /var/lib/lxc/"$NAME"/config > /dev/null
echo
echo "Create sudoers file for user $APP_USER"
echo "$APP_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /var/lib/lxc/"$NAME"/rootfs/etc/sudoers.d/1-"$APP_USER" > /dev/null

# Reboot the container
echo "Rebooting container"
sudo lxc-stop -n "$NAME"
sleep 5
sudo lxc-start -n "$NAME"

# Install python2.7 in container:
sleep 2
echo "Installing Python2.7"
sudo lxc-attach -n "$NAME" -- sudo apt update
sudo lxc-attach -n "$NAME" -- sudo apt install -y python2.7
echo
sudo lxc-ls -f "$NAME"
