{ modulesPath, config, lib, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  services.openssh.enable = true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # Ensure the rsync package is available on the system
  environment.systemPackages = with pkgs; [
    rsync
    curl
    git
    htop
    vim
    tmux
    lsof
    net-tools
    nmap
    strace
    tcpdump
    iotop
    ncdu
    btdu
    iftop
    bash-completion
    pciutils
    ethtool
    go
    python311Full
    R
    yggdrasil
  ];

  services.btrfs.autoScrub = {
    enable = true;
    period = "daily";
  };

  # Define the activation script
  system.activationScripts.copyESP = {
    text = ''
      # Ensure the mount point for the secondary ESP exists
      mkdir -p /efi2
      
      # Mount the backup ESP
      mount /dev/disk/by-partlabel/disk-backup-ESP /efi2
      
      # Use rsync to copy the ESP contents. This will only copy changes.
      ${pkgs.rsync}/bin/rsync --archive --delete /efi/ /efi2/
      
      # Unmount the secondary ESP
      umount /efi2
    '';
    deps = [];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIx7HUtW51MWtbPo/9Sq3yUVfNjPAZgRCDBkv4ZKVE55 dpfahey@gmail.com"
  ];

  # ssh setup
  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 2222;
    shell = "/bin/cryptsetup-askpass";
    authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
    hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
  };

  boot.initrd.availableKernelModules = [ "ixgbe" ];

  system.stateVersion = "23.11";
}
