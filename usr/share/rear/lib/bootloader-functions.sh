# Test for the syslinux version
function get_syslinux_version {
    local syslinux_version

    syslinux_version=$(get_version extlinux --version)

    if [[ -z "$syslinux_version" ]]; then
        syslinux_version=$(get_version syslinux --version)
    fi

    if [[ -z "$syslinux_version" ]]; then
        syslinux_version=$(strings $SYSLINUX_DIR/isolinux.bin | awk '/^ISOLINUX / { print $2 }')
    fi

    if [[ -z "$syslinux_version" ]]; then
        Log "Could not detect syslinux version, assuming it is old"
    fi

    echo "$syslinux_version"
}

function find_syslinux_file {
    # input argument is usually isolinux.bin
    # output argument is the full path of isolinux.bin
    local syslinux_file=""

    for file in /usr/{share,lib,libexec,lib/syslinux}/*/"$1" ; do
        if [[ -s "$file" ]]; then
            syslinux_file="$file"
            break # for loop
        fi
    done
    echo "$syslinux_file"
}

function find_syslinux_modules_dir {
    # input argument is usually a com32 image file
    # output argument is the full path of the SYSLINUX_MODULES_DIR directory (not of the com32 file!)
    local syslinux_version=$(get_syslinux_version)
    local syslinux_modules_dir=

    if [[ -n "$SYSLINUX_MODULES_DIR" ]]; then
        [[ -d "$SYSLINUX_MODULES_DIR" ]] && echo "$SYSLINUX_MODULES_DIR"
        return
    fi

    if version_newer "$syslinux_version" 5.00; then
        # check for the default location - fast and easy
        if [[ -d /usr/lib/syslinux/modules ]]; then
            if is_true $USING_UEFI_BOOTLOADER ; then
                syslinux_modules_dir=/usr/lib/syslinux/modules/efi64
            else
                syslinux_modules_dir=/usr/lib/syslinux/modules/bios
            fi
        else
            # not default location? try to find it
            # file=/usr/lib/syslinux/modules/efi32/menu.c32
            # f23: file=/usr/share/syslinux/menu.c32
            file=$( find /usr -name "$1" 2>/dev/null | tail -1 )
            syslinux_modules_dir=$( dirname "$file" )        # /usr/lib/syslinux/modules/efi32
            syslinux_modules_dir=${syslinux_modules_dir%/*}  # /usr/lib/syslinux/modules
            if is_true $USING_UEFI_BOOTLOADER ; then
                syslinux_modules_dir=${syslinux_modules_dir}/efi64
            else
                syslinux_modules_dir=${syslinux_modules_dir}/bios
            fi
            if [[ ! -d "$syslinux_modules_dir" ]] ; then     # f23: /usr/share/bios
                syslinux_modules_dir=$( dirname "$file" )    # try again (f23 uses old location for its modules)
            fi
            [[ -d "$syslinux_modules_dir" ]]
            BugIfError "Define SYSLINUX_MODULES_DIR in local.conf as syslinux modules were not found"
        fi
    fi
    echo "$syslinux_modules_dir"
}

function find_yaboot_file {
    # input argument is usually: yaboot
    # output argument is the full path of the yaboot binary
    local yaboot_file=""

    for file in /{lib/lilo,usr/lib}/*/"$1" ; do
        if [[ -s "$file" ]]; then
            yaboot_file="$file"
            break
        fi
    done
    echo "$yaboot_file"
}

function set_syslinux_features {
    # Test for features in syslinux
    # true if isolinux supports booting from /boot/syslinux, /boot or only from / of the ISO
    FEATURE_ISOLINUX_BOOT_SYSLINUX=
    # true if syslinux supports booting from /boot/syslinux, /boot or only from / of the USB media
    FEATURE_SYSLINUX_BOOT_SYSLINUX=
    # true if syslinux and extlinux support localboot
    FEATURE_SYSLINUX_EXTLINUX_WITH_LOCALBOOT=
    # true if extlinux supports the -i option
    FEATURE_SYSLINUX_EXTLINUX_INSTALL=
    # true if syslinux supports INCLUDE directive
    FEATURE_SYSLINUX_INCLUDE=
    # true if syslinux supports advanced label names (eg. linux-2.6.18)
    FEATURE_SYSLINUX_LABEL_NAMES=
    # true if syslinux supports MENU DEFAULT directive
    FEATURE_SYSLINUX_MENU_DEFAULT=
    # true if syslinux supports MENU HELP directive
    FEATURE_SYSLINUX_MENU_HELP=
    # true if syslinux supports MENU BEGIN/MENU END/MENU QUIT directives
    FEATURE_SYSLINUX_SUBMENU=
    # true if syslinux supports MENU HIDDEN directive
    FEATURE_SYSLINUX_MENU_HIDDEN=
    # true if syslinux supports TEXT HELP directive
    FEATURE_SYSLINUX_TEXT_HELP=
    # true if syslinux supports modules sub-dir (Version > 5.00)
    FEATURE_SYSLINUX_MODULES=
    # If ISO_DEFAULT is not set or empty or only blanks, set it to default 'boothd'
    test $ISO_DEFAULT || ISO_DEFAULT="boothd"
    # Define the syslinux directory for later usage (since version 5 the bins and c32 are in separate dirs)
    if [[ -z "$SYSLINUX_DIR" ]]; then
        ISOLINUX_BIN=$(find_syslinux_file isolinux.bin)
        if [[ -s "$ISOLINUX_BIN" ]]; then
            SYSLINUX_DIR="$(dirname $ISOLINUX_BIN)"
        fi
    fi
    [[ "$SYSLINUX_DIR" ]]
    StopIfError "Could not find a working syslinux path."

    local syslinux_version=$(get_syslinux_version)
    if [[ "$1" ]] && version_newer "$1" "$syslinux_version"; then
        syslinux_version="$1"
    fi
    Log "Features based on syslinux version: $syslinux_version"

    if version_newer "$syslinux_version" 4.00; then
        FEATURE_SYSLINUX_MENU_HELP="y"
        FEATURE_ISOLINUX_BOOT_SYSLINUX="y"
    fi
    if version_newer "$syslinux_version" 3.72; then
        FEATURE_SYSLINUX_MENU_DEFAULT="y"
    fi
    if version_newer "$syslinux_version" 3.70; then
        FEATURE_SYSLINUX_EXTLINUX_WITH_LOCALBOOT="y"
    fi
    if version_newer "$syslinux_version" 3.62; then
        FEATURE_SYSLINUX_SUBMENU="y"
    fi
    if version_newer "$syslinux_version" 3.52; then
        FEATURE_SYSLINUX_MENU_HIDDEN="y"
    fi
    if version_newer "$syslinux_version" 3.50; then
        FEATURE_SYSLINUX_INCLUDE="y"
        FEATURE_SYSLINUX_TEXT_HELP="y"
    fi
    if version_newer "$syslinux_version" 3.35; then
        FEATURE_SYSLINUX_BOOT_SYSLINUX="y"
        FEATURE_SYSLINUX_LABEL_NAMES="y"
    fi
    if version_newer "$syslinux_version" 3.20; then
        FEATURE_SYSLINUX_EXTLINUX_INSTALL="y"
    fi

    if version_newer "$syslinux_version" 5.00; then
        FEATURE_SYSLINUX_MODULES="y"
    fi

    if [[ "$FEATURE_SYSLINUX_BOOT_SYSLINUX" ]]; then
        SYSLINUX_PREFIX="boot/syslinux"
    else
        SYSLINUX_PREFIX=
    fi
    Log "Using syslinux prefix: $SYSLINUX_PREFIX"

    FEATURE_SYSLINUX_IS_SET=1
}



# Create a suitable syslinux configuration based on capabilities
# the mandatory first argument is the full path to an existing directory where required
# binaries will be copied to
# the optional second argment is the target flavour and defaults to isolinux
function make_syslinux_config {
    [[ -d "$1" ]]
    BugIfError "Required argument for BOOT_DIR is missing"
    [[ -d "$SYSLINUX_DIR" ]]
    BugIfError "Required environment SYSLINUX_DIR ($SYSLINUX_DIR) is not set or not a directory"
    [[ "$FEATURE_SYSLINUX_IS_SET" ]]
    BugIfError "You must call set_syslinux_features before"

    local BOOT_DIR="$1" ; shift
    local flavour="${1:-isolinux}" ; shift
    # syslinux v5 and higher has now its modules in a separate directory structure
    local syslinux_modules_dir=

    if [[ "$FEATURE_SYSLINUX_MODULES" ]]; then
        syslinux_modules_dir=$( find_syslinux_modules_dir menu.c32 )
        # the modules dir is the base for SYSLINUX_DIR (to comply with versions < 5)
        SYSLINUX_DIR="$syslinux_modules_dir"
    fi

    # Enable serial console, unless explicitly disabled (only last entry is used on some systems thats where SERIAL_CONSOLE_DEVICE_SYSLINUX comes in :-/)
    if [[ "$USE_SERIAL_CONSOLE" =~ ^[yY1] ]]; then
        for devnode in $(ls /dev/ttyS[0-9]* | sort); do
            # Not sure if using all serial devices do screw up syslinux in general
            # for me listing more then one serial line in the config screwed it
            # see https://github.com/rear/rear/pull/2650
            if [ -z $SERIAL_CONSOLE_DEVICE_SYSLINUX ] || [[ $SERIAL_CONSOLE_DEVICE_SYSLINUX == $devnode ]]; then
                speed=$(stty -F $devnode 2>/dev/null | awk '/^speed / { print $2 }')
                if [ "$speed" ]; then
                    echo "serial ${devnode##/dev/ttyS} $speed"
                fi
            fi
        done
    fi

    # if we have the menu.c32 available we use it. if not we make sure that there will be no menu lines in the result
    # so that we don't confuse older syslinux
    if [[ -r "$SYSLINUX_DIR/menu.c32" ]] ; then
        cp $v "$SYSLINUX_DIR/menu.c32" "$BOOT_DIR/menu.c32" >&2
        function syslinux_menu {
            echo "MENU $@"
        }
    else
        # without menu we don't set a default but we ask syslinux to prompt for user input
        echo "prompt 1"
        function syslinux_menu {
            : #noop
        }
    fi

    function syslinux_menu_help {
        if [[ "$FEATURE_SYSLINUX_MENU_HELP" ]]; then
            echo "TEXT HELP"
            for line in "$@" ; do echo "$line" ; done
            echo "ENDTEXT"
        fi
    }

    echo "say ENTER - boot local hard disk"
    echo "say --------------------------------------------------------------------------------"
    echo "$VERSION_INFO" >$BOOT_DIR/message
    echo "display message"
    echo "F1 message"

    if [[ -s $(get_template "rear.help") ]]; then
        cp $v $(get_template "rear.help") "$BOOT_DIR/rear.help" >&2
        echo "F2 rear.help"
        echo "say F2 - Show help"
        syslinux_menu "TABMSG Press [Tab] to edit, [F2] for help, [F1] for version info"
    else
        syslinux_menu "TABMSG Press [Tab] to edit options and [F1] for version info"
    fi

    echo "timeout 300"
    echo "#noescape 1"
    syslinux_menu title $PRODUCT v$VERSION

    echo "say rear - Recover $HOSTNAME"
    echo "label rear"
    syslinux_menu "label ^Recover $HOSTNAME"
    syslinux_menu_help "Rescue image kernel $KERNEL_VERSION ${IPADDR:+on $IPADDR} $(date -R)" \
            "${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${BACKUP_URL:+BACKUP_URL=$BACKUP_URL}"
    echo "kernel kernel"
    echo "append initrd=$REAR_INITRD_FILENAME root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE"
    if [ "$ISO_DEFAULT" == "manual" ] ; then
        echo "default rear"
        syslinux_menu "default"
    fi
    echo ""

    echo "say rear - Recover $HOSTNAME"
    echo "label rear-automatic"
    syslinux_menu "label ^Automatic Recover $HOSTNAME"
    syslinux_menu_help "Rescue image kernel $KERNEL_VERSION ${IPADDR:+on $IPADDR} $(date -R)" \
            "${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${BACKUP_URL:+BACKUP_URL=$BACKUP_URL}"
    echo "kernel kernel"
    echo "append initrd=$REAR_INITRD_FILENAME root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE auto_recover $ISO_RECOVER_MODE"

    if [ "$ISO_DEFAULT" == "automatic" ] ; then
        echo "default rear-automatic"
        syslinux_menu "default"
        echo "timeout 50"
    fi
    echo ""

    syslinux_menu separator
    echo "label -"
    syslinux_menu "label Other actions"
    syslinux_menu "disable"
    echo ""

    if [[ "$FEATURE_SYSLINUX_MENU_HELP" && -r $(get_template "rear.help") ]]; then
        echo "label help"
        syslinux_menu "label ^Help for $PRODUCT"
        syslinux_menu_help "More information about Relax-and-Recover and the steps for recovering your system"
        syslinux_menu "help rear.help"
    fi

    # Use chain booting for booting disk, if chain.c32 is available
    if [[ -r "$SYSLINUX_DIR/chain.c32" ]]; then
        cp $v "$SYSLINUX_DIR/chain.c32" "$BOOT_DIR/chain.c32" >&2

        echo "say boothd0 - boot first local disk"
        echo "label boothd0"
        syslinux_menu "label Boot First ^Local disk (hd0)"
        if [[ "$flavour" == "isolinux" ]] && [ "$ISO_DEFAULT" == "boothd" ] ; then
            # for isolinux local boot means boot from first disk
            echo "default boothd0"
            syslinux_menu "default"
        fi
        if test "boothd0" = "$ISO_DEFAULT" ; then
            # the user has explicitly specified to boot via boothd0 by default
            echo "default boothd0"
            syslinux_menu "default"
        fi
        echo "kernel chain.c32"
        echo "append hd0"
        echo ""

        echo "say boothd1 - boot second local disk"
        echo "label boothd1"
        syslinux_menu "label Boot ^Second Local disk (hd1)"
        if [[ "$flavour" == "extlinux" ]] && [ "$ISO_DEFAULT" == "boothd" ]; then
            # for extlinux local boot means boot from second disk because the boot disk became the first disk
            # which usually allows us to access the original first disk as second disk
            echo "default boothd1"
            syslinux_menu "default"
        fi
        if test "boothd1" = "$ISO_DEFAULT" ; then
            # the user has explicitly specified to boot via boothd1 by default
            echo "default boothd1"
            syslinux_menu "default"
        fi
        echo "kernel chain.c32"
        echo "append hd1"
        echo ""

    fi

    if [[ "$flavour" != "extlinux" || "$FEATURE_SYSLINUX_EXTLINUX_WITH_LOCALBOOT" ]]; then
        # localboot is a isolinux and pxelinux feature only, see http://syslinux.zytor.com/wiki/index.php/SYSLINUX#LOCALBOOT_type_.5BISOLINUX.2C_PXELINUX.5D
        # but extlinux >= 3.70 actually also supports localboot, see http://syslinux.zytor.com/wiki/index.php/Syslinux_3_Changelog#Changes_in_3.70

        if [[ ! -r "$SYSLINUX_DIR/chain.c32" ]]; then
            # this should be above under the if chain.c32 section but it comes here because it will work only if localboot is supported
            # if you use old extlinux then you just cannot boot from other device unless chain.c32 is available :-(
            echo "say boot80 - Boot from first BIOS disk 0x80"
            echo "label boot80"
            syslinux_menu "label Boot First ^Local BIOS disk (0x80)"
            if [[ "$flavour" == "isolinux" ]]; then
                # for isolinux local boot means boot from first disk
                echo "default boot80"
                syslinux_menu default
            fi
            echo "localboot 0x80"
            echo
            echo "say boot81 - Boot from second BIOS disk 0x81"
            echo "label boot81"
            syslinux_menu "label Boot Second ^Local BIOS disk (0x81)"
            if [[ "$flavour" == "extlinux" ]]; then
                # for extlinux local boot means boot from second disk because the boot disk became the first disk
                # which usually allows us to access the original first disk as second disk
                echo "default boot81"
                syslinux_menu default
            fi
            echo "localboot 0x81"
            echo ""
        fi

        echo "say local - Boot from next boot device"
        echo "label local"
        syslinux_menu "label Boot ^Next device"
        syslinux_menu_help "Boot from the next device in the BIOS boot order list."
        if [[ "$flavour" == "pxelinux" ]]; then
            echo "localboot 0"
        else
            # iso/extlinux support -1 for try next boot device
            echo "localboot -1"
        fi
        echo ""
    fi

    # Add needed libraries for syslinux v5 and hdt
    if [[ -r "$SYSLINUX_DIR/ldlinux.c32" ]]; then
        cp $v "$SYSLINUX_DIR/ldlinux.c32" "$BOOT_DIR/ldlinux.c32" >&2
    fi
    if [[ -r "$SYSLINUX_DIR/libcom32.c32" ]]; then
        cp $v "$SYSLINUX_DIR/libcom32.c32" "$BOOT_DIR/libcom32.c32" >&2
    fi
    if [[ -r "$SYSLINUX_DIR/libgpl.c32" ]]; then
        cp $v "$SYSLINUX_DIR/libgpl.c32" "$BOOT_DIR/libgpl.c32" >&2
    fi
    if [[ -r "$SYSLINUX_DIR/libmenu.c32" ]]; then
        cp $v "$SYSLINUX_DIR/libmenu.c32" "$BOOT_DIR/libmenu.c32" >&2
    fi
    if [[ -r "$SYSLINUX_DIR/libutil.c32" ]]; then
        cp $v "$SYSLINUX_DIR/libutil.c32" "$BOOT_DIR/libutil.c32" >&2
    fi
    if [[ -r "$SYSLINUX_DIR/vesamenu.c32" ]]; then
        cp $v "$SYSLINUX_DIR/vesamenu.c32" "$BOOT_DIR/vesamenu.c32" >&2
    fi

    if [[ -r "$SYSLINUX_DIR/hdt.c32" ]]; then
        cp $v "$SYSLINUX_DIR/hdt.c32" "$BOOT_DIR/hdt.c32" >&2
        if [[ -r "/usr/share/hwdata/pci.ids" ]]; then
            cp $v "/usr/share/hwdata/pci.ids" "$BOOT_DIR/pci.ids" >&2
        elif [[ -r "/usr/share/pci.ids" ]]; then
            cp $v "/usr/share/pci.ids" "$BOOT_DIR/pci.ids" >&2
        fi
        if [[ -r "/lib/modules/$KERNEL_VERSION/modules.pcimap" ]]; then
            cp $v "/lib/modules/$KERNEL_VERSION/modules.pcimap" "$BOOT_DIR/modules.pcimap" >&2
        fi
        echo "say hdt - Hardware Detection Tool"
        echo "label hdt"
        syslinux_menu "label ^Hardware Detection Tool"
        syslinux_menu_help "Information about your current hardware configuration"
        echo "kernel hdt.c32"
        echo ""
    fi

    # Because usr/sbin/rear sets 'shopt -s nullglob' the 'ls' command will list all files
    # in the current working directory if nothing matches the globbing pattern '/boot/memtest86+-*'
    # which results '.' in MEMTEST_BIN (the plain 'ls -d' output in the current working directory).
    # You need the memtest86+ package installed for this to work
    MEMTEST_BIN=$(ls -d /boot/memtest86+-* 2>/dev/null | tail -1)
    if [[ "$MEMTEST_BIN" != "." && -r "$MEMTEST_BIN" ]]; then
        cp $v "$MEMTEST_BIN" "$BOOT_DIR/memtest" >&2
        echo "memtest - Run memtest86+"
        echo "label memtest"
        syslinux_menu "label ^Memory test"
        syslinux_menu_help "Test your memory for problems with memtest86+"
        echo "kernel memtest"
        echo "append -"
        echo ""
    fi

    if [[ -r "$SYSLINUX_DIR/reboot.c32" ]] ; then
        cp $v "$SYSLINUX_DIR/reboot.c32" "$BOOT_DIR/reboot.c32" >&2
        echo "say reboot - Reboot the system"
        echo "label reboot"
        syslinux_menu "label Re^Boot system"
        syslinux_menu_help "Reboot the system now"
        echo "kernel reboot.c32"
        echo ""
    fi

    local prog=
    if [[ -r "$SYSLINUX_DIR/poweroff.com" ]] ; then
        prog="$SYSLINUX_DIR/poweroff.com"
    elif [[ -r "$SYSLINUX_DIR/poweroff.c32" ]] ; then
        prog="$SYSLINUX_DIR/poweroff.c32"
    fi

    if [[ -n "$prog" ]] ; then
        cp $v "$prog" "$BOOT_DIR/" >&2
        echo "say poweroff - Poweroff the system"
        echo "label poweroff"
        syslinux_menu "label ^Power off system"
        syslinux_menu_help "Power off the system now"
        echo "kernel $(basename "$prog")"
        echo ""
    fi

    if [[ -r "$SYSLINUX_DIR/menu.c32" ]]; then
        echo "default menu.c32"
    fi
}

# Create configuration file for elilo
function create_ebiso_elilo_conf {
cat << EOF
timeout = 5
default = "Relax-and-Recover (no Secure Boot)"

image = kernel
    label = "Relax-and-Recover (no Secure Boot)"
    initrd = $REAR_INITRD_FILENAME
EOF
    [[ -n $KERNEL_CMDLINE ]] && cat << EOF
    append = "$KERNEL_CMDLINE"
EOF
}

function get_root_disk_UUID {
    # SLES12 SP1 boot throw kernel panic without root= set
    # cf. https://github.com/rear/rear/commit/b81693f27a41482ed89da36a9af664fe808f8186
    # Use grep ' on / ' with explicitly specified spaces as separators instead of
    # grep -w 'on /' because on SLES with btrfs and snapper the latter results two matches
    #   # mount | grep -w 'on /'
    #   /dev/sda2 on / type btrfs (rw,relatime,space_cache,subvolid=267,subvol=/@/.snapshots/1/snapshot)
    #   /dev/sda2 on /.snapshots type btrfs (rw,relatime,space_cache,subvolid=266,subvol=/@/.snapshots)
    # because /.snapshots is one word for grep -w and then those two matches result
    # two same UUIDs (with newline) that end up (with newline) in the boot menuentry
    # cf. https://github.com/rear/rear/issues/1871
    echo $(mount | grep ' on / ' | awk '{print $1}' | xargs blkid -s UUID -o value)
}

function create_grub2_serial_entry {
    # Enable serial console, unless explicitly disabled
    # Note: as for syslinux it may be usefull to reduce it to exact one device since the last 'serial' line wins in grub...
    if [[ "$USE_SERIAL_CONSOLE" =~ ^[yY1] ]]; then
        for devnode in $(ls /dev/ttyS[0-9]* | sort); do
            speed=$(stty -F $devnode 2>/dev/null | awk '/^speed / { print $2 }')
            if [ "$speed" ]; then
                echo "serial --speed=$speed --unit=${devnode##/dev/ttyS} --word=8 --parity=no --stop=1"
                # use the first one found - ignore the rest or the last 'serial' line will win
                break
            fi
        done
        if is_true $GRUB_FORCE_SERIAL ; then
            cat << EOF
terminal_input serial
terminal_output serial
EOF
        fi
    fi
}

function create_grub2_rear_boot_entry {
    if is_true $USING_UEFI_BOOTLOADER ; then
        cat << EOF
menuentry "Relax-and-Recover (no Secure Boot)"  --class gnu-linux --class gnu --class os {
    insmod gzio
    echo 'Loading kernel ...'
    linux $esp_kernel root=UUID=$root_uuid $KERNEL_CMDLINE
    echo 'Loading initial ramdisk ...'
    initrd $esp_initrd
}

menuentry "Relax-and-Recover (Secure Boot)"  --class gnu-linux --class gnu --class os {
    insmod gzio
    echo 'Loading kernel ...'
    linuxefi $esp_kernel root=UUID=$root_uuid $KERNEL_CMDLINE
    echo 'Loading initial ramdisk ...'
    initrdefi $esp_initrd
}
EOF
    else
        cat << EOF
menuentry "Relax-and-Recover (no Secure Boot)"  --class gnu-linux --class gnu --class os {
    insmod gzio
    echo 'Loading kernel ...'
    linux $esp_kernel root=UUID=$root_uuid $KERNEL_CMDLINE
    echo 'Loading initial ramdisk ...'
    initrd $esp_initrd
}
EOF
    fi
}

function create_grub2_boot_next_entry {
    if is_true $USING_UEFI_BOOTLOADER ; then
        # search next EFI and chainload it
        cat << EOF
menuentry "Boot original system" {
    insmod chain
    search --fs-uuid --no-floppy --set=esp $esp_disk_uuid
    chainloader (\$esp)$esp_relative_bootloader
}
EOF
    else
        # just try booting from next disk
        cat << EOF
menuentry "Boot next disk" {
    insmod chain
    set root=(hd1)
    chainloader +1
}
EOF
    fi
}

function create_grub2_reboot_entry {
    cat << EOF
menuentry "Reboot" {
     reboot
}
EOF
}

function create_grub2_exit_entry {
    if is_true $USING_UEFI_BOOTLOADER ; then 
        cat << EOF
menuentry "Exit to EFI Shell" {
     exit
}
EOF
    else
        cat << EOF
menuentry "Exit to continue bootchain" {
     exit
}
EOF
    fi
}

# Create configuration grub
function create_grub2_cfg {
    root_uuid=$(get_root_disk_UUID)

    local esp_kernel="$1"
    local esp_initrd="$2"

    test $esp_kernel || esp_kernel="/isolinux/kernel"
    test $esp_initrd || esp_initrd="/isolinux/$REAR_INITRD_FILENAME"

    cat << EOF
${grub2_set_root:+"set root=$grub2_set_root"}
set default="$GRUB2_DEFAULT_BOOT"

insmod all_video

set gfxpayload=keep

insmod part_gpt
insmod part_msdos
insmod ext2

set timeout=5

$(create_grub2_serial_entry)

search --no-floppy --file /boot/efiboot.img --set
$grub2_set_usb_root

$(create_grub2_rear_boot_entry)

$(create_grub2_boot_next_entry)

$(create_grub2_reboot_entry)

$(create_grub2_exit_entry)
EOF
}

function make_pxelinux_config {
    # we use this function in case we are using $PXE_CONFIG_URL style of configuration
    echo "timeout 300"
    case "$PXE_RECOVER_MODE" in
        "automatic"|"unattended" ) echo "prompt 0" ;;
        * ) # manual mode
            echo "prompt 1"
            echo "say ENTER - boot next local device"
            echo "say --------------------------------------------------------------------------------" ;;
    esac
    # Display MENU title first
    echo "MENU title Relax-and-Recover v$VERSION"

    # Display message now:
    echo "display $PXE_MESSAGE"
    echo "say ----------------------------------------------------------"

    # start with rear entry
    case "$PXE_RECOVER_MODE" in
        "automatic")
            echo "say rear-automatic - Recover $HOSTNAME with auto-recover kernel option"
            echo "label rear-automatic"
            echo "MENU label ^Automatic Recover $HOSTNAME"
            ;;
        "unattended")
            echo "say rear-unattended - Recover $HOSTNAME with unattended kernel option"
            echo "label rear-unattended"
            echo "MENU label ^Unattended Recover $HOSTNAME"
            ;;
        *)
            echo "say rear - Recover $HOSTNAME"
            echo "label rear"
            echo "MENU label ^Recover $HOSTNAME"
            ;;
    esac
    echo "TEXT HELP"
    echo "Rescue image kernel $KERNEL_VERSION ${IPADDR:+on $IPADDR} $(date -R)"
    echo "${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${BACKUP_URL:+BACKUP_URL=$BACKUP_URL}"
    echo "ENDTEXT"
    echo "    kernel $PXE_KERNEL"
    echo "    append initrd=$PXE_INITRD root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE $PXE_RECOVER_MODE"
    echo "say ----------------------------------------------------------"

    # start the the other entries like local,...
    echo "say local - Boot from next boot device"
    echo "label local"
    echo "MENU label Boot ^Next device"
    echo "TEXT HELP"
    echo "Boot from the next device in the BIOS boot order list."
    echo "ENDTEXT"
    echo "localboot -1"
    echo "say ----------------------------------------------------------"
    if [[ -f $syslinux_modules_dir/chain.c32 ]] ; then
        echo "say boothd0 - boot first local disk"
        echo "label boothd0"
        echo "MENU label Boot First ^Local disk (hd0)"
        echo "kernel chain.c32"
        echo "append hd0"
        echo "say ----------------------------------------------------------"
        echo "say boothd1 - boot second local disk"
        echo "label boothd1"
        echo "MENU label Boot ^Second Local disk (hd1)"
        echo "kernel chain.c32"
        echo "append hd1"
        echo "say ----------------------------------------------------------"
    fi
    if [[ -f $syslinux_modules_dir/hdt.c32 ]] ; then
        echo "say hdt - Hardware Detection Tool"
        echo "label hdt"
        echo "MENU label ^Hardware Detection Tool"
        echo "TEXT HELP"
        echo "Information about your current hardware configuration"
        echo "ENDTEXT"
        echo "kernel hdt.c32"
        echo "say ----------------------------------------------------------"
    fi
    if [[ -f $syslinux_modules_dir/reboot.c32 ]] ; then
        echo "say reboot - Reboot the system"
        echo "label reboot"
        echo "MENU label Re^Boot system"
        echo "TEXT HELP"
        echo "Reboot the system now"
        echo "ENDTEXT"
        echo "kernel reboot.c32"
        echo "say ----------------------------------------------------------"
    fi
    local prog=
    if [[ -r "$syslinux_modules_dir/poweroff.com" ]] ; then
        prog="$syslinux_modules_dir/poweroff.com"
    elif [[ -r "$syslinux_modules_dir/poweroff.c32" ]] ; then
        prog="$syslinux_modules_dir/poweroff.c32"
    fi
    if [[ -n "$prog" ]] ; then
        echo "say poweroff - Poweroff the system"
        echo "label poweroff"
        echo "MENU label ^Power off system"
        echo "TEXT HELP"
        echo "Power off the system now"
        echo "ENDTEXT"
        echo "kernel $(basename "$prog")"
    fi

    # And, finally define the default entry to boot off
    case "$PXE_RECOVER_MODE" in
        "automatic") echo "default rear-automatic" ;;
        "unattended") echo "default rear-unattended" ;;
        "boothd") echo "default boothd0" ;;
        *) echo "default local" ;;
    esac
    # end of function make_pxelinux_config
}

function make_pxelinux_config_grub {
    net_default_server_opt=""

    # Be sure that TFTP Server IP is set with TFTP_SERVER_IP Variable.
    # else set it based on PXE_TFTP_UR variable.
    if [[ -z $PXE_TFTP_IP ]] ; then
        if [[ -z $PXE_TFTP_URL ]] ; then
            LogPrintError "Can't find TFTP IP information. Variable TFTP_SERVER_IP or PXE_TFTP_URL with clear IP address must be set."
            return
        else
            # Get IP address from PXE_TFTP_URL (ex:http://xx.yy.zz.aa:port/foo/bar)
            PXE_TFTP_IP=$(echo "$PXE_TFTP_URL" | awk -F'[/:]' '{ print $4 }')

            # If PXE_TFTP_IP is not an IP, it could be a FQDM that must be resolved to IP.
            # is_ip() function is defined in network-function.sh
            if ! is_ip $PXE_TFTP_IP ; then
                Log "Trying to resolve [$PXE_TFTP_IP] to a valid IP."
                # get_ip_from_fqdn() function is defined in network-function.sh
                PXE_TFTP_IP=$(get_ip_from_fqdn $PXE_TFTP_IP)
            fi
        fi
    fi

    # If PXE_TFTP_IP is a valid IP, set `net_default_server_opt` grub2 option.
    if  is_ip $PXE_TFTP_IP ; then
        LogPrint "Using $PXE_TFTP_IP as boot/tftp server IP."
        net_default_server_opt="set net_default_server=$PXE_TFTP_IP"
    else
        LogPrintError "No valid TFTP IP found. Please update your ReaR configuration file with PXE_TFTP_IP."
        return
    fi

    # we use this function only when $PXE_CONFIG_URL is set and $PXE_CONFIG_GRUB_STYLE=y
    # TODO First Draft. Need to complete with all other options (see make_pxelinux_config).
    echo "menuentry 'Relax-and-Recover v$VERSION' {"
    echo "insmod tftp"
    echo "$net_default_server_opt"
    echo "echo 'Network status: '"
    echo "net_ls_cards"
    echo "net_ls_addr"
    echo "net_ls_routes"
    echo "echo"
    echo "echo \" Relax-and-Recover Rescue image\""
    echo "echo \"---------------------------------\""
    echo "echo \"build from host: $HOSTNAME ($OS_VENDOR $OS_VERSION $ARCH)\""
    echo "echo \"kernel $KERNEL_VERSION ${IPADDR:+on $IPADDR} $(date -R)\""
    echo "echo \"${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${BACKUP_URL:+BACKUP_URL=$BACKUP_URL}\""
    echo "echo"
    echo "echo 'Loading kernel ...'"
    echo "linux (tftp)/$PXE_KERNEL root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE $PXE_RECOVER_MODE"
    echo "echo 'Loading initial ramdisk ...'"
    echo "initrd (tftp)/$PXE_INITRD"
    echo "}"
}

# vim: set et ts=4 sw=4
