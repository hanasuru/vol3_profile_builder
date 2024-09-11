#!/bin/bash
GENERIC_BASE_URL='http://ddebs.ubuntu.com/pool/main/l/linux/'
CANONICAL_BASE_URL='https://launchpad.net/ubuntu/'


BOLD="\033[1m"
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

install_requirement(){
    if ! which go > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ go is not in PATH.${RESET}"
        echo -e "${GREEN}✅ Installing golang-go dependencies${RESET}"
        sudo apt install golang-go build-essential -y
        echo
    fi

    if ! which dwarf2json > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ dwarf2json is not in PATH${RESET}"
        echo -e "${GREEN}✅ Compiling and Installing dwarf2json${RESET}"
        git clone https://github.com/volatilityfoundation/dwarf2json
        cd dwarf2json && go build && chmod +x dwarf2json && sudo mv dwarf2json /usr/local/bin/
        echo && cd ..
    fi
}

get_ddeb_url(){
    LIST_FILE=$(curl -s $GENERIC_BASE_URL)
    echo $LIST_FILE | grep -oP "(?<=href=\")linux-image-(unsigned-)?$1-generic-dbgsym_$1[\d\.\-]+_$2.ddeb"
}

get_canonical_name(){
    curl -s http://archive.ubuntu.com/ubuntu/dists/ | grep -oP '(?<=href=")[\w]+(?=/")' | paste -sd ','
}

get_canonical_url(){
    URLS=$(eval "echo https://launchpad.net/ubuntu/{$(get_canonical_name)}/$2/linux-image-unsigned-$1-generic-dbgsym")
    
    for URL in $URLS; do
        if curl -s "$URL" | grep -m1 -oP '(?<=/ubuntu/).+dbgsym/[\d\.\-~]+'; then
            break
        fi
    done
}

get_kernel_path(){
    DDEB_URL=$(get_ddeb_url $1 $2)

    if [ -z "${DDEB_URL}" ]; then
        CANONICAL_URL=$(get_canonical_url $1 $2)
        if [ -z "${CANONICAL_URL}" ]; then
            exit 1
        else
            curl -s "${CANONICAL_BASE_URL}${CANONICAL_URL}" | grep -oP 'http://launchpadlibrarian.net.+.ddeb(?=")'
        fi

    else
        echo "${GENERIC_BASE_URL}${DDEB_URL}"
    fi
}

download_kernel_image(){
    echo -e "${YELLOW}⚠️ $(basename $1) does not exist yet${RESET}"
    echo -e "${GREEN}✅ Downloading $1 from repository${RESET}"
    wget -c -P /tmp $1
    echo
}

unpack_vm_kernel(){
    echo -e "${GREEN}✅ Unpacking vmlinux file${RESET}"
    ar x /tmp/$1 data.tar.xz
    tar -xI/usr/bin/xz -f data.tar.xz ./usr/lib/debug/boot/vmlinux-$2-generic
}

generate_isf_file(){
    echo -e "${GREEN}✅ Generating ISF file${RESET}"
    dwarf2json linux --elf ./usr/lib/debug/boot/vmlinux-$1-generic | xz > "linux-image-${1}-generic_$2.json.xz"
}

cleanup_file(){
    echo -e "${GREEN}✅ Cleaning kernel image file${RESET}"
    if [[ "$(pwd)" != "/" ]]; then
        rm -rf ./usr
    fi
    rm -rf $1 data.tar.xz dwarf2json
}

upload_isf_file(){
    echo -e "${GREEN}✅ Uploading ISF File${RESET}"
    if ! which ffsend > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ ffsend is not in PATH${RESET}"
        echo -e "${GREEN}✅ Installing ffsend${RESET}"
        sudo wget -q -O/usr/local/bin/ffsend https://github.com/timvisee/ffsend/releases/download/v0.2.76/ffsend-v0.2.76-linux-x64-static
        sudo chmod +x /usr/local/bin/ffsend
    fi
    echo -e "${GREEN}"
    ffsend upload "linux-image-${1}-generic_$2.json.xz"
    echo -e "${RESET}"
}

if [ "$#" -ge 2 ] && [ "$#" -le 3 ]; then
    KERNEL_VERSION=$1
    ARCH=$2

    UPLOAD=0
    if [ "$#" -eq 3 ] && [ "$3" == "--upload" ]; then
        UPLOAD=1
    fi
    
    install_requirement
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error occurred while installing dependencies${RESET}"
        exit 1
    fi

    echo -e "${GREEN}✅ Getting kernel url from repository${RESET}"
    KERNEL_URL=$(get_kernel_path $KERNEL_VERSION $ARCH)
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Requested linux ${KERNEL_VERSION}_${ARCH} is nowhere to be found on both ddebs or canonical repository${RESET}"
        exit 1
    fi

    download_kernel_image $KERNEL_URL
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error occurred while downloading $KERNEL_URL${RESET}"
        exit 1
    fi

    unpack_vm_kernel $(basename $KERNEL_URL) $KERNEL_VERSION
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error occurred while unpacking kernel image file${RESET}"
        exit 1
    fi

    generate_isf_file $KERNEL_VERSION $ARCH
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error occurred while generating ISF file${RESET}"
        exit 1
    fi

    cleanup_file $(basename $KERNEL_URL)
    echo -e "${GREEN}✅ Saved profile to linux-image-${KERNEL_VERSION}-generic.json.xz${RESET}"

    if [ $UPLOAD -eq 1 ]; then
        upload_isf_file $KERNEL_VERSION $ARCH
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Error occurred during upload${RESET}"
            exit 1
        fi
    fi

else
    echo -e "\n${BLUE}Usage:${RESET} $(basename $0) ${CYAN}<kernel_version>${RESET} ${CYAN}<architecture>${RESET} [--upload]"
    echo -e "\n${BLUE}Arguments:${RESET}"
    echo -e "  ${CYAN}<kernel_version>${RESET}   Specify the kernel version (e.g., ${GREEN}5.4.0-192${RESET})"
    echo -e "  ${CYAN}<architecture>${RESET}     Specify the architecture (e.g., ${GREEN}amd64${RESET})"
    echo -e "  ${CYAN}--upload${RESET}           Upload ISF file to public send-instances (optional)"
    echo -e "\n${BLUE}Example:${RESET}"
    echo -e "  $(basename $0) ${GREEN}5.4.0-192${RESET} ${GREEN}amd64${RESET} ${CYAN}--upload${RESET}\n"
fi
