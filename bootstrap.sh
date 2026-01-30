#!/bin/bash -e

is_wsl2() {
    grep -qi microsoft /proc/version 2>/dev/null && \
    [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]
}

# Add the user to the sudoers file
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER"

# Install zsh
sudo apt update
sudo apt install -y \
    zsh

# Set zsh as the default shell
sudo chsh -s $(which zsh) $USER

# Install oh-my-zsh
curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended

# Install oh-my-zsh plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# # Enable oh-my-zsh plugins
PLUGINS=(
    docker
    z
    zsh-syntax-highlighting
    zsh-autosuggestions
)
sed -i "s/^plugins=.*/plugins=(${PLUGINS[*]})/" ~/.zshrc

# Install tools
sudo apt install -y \
    jq

# Install brew
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
cat <<'EOF' >> ~/.zshrc

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
EOF

# Set up Docker installation
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update

# Install Docker
sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
sudo groupadd docker || true
sudo usermod -aG docker $USER

if is_wsl2; then
    # Install Docker Credential Helper for Windows
    wincred_version=$(curl -fsSL -o /dev/null -w "%{url_effective}" https://github.com/docker/docker-credential-helpers/releases/latest | xargs basename)
    sudo curl -fL -o /usr/local/bin/docker-credential-wincred.exe \
        "https://github.com/docker/docker-credential-helpers/releases/download/${wincred_version}/docker-credential-wincred-${wincred_version}.windows-$(dpkg --print-architecture).exe"
    sudo chmod +x /usr/local/bin/docker-credential-wincred.exe

    # Configure Docker to use Windows credential store
    mkdir -p ~/.docker
    if [ -f ~/.docker/config.json ]; then
        # Update existing config
        jq '. + {"credsStore": "wincred.exe"}' ~/.docker/config.json > ~/.docker/config.json.tmp && mv ~/.docker/config.json.tmp ~/.docker/config.json
    else
        # Create new config
        echo '{"credsStore": "wincred.exe"}' | jq > ~/.docker/config.json
    fi
fi

# Set up GitHub CLI installation
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update

# Install GitHub CLI
sudo apt install -y gh
gh completion -s zsh | sudo tee /usr/local/share/zsh/site-functions/_gh > /dev/null

# Install GitHub Copilot CLI
curl -fsSL https://gh.io/copilot-install | sudo bash

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
cat <<'EOF' >> ~/.zshrc

# Azure CLI
source /etc/bash_completion.d/azure-cli
EOF

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | PROFILE=~/.zshrc bash

# Install pyenv
curl -fsSL https://pyenv.run | bash
cat <<'EOF' >> ~/.zshrc

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
EOF

echo "Bootstrap completed, restart the terminal to apply changes."
