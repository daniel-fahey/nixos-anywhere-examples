{ modulesPath, config, lib, pkgs, ... }: {
  imports = [
    #(modulesPath + "/installer/scan/not-detected.nix")
    #(modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  services.openssh.enable = true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIx7HUtW51MWtbPo/9Sq3yUVfNjPAZgRCDBkv4ZKVE55 dpfahey@gmail.com"
  ];

  system.stateVersion = "23.11";
}
