#!/bin/bash

# ##################################################
# NAME:
#   Deploying Software for New MacOS Images
#
# Author: Manny
# Kudos to Axel Garcia
#
# Version:
#   3
#
# HISTORY:
#   9.21.2020 - Fully tested and functional
#   06.13.2022 - Applied to Shoprunner Manual Install
#
# Usage:
#   1) Change USBNAME to your USB's Name
#   2) Open Terminal then type "sudo sh " and drag and drop the script file to fill out the full path to the script
#   3) Prompt asking if you need to install WS1 will appear please select "Yes" or "No" this will tell the script to download or not to download Airwatch installer
#   4) A file named Druva.csv should show up in your USB drive, should be formatted to upload to Druva with all the info you need to activate it.
#
# Synopsis:
#   This script is to automate Naming convention setting, Druva deployment, and installing Airwatch, installing Zoom, and Moving GH Folder to User's desktop.
#   Log file is created in /var/log/ITstartup.log
#
# CAVEATS:
#   1) IF A Desktop Folder is required to exist on the root of the USB drive for the script to find it
#####Add the Desktop_folder from the root of USB to Login user's Desktop ##
# if [ -d "/Volumes/$USBNAME/GH" ]; then
#  LoggingTool "Adding Desktop_folder to Desktop"
#  cp -R "/Volumes/$USBNAME/GH" "/Users/$user/Desktop/Desktop_Folder"
# else
#  LoggingTool "-- Desktop_Folder IS NOT ON THE ROOT OF USBDRIVE --"
# fi
# ##################################################

#This is whatever your USB Device is called. CASE-SENSITIVE!
USBNAME="Untitled"

#log location
logfile="/var/log/SRInstall.log"
#Logging Tool
LoggingTool() {
  echo "${1}"
  echo "`date`: ${1}" >> ${logfile}
}

#Pull current login user
#LoggingTool "Setting up Computer Name"

#Get Current Login User Info
user=`ls -l /dev/console | awk '{print $3}'`


#IF Setting up Computer name is needed ###########################################################
#we need to get serial number of the machine
#Suffix=`sysctl hw.model | awk '{print $2}' | sed s/[0-9][0-9]\,[0-9]//`
#Prefix=$(id -P $(stat -f%Su /dev/console) | awk -F '[:]' '{print $8}')
#serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
#computerName="${Prefix} ${Suffix} - ${serial}"
#LoggingTool "Device Name should be set to: ${computerName}"

#Setting up computer Name
#scutil --set HostName "${computerName}"
#scutil --set LocalHostName "${computerName}"
#sleep 1
#scutil --set ComputerName "${computerName}"

#Echo "Done! Device Name was set to: ${computerName}"

#Rest for HostName to Set
#sleep 2


############################################################

#Installing Rosetta 2
sudo softwareupdate --install-rosetta --agree-to-license

sleep 5

#Zoom installer
LoggingTool "Installing Zoom"
Zoomfile="Zoom.pkg"
OSvers_URL=$( sw_vers -productVersion | sed 's/[.]/_/g' )
userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"
latestver=`/usr/bin/curl -s -A "$userAgent" https://zoom.us/download | grep 'ZoomInstallerIT.pkg' | awk -F'/' '{print $3}'`
Zoomurl="https://zoom.us/client/latest/ZoomInstallerIT.pkg"
curl -sLo /tmp/${Zoomfile} ${Zoomurl} &&
installer -allowUntrusted -pkg /tmp/${Zoomfile} -target /
rm /tmp/${Zoomfile}
sleep 8

#Chrome Installer
# Changed the installer from .dmg to .pkg and took out the bit for choosing an architecture.
#Source: https://community.jamf.com/t5/jamf-pro/google-chrome-script-for-installing-either-intel-or-m1-apple/m-p/252017
# make temp folder for downloads
mkdir "/tmp/googlechrome"
# change working directory
cd "/tmp/googlechrome"
# Download Google Chrome
curl -L -o "/tmp/googlechrome/googlechrome.pkg" "https://dl.google.com/chrome/mac/stable/accept_tos%3Dhttps%253A%252F%252Fwww.google.com%252Fintl%252Fen_ph%252Fchrome%252Fterms%252F%26_and_accept_tos%3Dhttps%253A%252F%252Fpolicies.google.com%252Fterms/googlechrome.pkg"
# Install Google Chrome
sudo /usr/sbin/installer -pkg googlechrome.pkg -target /
#Tidy Up
sudo rm -rf "/tmp/googlechrome"
#Bless Google Chrome app
xattr -rc "/Applications/Google Chrome.app"
sleep 7

###Slack Installer
#VARIABLES#

currentUser=$(stat -f%Su /dev/console)
currentUserUID=$(dscl . read /Users/$currentUser UniqueID | awk {'print $2'})
installedVersion=$(if [[ -d /Applications/Slack.app ]]; then /usr/bin/defaults read /Applications/Slack.app/Contents/Info.plist CFBundleShortVersionString; else echo 0; fi)
currentVersion=$(curl "https://slack.com/ssb/download-osx-universal" -s -L -I -o /dev/null -w '%{url_effective}' | rev | cut -d '/' -f 1 | rev | awk -F- {'print $2'} )
arch=$(uname -m)

## Determine Download URL Based on Arch * If x86_64 Installs https://slack.com/ssb/download-osx * else installs arm64 https://slack.com/ssb/download-osx-silicon ##
if [[ ${arch} == 'x86_64' ]];then
  downloadURL=$(curl "https://slack.com/ssb/download-osx" -s -L -I -o /dev/null -w '%{url_effective}')
else
  downloadURL=$(curl "https://slack.com/ssb/download-osx-silicon" -s -L -I -o /dev/null -w '%{url_effective}')
fi
mountFileName=$(echo ${downloadURL} | rev | cut -d '/' -f 1 | rev)

echo $currentUser
echo $currentUserUID
echo $currentVersion
echo $installedVersion
echo $downloadURL
echo $mountFileName

## Setup Temp Work Space for the dmg to be downloaded and mounted##
mkdir -p /private/var/tmp/SlackInstall
cd /private/var/tmp/SlackInstall

#Find if Slack.app is installed and current#
if [[ -d /Applications/Slack.app ]];then
    if [[ ${currentVersion} = ${installedVersion} ]];then
        echo "Slack is already current"
    else
#Find the Slack process ID * If is running * Kill it #
      if curl --retry 3 -L -s -O "${downloadURL}";then
        if pgrep -xq Slack; then
          pkill -x Slack
#Mount the Slack-x.x.x-MacOS.dmg * Copy to /Applications * Unmount DMG and remove the installer#
          /usr/bin/hdiutil attach  -nobrowse -mountpoint /Volumes/${mountFileName} ./${mountFileName}
          /usr/bin/ditto --rsrc /Volumes/${mountFileName}/Slack.app /Applications/Slack.app/
          /usr/bin/hdiutil detach  /Volumes/${mountFileName}
          rm -rf /private/var/tmp/SlackInstall
        else
          echo "Slack not running, installing...."
          /usr/bin/hdiutil attach -nobrowse -mountpoint /Volumes/${mountFileName} ./${mountFileName}
          /usr/bin/ditto --rsrc /Volumes/${mountFileName}/Slack.app /Applications/Slack.app/
          /usr/bin/hdiutil detach /Volumes/${mountFileName}
          rm -rf /private/var/tmp/SlackInstall
        fi
      else
        echo "Download Failed"
      fi
    fi
else
    echo "Slack Not Installed. Downloading....."
    if curl --retry 3 -L -s -O "${downloadURL}";then
        /usr/bin/hdiutil attach -nobrowse -mountpoint /Volumes/${mountFileName} ./${mountFileName}
        /usr/bin/ditto --rsrc /Volumes/${mountFileName}/Slack.app /Applications/Slack.app/
        /usr/bin/hdiutil detach /Volumes/${mountFileName}
        rm -rf /private/var/tmp/SlackInstall
    else
        echo "Download Failed"
    fi
fi


##OFFICE INSTALL
#Installing the Office directly from USB Drive /Microsoft_Office_16.58.22021501_BusinessPro_Installer.pkg
#/usr/sbin/installer -allowUntrusted -pkg /Volumes/Untitled/Microsoft_Office_16.58.22021501_BusinessPro_Installer.pkg -target /

mkdir -p /private/var/tmp/officeInstall
cd /private/var/tmp/officeInstall
/usr/bin/ditto --rsrc /Volumes/Untitled/Microsoft_Office_16.58.22021501_BusinessPro_Installer.pkg /private/var/tmp/officeInstall
/usr/sbin/installer -allowUntrusted -pkg /private/var/tmp/officeInstall/Microsoft_Office_16.58.22021501_BusinessPro_Installer.pkg -target /
sleep 30
rm -rf /private/var/tmp/officeInstall 
sleep 2

echo "Job Done!"


#Open VPN install
#Installing Open VPN directly from USB Drive OpenVPN pkg
#Variables
arch=$(uname -m)

if [[ ${arch} == 'x86_64' ]];then
{
echo "x86_64 detected - Installing x86_64 Pkg"
mkdir -p /private/var/tmp/openvpninstall
cd /private/var/tmp/openvpninstall
/usr/bin/ditto --rsrc "/Volumes/Untitled/OpenVPN_Connect_3_4_1(4522)_x86_64_Installer_signed.pkg" "/private/var/tmp/openvpninstall"
/usr/sbin/installer -allowUntrusted -pkg "/private/var/tmp/openvpninstall/OpenVPN_Connect_3_4_1(4522)_x86_64_Installer_signed.pkg" -target /
sleep 10
rm -rf /private/var/tmp/openvpninstall
sleep 2
}

else

{
echo "arm64 detected - Installing arm64 Pkg"
mkdir -p /private/var/tmp/openvpninstall
cd /private/var/tmp/openvpninstall
/usr/bin/ditto --rsrc "/Volumes/Untitled/OpenVPN_Connect_3_4_1(4522)_arm64_Installer_signed.pkg" "/private/var/tmp/openvpninstall"
/usr/sbin/installer -allowUntrusted -pkg "/private/var/tmp/openvpninstall/OpenVPN_Connect_3_4_1(4522)_arm64_Installer_signed.pkg" -target /
sleep 10
rm -rf /private/var/tmp/openvpninstall
sleep 2
}
fi


####EndPoint Checkpoint VPN install
#Installing Checkpoint directly from USB Drive Endpoint_Security_VPN.pkg
#/usr/sbin/installer -allowUntrusted -pkg /Volumes/Untitled/Endpoint_Security_VPN.pkg-target /

mkdir -p /private/var/tmp/checkpointVPN
cd /private/var/tmp/checkpointVPN
/usr/bin/ditto --rsrc "/Volumes/Untitled/Endpoint_Security_VPN.pkg" "/private/var/tmp/checkpointVPN"
/usr/sbin/installer -allowUntrusted -pkg /private/var/tmp/checkpointVPN/Endpoint_Security_VPN.pkg -target /
sleep 10
rm -rf /private/var/tmp/checkpointVPN
sleep 2

echo "Job Done!"

#End