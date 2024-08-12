#!/bin/bash
BASE_URL='http://ddebs.ubuntu.com/pool/main/l/linux/'

install_requirement(){
    if ! which go > /dev/null 2>&1; then
        echo "[x] go is not in PATH. Installing golang-go..."
        sudo apt install golang-go build-essential -y
        echo
    fi

    if ! which dwarf2json > /dev/null 2>&1; then
        echo "[x] dwarf2json is not in PATH. Installing dwarf2json..."
        git clone https://github.com/volatilityfoundation/dwarf2json
        cd dwarf2json && go build && chmod +x dwarf2json && sudo mv dwarf2json /usr/bin/
        echo && cd ..
    fi
}

get_ddeb_DDEB_PATH(){
    LIST_FILE=$(curl -s $BASE_URL)
    DDEB_PATH=$(echo $LIST_FILE | grep -oP "(?<=href=\")linux-image-(unsigned-)?$1-generic-dbgsym_$1[\d\.\-]+_amd64.ddeb")
    echo $DDEB_PATH
}

download_ddeb(){
    echo -e "[x] $1 does not exist. Start downloading DDEB files..."
    DDEB_URL="${BASE_URL}$1"
    wget -P /tmp $DDEB_URL
    echo
}

unpack_vm_kernel(){
    echo -e "[x] Unpacking vmlinux file..."
    ar x /tmp/$1 data.tar.xz
    tar -xI/usr/bin/xz -f data.tar.xz ./usr/lib/debug/boot/vmlinux-$2-generic
}

generate_dwarf_file(){
    echo -e "[x] Generating DWARF JSON file..."
    dwarf2json linux --elf ./usr/lib/debug/boot/vmlinux-$1-generic | xz > "linux-image-${1}-generic.json.xz"
}

if [ "$#" -eq 1 ]; then
    KERNEL_VERSION=$1
    install_requirement
    if [ $? -ne 0 ]; then
        echo "Error occurred in install_requirement."
        exit 1
    fi

    DDEB_PATH=$(get_ddeb_DDEB_PATH $KERNEL_VERSION)
    if [ $? -ne 0 ]; then
        echo "Error occurred in get_ddeb_DDEB_PATH."
        exit 1
    fi

    if [ ! -e "/tmp/$DDEB_PATH" ]; then
        download_ddeb $DDEB_PATH
        if [ $? -ne 0 ]; then
            echo "Error occurred in download_ddeb."
            exit 1
        fi
    fi
    
    unpack_vm_kernel $DDEB_PATH $KERNEL_VERSION
    if [ $? -ne 0 ]; then
        echo "Error occurred in unpack_vm_kernel."
        exit 1
    fi

    generate_dwarf_file $KERNEL_VERSION
    if [ $? -ne 0 ]; then
        echo "Error occurred in generate_dwarf_file."
        exit 1
    fi

    echo "[v] Saved profile to linux-image-${1}-generic.json.xz"
else
    echo
    echo "Usage: $0 kernel_version"
    echo "Example: $0 5.15.0-118"
fi