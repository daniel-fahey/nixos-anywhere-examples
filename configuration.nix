{ modulesPath, config, lib, pkgs, secrets, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  # This line will populate NIX_PATH
  nix.nixPath = [ "nixpkgs=${pkgs.path}" ]; # for `nix-shell -p ...`

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  services.openssh.enable = true;
  services.openssh.settings.X11Forwarding = true;

  environment.variables.EDITOR = "vim";

  networking = {
    interfaces = {
      eno3.ipv6.addresses = [{
        address = secrets.networking.ipv6_address;
        prefixLength = 64;
      }];
    };
    defaultGateway6 = {
      address = secrets.networking.ipv6_gateway;
      interface = "eno3";
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
  };

  # https://nixos.org/manual/nixos/unstable/#module-security-acme-nginx
  security.acme = {
    acceptTerms = true;
    defaults.email = secrets.acme.email;
  };
  services.nginx = {
    enable = true;
    virtualHosts = let
      domain = secrets.nginx.domain;
    in {
      "${domain}" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ domain ];
        locations."/" = {
          root = "/var/www";
        };
      };
    };
  };



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
    nettools
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
    yggdrasil
    speedtest-go
    unibilium
    kitty
    git-crypt
  ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "daily";
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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbyBsOYlK6k6hQvpOwe9v6xC0mqpUvaR7oRUjsKU7EZ"
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

  boot.kernelParams = [ "ip=dhcp" ];

  zramSwap = {
    enable = true;
    swapDevices = 1;  # One zram device
    memoryPercent = 50;  # Use up to 50% of total RAM
    algorithm = "zstd";  # Use Zstandard compression
    priority = 10;  # Higher priority than disk-based swap
    # Optional: memoryMax, writebackDevice
  };

  system.stateVersion = "23.11";
}
