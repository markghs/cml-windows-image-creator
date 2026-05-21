#!/bin/bash
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_menu() {
    clear
    echo -e "${CYAN}##################################################################################${NC}"
    echo -e "${CYAN}#${GREEN}    _____ __  __ _       __           ___           _                           ${CYAN}#"
    echo -e "${CYAN}#${GREEN}   / ____|  \\/  | |      \\ \\         / (_)         | |                          ${CYAN}#"
    echo -e "${CYAN}#${GREEN}  | |    | \\  / | |       \\ \\  /\\  / / _ _ __   __| | _____      _____          ${CYAN}#"
    echo -e "${CYAN}#${GREEN}  | |    | |\\/| | |        \\ \\/  \\/ / | | '_ \\ / _\` |/ _ \\ \\ /\\ / / __|         ${CYAN}#"
    echo -e "${CYAN}#${GREEN}  | |____| |  | | |____     \\  /\\  /  | | | | | (_| | (_) \\ V  V /\\__ \\         ${CYAN}#"
    echo -e "${CYAN}#${GREEN}   \\_____|_|  |_|______|     \\/  \\/   |_|_|_|_|\\__,_|\\___/ \\_/\\_/ |___/         ${CYAN}#"
    echo -e "${CYAN}#${GREEN}  |_  _|                             / ____|              | |                   ${CYAN}#"
    echo -e "${CYAN}#${GREEN}    | |  _ __ ___   __ _  __ _  ___  | |      _ _____ __ _| |_ ___  _ __        ${CYAN}#"
    echo -e "${CYAN}#${GREEN}    | | | '_ \` _ \\ / _\` |/ _\` |/ _ \\ | |    | '__/ _ \\/ _\` | __/ _ \\| '__|      ${CYAN}#"
    echo -e "${CYAN}#${GREEN}   _| |_| | | | | | (_| | (_| |  __/ | |____| | |  __/ (_| | || (_) | |         ${CYAN}#"
    echo -e "${CYAN}#${GREEN}  |_____|_| |_| |_|\\__,_|\\__, |\\___|  \\_____|_|  \\___|\\__,_|\\__\\___/|_|         ${CYAN}#"
    echo -e "${CYAN}#${GREEN}                         __/ |                                                  ${CYAN}#"
    echo -e "${CYAN}#${GREEN}                        |___/                                                   ${CYAN}#"
    
    echo -e "${CYAN}##################################################################################${NC}"
    
    echo
    echo -e "${GREEN}Please select an option:${NC}"
    echo -e "  1) Create Windows 11 image"
    echo -e "  2) Create Windows Server 2025 image"
    echo -e "  3) Test Connection to CML API"
    echo -e "  4) Exit"
    echo
}

while true; do

   print_menu
   read -p "Enter your choice [1-4]: " choice

case $choice in
    1)
        
        echo "Enter the username and password for the CML API"
        read -p "Enter username: " username
        read -s -p "Enter password: " password
        echo

        # Authenticate and capture both API key and HTTP status code
        auth_response=$(mktemp)
        http_code=$(curl -k -X 'POST' \
        'https://localhost/api/v0/authenticate' \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -d '{
        "username": "'"$username"'",
        "password": "'"$password"'"
        }' \
        -w "%{http_code}" -o "$auth_response")

        # Check for authentication error in response (403)
        if grep -q '"code":403' "$auth_response"; then
        echo -e "\nAuthentication failed: Forbidden (403). You do not have permission to access this resource. Please check username and password."
        cat "$auth_response"
        rm -f "$auth_response"
        exit 1
        fi

        # Extract API key using tr -d '\r\n' | xargs (assumes response is just the key or a simple string)
        api_key=$(cat "$auth_response" | tr -d '\r\n' | xargs)
        if [[ -z "$api_key" || "$api_key" == *code* ]]; then
        echo -e "\nAuthentication failed: No valid API key received."
        cat "$auth_response"
        rm -f "$auth_response"
        exit 1
        fi
        rm -f "$auth_response"

        echo "API key captured"

        ISO_NAME="/var/tmp/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso"
        if [[ -f "$ISO_NAME" ]]; then
            echo "ISO file '$ISO_NAME' is present."
        else
            echo "ISO file '$ISO_NAME' is NOT present going to download it."
            wget --content-disposition -P /var/tmp/ "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso"
        fi
        echo "Windows 11 ISO download script completed."

        echo "Creating ISO image..."
        echo "This may take a few minutes. Please wait..."
        WINDOWS_ISO="/var/tmp/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso"
        mkdir /mnt/windowsiso
        mount -o loop $WINDOWS_ISO /mnt/windowsiso
        mkdir /var/tmp/WindowsISO_Files
        cp -vR /mnt/windowsiso/ /var/tmp/WindowsISO_Files/

        mkdir -p "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/System32/Sysprep"
        mkdir -p "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/Setup/Scripts"

        cp Windows_11/autounattend.xml /var/tmp/WindowsISO_Files/windowsiso/
        cp Windows_11/unattend.xml "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/System32/Sysprep/"
        cp Windows_11/SetupComplete.cmd "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/Setup/Scripts/"

        umount /mnt/windowsiso
        rmdir /mnt/windowsiso

        mkisofs \
            -v \
            -udf \
            -iso-level 3 \
            -eltorito-platform=x86 \
            -eltorito-boot boot/etfsboot.com \
            -no-emul-boot \
            -boot-load-seg 0x07C0 \
            -boot-load-size 8 \
            -eltorito-alt-boot \
            -eltorito-platform=efi \
            -eltorito-boot efi/microsoft/boot/efisys.bin \
            -no-emul-boot \
            -J \
            -l \
            -D \
            -N \
            -joliet-long \
            -allow-limited-size \
            -V "WIN_11" \
            -o /var/tmp/WIN11_IMG.iso \
            /var/tmp/WindowsISO_Files/windowsiso/
            
        echo "ISO image created: /var/tmp/WIN11_IMG.iso"
        FILE="/var/tmp/WIN11_IMG.iso"
        size_bytes=$(stat -c%s "$FILE")
        size_mb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1024/1024}")
        echo "File size: $size_mb MB"
        rm -rf /var/tmp/WindowsISO_Files/
        echo "ISO creation process completed."

        ISO="/var/tmp/WIN11_IMG.iso"
        MEMORY="8G"
        CPUS=4
        CPU_FLAGS="Westmere,-waitpkg,-hle,-rtm,-mpx"

        # === no change needed ===
        DISK="/var/tmp/WIN11_IMG.qcow2"
        DISK_SIZE="160G"


        # === Create disk if it doesn't exist ===
        if [ ! -f "$DISK" ]; then
            echo "Creating disk image..."
            qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
        fi

        echo "#######################################################"
        echo "#   Creating VM this may take several minutes         #"
        echo "#######################################################"

        # === Launch VM ===
        sudo /usr/bin/qemu-system-x86_64 \
            -name WIN11_IMG_MBR \
            -machine type=q35,accel=kvm \
            -cpu $CPU_FLAGS \
            -smp $CPUS \
            -m $MEMORY \
            -drive file="$DISK",format=qcow2,if=none,id=disk0 \
            -device ahci,id=ahci -device ide-hd,drive=disk0,bus=ahci.0 \
            -drive file="$ISO",media=cdrom,if=none,id=cdrom0 \
            -device ide-cd,drive=cdrom0,bootindex=1 \
            -netdev tap,id=net0,ifname=tap0,script=no,downscript=no \
            -device virtio-net-pci,netdev=net0 \
            -serial file:win11-serial.log \
            -device qxl-vga,ram_size=134217728,vram_size=67108864,vgamem_mb=64 \
            -vnc :1 

        curl -k -X 'POST' \
        'https://localhost/api/v0/node_definitions' \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $api_key" \
        -H 'Content-Type: application/json' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -d ' {"id":"WIN11_IMG","boot":{"timeout":600,"uses_regex":false},"sim":{"linux_native":{"libvirt_domain_driver":"kvm","driver":"server","disk_driver":"sata","efi_boot":false,"machine_type":"q35","ram":4096,"cpus":2,"cpu_limit":100,"nic_driver":"e1000","video":{"memory":128,"model":"vga"},"enable_rng":false,"enable_tpm":false}},"general":{"nature":"server","description":"WIN11_IMG","read_only":false},"configuration":{"generator":{"driver":"server"}},"device":{"interfaces":{"serial_ports":1,"physical":["eth0"],"has_loopback_zero":false}},"ui":{"label_prefix":"win11-img-","icon":"host","label":"WIN11_IMG","visible":true,"description":"WIN11_IMG"},"inherited":{"image":{"ram":true,"cpus":true,"data_volume":true,"boot_disk_size":true,"cpu_limit":true},"node":{"ram":true,"cpus":true,"data_volume":true,"boot_disk_size":true,"cpu_limit":true}},"schema_version":"0.0.1"}'
        
        curl -k -X 'GET' \
        'https://localhost/api/v0/node_definitions/WIN11_IMG?json=true' \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $api_key" \
        -H 'X-CML-CLIENT: SwaggerUI'

        curl --progress-bar -k -X 'POST' \
        'https://localhost/api/v0/images/upload' \
        -H 'accept: application/json' \
        -H 'x-original-file-name: WIN11_IMG.qcow2' \
        -H 'X-File-Name: WIN11_IMG.qcow2' \
        -H "Authorization: Bearer $api_key" \
        -H 'Content-Type: multipart/form-data' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -F 'file=@/var/tmp/WIN11_IMG.qcow2'

        curl -k -X 'POST' \
        'https://localhost/api/v0/image_definitions' \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $api_key" \
        -H 'Content-Type: application/json' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -d '{
        "description": "WIN11_IMG API",
        "disk_image": "WIN11_IMG.qcow2",
        "id": "WIN11_IMG",
        "label": "WIN11_IMG",
        "node_definition_id": "WIN11_IMG",
        "read_only": true,
        "schema_version": 0.0.1
        }'
        
        rm /var/tmp/WIN11_IMG.iso
        rm /var/tmp/WIN11_IMG.qcow2
        echo
        echo "#######################################################"
        echo "#       Windows 11 Image Creation Finished		    #"
        echo "#######################################################"
        break

        ;;

    2) 

        echo "Enter the username and password for the CML API"
        read -p "Enter username: " username
        read -s -p "Enter password: " password
        echo

        # Authenticate and capture both API key and HTTP status code
        auth_response=$(mktemp)
        http_code=$(curl -k -X 'POST' \
        'https://localhost/api/v0/authenticate' \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -d '{
        "username": "'"$username"'",
        "password": "'"$password"'"
        }' \
        -w "%{http_code}" -o "$auth_response")

        # Check for authentication error in response (403)
        if grep -q '"code":403' "$auth_response"; then
        echo -e "\nAuthentication failed: Forbidden (403). You do not have permission to access this resource. Please check username and password."
        cat "$auth_response"
        rm -f "$auth_response"
        exit 1
        fi

        # Extract API key using tr -d '\r\n' | xargs (assumes response is just the key or a simple string)
        api_key=$(cat "$auth_response" | tr -d '\r\n' | xargs)
        if [[ -z "$api_key" || "$api_key" == *code* ]]; then
        echo -e "\nAuthentication failed: No valid API key received."
        cat "$auth_response"
        rm -f "$auth_response"
        exit 1
        fi
        rm -f "$auth_response"

        echo "API key captured"    


        ISO_NAME="/var/tmp/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
        
        if [[ -f "$ISO_NAME" ]]; then
            echo "ISO file '$ISO_NAME' is present."
        else
            echo "ISO file '$ISO_NAME' is NOT present going to download it."
            wget --content-disposition -P /var/tmp/ "https://software-static.download.prss.microsoft.com/dbazure/998969d5-f34g-4e03-ac9d-1f9786c66749/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
        fi

        echo "Windows 11 ISO download script completed."
        
        
        echo "Windows Server ISO download script completed."

        echo "Creating ISO image..."
        echo "This may take a few minutes. Please wait..."
        WINDOWS_ISO="/var/tmp/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
        mkdir /mnt/windowsiso
        mount -o loop $WINDOWS_ISO /mnt/windowsiso
        mkdir /var/tmp/WindowsISO_Files
        cp -vR /mnt/windowsiso/ /var/tmp/WindowsISO_Files/

        mkdir -p "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/System32/Sysprep"
        mkdir -p "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/Setup/Scripts"


        cp Server_2025/autounattend.xml /var/tmp/WindowsISO_Files/windowsiso/
        cp Server_2025/unattend.xml "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/System32/Sysprep/"
        cp Server_2025/SetupComplete.cmd "/var/tmp/WindowsISO_Files/windowsiso/sources/\$OEM\$/\$\$/Setup/Scripts/"

        umount /mnt/windowsiso
        rmdir /mnt/windowsiso

        mkisofs \
            -v \
            -udf \
            -iso-level 3 \
            -eltorito-platform=x86 \
            -eltorito-boot boot/etfsboot.com \
            -no-emul-boot \
            -boot-load-seg 0x07C0 \
            -boot-load-size 8 \
            -eltorito-alt-boot \
            -eltorito-platform=efi \
            -eltorito-boot efi/microsoft/boot/efisys.bin \
            -no-emul-boot \
            -J \
            -l \
            -D \
            -N \
            -joliet-long \
            -allow-limited-size \
            -V "WIN_SERVER" \
            -o /var/tmp/WIN25_IMG.iso \
            /var/tmp/WindowsISO_Files/windowsiso/
            
        echo "ISO image created: /var/tmp/WIN25_IMG.iso"
        FILE="/var/tmp/WIN25_IMG.iso"
        size_bytes=$(stat -c%s "$FILE")
        size_mb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1024/1024}")
        echo "File size: $size_mb MB"
        rm -rf /var/tmp/WindowsISO_Files/
        echo "ISO creation process completed."

        ISO="/var/tmp/WIN25_IMG.iso"
        MEMORY="8G"
        CPUS=4
        CPU_FLAGS="Westmere,-waitpkg,-hle,-rtm,-mpx"

        # === no change needed ===
        DISK="/var/tmp/WIN25_IMG.qcow2"
        DISK_SIZE="160G"


        # === Create disk if it doesn't exist ===
        if [ ! -f "$DISK" ]; then
            echo "Creating disk image..."
            qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
        fi

        echo "#######################################################"
        echo "#   Creating VM this may take several minutes         #"
        echo "#######################################################"
        # === Launch VM ===
        sudo /usr/bin/qemu-system-x86_64 \
            -name WIN25_IMG_MBR \
            -machine type=q35,accel=kvm \
            -cpu $CPU_FLAGS \
            -smp $CPUS \
            -m $MEMORY \
            -drive file="$DISK",format=qcow2,if=none,id=disk0 \
            -device ahci,id=ahci -device ide-hd,drive=disk0,bus=ahci.0 \
            -drive file="$ISO",media=cdrom,if=none,id=cdrom0 \
            -device ide-cd,drive=cdrom0,bootindex=1 \
            -netdev tap,id=net0,ifname=tap0,script=no,downscript=no \
            -device virtio-net-pci,netdev=net0 \
            -serial file:win25-serial.log \
            -device qxl-vga,ram_size=134217728,vram_size=67108864,vgamem_mb=64 \
            -vnc :1 

        echo "API key captured"

        curl -k -X 'POST' \
        'https://localhost/api/v0/node_definitions' \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $api_key" \
        -H 'Content-Type: application/json' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -d ' {"id":"WIN25_IMG","boot":{"timeout":600,"uses_regex":false},"sim":{"linux_native":{"libvirt_domain_driver":"kvm","driver":"server","disk_driver":"sata","efi_boot":false,"machine_type":"q35","ram":4096,"cpus":2,"cpu_limit":100,"nic_driver":"e1000","video":{"memory":128,"model":"vga"},"enable_rng":false,"enable_tpm":false}},"general":{"nature":"server","description":"WIN25_IMG","read_only":false},"configuration":{"generator":{"driver":"server"}},"device":{"interfaces":{"serial_ports":1,"physical":["eth0"],"has_loopback_zero":false}},"ui":{"label_prefix":"win25-IMG-","icon":"server","label":"WIN25_IMG","visible":true,"description":"WIN25_IMG"},"inherited":{"image":{"ram":true,"cpus":true,"data_volume":true,"boot_disk_size":true,"cpu_limit":true},"node":{"ram":true,"cpus":true,"data_volume":true,"boot_disk_size":true,"cpu_limit":true}},"schema_version":"0.0.1"}'
        
        curl -k -X 'GET' \
        'https://localhost/api/v0/node_definitions/WIN25_IMG?json=true' \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $api_key" \
        -H 'X-CML-CLIENT: SwaggerUI'

        curl --progress-bar -k -X 'POST' \
        'https://localhost/api/v0/images/upload' \
        -H 'accept: application/json' \
        -H 'x-original-file-name: WIN25_IMG.qcow2' \
        -H 'X-File-Name: WIN25_IMG.qcow2' \
        -H "Authorization: Bearer $api_key" \
        -H 'Content-Type: multipart/form-data' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -F 'file=@/var/tmp/WIN25_IMG.qcow2'

        curl -k -X 'POST' \
        'https://localhost/api/v0/image_definitions' \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $api_key" \
        -H 'Content-Type: application/json' \
        -H 'X-CML-CLIENT: SwaggerUI' \
        -d '{
        "description": "WIN25_IMG",
        "disk_image": "WIN25_IMG.qcow2",
        "id": "WIN25_IMG",
        "label": "WIN25_IMG",
        "node_definition_id": "WIN25_IMG",
        "read_only": true,
        "schema_version": 0.0.1
        }'
        
        rm /var/tmp/WIN25_IMG.iso
        rm /var/tmp/WIN25_IMG.qcow2
        echo
        echo "#######################################################"
        echo "#         Server 2025 Image Creation Finished		    #"
        echo "#######################################################"
        break
        ;;
        3)
            echo "Enter the username and password for the CML API"
            read -p "Enter username: " username
            read -s -p "Enter password: " password
            echo

            # Authenticate and capture both API key and HTTP status code
            auth_response=$(mktemp)
            http_code=$(curl -k -X 'POST' \
            'https://localhost/api/v0/authenticate' \
            -H 'accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'X-CML-CLIENT: SwaggerUI' \
            -d '{
            "username": "'"$username"'",
            "password": "'"$password"'"
            }' \
            -w "%{http_code}" -o "$auth_response")

            # Check for authentication error in response (403)
            if grep -q '"code":403' "$auth_response"; then
            echo -e "\nAuthentication failed: Forbidden (403). You do not have permission to access this resource. Please check username and password."
            cat "$auth_response"
            rm -f "$auth_response"
            exit 1
            fi

            # Extract API key using tr -d '\r\n' | xargs (assumes response is just the key or a simple string)
            api_key=$(cat "$auth_response" | tr -d '\r\n' | xargs)
            if [[ -z "$api_key" || "$api_key" == *code* ]]; then
            echo -e "\nAuthentication failed: No valid API key received."
            cat "$auth_response"
            rm -f "$auth_response"
            exit 1
            fi
            rm -f "$auth_response"

            echo "Connection to CML API successful. API key captured."    
            echo
			break
            ;;
        4)
            echo "Exiting."
            break
            ;;
        *)
            echo "Invalid choice. Please select a valid option from the menu."
            echo
            break
            ;;
  esac
  echo
done
