```sh
# for remote unlock
temp=$(mktemp -d)
install -d -m755 "$temp/etc/secrets/initrd"
ssh-keygen -t ed25519 -N "" -f $temp/etc/secrets/initrd/ssh_host_ed25519_key

# host key
install -d -m755 "$temp/etc/ssh"
ssh-keygen -t ed25519 -N "" -f $temp/etc/ssh/ssh_host_ed25519_key

# disk password
echo "password" > /tmp/password.key

# install
nix run github:nix-community/nixos-anywhere -- --extra-files "$temp" --disk-encryption-keys /tmp/password.key /tmp/password.key --flake .#ovhcloud root@<ip address>

# local update
nixos-rebuild switch --flake github:daniel-fahey/nixos-anywhere-examples#ovhcloud

# remote update (probably much slower)
nixos-rebuild switch --flake .#ovhcloud --target-host root@<ip address>
```