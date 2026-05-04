# MrStream-Cli 📡

> ⚠️ **IMPORTANT**: MrStream-Cli is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider. Use at your own risk.

MrStream-Cli is a minimalist, terminal-native sports event browser and stream launcher. It provides a distraction-free way to browse upcoming sports events and watch them in your favorite media player.

## Features
- **POSIX-compliant**: Lightweight shell scripts with minimal dependencies.
- **Fast Search**: Instant search through sports schedules using `fzf`.
- **Integrated Playback**: Seamlessly hands over streams to `mpv`.
- **Cached Results**: Local caching to reduce network load and improve speed.
- **Ethical Design**: Requires explicit user consent for third-party sources.

## Prerequisites
Ensure you have the following installed:
- `curl`: For fetching data.
- `fzf`: For the interactive search menu.
- `mpv`: For stream playback.
- `grep`, `sed`: Standard Unix utilities.

## Installation

### Automatic (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/Prarambha369/mrstream-cli/main/scripts/install.sh | bash
```

### Manual
1. Clone the repository:
   ```bash
   git clone https://github.com/Prarambha369/mrstream-cli.git
   cd mrstream-cli
   ```
2. Run directly from the source or link it to your path:
   ```bash
   ln -s "$(pwd)/mrstream" ~/.local/bin/mrstream
   ```

## Usage

### Basic Search
Run `mrstream search` to see all available events:
```bash
mrstream search
```
Or search for a specific team or sport:
```bash
mrstream search "football"
```

### Advanced Options
- `--refresh`: Force a refresh of the local cache.
- `--help`: Display the help menu.

### Troubleshooting
Run the doctor command to check if all dependencies are correctly installed:
```bash
mrstream doctor
```

## Configuration
The configuration is stored at `~/.config/mrstream/sources.yaml`. By default, external sources are disabled for ethical reasons. You will be prompted to enable a source the first time you search, or you can manually edit the file:
```yaml
sources:
  sportsonline:
    enabled: true
    acknowledge_non_affiliation: true
```

## License
GPL-3.0
