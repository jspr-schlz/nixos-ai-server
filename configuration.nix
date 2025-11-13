# =============================================================================
# NixOS Configuration for AMD Strix Halo LLM Server
# =============================================================================
# 
# This configuration sets up a NixOS system optimized for running LLM inference
# with llama.cpp on AMD Strix Halo APU using Vulkan backend.
#
# Hardware: AMD Strix Halo (RDNA 3+ iGPU with unified memory architecture)
# Target: High-performance LLM inference server
# Backend: Vulkan (AMDVLK)
#
# Author: Jasper Schulz
# Repository: https://github.com/yourusername/nixos-ai-server
# =============================================================================

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # Hardware-specific configuration
  ];

  # =============================================================================
  # CUSTOM PACKAGES OVERLAY
  # =============================================================================
  # Override llama.cpp with latest build optimized for AMD Strix Halo
  # This ensures we have the latest Vulkan optimizations and Strix Halo support
  nixpkgs.overlays = [
    (final: prev: {
      llama-cpp = (prev.llama-cpp.overrideAttrs (oldAttrs: rec {
        # Use latest llama.cpp build (b7050) with enhanced Vulkan support
        version = "7050";
        src = final.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b${version}";
          hash = "sha256-74e60ee220569b25fc598641964872e1a3035ec8b216c5df4ed0dc2fc14e183a";
        };
      })).override { 
        vulkanSupport = true;  # Enable Vulkan backend for AMD GPU acceleration
      };
    })
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

  # =============================================================================
  # BOOT AND KERNEL CONFIGURATION
  # =============================================================================
  
  # Use systemd-boot with EFI support
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel for best hardware support and performance
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =============================================================================
  # AMD STRIX HALO SPECIFIC KERNEL MODULES
  # =============================================================================
  # These settings optimize the AMD GPU driver for LLM workloads on Strix Halo:
  # - gttsize=120000: Maximize Graphics Translation Table for large models (120GB)
  # - pages_limit/page_pool_size: Optimize TTM memory management for UMA systems
  # - sg_display=0: Disable display-related memory allocation for compute-only workloads
  # - vm_fragment_size=9: Optimize virtual memory fragmentation for large models
  boot.extraModprobeConfig = ''
    options amdgpu gttsize=120000
    options ttm pages_limit=31457280
    options ttm page_pool_size=15728640
    options amdgpu sg_display=0
    options amdgpu vm_fragment_size=9
  '';

  # =============================================================================
  # NETWORK AND LOCALIZATION
  # =============================================================================
  
  networking.hostName = "homelab01";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";

  # German localization
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

  # German keyboard layout
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  console.keyMap = "de";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # =============================================================================
  # USER CONFIGURATION
  # =============================================================================
  
  users.users.jasper = {
    isNormalUser = true;
    description = "Jasper Schulz";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
  };

  # =============================================================================
  # PACKAGE CONFIGURATION
  # =============================================================================
  
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # System utilities
    vim
    wget
    curl
    ethtool
    git
    tmux
    
    # Python environment for AI/ML workloads
    (python3.withPackages (python-pkgs: with python-pkgs; [
       pandas
    ]))
    python313Packages.conda
    python313Packages.pip
    
    # Containerization
    docker
    toolbox
    
    # Development tools
    opencode
    
    # LLM inference engine (custom build with Vulkan support)
    llama-cpp
    
    # AMD Vulkan stack for Strix Halo GPU acceleration
    amdvlk              # AMD Vulkan driver
    vulkan-headers      # Vulkan development headers
    vulkan-tools        # Vulkan validation and debugging tools
  ];





  # =============================================================================
  # SERVICES
  # =============================================================================
  
  # Enable SSH for remote management
  services.openssh.enable = true;

  # Docker for containerized workloads
  virtualisation.docker.enable = true;
 
  # Allow user services to persist after logout
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/jasper"
  ];

  # =============================================================================
  # LLAMA.CPP SERVER SERVICE
  # =============================================================================
  # Systemd service for running llama.cpp server with AMD Strix Halo optimization
  systemd.services.llama-cpp = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "jasper";
      Type = "simple";
      Restart = "always";
      ExecStart = ''
        ${pkgs.llama-cpp}/bin/llama-server \
          --host :: \
          --port 8080 \
          --jinja \
          --no-mmap \
          --temp 1.0 \
          --min-p 0.0 \
          --top-p 0.95 \
          --top-k 64 \
          -c 0 -fa on \
          --n-gpu-layers 999 \
          --gpu-layers-stride 8 \
          --main-gpu 0 \
          --tensor-split 0 \
          -hf unsloth/gemma-3-27b-it-GGUF
      '';
      # Security hardening while allowing GPU access
      ProtectSystem = "full";
      PrivateTmp = true;
      PrivateDevices = false;  # Required for GPU device access
      DeviceAllow = [
        "/dev/dri rw"              # DRI device access
        "/dev/dri/renderD128 rw"   # Render node for Vulkan
        "/dev/dri/card0 rw"        # Card device for GPU initialization
      ];
      ProtectKernelModules = false;  # Required for Vulkan kernel modules
    };
  };

  # =============================================================================
  # FIREWALL
  # =============================================================================
  # Disable firewall for LLM server access (configure as needed)
  networking.firewall.enable = false;

  # =============================================================================
  # SYSTEM VERSION
  # =============================================================================
  system.stateVersion = "25.05";

}
