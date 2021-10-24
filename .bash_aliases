#
# ~/.bash_aliases
#

# This file contains various functions and aliases I frequently use to make tasks significantly easier

# Package manager shortcuts
# Warning if package manager is undefined
if [ -z "$PKG_MANAGER" ]; then
  echo "Warning - \$PKG_MANAGER is not set!"
fi

# Force colour mode for less, ls, and grep
alias less='less -r'
alias ls='ls --color'
alias grep='grep --colour=always'
# HighLight alias for ack with passthrough
if [ -x "$(command -v ack)" ]; then
  hl() {
    ack --passthru $@ # First command receives the stream
  }
else
  echo "Warning - ack is not installed. 'hl' will not provide colours."
  hl() {
    cat # First command receives the stream
  }
fi

# Install one or more packages
fetch() {
  case $PKG_MANAGER in
    apt-get)
      sudo apt-get install "${@:1}"
      ;;
    pacman)
      sudo pacman -S "${@:1}"
      ;;
    *)
      echo ${FUNCNAME[0]}: Unsupported package manager \""$PKG_MANAGER"\"
      return
  esac
}
# Remove one or more packages, as well as any orphaned dependencies associated with the package(s)
purge() {
  case $PKG_MANAGER in
    apt-get)
      sudo apt-get purge "${@:1}"
      ;;
    pacman)
      sudo pacman -Rs "${@:1}";
      ;;
    *)
      echo ${FUNCNAME[0]}: Unsupported package manager \""$PKG_MANAGER"\"
      return
  esac
}
# Searches for one or more packages
findme() {
  for package in "${@:1}"; do
    case $PKG_MANAGER in
      apt-get)
        apt-cache search "$package" | hl "$package"
        ;;
      pacman)
        pacman -Ss "$package" | hl "$package"
        ;;
      *)
        echo ${FUNCNAME[0]}: Unsupported package manager \""$PKG_MANAGER"\"
        return
    esac
  done
}
# Syncs package database
update() {
  case $PKG_MANAGER in
    apt-get)
      sudo apt-get update
      ;;
    pacman)
      sudo pacman -Syy
      ;;
    *)
      echo ${FUNCNAME[0]}: Unsupported package manager \""$PKG_MANAGER"\"
  esac
}
# Performs an upgrade of all packages
upgrade() {
  case $PKG_MANAGER in
    apt-get)
      sudo apt-get upgrade
      ;;
    pacman)
      sudo pacman -Syu
      ;;
    *)
      echo ${FUNCNAME[0]}: Unsupported package manager \""$PKG_MANAGER"\"
  esac
}
# Automatically removes orphaned packages
autoremove() {
  case $PKG_MANAGER in
    apt-get)
      sudo apt-get autoremove
      ;;
    pacman)
      unused=$(pacman -Qtdq)
      if [ -z "$unused" ]; then
        echo Nothing to do
      else
        sudo pacman -Rs $unused
      fi
      ;;
    *)
      echo ${FUNCNAME[0]}: Unsupported package manager \""$PKG_MANAGER"\"
  esac
}

# Allows automatically installing a collection of packages that I would consider to be essential or useful
initial-setup() {
  # Check that a package manager has been detected.
  if [ ! "$PKG_MANAGER" ]; then
    echo -e "Error: no package manager was detected, cannot possibly autoinstall packages.\nTo fix this, please investigate .bashrc to determine why \$PKG_MANAGER is not being set."
    return
  fi

  # Verify that whiptail is available on the system
  if [ ! "$(command -v whiptail)" ]; then
    echo "Error: whiptail is not installed."
    return
  fi
  
  : <<'END_COMMENT'
  # Warning message (only show for optionals/apps?)
  echo -e "WARNING!\nYou are about to install a lot of packages onto your machine.\nOf course, this will require a lot of patience and a decent internet connection.\nSome packages will need to be installed via Pip, and if you're\nusing Arch then an AUR helper such as paru or yay will be needed.\n"
  select answer in "Confirm" "Cancel"
  do
    case $answer in
      Confirm) break;;
      Cancel) return;;
    esac
  done
  echo "Proceeding"
END_COMMENT

  # Manually ordered list of package categories
  local package_categories=(core pip optional apps)
  
  declare -A packages # Dictionary of strings, which will be treated as lists.
  
  # List of 'essential' packages, any tool used in this file should be listed here.
  packages[core]="\
    coreutils\
    ncurses\
    ack\
    nano\
    ne\
    neofetch\
    python3\
    rsync\
    tar\
    wget\
  "

  # Python packages that are useful to have. These are in their own category because pip is used to install them
  packages[pip]="\
    pip_search\
    tw2.pygmentize\
  "

  # List of 'nice-to-have' packages
  # Note; some of these are on the AUR, so it's useful to have a helper like paru or yay for those
  packages[optional]="\
    adbfs-rootless-git\
    android-sdk-platform-tools\
    bc\
    cdrdao\
    dos2unix\
    downgrade\
    dvd+rw-tools\
    exfatprogs\
    ffmpeg\
    git\
    grub-customizer\
    htop\
    inetutils\
    iotop\
    lftp\
    lshw\
    lynx\
    make\
    mediainfo\
    net-tools\
    nmap\
    noto-fonts-cjk\
    noto-fonts-emoji\
    ntfs-3g\
    nvme-cli\
    scrcpy\
    screen\
    sox\
    speedtest-cli\
    tmux\
    tree\
    ttf-windows\
    unrar\
    unzip\
    xterm\
    youtube-dl\
    zip\
  "
  
  # List of GUI applications
  packages[apps]="\
    arduino\
    ark\
    atom\
    audacity\
    bitwarden\
    cool-retro-term\
    davinci-resolve\
    deja-dup\
    elisa\
    filelight\
    firefox\
    ghex\
    gimp\
    gnome-disk-utility\
    gwenview\
    kate\
    kdenlive\
    kompare\
    konsole\
    ksysguard\
    minecraft-launcher\
    obs-studio\
    partitionmanager\
    spectacle\
    speedcrunch\
    steam\
    teams\
    thunderbird\
    transmission-gtk\
    xfburn\
  "
  
  # TODO: Show a menu to select categories with nested entries to fine-tune package selection.
  # TODO: For all selected packages from the aforementioned menu, attempt to install each one.

  # Associative array to keep track of selections
  declare -A selections
  
  # TODO: Automatically select all from core and pip
  
  # Whiptail configurations
  local TITLE="Package Selection"
  local SIZE="$(( $LINES-20)) $(( $COLUMNS-20 )) $(( $LINES-30 ))" # Dynamic box size
  
  # Category menu
  while true; do
    # Construct list of options to present to the user
    local menu_options="" # Clear list
    for i in "${package_categories[@]}"
    do
      # TODO: Option for select/remove all should be put here
      # "$i_all" "  Remove all"
      menu_options=$menu_options"$i $i "
    done
    menu_options=$menu_options"INSTALL -=Install=-"
    
    exec 3> /tmp/whiptail_stderr # Open an IO stream into a temporary file

    # Show the main menu, redirecting its stderr to our temporary file
    whiptail --notags\
      --backtitle "$TITLE" --title "$TITLE"\
      --ok-button "Select" --cancel-button "Abort"\
      --menu "Main menu" $SIZE\
      -- $menu_options # Standalone -- to escape the rest of the command
    
    wtcode=$? # Store the return code
    exec 3>&- # Close the IO stream
    
    # Detect if the Abort button was pressed
    if [[ $wtcode -ne 0 ]]; then
      return # Do not proceed
    fi
    
    # Read the temporary file into a variable and tidy up
    choice=$(tr -d '"' < /tmp/whiptail_stderr)
    rm /tmp/whiptail_stderr
    
    # TODO: "INSTALL" choice should exit the loop and install any packages
    # TODO: Choice ending in _all should select/remove all packages in the category
    # TODO: Anything else should display a checkbox menu for all the packages in that category
    echo $choice
  done
}

# Python aliases
alias python=python3
alias py=python3
alias pip=pip3

if ! [ -x "$(command -v pip_search)" ]; then
  echo "Warning - pip_search is not installed. 'pip3 search' will not function."
fi
pip3() { # Rest in peace 'pip3 search'.
  if [ "$1" == "search" ]; then
    # Run pip_search with the remaining arguments, piped into more.
    pip_search "${@:2}" | more
  else
    # Execute pip3 as normal
    local pip_exec=$(which pip3) # Determine path to pip3
    $pip_exec "$@"
  fi
}

# Miscellaneous aliases
alias q=exit
alias ls='ls --color=auto'
alias new='konsole &'
alias ftp=lftp
alias music-dl="youtube-dl -ciwx --audio-format mp3 --embed-thumbnail --add-metadata -o \%\(title\)s.\%\(ext\)s"
alias ne='ne --utf8 --ansi --keys ~/.ne/backspacefix.keys' # nice-editor

# "MaKe and Change Directory"
mkcd() { mkdir -p "$@" && cd "$@" }

init-adbfs() { # "Initialise ADBFS"
  # Use either a manually specified mountpoint or the default in /run
  if [ "$1" != "" ]; then
    mntdir="$1"
  else
    mntdir="/run/media/$(whoami)/Connor"
  fi

  # Make the folder if it doesn't exist
  if [ ! -d $mntdir ]; then
    sudo mkdir "$mntdir" # Root must make it...
    # But the current user must then own it.
    sudo chown $(whoami) "$mntdir"
  fi
  # Double check if it worked
  if [ -d $mntdir ]; then
    # It did, proceed.
    adbfs "$mntdir" -o auto_unmount -o fsname=Connor
  else
    # Error message
    echo "Aborting, mountpoint couldn't be created."
  fi
}

git() { # Git shortcuts
  local git_exec=$(which git) # Determine path to git
  if [ "$1" == "clone" ]; then
    # Clone the repository then cd into it
    $git_exec clone "${@:2}" && cd "$(basename "$2" .git)"
  elif [ "$1" == "tree" ]; then
    # Fancier git logs
    $git_exec log --graph --decorate --abbrev-commit --pretty=medium --branches --remotes "${@:2}"
  else
    # Run Git as normal
    $git_exec "${@:1}"
  fi
}

ccat() { # Its like cat, but with syntax highlighting. 
  # pygmentize is part of the python-pygments package
  
  # Swap instances of 'pygmentize' in the stderr to the function name to avoid breaking the illusion
  # https://stackoverflow.com/questions/3618078/pipe-only-stderr-through-a-filter/52575087#52575087
  pygmentize -g -O style=monokai "$@" 2> >(sed -e "s/pygmentize/${FUNCNAME[0]}/g" >&2)
}

volume() { # System volume adjustment/readback tool
  # NOTE: This uses amixer, so be sure to install alsa-utils.
  if [[ $1 == *-h* ]]; then  # Determine if "-h" appears in the argument. This matches -h and --help
    # Help text
    echo "Usage: ${FUNCNAME[0]} [value]"
    echo "Returns the current audio volume percentage, "
    echo "or if a percentage is provided, sets it to that value."
  elif [ $# -eq 0 ]; then
    # Output the current volume percentage if no argument was given

    # TODO: amixer is a tricksy gremlin.
    # Find a way to reliably determine current volume %, with or without amixer.
    echo "Volume readback not implemented"

    # Previous non-functional method, kept here as a starting point:
    #awk -F"[][]" '/Left:/ { print $2 }' <(amixer sget Master)

    return
  elif ! [[ $1 =~ ^[-]?[0-9]+$ ]]; then  # Check argument is actually text rather than a number
    echo "${FUNCNAME[0]}: Input was not a number."
  elif [[ $1 -ge 0 && $1 -le 100 ]]; then  # If it's a number between 0 and 100, pass it to amixer
    amixer sset Master $1\%;
  else  # However, if it is not within that range, exit with an error.
    echo "${FUNCNAME[0]}: Input outside of range 0-100."
  fi
}

when() { # Calculates the age of files/directories and displays it in a human-readable format
  # Parse the first argument, if any.
  case "$1" in

    --help)
      echo "Usage: ${FUNCNAME[0]} [OPTION] FILES
Displays a human-readable time since the created/accessed/modified field of files and folders.

Measurement arguments:
  -c, --created           Time since file creation
  -a, --accessed          Time since last file access
  -m, --modified          Time since last modification (default mode)
  -s, --statuschanged     Time since last status change"
      return 0
      ;;

    -c|--created)
      #  %W   time of file birth, seconds since Epoch; 0 if unknown
      local format_code=%W
      shift
      ;;
    -a|--accessed)
      #  %X   time of last access, seconds since Epoch
      local format_code=%X
      shift
      ;;
    -m|--modified)
      # Use the modified time by default
      local format_code=%Y
      shift
      ;;
    -s|--statuschanged)
      #  %Z   time of last status change, seconds since Epoch
      local format_code=%Z
      shift
      ;;
    -*)
      echo "${FUNCNAME[0]}: unrecognised option '$1'
Try '${FUNCNAME[0]} --help' for more information"
      return 1
      ;;
    *)
      # First argument is a filename, use the Last Modified value by default.
      #  %Y   time of last data modification, seconds since Epoch
      local format_code=%Y
      ;;
  esac

  # Check if no files were supplied
  if [ $# -eq 0 ]; then
    echo "${FUNCNAME[0]}: specify at least 1 file or folder.
Try '${FUNCNAME[0]} --help' for more information"
    return 1
  fi

  for file in "${@:1}"; do
    # Check if the file is even a file or directory
    if [[ ! (-f "$file" || -d "$file") ]]; then
      echo ${FUNCNAME[0]}: \'$file\' does not exist
      continue
    fi

    # Use stat to read the file's age field, according to which one the user wants.
    local file_epoch=$(stat -c$format_code "$file")
    # Is it 0? That means there was an error, usually.
    if [ $file_epoch -eq 0 ]; then
      printf '%s: <UNKNOWN>\n' "$file"
      continue
    fi

    # Get the current Epoch and subtract the Epoch of the file
    local age=$(( $(date +%s) - $file_epoch ))

    # https://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
    # Tweaked to support years and to output the name of the file in question
    local Y=$((age/60/60/24/365))
    local D=$((age/60/60/24%365))
    local H=$((age/60/60%24))
    local M=$((age/60%60))
    local S=$((age%60))
    printf '%s: ' "$file"
    (( $Y > 0 )) && printf '%d years ' $Y
    (( $D > 0 )) && printf '%d days ' $D
    (( $H > 0 )) && printf '%d hours ' $H
    (( $M > 0 )) && printf '%d minutes ' $M
    (( $Y > 0 || $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
    printf '%d seconds\n' $S
  done
}

# KDE session management aliases
alias lock='loginctl lock-session $(loginctl show-seat seat0 | grep ActiveSession | cut -d'=' -f 2)'
alias unlock='loginctl unlock-session $(loginctl show-seat seat0 | grep ActiveSession | cut -d'=' -f 2)'
alias logout='qdbus org.kde.ksmserver /KSMServer logout 0 0 0'
