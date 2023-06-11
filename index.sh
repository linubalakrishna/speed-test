# Powered by: FLYTXT Mobile Solutions
# @Author: Linumon B
# @Email: linumon.b@flytxt.com

# This is to automate 2 functionalities - network speed test and disk speed test
# Network speed test will accept the inputs "password" and "remote hostname" and calculate speed between the servers and provide the results as satisfied or dissatisfied value
# Disk speed test will accept the the inputs "disk name/mount point" and provide the result as satisfied or dissatisfied value
#!/bin/bash
#Global variables declaration
FREE_PORT=''
BLUE='\x1b[34m'
RED='\x1b[31m'
BOLD='\x1b[1m'
IP=$(hostname -i)
WHITE='\x1b[37m'
PACKAGES="iperf3"
ISPACKAGEINSTALLED=0
USERNAMES=$(whoami)

# The "GetAvailablePort" function used to find out the free port from the range 8250-8275
GetAvailablePort() {
    for port in {8250..8275}; do
        if [ -z "$(sudo netstat -tupln | grep -w $port)" ]; then
            FREE_PORT=$port
            return
        fi
    done
}

# This is "ConnectTo" function which is used by another function "SpeedTest" to perform iperf3 commands locally and remotely.
# This function asks remote hostname and password and it should be provided by the client
ConnectTo() {
    echo -e "$BLUE $BOLD Please enter the hostname \x1b[m"
    # read hostname
    hostname="model-node2" # remove#1    
    SCR="mkdir -p /home/$USERNAMES/disk_speed; iperf3 -c $IP -p $FREE_PORT -n 1G 1>/home/$USERNAMES/disk_speed/test"
    mkdir -p /home/$USERNAMES/disk_speed
    # ssh dxadmin@model-node2 '( whoami > /home/dxadmin/test)'
    # scp dxadmin@model-node2:/home/dxadmin/test /home/$USERNAMES/passwd
    # cat /home/$USERNAMES/passwd
    # exit
    #sudo should be used in the following command if the user is not "root"
    (iperf3 -s -p $FREE_PORT &>/dev/null) &
    ssh -l ${USERNAMES} ${hostname} "${SCR}"
    scp $USERNAMES@$hostname:/home/$USERNAMES/disk_speed/test /home/$USERNAMES/disk_speed/test1
    if [ -n "$(sudo cat /home/$USERNAMES/disk_speed/test1 | grep 'Could not resolve')" ]; then
        echo "You have provided invalid hostname."
        exit
    fi

    speed_per_sec=$(sudo cat /home/$USERNAMES/disk_speed/test1 | grep 'sender' | grep 'Gbits/sec\|Mbits/sec' | awk {'print $7'})
    if [ -z $speed_per_sec ]; then
        echo "Something went wrong!!"
        exit
    fi

    type=$(sudo cat /home/$USERNAMES/disk_speed/test1 | grep 'sender' | grep 'Gbits/sec\|Mbits/sec' | awk {'print $8'})
    if [ "${speed_per_sec%.*}" -ge 6 ]; then
        echo -e "Network speed is $BLUE $BOLD $speed_per_sec $type and satisfying the condition$WHITE"
    else
        echo -e "Network speed is $RED $BOLD $speed_per_sec $type and not satisfying the condition$WHITE"
    fi
    # delete disk_speed folder from remote server
    ssh -l ${USERNAMES} ${hostname} "rm -rf /home/$USERNAMES/disk_speed" &>/dev/null
    sudo rm -rf /home/$USERNAMES/disk_speed &>/dev/null
    (netstat -tulpn | grep iperf3 | awk {'print $7'} | cut -d "/" -f1 | xargs kill -9) &>/dev/null
}

# The "SpeedTest" function is for checking the network-speed between the servers.
# It calls "GetAvailablePort" function to find out the available port from 8250-8275. If the result is null, the program will ask to enter a free port manually.
# If there is it will call the function "ConnectTo" and then call the fuction "DisplayOptionAgain"
SpeedTest() {
    GetAvailablePort
    if [ -z "$FREE_PORT" ]; then
        echo -e "$RED No port is free. Please provide the port number$WHITE"
        read FREE_PORT
    fi
    ConnectTo
    DisplayOptionAgain
}
# This is "DiskSpeed" function to test disk speed
# Files created by this function will be removed at the end
# Once this function executed, it will call "DisplayOptionAgain" to ask whether the client would like to proceed any test again
DiskSpeed() {
    echo "Enter the mount point name"
    read mount_point
    echo "We are calculating the disk speed. Please be patient!!"

    sudo mkdir -p /$mount_point/disk_speed
    sudo dd if=/dev/zero of=/$mount_point/disk_speed/test-1G bs=1M count=1000 conv=fsync 2>/home/$USERNAMES/disk_speed_out
    speed_per_sec=$(sudo cat /home/$USERNAMES/disk_speed_out | grep 'GB\|MB' | awk {'print $8'})
    speed_type=$(sudo cat /home/$USERNAMES/disk_speed_out | grep 'GB\|MB' | awk {'print $9'})
    if [ $speed_type == "MB/s" ]; then
        if [ "${speed_per_sec%.*}" -ge 175 ]; then
            echo -e "Disk Writing speed is $BLUE $BOLD $speed_per_sec $speed_type and satisfying the condition$WHITE"
        else
            echo -e "Disk Writing speed is $RED $BOLD $speed_per_sec $speed_type and not satisfying the condition$WHITE"
        fi
    elif [ $speed_type == "GB/s" ]; then
        echo -e "Disk Writing speed is $BLUE $BOLD $speed_per_sec $speed_type and satisfying the condition$WHITE"
    else
        echo -e "Disk Writing speed is $speed_per_sec $speed_type and not satisfying the condition$WHITE"
    fi

    # sudo rm -v /$mount_point/disk_speed/test-1G &>/dev/null
    # sudo rm -v /$mount_point/disk_speed/out &>/dev/null
    DisplayOptionAgain
}

# The "DisplayOptionAgain" is used to ask whether the client proceed with any test further.
# If the client wants to proceed further, it will call the "ReadOption" fuction, otherwise exit.
DisplayOptionAgain() {
    echo "Do you wanna continue any speed test Y/N?"
    read option
    if [[ $option == "Y" || $option == "y" ]]; then
        ReadOption
    else
        echo "Thank you!!"
        exit
    fi
}

PrintWelcomeMessage() {
    echo "#################################################"
    echo "#                                               #"
    if [ -z $2 ]; then
        echo -e "#        $BLUE Welcome to $1$WHITE         #"
    else
        echo -e "#        $BLUE Welcome to $1$WHITE            #"
    fi
    echo "#                                               #"
    echo "#################################################"
}

checkForPackage() {
    if rpm -qa | grep -i "${1}" 1>/dev/null 2>&1; then
        return 0 # package is installed
    else
        return 1 # package is not installed.
    fi
}

CheckPackage() {

    for package in $PACKAGES; do
        if checkForPackage "$package"; then
            echo -e "$BLUE $package package is installed$WHITE"
        else
            echo -e "$RED $package package is not installed, Contact TAC team$WHITE"
            ISPACKAGEINSTALLED=1
        fi
    done
}
# Asking client to enter the option that he wants to perform
# "read -d" option is used to set of lines to print as we can't use "echo" to print a block of messages
# Based on the option that client chose, calling the function "SpeedTest" or "DiskSpeed"
ReadOption() {
    CheckPackage
    if [[ "$ISPACKAGEINSTALLED" == 1 ]]; then
        exit
    fi

    read -d '' option_message <<"BLOCK"
Please select the option to automate
1. Network Speed test
2. Disk Speed
3. Exit
BLOCK

    echo "$option_message"
    read option
    case "$option" in
    "1")
        PrintWelcomeMessage "Network Speed Test"
        SpeedTest
        ;;
    "2")
        PrintWelcomeMessage "Disk Speed Test" "true"
        DiskSpeed
        ;;
    "3")
        exit
        ;;
    esac
}

ReadOption
