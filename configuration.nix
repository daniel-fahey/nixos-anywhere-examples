{ modulesPath, config, lib, pkgs, secrets, ... }:

let
  # Custom derivation to substitute placeholders in coolwsd.xml
  coolwsdXml = pkgs.stdenv.mkDerivation {
    name = "coolwsd-xml";
    src = ./coolwsd.xml; # Adjust if coolwsd.xml is in a different directory
    buildInputs = [ pkgs.gnused ];

    unpackPhase = ":"; # Override default unpack phase
    patchPhase = ":"; # Override default patch phase

    buildPhase = ''
      cp $src coolwsd.xml
      sed -i \
        -e "s|__NEXTCLOUD_DOMAIN__|cloud.${secrets.nginx.domain}|g" \
        -e "s|__PASSWORD__|${secrets.collabora.admin-password}|g" \
        coolwsd.xml
    '';

    installPhase = ''
      mkdir -p $out
      cp coolwsd.xml $out
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  users.users.daniel = {
    isNormalUser = true;
    extraGroups = [ 
      "wheel" # Enable ‘sudo’ for the user.
    ];
  };

  # This line will populate NIX_PATH
  nix.nixPath = [ "nixpkgs=${pkgs.path}" ]; # for `nix-shell -p ...`

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-substituters = [ "https://cache.nixos.org/" "https://ai.cachix.org" ];
  nix.settings.trusted-users = [ "root" "daniel" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      X11Forwarding = true;
    };
  };

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

  mailserver = {
    enable = true;
    fqdn = "mail.${secrets.nginx.domain}";
    domains = [ secrets.nginx.domain ];

    certificateScheme = "acme";

  };

  environment.etc."coolwsd/coolwsd.xml".source = coolwsdXml;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.collabora = {
      image = "collabora/code:latest";
      volumes = [
        # Mount the coolwsd.xml file in the container
        "${coolwsdXml}/coolwsd.xml:/etc/coolwsd/coolwsd.xml"
      ];
      # imageFile = pkgs.dockerTools.pullImage {
      #   imageName = "collabora/code";
      #   imageDigest = "sha256:d9b7ca592d2fb6956b7bf399b7080c338a73ea336718570051749ebcb9546ef2";
      #   sha256 = "05zk1p9mby59id7ny78d971nsz9dyrrf1ng6dsd2y7nkwa1679m4";
      # };
      ports = ["9980:9980"];
      # environment = {
      #   # username = "admin";
      #   # password = secrets.collabora.admin-password;
      #   # server_name = builtins.replaceStrings ["."] ["\\."] "code.${secrets.nginx.domain}"; # corrupts URL in /hosting/discovery
      #   aliasgroup1 = builtins.replaceStrings ["."] ["\\."] "https://cloud.${secrets.nginx.domain}";
      #   server_name = "code.${secrets.nginx.domain}";
      #   # aliasgroup1 = "https://cloud.${secrets.nginx.domain}:443";
      #   extra_params = "--o:ssl.enable=false --o:ssl.termination=true";
      # };
      extraOptions = [ "--cap-add=MKNOD" ];
    };
  };

  services.nginx = {
    enable = true;

    additionalModules = [ pkgs.nginxModules.moreheaders ]; # Include headers-more-nginx-module

    virtualHosts = let
      domain = secrets.nginx.domain;
    in {
      # "${domain}" = {
      #   forceSSL = true;
      #   enableACME = true;
      #   serverAliases = [ domain ];
      #   locations."/" = {
      #     root = "/var/www";
      #   };
      # };
      "mail.${domain}" = {
        forceSSL = true;
        enableACME = true;
      };
      ${config.services.nextcloud.hostName} = {
        forceSSL = true;
        enableACME = true;
        # locations = {
        #   "/".proxyWebsockets = true;
        # };
      };
      "code.${secrets.nginx.domain}" = {
        forceSSL = true;
        enableACME = true;
        locations = let
          collaboraURL = "http://localhost:9980";
          collaboraProxy = {
            proxyPass = collaboraURL;
            extraConfig = ''
              proxy_set_header Host $host;
              more_set_headers "X-Frame-Options: ALLOWALL";
            '';
          };
          collaboraSocket = {
            proxyPass = collaboraURL;
            extraConfig = ''
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
              proxy_set_header Host $host;
              proxy_read_timeout 36000s;
              more_set_headers "X-Frame-Options: ALLOWALL"; # Note: The Admin Console websocket does not use X-Frame-Options
            '';
          };
        in {
          "^~ /browser" = collaboraProxy; # static files
          "^~ /hosting/discovery" = collaboraProxy; # WOPI discovery URL
          "^~ /hosting/capabilities" = collaboraProxy; # Capabilities
          "~ ^/cool/(.*)/ws$" = collaboraSocket; # main websocket
          "~ ^/(c|l)ool" = collaboraProxy; # download, presentation and image upload
          "^~ /cool/adminws" = collaboraSocket; # Admin Console websocket
        };
      };
    };
  };

  age.secrets.nextcloud-admin-pass = {
    file = ./secrets/nextcloud-admin-pass.age;
    mode = "600";
    owner = "nextcloud";
    group = "nextcloud";
  };

  services.nextcloud = {                
    enable = true;
    package = pkgs.nextcloud28;
    hostName = "cloud.${secrets.nginx.domain}";
    database.createLocally = true;
    config = {
      adminpassFile = config.age.secrets.nextcloud-admin-pass.path;
      dbtype = "pgsql";
    };
    appstoreEnable = true;
    # autoUpdateApps.enable = true;
    # extraApps = {
    #   inherit (config.services.nextcloud.package.packages.apps) contacts calendar tasks polls twofactor_webauthn deck mail;
    #   richdocuments = pkgs.fetchNextcloudApp {
    #     # sha256 and url from https://github.com/helsinki-systems/nc4nix/blob/main/28.json
    #     sha256 = "1d2pc1d871dwrqcif8qp5ixrvjjbcpy0b6p1a9pkh8hj616zhjc6"; # used nix repl with builtins.fetchTarball
    #     url = "https://github.com/nextcloud-releases/richdocuments/releases/download/v8.3.1/richdocuments-v8.3.1.tar.gz";
    #     license = "agpl3";
    #   };
    #   # richdocumentscode = pkgs.fetchNextcloudApp {
    #   #   sha256 = "z+MKslAyWo/DWw5h4XpxgTuvgsUE+UQ652DPIoJgEyo="; # had to use lib.fakeSha256 to get correct hash
    #   #   url = "https://github.com/CollaboraOnline/richdocumentscode/releases/download/23.5.705/richdocumentscode.tar.gz";
    #   #   # must use license names from https://github.com/NixOS/nixpkgs/blob/master/lib/licenses.nix
    #   #   license = "asl20";
    #   # };
    # };
    # extraAppsEnable = true;
    configureRedis = true;
    extraOptions = {
      mail_smtpmode = "sendmail";
      mail_sendmailmode = "pipe";
      # overwriteprotocol = "https";
      default_phone_region = "GB";
      # allow_local_remote_servers = true;
      # trusted_domains = [ config.virtualisation.oci-containers.containers.collabora.environment.server_name ];
      overwrite.cli.url = "https://cloud.${secrets.nginx.domain}";
    };
    maxUploadSize = "16G";
    https = true;
    # phpOptions = {
    #   "opcache.jit" = "tracing";
    #   "opcache.jit_buffer_size" = "100M";
    #   # recommended by nextcloud admin overview
    #   "opcache.interned_strings_buffer" = "16";
    # };

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
    memoryPercent = 95;  # Use up to 95% of total RAM
    algorithm = "zstd";  # Use Zstandard compression
    priority = 10;  # Higher priority than disk-based swap
    # Optional: memoryMax, writebackDevice
  };

  system.stateVersion = "23.11";
}
