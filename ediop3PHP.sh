#!/bin/bash

echo "███████╗██████╗░██╗░█████╗░██████╗░██████╗░"
echo "██╔════╝██╔══██╗██║██╔══██╗██╔══██╗╚════██╗"
echo "█████╗░░██║░░██║██║██║░░██║██████╔╝░█████╔╝"
echo "██╔══╝░░██║░░██║██║██║░░██║██╔═══╝░░╚═══██╗"
echo "███████╗██████╔╝██║╚█████╔╝██║░░░░░██████╔╝"
echo "╚══════╝╚═════╝░╚═╝░╚════╝░╚═╝░░░░░╚═════╝░"
echo ""
echo "██████╗░██╗░░██╗██████╗░"
echo "██╔══██╗██║░░██║██╔══██╗"
echo "██████╔╝███████║██████╔╝"
echo "██╔═══╝░██╔══██║██╔═══╝░"
echo "██║░░░░░██║░░██║██║░░░░░"
echo "╚═╝░░░░░╚═╝░░╚═╝╚═╝░░░░░"
echo ""

# Declare visited URLs to avoid re-checking the same ones
visited_urls=()
vulnerabilities_found=()

# Function to check for Google Dork results
check_google_dork() {
    google_url="https://www.google.com/search?q=site:$target"
    google_response=$(curl -s "$google_url")
    clean_response=$(echo "$google_response" | sed 's/<[^>]*>//g' | sed 's/&[^;]*;//g')  # Remove HTML tags and entities
    urls=$(echo "$clean_response" | grep -oP 'https?://\S+' 2>/dev/null)  # Extract URLs only
    for url in $urls; do
        # If URL has not been visited yet
        if [[ ! " ${visited_urls[@]} " =~ " $url " ]]; then
            visited_urls+=("$url")
            echo "Google Dork found URL: $url"
        fi
    done
}

# Function to check FOFA search results
check_fofa() {
    fofa_url="https://fofa.info/search?q=$target"
    fofa_response=$(curl -s "$fofa_url")
    clean_response=$(echo "$fofa_response" | sed 's/<[^>]*>//g' | sed 's/&[^;]*;//g')  # Remove HTML tags and entities
    urls=$(echo "$clean_response" | grep -oP 'https?://\S+' 2>/dev/null)  # Extract URLs only
    for url in $urls; do
        # If URL has not been visited yet
        if [[ ! " ${visited_urls[@]} " =~ " $url " ]]; then
            visited_urls+=("$url")
            echo "FOFA found URL: $url"
        fi
    done
}

# Function to check Shodan search results
check_shodan() {
    shodan_url="https://www.shodan.io/search?query=$target"
    shodan_response=$(curl -s "$shodan_url")
    clean_response=$(echo "$shodan_response" | sed 's/<[^>]*>//g' | sed 's/&[^;]*;//g')  # Remove HTML tags and entities
    urls=$(echo "$clean_response" | grep -oP 'https?://\S+' 2>/dev/null)  # Extract URLs only
    for url in $urls; do
        # If URL has not been visited yet
        if [[ ! " ${visited_urls[@]} " =~ " $url " ]]; then
            visited_urls+=("$url")
            echo "Shodan found URL: $url"
        fi
    done
}

# Function to check for WAF/Firewall detection
check_firewall() {
    response=$(curl -I "$target" -s)
    if echo "$response" | grep -i "X-WAF" > /dev/null || echo "$response" | grep -i "cf-ray" > /dev/null || echo "$response" | grep -i "X-Sucuri-ID" > /dev/null || echo "$response" | grep -i "Server: cloudflare" > /dev/null; then
        echo "[+] WAF or Firewall detected on $target."
    fi
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$target")
    if [[ "$status_code" == "403" ]]; then
        echo "[+] Forbidden access, possible WAF/Firewall blocking."
    elif [[ "$status_code" == "429" ]]; then
        echo "[+] Too many requests, possible rate limiting detected."
    fi
}

# Function to scan for vulnerabilities (example function)
scan_vulnerabilities() {
    payloads=($(cat payloads1219.txt))
    for payload in "${payloads[@]}"; do
        response=$(curl -X GET "$target?id=$payload" -s -o /dev/null -w "%{http_code}")
        if [[ "$response" == "200" || "$response" == "302" || "$response" == "500" ]]; then
            if [[ ! " ${vulnerabilities_found[@]} " =~ " $payload " ]]; then
                vulnerabilities_found+=("$payload")
                echo "[+] Vulnerability found: $payload on page $target?id=$payload"
            fi
        fi
    done
}

# Main function
main() {
    if [[ -z "$1" ]]; then
        echo "Usage: bash ediop3PHP.sh -u <URL>"
        exit 1
    fi

    while getopts ":u:" opt; do
        case ${opt} in
            u )
                target=$OPTARG
                ;;
        esac
    done

    # Continuous scanning loop
    while true; do
        check_firewall &
        scan_vulnerabilities &
        check_google_dork &
        check_fofa &
        check_shodan &

        wait  # Wait for all background processes to finish

        # Pause for 1 second before repeating the scan
        echo "[+] Scanning again in 1 second..."
        sleep 1  # Changed from 5 seconds to 1 second
    done
}

main "$@"
