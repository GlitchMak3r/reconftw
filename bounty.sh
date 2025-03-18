#!/bin/bash

# Default values
threads=10
reconftw=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )    
PROXY="proxychains -q "

SUBDOMAIN_ENUM="$PROXY $reconftw/reconftw.sh -s -d "
VULN_SCAN="$PROXY $reconftw/reconftw.sh -a -d "

sudo service tor start  

# Function to show usage
usage() {
    echo "Usage: $0 -d <domain> | -l <list> | -s <subdomains_list> [-h <threads>]"
    echo "Example: $0 -d company.com -h 15"
    exit 1
}

# Check if required tools exist
if ! command -v proxychains &> /dev/null; then
    echo "Error: proxychains not found. Install it first."
    exit 1
fi
if [[ ! -f "$reconftw/reconftw.sh" ]]; then
    echo "Error: reconftw.sh not found in $reconftw. Check the path."
    exit 1
fi

# Process arguments
while getopts "d:l:s:h:" opt; do
    case "$opt" in
        d) domain=$OPTARG ;;
        l) list=$OPTARG ;;
        s) subdomains_list=$OPTARG ;;
        h) threads=$OPTARG ;;
        *) usage ;;
    esac
done

# Verify arguments
if [[ -z "$domain" && -z "$list" && -z "$subdomains_list" ]]; then
    usage
fi

# If a single domain
if [[ -n "$domain" ]]; then
    echo "Running subdomain search for domain: $domain"
    $SUBDOMAIN_ENUM "$domain"

    subdomains_file="$reconftw/Recon/$domain/subdomains/subdomains.txt"
    if [[ -f $subdomains_file ]]; then
        echo "Running vulnerability scanner on discovered subdomains..."
        cat "$subdomains_file" | xargs -P $threads -I {} $VULN_SCAN "{}"
    else
        echo "No subdomains file found for $domain"
    fi

# If a list of domains
elif [[ -n "$list" ]]; then
    if [[ ! -f "$list" ]]; then
        echo "Error: The domain list does not exist: $list"
        exit 1
    fi
    
    echo "Running ReconFTW for the list of domains in $list with $threads threads"
    cat "$list" | xargs -P $threads -I {} $SUBDOMAIN_ENUM  "{}"
    
    for domain in $(cat "$list"); do
        subdomains_file="$reconftw/Recon/$domain/subdomains/subdomains.txt" 
        if [[ -f $subdomains_file ]]; then
            echo "Running vulnerability scanner for subdomains of $domain..."
            cat "$subdomains_file" | xargs -P $threads -I {} $VULN_SCAN "{}"
        else
            echo "No subdomains file found for $domain"
        fi
    done
    
# If directly scanning a list of subdomains
elif [[ -n "$subdomains_list" ]]; then
    if [[ ! -f "$subdomains_list" ]]; then
        echo "Error: The subdomain list does not exist: $subdomains_list"
        exit 1
    fi
    
    echo "Running vulnerability scanner on provided subdomains list..."
    cat "$subdomains_list" | xargs -P $threads -I {} $VULN_SCAN "{}"
fi

exit 0
