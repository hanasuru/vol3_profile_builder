# vol3_profile_builder

vol3_profile_builder is a script to build a volatility3 profile based on given kernel version. It's worked by converting vmlinux from [ddebs repository](http://ddebs.ubuntu.com/pool/main/l/) with [dwarf2json](https://github.com/volatilityfoundation/dwarf2json) into ISF file. Mainly tested on Ubuntu-based virtual machine with `generic` kernel image

## Usage

```bash
Usage: ./build.sh <kernel_version> <architecture>

Arguments:
  <kernel_version>   Specify the kernel version (e.g., 5.4.0-192)
  <architecture>     Specify the architecture (e.g., amd64)

Example:
  ./build.sh 5.4.0-192 amd64
```

## Authors

* **hanasuru** - *Initial work* 

See also the list of [contributors](https://github.com/hanasuru/vol3_profile_builder/contributors) who participated in this project.
