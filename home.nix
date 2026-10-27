{ config, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";

  # Language toolchains live in their own version managers, not Nix.
  # Bump a version here and run ./rebuild.sh to install it and make it the default.
  goVersion = "go1.27.3";
  pythonVersion = "3.15.2";
  nodeVersion = "24.22.1";
  rustToolchain = "stable";
  gvmRev = "dd652539fa4b771840846f8319fad303c7d0a8d2";
  gvmInstaller = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/moovweb/gvm/${gvmRev}/binscripts/gvm-installer";
    hash = "sha256-RVU/4/PP8/d2annzovSpYs9iPJhNO5YFdKmrlSStGQU=";
  };
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";
  # rustup is keg-only in Homebrew; cargo installs binaries into ~/.cargo/bin
  home.sessionPath = [ "/opt/homebrew/opt/rustup/bin" "$HOME/.cargo/bin" ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept

      eval "$(pyenv init - zsh)"
      [[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
      eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Installs the pinned toolchains with the version managers from configuration.nix.
  # Homebrew activation runs before this, so the managers are already on disk.
  home.activation.toolchains = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="/opt/homebrew/bin:/opt/homebrew/opt/rustup/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    if [ ! -d "$HOME/.gvm" ]; then
      run env GVM_NO_UPDATE_PROFILE=1 bash ${gvmInstaller} ${gvmRev}
    fi
    if [ ! -d "$HOME/.gvm/gos/${goVersion}" ]; then
      run bash -c 'source "$HOME/.gvm/scripts/gvm" && gvm install ${goVersion} -B'
    fi
    run bash -c 'source "$HOME/.gvm/scripts/gvm" && gvm use ${goVersion} --default >/dev/null'

    if [ ! -d "$(pyenv root)/versions/${pythonVersion}" ]; then
      run pyenv install ${pythonVersion}
    fi
    run pyenv global ${pythonVersion}

    if ! fnm list | grep -q "v${nodeVersion}"; then
      run fnm install ${nodeVersion}
    fi
    run fnm default ${nodeVersion}

    if ! rustup toolchain list | grep -q "^${rustToolchain}-"; then
      run rustup toolchain install ${rustToolchain} --profile default
    fi
    run rustup default ${rustToolchain}
  '';

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
