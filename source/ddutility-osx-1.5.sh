#!/bin/sh
#
# dd Utility version 1.5 - Mac OS X 
#
# Write and Backup Operating System IMG files on Memory Card 
#
# By The Fan Club 2015
# http://www.thefanclub.co.za
#
### BEGIN LICENSE
# Copyright (c) 2015, The Fan Club <info@thefanclub.co.za>
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranties of
# MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
### END LICENSE
#
### NOTES 
#
# Dependencies : zip xz gzip dd osascript 
#
# Program packaged and Progress bar by Platypus - http://sveinbjorn.org/platypus
#
# To run script make executable with: sudo chmod +x ddutility-mac.sh
# and then run with: sudo ddutility-mac.sh
#
###

# Vars
apptitle="dd Utility"
version="1.5 beta"
export LC_ALL=en_US.UTF-8
mountpath="/Volumes"

echo "dd Utility Started" 
echo "PROGRESS:0"

# Set Icon directory and file 
iconfile="/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/Removable.icns"

# Read args
if [ "$1" == "--Backup" ] ; then
  action="Backup"
fi
if [ "$1" == "--Restore" ] ; then
  action="Restore"
fi

# Check if Disk Dev was dropped
if [ "$(dirname "$1")" == "$mountpath" ] ; then
   memcard=$( diskutil info "$1" | grep "Device Node" | awk {'print $3'} | grep "\/dev\/" )
   if [ $memcard ] ; then
     devdisk=$( echo $memcard | sed 's/s[0-9]//g' )
     action="Backup"
   fi
fi

# Check if Restore file was dropped
if [ -f "$1" ] ; then
  # Check extension if file
  extension=$( echo "${1##*.}" | tr '[:upper:]' '[:lower:]' )
  case "$extension" in
    img|iso|zip|gz|xz)
      action="Restore"
      imagepath=$1
      ;;
  esac
fi

# Convert Bytes to Human Readable 
function filesizehuman () {
  filesize=$1
  if [ "$filesize" -gt 1000000000000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000000000000" | bc ) TB" 
  elif [ "$filesize" -gt 1000000000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000000000" | bc ) GB" 
  elif [ "$filesize" -gt 1000000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000000" | bc ) MB" 
  elif [ "$filesize" -gt 1000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000" | bc ) KB" 
  fi
  echo $fsize
}

# Calculate progress in percentage for progress bar
function progressmonitor () {
  echo "$progresstext"
  processactive=$( ps -p $pid -o pid= )
  # While process running show progress
  while [ $processactive ] ; do
    # Backup Progress
    if [ "$action" == "Backup" ] ; then
      # img
      if [ "$compression" == "No" ] ; then
        # Calc progress with size of output file and disk dev size  
        outputfilesize=$(stat -f%z "$outputfile")
      fi
      # zip
      if [ "$compression" == "Yes" ] ; then
        # Calc progress for compressed backup using read offset on disk device and total size of disk
        outputfilesize=$( lsof -o0 -o | grep "$inputfile" | awk {'print $7'} | cut -d 't' -f2 )         
      fi      
    fi
    
    # Restore Progress
    if [ "$action" == "Restore" ] ; then
        # Calc progress by using offset bytes on disk device and uncompressed size pf restore file
        outputfilesize=$( lsof -o0 -o -p $pid | grep "$outputfile" | awk {'print $7'} | cut -d 't' -f2 )
    fi
       
    # Calc percentage of progress
    percentage=$(printf "%.0f" $( echo "scale=2; ($outputfilesize/$totalbytes)*100" | bc ))  
 
    # Update progress bar
    echo "PROGRESS:$percentage"
    sleep 1
    
    # Check if process still active
    processactive=$( ps -p $pid -o pid= )
  done
}

# Select Disk Volume Dialog
function getdevdisk () {
  # Check for mounted devices in user media folder
  # Parse memcard disk volume Goodies
  memcard=$( df | grep "$mountpath" | awk {'print $1'} | grep "\/dev\/" )
  # Get dev names of drive - remove partition numbers
  checkdev=$( echo $memcard | sed 's/s[0-9]//g' )
  # Remove duplicate dev names
  devdisks=$( echo $checkdev | xargs -n1 | sort -u | xargs )
  # How many devs found
  countdev=$( echo $devdisks | wc -w )
  # Retry detection if no memcards found
  while [ $countdev -eq 0 ] ; do
    # Ask for redetect
    response=$( osascript -e 'tell app "System Events" to display dialog "No Volumes Detected \n\nInsert a memory card or removable storage \nand click Retry.\n\nSelect Cancel to Quit" buttons {"Cancel", "Retry"} default button 2 with title "'"$apptitle"' - '"$action"'" with icon POSIX file "'"$iconfile"'"  ')
    
    answer=$(echo $response | cut -d ':' -f2)
    if [ "$answer" != "Retry" ] ; then
      exit 1
    fi
    # Do Re-Detection of Devices
    # Parse memcard disk volume Goodies
    memcard=$( df | grep "$mountpath" | awk {'print $1'} | grep "\/dev\/" )
    # Get dev names of drive - remove partition numbers
    checkdev=$( echo $memcard | sed 's/s[0-9]//g' )
    # Remove duplicate dev names
    devdisks=$( echo $checkdev | xargs -n1 | sort -u | xargs )
    # How many devs found
    countdev=$( echo $devdisks | wc -w )
  done

  # Generate select Dialog 
  devitems=""
  # Generate list of devices
  for (( c=1; c<=$countdev; c++ ))
    do
      devitem=$( echo $devdisks | awk -v c=$c '{print $c}')
      drivesizehuman=$( diskutil info $devitem | grep "Total\ Size" | awk {'print $3" "$4'} )
      devtype=$(diskutil info "$devitem" | grep "Device\ \/\ Media" | cut -d ":" -f2 | xargs)
      disknum=$( diskutil list | grep "$devitem" | awk -F 'disk' '{print $2}' | cut -d 's' -f1 )
      # Create List of "item","item","item" for select dialog
      devitems=$devitems"\"\t$drivesizehuman \t\t$devtype \t\tDisk $disknum\""
      # Add comma if not last item
      if [ $c -ne $countdev ] ; then
        devitems=$devitems","
      fi
  done

  # Select Dialog
  devselect="$( osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to return (choose from list {'"$devitems"'} with prompt "Select your memory card" with title "'"$apptitle"' - '"$action"'" OK button name "Continue" cancel button name "Cancel")')"
  
  # get dev value back from devselect
  devdisk=$( echo $devselect | grep 'Disk' | rev | cut -d' ' -f1 | xargs | awk '{print "/dev/disk"$1}' )

  # Return value or false
  echo $devdisk
}


# Select Backup or Restore if not in args
echo "Select Backup or Restore"
echo "PROGRESS:10"
if [ ! "$action" ] ; then
  response=$(osascript -e 'tell app "System Events" to display dialog "Select Backup to create an image file from a memory card or disk.\n\nSelect Restore to write an image file to a memory card or disk. \nSupported formats: img, iso, zip, gzip, xz\n\nSelect Cancel to Quit" buttons {"Cancel", "Backup", "Restore"} default button 3 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'"  ')

  action=$(echo $response | cut -d ':' -f2)

  if [ ! "$action" ] ; then
    echo "Program cancelled"
    exit 0
  fi
fi
 
### BACKUP : Select inputfile and outputfile
if [ "$action" == "Backup" ] ; then

  # Get memcard device name
  echo "Select your memory card"
  echo "PROGRESS:20"
  
  # Check if volume was dropped already
  if [ ! "$devdisk" ] ; then
    # Select Disk Volume
    devdisk=$( getdevdisk )
  fi
  
  # Cancel if user selects Cancel
  if [ ! "$devdisk" ] ; then
    echo "No Volumes Selected. $action Cancelled."
    exit 0
  fi
 
  # Get filename for for backup image
  echo "Enter filename for disk image"
  echo "PROGRESS:60"
  response=$(osascript -e 'tell app "System Events" to display dialog "Enter filename for disk image:" default answer "imagefile.img" with title "'"$apptitle"' - '"$action"'" ' )
  
  # Cancel is user selects Cancel
  if [ ! "$response" ] ; then
    echo "$action Cancelled."
    exit 0
  fi
  
  getfilename=$( echo $response | cut -d "," -f2 | cut -d ":" -f2 )
  # Strip path if given
  filename=$(basename "$getfilename")

  # Get output folder for backup image
  echo "Select backup folder for memory card image file"
  echo "PROGRESS:40"
  imagepath=`/usr/bin/osascript << EOT
    tell application "Finder"
        activate
        set folderpath to choose folder default location (path to desktop folder) with prompt "Select backup folder for memory card image file"
    end tell 
    return (posix path of folderpath) 
  EOT`

  # Cancel is user selects Cancel
  if [ ! "$imagepath" ] ; then
    echo "$action Cancelled"
    exit 0
  fi

  # check if compression implied in filename extension
  extension=$( echo "${filename##*.}" | tr '[:upper:]' '[:lower:]' )
  
  # Check if extension is already gz
  if [ "$extension" == "gz" ] ; then
     compression="Yes"
  else
    # Ask for compression
    echo "Compress the Backup image file?"
    echo "PROGRESS:80"
    response=$(osascript -e 'tell app "System Events" to display dialog "Compress the Backup image file? \n\nThis can significantly reduce the space used by the backup." buttons {"No", "Yes"} default button 2 with title "'"$apptitle"' - '"$action"'" with icon POSIX file "'"$iconfile"'"  ')

    compression=$(echo $response | cut -d ':' -f2)
  fi

  # Parse vars for dd
  outputfile="$imagepath$filename"

  # Add img extension if missing
  if [ "$extension" != "gz" ] && [ "$extension" != "img" ] ; then
    outputfile="$outputfile.img"
  fi
  # Add gz for compressed backup
  if [ "$compression" == "Yes" ] && [ "$extension" != "gz" ] ; then    
    outputfile="$outputfile.gz"
  fi
 
  # Check if image file exists
  if [ -f "$outputfile" ] ; then
    response=$(osascript -e 'tell app "System Events" to display dialog "The file '"$(basename $outputfile)"' already exist.\n\nSelect Continue to overwrite the file.\n\nSelect Cancel to Quit" buttons {"Cancel", "Continue"} default button 2 with title "'"$apptitle"' - '"$action"'" with icon 0 ')

    # Cancel is user selects Cancel
    if [ ! "$response" ] ; then
      echo "$action Cancelled"
      exit 0
    fi

    # Delete the file if exists
    rm $outputfile
  fi

fi


### RESTORE : Select image file and memcard location
if [ "$action" == "Restore" ] ; then
 
  # Get image file location
  echo "Select image file to restore to memory card or disk"
  echo "PROGRESS:33"

  # Check if restore file was dropped as arg already
  if [ ! $imagepath ] ; then
    # Get restore image file
    imagepath=`/usr/bin/osascript << EOT
      tell application "Finder"
        activate
        set imagefilepath to choose file of type {"img", "iso", "gz", "zip", "xz"} default location (path to desktop folder) with prompt "Select image file to restore to memory card or disk. Supported file formats : IMG, ISO, ZIP, GZ, XZ"
      end tell 
      return (posix path of imagefilepath) 
    EOT`

    # Cancel is user selects Cancel
    if [ ! "$imagepath" ] ; then
      echo "$action Cancelled"
      exit 0
    fi
  fi
  
  # Get memcard device name
  echo "Select your memory card"
  echo "PROGRESS:66"
  devdisk=$( getdevdisk )
   
  # Cancel if user selects Cancel
  if [ ! $devdisk ] ; then
    echo "No Volumes Selected. $action Cancelled. "
    exit 0
  fi
 
  # Parse vars for dd
  inputfile="$imagepath"
 
  # Check if Compressed from extension
  extension=$( echo "${inputfile##*.}" | tr '[:upper:]' '[:lower:]' )
  if [ "$extension" == "gz" ] || [ "$extension" == "zip" ] || [ "$extension" == "xz" ]; then
    compression="Yes"
  else
    compression="No"
  fi

fi
 
### Parse data 
# Use rdisk for faster copy
disknum=$( echo "$devdisk" | awk -F 'disk' '{print $2}' )
echo "devdisk = $devdisk"
devdiskr="/dev/rdisk$disknum"

# Get Drive size in bytes and human readable
drivesize=$( diskutil info $devdisk | grep "Total\ Size" | cut -d "(" -f2 | awk {'print $1'})
drivesizehuman=$( diskutil info $devdisk | grep "Total\ Size" | awk {'print $3" "$4'} )
 
# Set output option
if [ "$action" == "Backup" ] ; then
  inputfile=$devdiskr
  source="$drivesizehuman Volume"
  dest="$(basename "$outputfile")"
  totalbytes=$drivesize
  # Check available space left for backup
  outputspace=$( df -k "$(dirname "$outputfile")" | tail -1 | awk {'print $4'})
  # df -k on OSX sets blocks of 1024 bytes
  outputspace=$(( $outputspace * 1024 ))
fi

if [ "$action" == "Restore" ] ; then
  inputfilesize=$(stat -f%z "$inputfile")
  inputfilesizehuman=$( filesizehuman $inputfilesize )
  source="$(basename "$inputfile")"
  dest="$drivesizehuman Volume"
  outputfile=$devdiskr
  outputspace=$drivesize
  # Get uncompressed size of image restore files 
  case "$extension" in
    img | iso )
       totalbytes=$inputfilesize
       ;;
    zip)
       totalbytes=$( unzip -l "$inputfile" | tail -1 | awk '{print $1}')
       ;;
     gz)
       totalbytes=$( gzip -l "$inputfile" | tail -1 | awk '{print $2}')
       ;;
     xz)
       totalbytes=$( xz -lv  "$inputfile" | grep "Uncompressed" | cut -d "(" -f2 | cut -d "B" -f1 | sed -e 's/[^0-9]*//g')
       ;;
  esac
fi

# Check sizes to find out if there is enough space to do backup or restore
if [ $totalbytes -gt $outputspace ] ; then
  sizedif=$(( $totalbytes - $outputspace ))
  sizedifhuman=$( filesizehuman $sizedif )

  if [ "$compression" == "Yes" ] && [ "$action" == "Restore" ] ; then
    compressflag=" uncompressed"
  fi
  # Add Warning text 
  warning="WARNING: The$compressflag $(echo $action | tr '[:upper:]' '[:lower:]') file is $sizedifhuman too big to fit on the destination storage device. You can click Start to continue anyway, or select Cancel to Quit."

fi 
  
### Confirmation Dialog
echo "Confirm Settings and click Start"
echo "PROGRESS:100"
response=$(osascript -e 'tell app "System Events" to display dialog "Please confirm settings and click Start\n\nSource: \n'"$source"' \n\nDestination: \n'"$dest"' \n\n'"$warning"'\n\nNOTE: All Data on the Destination will be deleted" buttons {"Cancel", "Start"} default button 2 with title "'"$apptitle"' - '"$action"'" with icon POSIX file "'"$iconfile"'" ')

answer=$(echo $response | grep "Start")

# Cancel is user does not select Start
if [ ! "$answer" ] ; then
  echo "$action Cancelled"
  exit 0
fi
 
# Unmount Volume
response=$( diskutil unmountDisk $devdisk | grep "successful" ) 

# Cancel if unable to unmount
if [ ! "$response" ] ; then
  echo "Cannot Unmount "$devisk". $action Cancelled"
  osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Cannot Unmount '"$devisk"'"'
  exit 0
fi
 
# Activate progress window if not active
osascript -e 'tell application "dd Utility" to activate'


### Start dd copy
echo "Initialising $action ..."
echo "PROGRESS:0"
osascript -e 'display notification "Please be patient...." with title "'"$apptitle"'" subtitle "'"$drivesizehuman"' Volume '$action' Started"'

# Backup
if [ "$action" == "Backup" ] ; then
  if [ "$compression" == "Yes" ] ; then
    # Compressed Backup to GZ file
    dd if="$inputfile" bs=1m | gzip > "$outputfile" &
  else
    # Normal dd uncompressed Backup
    dd if="$inputfile" of="$outputfile" bs=1m &
  fi  
fi
 
# Restore
if [ "$action" == "Restore" ] ; then
  # Re-partition the Disk to eliminate any write issues
  response=$( diskutil partitionDisk $devdisk 1 MBR "Free Space" "%noformat%" 100% | grep "Finished" )
  
  # Cancel if unable to re-partition
  if [ ! "$response" ] ; then
    echo "Cannot Partition $drivesizehuman Volume. $action Cancelled"
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Cannot Partition '"$drivesizehuman"' Volume"'
    exit 0
  fi
    
  # ISO files - On OS X they need to be converted to IMG before we use dd
  if [ "$extension" == "iso" ] ; then
    outputfiletemp=$outputfile
    outputfile=$( echo "$inputfile" | sed -e "s/\.[Ii][Ss][Oo]/\.img/g" )
    # Check if file has been converted previously
    if [ ! -f "$outputfile" ] ; then
      # Convert ISO to IMG
      hdiutil convert -format UDRW -o "$outputfile" -quiet "$inputfile" &
      # Get PID of hdiutil
      pid=$!
      # Monitor progress
      progresstext="Converting ISO to IMG format..."
      progressmonitor
      # quit if file convert failed
      if [ ! -f "$outputfile.dmg" ] ; then
        osascript -e 'tell app "System Events" to display dialog "'"$drivesizehuman"' Volume '"$action"' Failed.\n\nCould not convert the ISO file to IMG format." buttons {"Done"} default button 1 with title "'"$apptitle"' '"$version"'" with icon 0 '
        exit 0
      fi
      # rename to remove DMG that os x ads by default
      mv "$outputfile.dmg" "$outputfile"    
    fi
    # When done set img outputfile as new inputfile for dd
    inputfile=$outputfile
    extension="img"
    outputfile=$outputfiletemp
    # Get new totalsize from new img file
    totalbytes=$(stat -f%z "$inputfile")
  fi     
  # IMG files
  if [ "$extension" == "img" ] ; then
    dd if="$inputfile" of="$outputfile" bs=1m &
  fi
  # GZ files
  if [ "$extension" == "gz" ] ; then
    gzip -dc "$inputfile" | dd of="$outputfile" bs=1m &
  fi
  # ZIP files
  if [ "$extension" == "zip" ] ; then
    unzip -p "$inputfile" | dd of="$outputfile" bs=1m &    
  fi
  # XZ files - OSX 10.10 only I think 
  if [ "$extension" == "xz" ] ; then
    tar -xJOf "$inputfile" | dd of="$outputfile" bs=1m &
  fi

fi  


# Get PID of dd running in background
pid=$!

# Monitor progress
progresstext="$action in progress..."
progressmonitor

if [ $percentage -gt 0 ] ; then
    status="Complete"
else
    status="Failed"
fi

# Set Permissions
if [ "$action" == "Backup" ] ; then  
  chown $USER "$outputfile"
fi
 
### Copy Complete
# Display Notifications
osascript -e 'display notification "You can remove you memory card now" with title "'"$apptitle"'" subtitle "'"$drivesizehuman"' Volume '"$action"' '"$status"' "'

echo "$action $status"
echo "PROGRESS:100"

response=$(osascript -e 'tell app "System Events" to display dialog "'"$drivesizehuman"' Volume '"$action"' '"$status"'" buttons {"Done"} default button 1 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'" ')

# exit
exit 0
# END