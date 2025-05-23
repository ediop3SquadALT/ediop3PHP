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

PAYLOAD_FILE="payloads1219.txt"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

if [ ! -f "$PAYLOAD_FILE" ]; then
    echo "[-] Error: Payload file $PAYLOAD_FILE not found!"
    exit 1
fi

scan_url() {
    local url=$1
    echo "[*] Scanning URL: $url"
    
    while IFS= read -r payload; do
        # ok
        [ -z "$payload" ] && continue
        
        echo "[*] Testing payload: $payload"
        response=$(curl -s -k -A "$USER_AGENT" -o /dev/null -w "%{http_code}" "$url?id=$payload")
        
        if [[ "$response" == "200" || "$response" == "302" || "$response" == "500" ]]; then
            echo "[+] VULNERABILITY FOUND: $payload on $url?id=$payload (Response: $response)"
        fi
    done < "$PAYLOAD_FILE"
}

check_firewall() {
    echo "[*] Checking WAF/Firewall for $1"
    response=$(curl -I -s -k -A "$USER_AGENT" "$1")
    
    if echo "$response" | grep -i "X-WAF" > /dev/null || \
       echo "$response" | grep -i "cf-ray" > /dev/null || \
       echo "$response" | grep -i "X-Sucuri-ID" > /dev/null || \
       echo "$response" | grep -i "Server: cloudflare" > /dev/null; then
        echo "[+] WAF or Firewall detected on $1"
    fi
    
    status_code=$(curl -s -k -A "$USER_AGENT" -o /dev/null -w "%{http_code}" "$1")
    
    if [[ "$status_code" == "403" ]]; then
        echo "[+] Forbidden access, possible WAF/Firewall blocking"
    elif [[ "$status_code" == "429" ]]; then
        echo "[+] Too many requests, possible rate limiting detected"
    fi
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 -u <URL>"
        echo "Example: $0 -u https://testphp.vulnweb.com"
        exit 1
    fi

    # lol
    while getopts ":u:" opt; do
        case $opt in
            u) target="$OPTARG" ;;
            *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        esac
    done

    # Vlol
    if [ -z "$target" ]; then
        echo "[-] Error: No target URL specified"
        exit 1
    fi

    echo "[*] Starting scan against: $target"
    
    check_firewall "$target"
    
    scan_url "$target"
    
    echo "[*] Initial scan completed"
}

main "$@"
