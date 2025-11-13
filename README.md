# NixOS AI Server - AMD Strix Halo LLM Inference

[![NixOS](https://img.shields.io/badge/NixOS-25.05-blue.svg)](https://nixos.org/)
[![AMD Strix Halo](https://img.shields.io/badge/AMD-Strix%20Halo-red.svg)](https://www.amd.com/en/processors/apu)
[![llama.cpp](https://img.shields.io/badge/llama.cpp-b7050-green.svg)](https://github.com/ggml-org/llama.cpp)

A production-ready NixOS configuration optimized for running Large Language Model inference with llama.cpp on AMD Strix Halo APUs using the Vulkan backend.

## 🚀 Features

- **AMD Strix Halo Optimization**: Specifically tuned for AMD's latest APU architecture
- **Vulkan Backend**: Hardware-accelerated inference using AMDVLK
- **Latest llama.cpp**: Custom build with enhanced Vulkan support (b7050)
- **Production Ready**: Systemd service with proper security hardening
- **Memory Optimized**: UMA-aware configuration for large models
- **German Localization**: Pre-configured for German users

## 🖥️ Hardware Requirements

### Minimum Requirements
- **CPU**: AMD Strix Halo APU (RDNA 3+ iGPU)
- **Memory**: 32GB RAM (64GB+ recommended for large models)
- **Storage**: 50GB available space
- **OS**: NixOS 25.05 or later

### Recommended Configuration
- **APU**: AMD Ryzen AI Max 395 (Strix Halo)
- **Memory**: 128GB unified memory
- **Storage**: NVMe SSD for model storage
- **Cooling**: Adequate cooling for sustained workloads

## 📋 Overview

This configuration provides:

1. **Custom llama.cpp Build**: Latest version with Vulkan optimizations
2. **AMD Driver Optimization**: Kernel module parameters for Strix Halo
3. **Systemd Service**: Auto-starting llama.cpp server
4. **Security Hardening**: Proper device access and sandboxing
5. **Development Environment**: Python, Docker, and essential tools

## 🛠️ Installation

### 1. Prerequisites

Ensure you have NixOS installed with basic configuration:

```bash
# Verify NixOS version
nixos-version
# Should show 25.05 or later
```

### 2. Configuration Setup

1. Clone this repository:
```bash
git clone https://github.com/yourusername/nixos-ai-server.git
cd nixos-ai-server
```

2. Copy the configuration:
```bash
sudo cp configuration.nix /etc/nixos/
```

3. Update hardware configuration (if needed):
```bash
sudo nixos-generate-config
```

4. Build and switch to the new configuration:
```bash
sudo nixos-rebuild switch
```

### 3. Model Setup

The default configuration uses `unsloth/gemma-3-27b-it-GGUF`. To use a different model:

1. Download your model to `/home/jasper/models/`
2. Update the systemd service in `configuration.nix`:
```nix
-hf /path/to/your/model.gguf
```

3. Rebuild:
```bash
sudo nixos-rebuild switch
```

## ⚙️ Configuration

### llama.cpp Server Parameters

The systemd service includes these optimizations:

```nix
ExecStart = ''
  ${pkgs.llama-cpp}/bin/llama-server \
    --host :: \              # Listen on all interfaces
    --port 8080 \            # Default port
    --jinja \                # Jinja templating
    --no-mmap \              # Disable memory mapping (UMA optimization)
    --temp 1.0 \             # Temperature
    --min-p 0.0 \            # Minimum probability
    --top-p 0.95 \           # Top-p sampling
    --top-k 64 \             # Top-k sampling
    -c 0 -fa on \            # Unlimited context, flash attention
    --n-gpu-layers 999 \     # Use GPU for all layers
    --gpu-layers-stride 8 \  # Memory stride optimization
    --main-gpu 0 \           # Primary GPU
    --tensor-split 0 \       # No tensor splitting (single GPU)
    -hf unsloth/gemma-3-27b-it-GGUF
'';
```

### AMD Kernel Module Optimization

```nix
boot.extraModprobeConfig = ''
  options amdgpu gttsize=120000      # 120GB GTT for large models
  options ttm pages_limit=31457280  # TTM page limit
  options ttm page_pool_size=15728640  # TTM page pool
  options amdgpu sg_display=0       # Disable display memory allocation
  options amdgpu vm_fragment_size=9  # VM fragmentation optimization
'';
```

## 🔧 Usage

### Starting the Service

The llama.cpp service starts automatically. To manage it:

```bash
# Check status
sudo systemctl status llama-cpp

# Restart service
sudo systemctl restart llama-cpp

# View logs
sudo journalctl -u llama-cpp -f
```

### Testing the Server

1. Check if the server is running:
```bash
curl http://localhost:8080/health
```

2. Test inference:
```bash
curl -X POST http://localhost:8080/completion \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Hello, how are you?",
    "n_predict": 100
  }'
```

### Model Management

Download additional models:

```bash
# Create models directory
mkdir -p ~/models

# Download a model (example with huggingface-cli)
pip install huggingface_hub
huggingface-cli download microsoft/DialoGPT-medium --local-dir ~/models/DialoGPT-medium
```

## 🐛 Troubleshooting

### Common Issues

1. **GPU not detected**:
```bash
# Check GPU devices
ls -la /dev/dri/
# Should show renderD128, card0, etc.

# Check Vulkan support
vulkaninfo --summary
```

2. **Service fails to start**:
```bash
# Check logs
sudo journalctl -u llama-cpp -n 50

# Verify permissions
sudo usermod -a -G render jasper
```

3. **Memory issues**:
```bash
# Check memory usage
free -h
# Monitor GPU memory
watch -n 1 'cat /sys/class/drm/renderD128/device/mem_info_vram_total'
```

### Performance Tuning

1. **Monitor performance**:
```bash
# GPU utilization
radeontop

# System resources
htop
iotop
```

2. **Adjust model parameters**:
- Reduce `--n-gpu-layers` if OOM occurs
- Adjust `--gpu-layers-stride` for memory efficiency
- Use quantized models for lower memory usage

## 📚 Documentation

### Key Files

- `configuration.nix`: Main NixOS configuration
- `hardware-configuration.nix`: Hardware-specific settings (auto-generated)

### Useful Commands

```bash
# Rebuild configuration
sudo nixos-rebuild switch

# Test configuration without applying
sudo nixos-rebuild test

# Rollback to previous configuration
sudo nixos-rebuild switch --rollback

# Clean old generations
sudo nix-collect-garbage -d
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [llama.cpp](https://github.com/ggml-org/llama.cpp) - LLM inference engine
- [AMD](https://www.amd.com/) - Strix Halo hardware and Vulkan drivers
- [NixOS](https://nixos.org/) - Declarative Linux distribution
- [Nixpkgs](https://github.com/NixOS/nixpkgs) - Package collection

## 📞 Support

For issues and questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Search existing [GitHub Issues](https://github.com/yourusername/nixos-ai-server/issues)
3. Create a new issue with detailed information

---

**Note**: This configuration is specifically designed for AMD Strix Halo hardware. While it may work with other AMD GPUs, optimal performance is only guaranteed on Strix Halo APUs.