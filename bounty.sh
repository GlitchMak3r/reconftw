#!/bin/bash

# Default values
threads=10
reconftw="~/reconftw"

# Function to show usage
usage() {
    echo "Usage: $0 -d <domain> | -l <list> [-h <threads>]"
    echo "Example: $0 -d company.com -h 15"
    exit 1
}

# Process arguments
while getopts "d:l:h:" opt; do
    case "$opt" in
        d) domain=$OPTARG ;;
        l) list=$OPTARG ;;
        h) threads=$OPTARG ;;
        *) usage ;;
    esac
done

# Verify arguments
if [[ -z "$domain" && -z "$list" ]]; then
    usage
fi

# If a single domain
if [[ -n "$domain" ]]; then
    # Subdomains
    echo "Running subdomain search for domain: $domain"
    proxychains | ~/reconftw/reconftw.sh -s "$domain"
    # Vulnerabilities
    echo "Running vulnerability scanner for domain: $domain"
    subdomains_file="$reconftw/Recon/$domain/subdomains/subdomains.txt"
    if [[ -f $subdomains_file ]]; then
        cat "$subdomains_file" | while read -r subdomain; do
            echo "Processing subdomain: $subdomain"
            proxychains | $reconftw/reconftw.sh -a "$subdomain" &
            (( $(jobs | wc -l) >= threads )) && wait
        done
    fi

# If a list of domains
elif [[ -n "$list" ]]; then
    if [[ ! -f "$list" ]]; then
        echo "The domain list does not exist: $list"
        exit 1
    fi

    echo "Running reconftw for the list of domains in $list with $threads threads"
    cat "$list" | while read -r domain; do
        echo "Processing domain: $domain"
        proxychains | $reconftw/reconftw.sh -s "$domain" &
        (( $(jobs | wc -l) >= threads )) && wait

        # Run reconftw for each subdomain
        subdomains_file="$reconftw/Recon/$domain/subdomains/subdomains.txt"
        if [[ -f $subdomains_file ]]; then
            cat "$subdomains_file" | while read -r subdomain; do
                echo "Processing subdomain: $subdomain"
                proxychains | $reconftw/reconftw.sh -a "$subdomain" &
                (( $(jobs | wc -l) >= threads )) && wait
            done
        else
            echo "Subdomain file not found for $domain"
        fi
    done
    wait
fi

exit 0

