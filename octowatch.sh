#!/bin/bash

CONFIG_FILE="printers.ini"
LOG_FILE="octowatch.log"
VERSION=1.1         # Version variable

DEFAULT_INTERVAL=5
DEFAULT_SCREEN_REFRESH=30
FILE_NAME_MAX=40  # Maximum length for print file names

# List of required dependencies
DEPENDENCIES=("curl" "jq" "git" "bc" "awk")

# ANSI color codes
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
LIGHT_YELLOW='\033[38;5;229m'
ORANGE='\033[38;5;208m'
BRIGHT_BLUE='\033[94m'
LIGHT_GREEN='\033[92m'
DIM_LIGHT_GREY="\033[2;37m"
BRIGHT_BLACK="\033[90m"
NC="\033[0m"  # No Color

# ANSI positioning codes
HOME="\033[H"
GotoX65="\033[65G"
GotoX2="\033[2G"

# Get refresh interval from command line if provided
REFRESH_INTERVAL=${1:-$DEFAULT_INTERVAL}
SCREEN_REFRESH=$DEFAULT_SCREEN_REFRESH
counter=0
SCREEN_REFRESH_FLAG=0

# Function to check and install missing dependencies
check_dependencies() {
    for cmd in "${DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "$cmd is not installed. Installing..."
            sudo apt-get update && sudo apt-get install -y "$cmd"
        else
            echo "$cmd is already installed."
        fi
    done
}

# Function to check if the configuration file exists
check_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file $CONFIG_FILE not found. Please create it before running the script."
        exit 1
    fi
}

# Function: progress_bar
# Input: progress percentage (e.g., 75.00)
# Output: A progress bar string with the percentage (padded with spaces) in the center,
#         enclosed in vertical bars.
progress_bar() {
    local progress="$1"
    local bar_length=48

    # Force progress to 100 if it is >= 100.
    if (( $(echo "$progress >= 100" | bc -l) )); then
        progress=100
    fi

    # Calculate number of filled characters (rounded)
    local filled
    filled=$(printf "%.0f" "$(echo "$progress * $bar_length / 100" | bc -l)")
    local empty=$((bar_length - filled))

    local filled_char="█"
    local empty_char="_"

    # Build the underlying bar
    local bar_filled
    bar_filled=$(printf "%0.s$filled_char" $(seq 1 $filled))

    # if the progress is 0, then the bar should be empty
    if [[ $(echo "$1 == 0" | bc) -eq 1 ]]; then
        bar_filled=""
    fi

    local bar_empty
    bar_empty=$(printf "%0.s$empty_char" $(seq 1 $empty))
    local bar="${bar_filled}${bar_empty}"

    # Format percentage string with 2 decimals and exactly one space before and after.
    local percent_value
    percent_value=$(printf "%.2f%%" "$progress")
    local percent_str=" ${percent_value} "
    local percent_len=${#percent_str}

    # Calculate insertion point (index where the percent_str should start within bar)
    local insert_index=$(( (bar_length - percent_len) / 2 ))

    # Build final bar by replacing a segment of the underlying bar with percent_str.
    local final_bar="${bar:0:insert_index}${percent_str}${bar:insert_index+percent_len}"

    #removing last character from final_bar
    final_bar=${final_bar%?}

    # Enclose with vertical bars.
    echo "${GREEN}|${LIGHT_GREEN}${final_bar}${GREEN}|${NC}"
}




# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to convert seconds to hh:mm:ss format
format_time() {
    local T=$1
    printf "%02d:%02d:%02d" $((T/3600)) $(( (T%3600)/60 )) $((T%60))
}

# Hide blinking cursor
echo -ne '\033[?25l'

# Run checks
check_dependencies
check_config_file

# Declare associative arrays for api_keys and base_urls
declare -A api_keys
declare -A base_urls

# Parse the INI file manually
current_section=""
while IFS= read -r line; do
    # Trim whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^\; || "$line" =~ ^\# ]]; then
        continue
    fi
    # Detect section headers like [PrinterName]
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
        current_section="${BASH_REMATCH[1]}"
        continue
    fi
    # Parse key=value pairs
    if [[ "$line" =~ ^([^=]+)=[[:space:]]*(.*)$ ]]; then
        key=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "${BASH_REMATCH[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ "$key" == "api_key" ]; then
            api_keys["$current_section"]="$value"
        elif [ "$key" == "base_url" ]; then
            base_urls["$current_section"]="$value"
        fi
    fi
done < "$CONFIG_FILE"

clear

# Main loop
while true; do

    # Array to hold printer info strings
    output=()

    for printer in "${!api_keys[@]}"; do
        # For each printer, get job info and temperature info
        api_key="${api_keys[$printer]}"
        base_url="${base_urls[$printer]}"

        # Get job info
        response=$(curl -s -w "\n%{http_code}" -H "X-Api-Key: $api_key" "$base_url/api/job")
        body=$(echo "$response" | sed '$d')
        http_code=$(echo "$response" | tail -n1)

        info=""

        info+="${BRIGHT_BLUE} Printer\t:${NC} $printer\n"
        if [ "$http_code" -ne 200 ]; then
            info+="${BRIGHT_BLUE} Status\t\t:${NC} ${RED}Error (HTTP $http_code)${NC}\n"
            log_message "Error: Printer $printer returned HTTP code $http_code."
            SCREEN_REFRESH_FLAG=1
        else
            state=$(echo "$body" | jq -r '.state')
            file_name=$(echo "$body" | jq -r '.job.file.name')

            if [ ${#file_name} -gt $FILE_NAME_MAX ]; then
                file_name="${file_name:0:$FILE_NAME_MAX}..."
            fi

            if [ "$file_name" == "null" ]; then
                file_name="N/A                                                        "
            fi

            # Get progress (with two decimals)
            current_progress=$(echo "$body" | jq -r '.progress.completion')
            if [ "$current_progress" = "null" ]; then
                current_progress=0.00
            fi
            current_progress=$(printf "%.2f" "$current_progress")

            # Get elapsed time and remaining time
            print_time=$(echo "$body" | jq -r '.progress.printTime')
            average_print_time=$(echo "$body" | jq -r '.job.averagePrintTime')
            estimated_print_time=$(echo "$body" | jq -r '.job.estimatedPrintTime')
            print_time_left=$(echo "$body" | jq -r '.progress.printTimeLeft')

            if [[ "$average_print_time" == "null" || $(echo "$average_print_time" | bc) == 0 ]]; then
                print_time_left=$(echo "$estimated_print_time - $print_time" | bc)
            else
                print_time_left=$(echo "$average_print_time - $print_time" | bc)
            fi

            print_time_left=$(printf "%.0f" "$print_time_left")


            if [ "$state" == "Printing" ]; then
                formatted_time=$(format_time "$print_time")
                remaining_time=$(format_time "$print_time_left")
                # Calculate finish epoch, finish date, and today's date
                finish_epoch=$(($(date +%s) + print_time_left))
                finish_date=$(date -d "@$finish_epoch" "+%Y-%m-%d")
                today_date=$(date "+%Y-%m-%d")
                if [ "$finish_date" == "$today_date" ]; then
                    est_finish_fmt=$(date -d "@$finish_epoch" "+%I:%M %p")
                else
                    est_finish_fmt=$(date -d "@$finish_epoch" "+%m-%d %I:%M %p")
                fi
            else
                formatted_time="N/A"
                remaining_time="N/A"
                est_finish_fmt="N/A"
            fi

            # Get printer temperature info from /api/printer
            temp_response=$(curl -s -w "\n%{http_code}" -H "X-Api-Key: $api_key" "$base_url/api/printer")
            temp_body=$(echo "$temp_response" | sed '$d')
            temp_http_code=$(echo "$temp_response" | tail -n1)
            if [ "$temp_http_code" -eq 200 ]; then
                bed_temp=$(echo "$temp_body" | jq -r '.temperature.bed.actual')
                nozzle_temp=$(echo "$temp_body" | jq -r '.temperature.tool0.actual')
                bed_target=$(echo "$temp_body" | jq -r '.temperature.bed.target')
                tool_target=$(echo "$temp_body" | jq -r '.temperature.tool0.target')

                bed_temp=$(printf "%.1f" "$bed_temp")
                nozzle_temp=$(printf "%.1f" "$nozzle_temp")
                bed_target=$(printf "%.1f" "$bed_target")
                tool_target=$(printf "%.1f" "$tool_target")

                # Compute absolute differences using awk (formatted to two decimals)
                abs_bed=$(echo "$bed_temp $bed_target" | awk '{diff = $1 - $2; if(diff < 0) diff = -diff; printf "%.2f", diff}')
                abs_nozzle=$(echo "$nozzle_temp $tool_target" | awk '{diff = $1 - $2; if(diff < 0) diff = -diff; printf "%.2f", diff}')

                # If within tolerance (≤3°C), use GREEN for current and BRIGHT_BLUE for target.
                if (( $(echo "$abs_bed <= 3" | bc -l) )); then
                    bed_display="${LIGHT_GREEN}${bed_temp}${NC}/${bed_target}"
                else
                    bed_display="${RED}${bed_temp}${NC}/${bed_target}"
                fi

                if (( $(echo "$abs_nozzle <= 3" | bc -l) )); then
                    nozzle_display="${LIGHT_GREEN}${nozzle_temp}${NC}/${tool_target}"
                else
                    nozzle_display="${RED}${nozzle_temp}${NC}/${tool_target}"
                fi

                status_string="Bed: ${bed_display},    End: ${nozzle_display}              "

            else
                status_string="${RED}COMMUNICATION ERROR                             ${NC}"
                log_message "Error: Printer $printer returned HTTP code $temp_http_code."
                SCREEN_REFRESH_FLAG=1
            fi

            # Set state color
            if [ "$state" == "Printing" ]; then
                state_display="${LIGHT_GREEN}$state${NC}"
            elif [ "$state" == "Operational" ]; then
                state_display="${LIGHT_YELLOW}$state${NC}"
            elif [ "$state" == "Cancelling" ]; then
                state_display="${ORANGE}$state${NC}"
                elif [ "$state" == "Error" ]; then
                state_display="${RED}$state${NC}"
            else
                state_display="$state"
            fi

            # Build progress bar
            bar=$(progress_bar "$current_progress")

            # Build info lines
            # Temperature info is added in the status line
            info+="${BRIGHT_BLUE} Status\t\t:${NC} $state_display                        \n"
            info+="${BRIGHT_BLUE} Temperature\t:${NC} $status_string                      \n"
            info+="${BRIGHT_BLUE} File\t\t:${NC} $file_name                               \n"
            info+="${BRIGHT_BLUE} Progress\t:${NC} ${LIGHT_GREEN}${bar}${NC}     \n"
            info+="${BRIGHT_BLUE} Elapsed Time\t:${NC} $formatted_time            \n"
            info+="${BRIGHT_BLUE} Remaining Time\t:${NC} $remaining_time (${est_finish_fmt})              \n"
        fi
        info+=" +------------------------------------------------------------------+ \n"
        output+=( "$info" )
    done

   if [ $((counter % SCREEN_REFRESH)) -eq 0 ]; then
        counter=0
        clear
    fi

    if [ ${SCREEN_REFRESH_FLAG} -eq 1 ]; then
        sleep "$REFRESH_INTERVAL"
        clear
        SCREEN_REFRESH_FLAG=0
    fi

    # Print overall dashboard heading with version
    echo -e "${HOME}"
    echo " =================================================================== "
    echo -e "${LIGHT_YELLOW}                        Monitoring 3D Printers${NC}  "
    echo " =================================================================== "
    echo -e "${GotoX65}v${VERSION} ${GotoX2}$(date)"
    echo ""

    for info in "${output[@]}"; do
        echo -e "$info"
    done

    sleep "$REFRESH_INTERVAL"
    counter=$((counter + 1))

done

# When exiting, restore the blinking cursor (handled by trap)
