#!/bin/bash
GENERIC_BASE_URL='http://ddebs.ubuntu.com/pool/main/l/linux/'
HWE_BASE_URL='http://ddebs.ubuntu.com/pool/main/l/linux-hwe/'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

install_requirement(){
    if ! which go > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ go is not in PATH.${NC}"
        echo -e "${GREEN}✅ Installing golang-go dependencies${NC}"
        sudo apt install golang-go build-essential -y
        echo
    fi

    if ! which dwarf2json > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ dwarf2json is not in PATH${NC}"
        echo -e "${GREEN}✅ Compiling and Installing dwarf2json${NC}"
        git clone https://github.com/volatilityfoundation/dwarf2json
        cd dwarf2json && go build && chmod +x dwarf2json && sudo mv dwarf2json /usr/bin/
        echo && cd ..
    fi
}

get_ddeb_path(){
    LIST_FILE=$(curl -s $GENERIC_BASE_URL)
    DDEB_PATH=$(echo $LIST_FILE | grep -oP "(?<=href=\")linux-image-(unsigned-)?$1-generic-dbgsym_$1[\d\.\-]+_$2.ddeb")
    
    echo $DDEB_PATH
    if [ -z "${DDEB_PATH}" ]; then
        exit 1
    fi
}

download_ddeb(){
    echo -e "${YELLOW}⚠️ $1 does not exist yet${NC}"
    echo -e "${GREEN}✅ Downloading $1 from repository${NC}"
    DDEB_URL="${GENERIC_BASE_URL}$1"
    wget -P /tmp $DDEB_URL
    echo
}

unpack_vm_kernel(){
    echo -e "${GREEN}✅ Unpacking vmlinux file${NC}"
    ar x /tmp/$1 data.tar.xz
    tar -xI/usr/bin/xz -f data.tar.xz ./usr/lib/debug/boot/vmlinux-$2-generic
}

generate_dwarf_file(){
    echo -e "${GREEN}✅ Generating DWARF JSON file${NC}"
    dwarf2json linux --elf ./usr/lib/debug/boot/vmlinux-$1-generic | xz > "linux-image-${1}-generic_$2.json.xz"
}

cleanup_file(){
    rm -f $1 data.tar.xz 
}

if [ "$#" -eq 2 ]; then
    KERNEL_VERSION=$1
    ARCH=$2
    
    install_requirement
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error occurred while installing dependencies${NC}"
        exit 1
    fi

    DDEB_PATH=$(get_ddeb_path $KERNEL_VERSION $ARCH)
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Requested linux $KERNEL_VERSION kernel for $ARCH is nowhere to be found${NC}"
        exit 1
    fi

    rm /tmp/*.ddeb
    if [ ! -e "/tmp/$DDEB_PATH" ]; then
        download_ddeb $DDEB_PATH
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Error occurred while downloading $DDEB_PATH${NC}"
            exit 1
        fi
    fi
    
    unpack_vm_kernel $DDEB_PATH $KERNEL_VERSION
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error occurred while unpacking ddeb kernel file${NC}"
        exit 1
    fi

    generate_dwarf_file $KERNEL_VERSION $ARCH
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error occurred while generating DWARF-json file${NC}"
        exit 1
    fi

    cleanup_file $DDEB_PATH

    echo -e "${GREEN}✅ Saved profile to linux-image-${1}-generic.json.xz${NC}"
else
    echo
    echo "Usage: $0 kernel_version architecture"
    echo "Example: $0 5.15.0-118 amd64"
fi