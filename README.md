# Arch Linux Setup Framework

A modular, idempotent setup framework for Arch Linux that can be cloned from GitHub and run on a minimal Arch install.

## Features

- **Modular Architecture**: Each application is a self-contained module
- **Idempotent**: Safe to run multiple times without side effects
- **Extensible**: Easy to add new modules without modifying core logic
- **Dotfile Management**: Pull configs from your dotfiles repository with fallback to sensible defaults
- **Interactive Confirmations**: Manual approval at each major phase
- **Dual Logging**: Output to both console and log files
- **AUR Support**: Automatic paru installation and AUR package management

## Quick Start

### Prerequisites

On a minimal Arch install, you'll need git to clone this repository:

```bash
pacman -Sy git
```

### Installation

1. Clone this repository:
```bash
git clone https://github.com/username/arch-setup.git
cd arch-setup
```

2. Edit the configuration file:
```bash
vim config/config.toml
```

Update the dotfiles repository URL and enable desired modules.

3. Run the setup:
```bash
chmod +x setup.sh
./setup.sh
```

The script will guide you through several phases with confirmation prompts.

## Configuration

Edit `config/config.toml` to customize your setup:

```toml
[dotfiles]
repo = "https://github.com/username/dotfiles"
branch = "main"
target_dir = "$HOME/.dotfiles"

[modules]
enabled = ["base", "hyprland", "waybar"]

[packages]
aur_helper = "paru"

[services]
auto_enable = true

[logging]
log_to_file = true
log_dir = "$HOME/.local/share/arch-setup/logs"
```

## Available Modules

### base
Essential system utilities and build tools:
- base-devel, git, wget, curl, stow, vim, NetworkManager

### hyprland
Hyprland Wayland compositor with sensible defaults:
- Hyprland, xdg-desktop-portal-hyprland, polkit-kde-agent, kitty

### waybar
Status bar for Wayland with preconfigured style:
- Waybar, Font Awesome icons

## Usage

### Basic Usage

```bash
# Full installation with all enabled modules
./setup.sh

# Dry run to preview what would be installed
./setup.sh --dry-run

# Install specific modules only
./setup.sh --modules base,hyprland

# Skip dotfile management
./setup.sh --skip-dotfiles

# Non-interactive mode (skip confirmations)
./setup.sh --no-confirm

# Show help
./setup.sh --help
```

### Command-Line Options

- `--dry-run`: Show what would be done without making changes
- `--modules MODULE1,MODULE2`: Install only specified modules (comma-separated)
- `--skip-dotfiles`: Skip dotfile cloning and symlinking
- `--no-confirm`: Skip all confirmation prompts (automatic yes)
- `--force`: Force reinstall even if packages are already installed
- `--help`: Display usage information
- `--verbose`: Enable verbose logging output

## Creating New Modules

Adding a new module is easy:

1. **Copy the example module:**
```bash
cp -r modules/example-module modules/myapp
```

2. **Edit the module file:**
```bash
vim modules/myapp/module.sh
```

Update the metadata and package lists:

```bash
#!/bin/bash

MODULE_NAME="myapp"
MODULE_DESCRIPTION="My Application"
MODULE_REQUIRES=("base")

OFFICIAL_PACKAGES=("package1" "package2")
AUR_PACKAGES=("aur-package1")

SERVICES=("myapp.service")
USER_SERVICES=()

# Optional hooks
module_install() {
    log_info "Installing $MODULE_NAME..."
    # Custom installation logic
}

module_configure() {
    log_info "Configuring $MODULE_NAME..."
    # Custom configuration logic
}

module_post_install() {
    log_success "$MODULE_NAME installed!"
    # Post-install tasks
}
```

3. **(Optional) Add default configs:**
```bash
mkdir -p modules/myapp/defaults/.config/myapp
vim modules/myapp/defaults/.config/myapp/config
```

4. **Enable the module:**

Edit `config/config.toml` and add your module to the enabled list:
```toml
[modules]
enabled = ["base", "hyprland", "waybar", "myapp"]
```

5. **Run the setup:**
```bash
./setup.sh --modules myapp
```

## Dotfile Management

### Repository Structure

Your dotfiles repository should use XDG-style structure:

```
dotfiles/
├── .config/
│   ├── hyprland/
│   │   └── hyprland.conf
│   ├── waybar/
│   │   ├── config
│   │   └── style.css
│   ├── kitty/
│   │   └── kitty.conf
│   └── ...
├── .bashrc
├── .zshrc
└── ...
```

### How It Works

1. The framework clones your dotfiles repository to `~/.dotfiles/`
2. GNU stow creates symlinks from `~/.dotfiles/` to your home directory
3. If the dotfiles repo is unavailable, module defaults are used as fallback

### Managing Dotfiles

```bash
# Update dotfiles
cd ~/.dotfiles
git pull

# Relink dotfiles (if needed)
stow -d ~/.dotfiles -t ~ .

# Add new configs
cd ~/.dotfiles
mkdir -p .config/myapp
vim .config/myapp/config
git add .config/myapp
git commit -m "Add myapp config"
git push
```

## Module Execution Flow

When you run the setup, each module goes through these steps:

1. **Dependency Check**: Ensure required modules are installed first
2. **Package Installation**: Install official packages (via pacman)
3. **AUR Installation**: Install AUR packages (via paru)
4. **Module Install Hook**: Run custom installation logic
5. **Configuration**: Apply dotfiles or module defaults
6. **Module Configure Hook**: Run custom configuration logic
7. **Service Enablement**: Enable systemd services
8. **Post-Install Hook**: Run post-install tasks

## Idempotency

The framework is designed to be idempotent - you can run it multiple times safely:

- Packages are checked before installation
- Services are checked before enablement
- Existing files are not overwritten without backup
- Module hooks can implement their own idempotency checks

## Troubleshooting

### View Logs

Logs are saved to `~/.local/share/arch-setup/logs/`:

```bash
ls -lah ~/.local/share/arch-setup/logs/
tail -f ~/.local/share/arch-setup/logs/setup-*.log
```

### Dry Run Mode

Test what would happen without making changes:

```bash
./setup.sh --dry-run
```

### Module-Specific Issues

Test individual modules:

```bash
./setup.sh --modules base
./setup.sh --modules hyprland
```

### Stow Conflicts

If stow reports conflicts (existing files in the way):

```bash
# Backup existing configs
mv ~/.config/hyprland ~/.config/hyprland.backup

# Retry dotfile linking
cd ~/.dotfiles
stow -d ~/.dotfiles -t ~ .
```

## Advanced Usage

### Custom Configuration Location

You can use a custom config file:

```bash
cp config/config.toml config/my-config.toml
vim config/my-config.toml
# Then source it manually in setup.sh or modify the script
```

### Module Groups

Group related modules for easier management:

```toml
[modules]
enabled = ["base", "desktop-hyprland", "development", "media"]
```

Create group modules that install multiple sub-modules.

### Pre-commit Hooks

Add validation before committing changes:

```bash
# .git/hooks/pre-commit
#!/bin/bash
bash -n setup.sh || exit 1
bash -n lib/*.sh || exit 1
bash -n modules/*/module.sh || exit 1
```

## Project Structure

```
arch-setup/
├── setup.sh                    # Main entry point
├── lib/
│   ├── core.sh                # Logging, TOML parsing, utilities
│   ├── package.sh             # Package management (pacman, paru)
│   ├── dotfiles.sh            # Dotfile management (stow)
│   └── service.sh             # Service management (systemd)
├── modules/
│   ├── base/
│   │   └── module.sh
│   ├── hyprland/
│   │   ├── module.sh
│   │   └── defaults/
│   ├── waybar/
│   │   ├── module.sh
│   │   └── defaults/
│   └── example-module/
│       └── module.sh          # Template for new modules
├── config/
│   └── config.toml            # Main configuration
├── logs/                      # Auto-generated logs (gitignored)
├── .gitignore
└── README.md
```

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Add your module or improvements
4. Test thoroughly on a fresh Arch VM
5. Submit a pull request

## License

MIT License - Feel free to modify and distribute

## Credits

Built with the following tools:
- [Arch Linux](https://archlinux.org/)
- [GNU Stow](https://www.gnu.org/software/stow/)
- [paru](https://github.com/Morganamilo/paru) AUR helper
- [Hyprland](https://hyprland.org/) Wayland compositor
- [Waybar](https://github.com/Alexays/Waybar) Status bar

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the troubleshooting section above

## Roadmap

Future enhancements:
- [ ] Additional modules (development tools, media apps, etc.)
- [ ] Hardware detection and conditional installation
- [ ] Backup and restore functionality
- [ ] Web-based configuration generator
- [ ] Module dependency graph visualization
