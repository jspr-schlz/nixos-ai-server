# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nixpkgs.overlays = [
    (final: prev: {
      llama-cpp = (prev.llama-cpp.overrideAttrs (oldAttrs: rec {
        version = "6885";
        src = final.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b${version}";
          hash = "sha256-fmSVLyX7QR45C+JRgTsh+MaXQajuyM5SJbxo47IuodE=";
        };
      })).override { vulkanSupport = true; };
    })
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Modprobe - maximize GTT for LLM usage on 128GB UMA system
  boot.extraModprobeConfig =
  ''
    options amdgpu gttsize=120000
    options ttm pages_limit=31457280
    options ttm page_pool_size=15728640
  '';

  networking.hostName = "homelab01"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "de_DE.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jasper = {
    isNormalUser = true;
    description = "Jasper Schulz";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.rocmSupport = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    ethtool
    (python3.withPackages (python-pkgs: with python-pkgs; [
       pandas
    ]))
    python313Packages.conda
    python313Packages.pip
    docker
    toolbox
    tmux
    opencode
    llama-cpp
    git

    # Vulkan libs
    # vulkan-radeon
    amdvlk
    vulkan-headers
    vulkan-tools

    #rocmPackages.rocminfo
    #rocmPackages.rocm-smi
    #rocmPackages.hipcc
    #rocmPackages.rpp
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Optional, für 32-Bit-Apps
    extraPackages = with pkgs; [
      amdvlk
      vulkan-headers
      vulkan-tools  # Für Tests wie vulkaninfo
    ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  virtualisation.docker.enable = true;
 
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/jasper"
  ];

  systemd.services.llama-cpp = {
    enable = true; 
    wantedBy = [ "multi-user.target" ]; 
    serviceConfig = {
      User = "jasper";
      Type = "simple";
      Restart = "always";
      # Debug available GPUs in systemd ExecStart = "${pkgs.llama-cpp}/bin/llama-server -ngl 999 --list-devices";
      ExecStart = ''
        ${pkgs.llama-cpp}/bin/llama-server \
          --host :: \
          --jinja \
          --no-mmap \
          --temp 1.0 \
          --min-p 0.0 \
          --top-p 0.95 \
          --top-k 64 \
          -c 0 -fa on \
          --n-gpu-layers 999 \
          -hf unsloth/gemma-3-27b-it-GGUF
      '';
      # llama-server --host :: --jinja --no-mmap --temp 0.6 --min-p 0.0 --top-p 0.95 --top-k 20 -c 0 -fa on --n-gpu-layers 999 -hf Qwen/Qwen3-30B-A3B-GGUF:Q4_K_M
      # Hardening lockern für GPU-Zugriff
      ProtectSystem = "full";  # Statt "strict" – erlaubt read-only System-Pfade (z. B. Vulkan-Configs)
      PrivateTmp = true;  # Bleibt (sicher)
      PrivateDevices = false;  # Wichtig: Erlaubt /dev/dri und GPU-Devices!
      DeviceAllow = [
        "/dev/dri rw"  # Allgemein für DRI-Zugriff
        "/dev/dri/renderD128 rw"  # Spezifisch für deinen Render-Node (rw für read/write)
        "/dev/dri/card0 rw"  # Für das Card-Device, falls benötigt (manchmal für Vulkan-Init)
      ];
      ProtectKernelModules = false;  # Falls Vulkan Kernel-Mods braucht
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ 8080 80 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
