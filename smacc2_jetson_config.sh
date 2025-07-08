#!/bin/bash

# smacc2_jetson_config.sh: Automate post-flashing setup for NVIDIA Jetson Orin with logging

# --- Logging Setup ---
LOG_DIR="$(pwd)" # Log directory (current directory)
LOG_FILE="${LOG_DIR}/setup_jetson_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE" # Create the log file upfront
chmod 644 "$LOG_FILE" # Set permissions (adjust if needed)

# Logging function: log_message LEVEL "message"
# LEVEL can be INFO, WARN, ERROR
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    # Log to file and print to stdout
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to log command output (optional, use if you want full command logs)
log_command_output() {
    local cmd_string="$@"
    log_message "INFO" "Executing command: $cmd_string"
    # Execute command, redirecting stdout and stderr to the log file
    # Use sudo if the command needs it
    if [[ "$cmd_string" == sudo* ]]; then
        eval "$cmd_string" >> "$LOG_FILE" 2>&1
    else
        eval "$cmd_string" >> "$LOG_FILE" 2>&1
    fi

    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_message "ERROR" "Command failed with exit code $exit_code: $cmd_string"
    else
         log_message "INFO" "Command finished successfully: $cmd_string"
    fi
    return $exit_code
}


# --- Script Start ---
log_message "INFO" "Starting SMACC2 Jetson Config script. Log file: $LOG_FILE"

# Exit immediately if a command exits with a non-zero status.
set -e

# --- System Update ---
log_message "INFO" "Starting system update..."
# Optional: Use log_command_output if you want detailed apt logs in the file
# log_command_output sudo apt update
sudo apt update 
log_message "INFO" "System update completed."

# --- System Upgrade ---
log_message "INFO" "Starting system update and upgrade..."
# Optional: Use log_command_output if you want detailed apt logs in the file
# log_command_output sudo apt upgrade -y
sudo apt upgrade -y
log_message "INFO" "System upgrade completed."

# --- Install Dolphin ---
log_message "INFO" "Starting dolphin installation..."
sudo apt install konsole -y
log_message "INFO" "Konsole install completed."
sudo apt install dolphin -y
log_message "INFO" "Dolphin install completed."

# --- Python pip Installation ---
log_message "INFO" "Installing Python3 pip..."
# Optional: Use log_command_output for detailed apt logs
# log_command_output sudo apt install python3-pip -y
sudo apt install python3-pip -y # Added -y to avoid prompt
log_message "INFO" "Python3 pip installation completed."

# --- ROS2 Humble Install ---
#Set Locale
locale  # check for UTF-8

sudo apt update && sudo apt install locales -y
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

locale  # verify settings
log_message "INFO" "Locale Set..."

# Add ROS2 Apt Repos 
sudo apt install software-properties-common -y
sudo add-apt-repository universe -y

sudo apt update && sudo apt install curl -y
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" # If using Ubuntu derivates use $UBUNTU_CODENAME
sudo dpkg -i /tmp/ros2-apt-source.deb

# Install ROS2 Desktop
sudo apt install ros-humble-desktop -y
# Install ROS2 Dev Tools
sudo apt install ros-dev-tools -y
# Source your environment
source /opt/ros/humble/setup.bash
log_message "INFO" "ROS2 Installed..."

# --- rosdep Intall ---
apt-get install python3-rosdep -y

sudo rosdep init
rosdep update
log_message "INFO" "rosdep Installed..."

# --- Create workspace ---
log_message "INFO" "Creating isaac_ros-dev workspace..."
mkdir workspaces
cd workspaces
mkdir isaac_ros-dev
cd isaac_ros-dev
mkdir src
cd ..
cd ..
echo "export ISAAC_ROS_WS=${HOME}/workspaces/isaac_ros-dev/" >> ~/.bashrc
source ~/.bashrc

# --- VS Code Installation ---
echo "Installing required dependencies..."
sudo apt-get install wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg

echo "Installing Visual Studio Code..."
sudo apt install apt-transport-https
sudo apt update
sudo apt install code

echo "Verifying installation..."
# Verify as the original user if possible, otherwise check directly
  # Fallback: verify directly (e.g., running as root)
  if command -v code >/dev/null 2>&1; then
    echo "VS Code version:"
    code --version
    echo "Visual Studio Code installed successfully!"
  else
    echo "Error: Visual Studio Code installation failed."
    exit 1
  fi

# --- SMACC2_RTA Installation ---
echo "Installing required dependencies..."
curl -s https://1449136d7e9e98bb9b74997f87835c3b56a84d379c06b929:@packagecloud.io/install/repositories/robosoft-ai/SMACC2_RTA-academic/script.deb.sh | sudo bash

sudo apt -y install ros-humble-smacc2-rta


# --- Final Steps ---
# Check if reboot is needed
if [ -f /var/run/reboot-required ]; then
  log_message "INFO" "System indicates a reboot is required."
  echo # Add a newline for better readability of the prompt
  log_message "INFO" "Setup complete. A reboot is required to finalize changes."
  echo "Reboot now? (y/N)"
  read -r reboot_choice
  log_message "INFO" "User input for reboot: $reboot_choice"
  if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    log_message "INFO" "User chose to reboot. Rebooting in 5 seconds..."
    echo "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
  else
    log_message "INFO" "User chose not to reboot now. Please reboot manually later."
    echo "Please reboot manually later to complete setup."
  fi
else
  # jtop often requires login/out or restart even if /var/run/reboot-required isn't present
  log_message "INFO" "Setup complete. No mandatory reboot flag found, but a reboot is recommended (e.g., for jtop)."
  echo "Setup complete. Please reboot or log out/in to ensure all changes take effect (especially for tools like jtop)."
fi

log_message "INFO" "Jetson setup script finished."
exit 0
