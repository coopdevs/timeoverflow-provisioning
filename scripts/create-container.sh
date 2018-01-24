#!/bin/bash

# Flags
set -e
# Uncomment the following line to debug the script
# set -x

# Load configuration
# shellcheck source=/dev/null
source "$PWD/scripts/config/lxc.cfg"

RETRIES=5

# Create LXC config file
echo "Creating config file: $LXC_CONFIG"
cat > "$LXC_CONFIG" <<EOL
# Network
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = lxcbr0

# Volumes
lxc.mount.entry = $PROJECT_PATH /var/lib/lxc/$NAME/rootfs/opt/$PROJECT_NAME none bind,create=dir 0.0
EOL

# Print configuration
echo "* CONFIGURATION:"
echo "  - Name: $NAME"
echo "  - Template: $TEMPLATE"
echo "  - LXC Configuration: $LXC_CONFIG"
echo "  - Release: $RELEASE"
echo "  - Host: $HOST"
echo "	- Project Name: $PROJECT_NAME"
echo "	- Project Directory: $PROJECT_PATH"
echo

# Create container
exist_container="$(sudo lxc-ls --filter ^"$NAME"$)"
if [ -z "${exist_container}" ] ; then
  echo "Creating container $NAME"
  sudo lxc-create --name "$NAME" -f "$LXC_CONFIG" -t "$TEMPLATE" -l INFO -- --release "$RELEASE"
fi
echo "Container ready"

# Check if container is running, if not start
count=1
while [ $count -lt $RETRIES ] && [ -z "$is_running" ]; do
  is_running=$(sudo lxc-ls --running --filter ^"$NAME"$)
  if [ -z "$is_running" ] ; then
    echo "Starting container"
    sudo lxc-start -n "$NAME" -d -l INFO
    ((count++))
  fi
done

# If container is not running stop execution
if [ -z "$is_running" ]; then
  echo "Container not started, something is wrong."
  echo "Please check log file /var/log/lxc/$NAME.log"
  exit 0
fi
echo "Container is running..."

# Wait to start container and check the IP
count=1
ip_container="$(sudo lxc-info -n "$NAME" -iH)"
while [ $count -lt $RETRIES ] && [ -z "$ip_container" ] ; do
  sleep 2
  echo "Waiting for container IP..."
  ip_container="$(sudo lxc-info -n "$NAME" -iH)"
  ((count++))
done
echo "Container IP: $ip_container"
echo

# Add container IP to /etc/hosts
echo "Removing old host $HOST from /etc/hosts"
sudo sed -i '/'"$HOST"'/d' /etc/hosts
host_entry="$ip_container       $HOST"
echo "Add '$host_entry' to /etc/hosts"
sudo -- sh -c "echo $host_entry >> /etc/hosts"
echo

# SSH Key
echo "Removing old $HOST from ~/.ssh/know_hosts"
ssh-keygen -R "$HOST"
echo
sudo lxc-ls -f --filter ^"$NAME"$
echo

# Add system user's SSH public key to root user in container
ssh_path="$HOME/.ssh/id_rsa.pub"
echo "Reading SSH public key from ${ssh_path}"
read -r ssh_key < "$ssh_path"
echo "Copying system user's SSH public key to root user in container"
sudo lxc-attach -n "$NAME" -- /bin/bash -c "/bin/mkdir -p /root/.ssh && echo $ssh_key > /root/.ssh/authorized_keys"

# Install python2.7 in container
echo "Installing Python2.7 in container $NAME"
sudo lxc-attach -n "$NAME" -- sudo apt update
sudo lxc-attach -n "$NAME" -- sudo apt install -y python2.7

# Ready to provision the container
echo "Very well! LXC container $NAME has been created and configured"
echo "You should be able to run the following commands now:"
echo "> ansible-playbook playbooks/sys_admins.yml --limit=dev"
echo "> ansible-playbook playbooks/provision.yml --limit=dev"
