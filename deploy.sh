#!/bin/bash

# ------------------------------------------------------
# Global config const
# Set it to INITIAL state before start main functionality
#

# The person who must be owner of the files and directories
OWNER="myusername"

# ROOT directory where all files live
TARGET_DIR="_not_defined_" 
TARGET_DIR_STATE="drwxr-xr-x${OWNER}mygroupname"

# Directory for saving builds relative TARGET_DIR
BUILDS_DIR="revs"
BUILDS_DIR_STATE="drwxr-xr-x${OWNER}mygroupname" 

# Name of the document root symlink relative TARGET_DIR
SITE_ROOT_SYMLINK="site" 
SITE_ROOT_SYMLINK_STATE="lrwxrwxrwx${OWNER}mygroupname"


#------------------------------------------------------
# Universal Functions
#


#------------------------------------------------------
# Test destination for existance and compare his rights
# and ownership with pattern
#
# $1 - destination name
# $2 - pattern of rights (ls rights+owner+group)
# $3 - destiatiopn type (-d|-L|-f)
#

function test_dst()
{

local dst="$1"
local pattern="$2"
local ftype="$3"

echo "Checking......... $dst"
    
local exist=0
local state=""
    
case "$ftype" in
    
  -d )

    test -d "$dst"
    exist=$?

    state="$(ls -al "$dst"|grep -w "\."|grep -v -w "\.\."|awk '{print $1 $3 $4}')"
  ;;
  

  -f )

    test -f "$dst"
    exist=$?

    state="$(ls -al "$dst"|awk '{print $1 $3 $4}')"
  ;;
  
  
  -L )

    test -L "$dst"
    exist=$?

    state="$(ls -al "$dst"|awk '{print $1 $3 $4}')"
  ;;      


  *)
    echo "Invalid file type $ftype"
    return 1
  ;;
            
esac


if [ ! "$exist" -eq 0 ]
then
    
    echo "FATAL...........: $dst doesn't exist."
    return 3

fi
    
echo "OK...............: $dst exist."


if [ "$state" != "$pattern" ]
then
    
    echo "ERROR...........: state: $state, for $dst doesn't math pattern $pattern."
    return 1
    
fi
    
echo "OK...............: $dst owner and rights math with pattern: $state."

return 0

}



#------------------------------------------------------
# Test if any file(s) was changed after deploy 
# if any file in target dir are newer then the directory
#
# $1 - symlink for shecking
#

function test_content()
{

local link="$1"

echo "Searching for local changes after deploy in directory $link"


if ! link_src="$(readlink -f "$link")"
then

    echo "ERROR...........: Can't read link $link"
    exit 1
    
fi


if [ "$(find "$link_src" -newer "$link" | wc -l)" -gt 0  ]
then

    echo "ERROR...........: Tehre are local changes in $link_src"
    find "$link_src" -newer "$link" 
    return 1
  
fi


echo "OK...............: Content was not changed in $link source dir $link_src"

return 0

}



#------------------------------------------------------
# Create symlink and print result to stdout
# 
# $1 - destination
# $2 - link
#

function create_symlink()
{

if ! ln -sfn "$1" "$2"
then

    echo "ERROR...........: Can't create symlink $2 to destination $1"
    return 1

fi

echo "OK...............: create symlink $2 to destination $1"

return 0

}



#------------------------------------------------------
# Unpack archive into dest dir
# in force backup dest and sync sylink in TARGET_DIR with backuped dest
#
# $1 - dir where all files are placed
# $2 - Archie file name
# $3 - destination dir whithin $1
# $4 - force mode
#

function unpack_archive()
{

local dir="$1"
local arch="$2"
local dest="$dir"/"$3"
local force="$4"

if [ ! -f "$arch" ] 
then

    echo "ERROR...........: Can't find archive $arch"
    echo "Do nothing. Unpacking aborted."        

    return 3


elif [ ! -d "$dest" ] 
then

    echo "Unpacking archive $arch to new dir $dest"

    if ! mkdir "$dest"
    then
   
        echo "ERROR...........: Can't create directory $dest".
        return 3
       
    fi


    if ! tar -xzf "$arch" -C "$dest"
    then
   
        echo "ERROR...........: Can't unpack $arch into $dest".
        return 3
       
    fi
   
    rm -f "$arch"
    
    chmod -R g+w "$dest"

    echo "Unpack done. Archive $arch removed."

    return 0
   


elif [ "$force" = true  ] 
then

    echo "WARNING..........: Force mode! Unpacking archive $arch to temp dir and then replace it with already existed dir $dest"

    TMP="$$"


    if ! mkdir "$dest.$TMP"
    then
   
        echo "ERROR...........: Can't create directory $dest.$TMP".
        return 3
       
    fi


    if ! tar -xzf "$arch" -C "$dest.$TMP"
    then
   
        echo "ERROR...........: Can't unpack $arch to $dest.$TMP".
        return 3
       
    fi

    chmod -R g+w "$dest.$TMP"
    
    rm -f "$arch"
    

    local link_to_prev
    
    link_to_prev="$(ls -l "$dir" | grep "${dest}" | awk '{ print $9}')"

    if ! mv "$dest" "$dest.bkp_""$TMP"
    then
    
        echo "ERROR...........: Can't create backup dir $dest.bkp_$TMP"
        return 3
       
    fi
    
    

    if [ " $link_to_prev" != " " ]
    then
                   
        if ! ln -sfn "$dest.bkp_$TMP" "$dir/$link_to_prev"
        then 
        
            echo "FATAL...........: $dest already was moved to $dest.bkp_$TMP but can't replace link $dir/$link_to_prev to that directory"
            exit 3
            
        fi
        
        echo "Link $dir/$link_to_prev is replaced to $dest.bkp_$TMP"
        
    fi
                                                                                


    if ! mv "$dest"."$TMP" "$dest"
    then
   
        echo "FATAL...........: Can't replce $dest.$TMP to $dest".
        return 3
       
    fi
    

    echo "Unpack and replacement done. Archive $arch removed."
    echo "Previous dir $dest is backuped to $dest.bkp_$TMP"

    return 0



else # No force mode

    echo "ERROR...........: The destination dir $dest already exist, to rewrite it use --force option."
    echo "Unpacking aborted."

    return 3

fi

}



# ------------------------------------------------------
# Restore previouse version of site if exist aproproate backup
#
#
# $1 - directory where we need resotre
# $2 - link to the production site within directory $1
#

function restore()
{

local dir="$1"
local link_to_live="$2"

echo "Try to restore $link_to_live from backup1 in directory $dir"

if [ ! -L "$dir"/backup1 ]
then

    echo "FATAL...........: backup link $dir/backup1 don't exist".
    echo "Restore unavilable."

    return 3
  
fi


local bckp_link_src

bckp_link_src="$(readlink -f "$dir"/backup1)"

if ! ln -sfn "$bckp_link_src" "$dir"/"$link_to_live"
then

   echo "Can't link $bckp_link_src to $dir/$link_to_live"
   return 1
   
fi

echo "Site root $dir/$link_to_live is linked to $bckp_link_src"



local i=2

while [ -L "$dir"/backup$i ] 
do
  
    bckp_link_src="$(readlink -f "$dir"/backup$i)"

    if ln -sfn "$bckp_link_src" "$dir/backup$(( i - 1 ))"
    then

        echo "$bckp_link_src is shifted from backup$i to backup$(( i - 1 ))"
        
    fi

    i=$(( i + 1 ))

done
            
unlink "$dir/backup$(( i - 1 ))"


echo "OK...............: Restore successfully done in dir $dir."

return 0
            
}



#------------------------------------------------------
# Create DOCROOT_SYMLINK and some backups link
#
# $1 - directory where all are placed
# $2 - new source for link $3 within base dir
# $3 - link within base dir
#

function link_to_site()
{

local dir="$1"
local new_src="$2"
local site_link="$3"

if [ "$(readlink -f "$dir/$site_link")" = "$dir/$new_src" ] 
then 

   echo "WARNING..........: The directory $dir/$new_src already linked to $dir/$site_link. No any action needed."
   ls -l "$dir/$site_link"

   return 0

fi


# make backup links

local bkp_link_src



local last_bkp_file=""

if [ -L "$dir/backup3" ]
then

    last_bkp_file="$(readlink -f $dir/backup3)"

fi



for i in {3..2..-1}
do

    local prev_bkp_link=backup$(( i - 1 ))

    if [ -L "$dir/$prev_bkp_link" ]
    then

        bkp_link_src="$(readlink -f "$dir"/"$prev_bkp_link")"
        
        ln -sfn "$bkp_link_src" "$dir"/backup$i
        
        echo "$bkp_link_src is shifted from $dir/$prev_bkp_link to $dir/backup$i"

    fi
done


if [ -L "$dir/$site_link" ]
then

  site_link_src="$(readlink -f "$dir/$site_link")"
  
  ln -sfn "$site_link_src" "$dir/backup1"
  
  echo "$site_link_src is shifted from $dir/$site_link to $dir/backup1"

fi


# Create/overwrite prod link (symbolic, force, no-dereference)

if ! ln -sfn  "$dir/$new_src" "$dir/$site_link"
then

    echo "FATAL...........: Can't link new src $dir/$new_src to $dir/$site_link"
    return 3
fi

echo "Site_root $dir/$site_link is linked to $dir/$new_src"


return 0

}


#------------------------------------------------------
# Delete older then 5 days not used revision from revs
#
# $1 - directory where all are placed
#

function scavenge() 
{
local target_dir="$1"

for revision in $(ls $target_dir/revs)
do

  file_time=$(stat --format='%Y' "$target_dir/revs/$revision")
  current_time="$(date +%s )"
  older_then_days=5

  if (( file_time < ( current_time - ( 60 * 60 * 24 * $older_then_days ) ) ))
  then

    if [ -z "$(ls -l $target_dir | grep $revision )" ]
    then
      echo "Delete old not used revision $revision"
      sudo /bin/chown -R jenkins $target_dir/revs/$revision/*
      sudo /bin/chown jenkins $target_dir/revs/$revision
      rm -rf $target_dir/revs/$revision
    else
      echo "Revision $revision used in prod or backup symlinks"
    fi

  else
    echo "Revision $revision younger then $older_then_days days"
  fi

done

return 0

}


#------------------------------------------------------
# Functions specific for the project
#

function usage()
{
  echo " "
  echo "Usage:"
  echo " "
  echo "$(basename "$0") [-f|--force] TARGET_DIR BUILD      - to deploy BUILD into TARGET_DIR"
  echo " "
  echo "TARGET_DIR - directory where all environment will be deployed."
  echo " "
  echo "BUILD can be .tgz archive or a directory within TARGET_DIR/$BUILDS_DIR."
  echo " "
  echo "force: Deploy anyway (the script will delete existing directory and ignore local changes)."
  echo " "
  echo "$(basename "$0") [-t|--test] TARGET_DIR             - to test environment consistent in TARGET_DIR"
  echo " "
  echo "$(basename "$0") [-r|--restore] TARGET_DIR          - to restore live from backup1 link if it exist in TARGET_DIR"
  echo " "
  echo "$(basename "$0") [-с|--content] TARGET_DIR          - to check if any file(s) was changed after deploy in TARGET_DIR"
  echo " "
  echo "$(basename "$0") [-s|--scavenge] TARGET_DIR         - delete old not used revision in TARGET_DIR"
  echo " "
  echo "$(basename "$0") [-h|--help]                        - to print this message"
  echo " "
}



#------------------------------------------------------
# Test environment for the script on the host
#
# $1 - directory where environment must be placed
#
# use global:
#     $TARGET_DIR_STATE
#     $BUILDS_DIR
#     $BUILDS_DIR_STATE
#     $SITE_ROOT_SYMLINK
#     $SITE_ROOT_SYMLINK_STATE
#
#     All global vars about local resources places
#

function test_env_cons()
{

local dir=$1

echo "Testing environment consistent for $(basename "$0") on $(hostname) in directory $dir"

test_dst "$dir" "$TARGET_DIR_STATE" "-d"
    
local ret=$?
    

if ! test_dst "$dir/$BUILDS_DIR" "$BUILDS_DIR_STATE" "-d"
then
    ret=3
fi
    

if ! test_dst "$dir/$SITE_ROOT_SYMLINK" "$SITE_ROOT_SYMLINK_STATE" "-L"
then
    ret=3
fi
    

# Place here the tests specific for your prject, i.e.:

#if ! test_dst "$dir/.env" "-rw-rw-r--${OWNER}devel" "-f"
#then
#    ret=3
#fi



if [ $ret -eq 0 ]
then

    echo "OK...............: Environment in $dir is consistent"

else

    echo "ERROR...........: Environment in $dir isn't consistens"

fi

return $ret

}



#------------------------------------------------------
# Do specigic for the project additional works for deploy
#
# $1 - target dir where all files live
# $2 - directory where site artifacts placed within target dir
#

function deploy_project_environment()
{

local _target_dir=$1

local _build_dir="$_target_dir"/$2

# Place here specific commands for deployment you project, i.e.:

#if ! create_symlink "$_target_dir/.env" "$_build_dir/.env"
#then
#    return 1
#fi

# or:

#if ! chmod -R a=rwx "$_build_dir/bootstrap"
#then
#    echo "ERROR...........: chmod -R a+rwx $_build_dir/bootstrap"
#   return 1
#fi


return 0

}




# ------------------------------------------------------
# Main execution
#

function main()
{


# Check if current user is OWNER, exit if no

if [ "$( whoami )" != "$OWNER" ]
then

    echo "FATAL...........: whoami != $OWNER"
    echo "Deploy aborted"
    exit 3
   
fi



# Argument parsing

if [ $# -lt 2 ] # Check if enough arguments are specified.
then
    usage
    exit 65
fi


force_mode=false # If force mode is enabled, the script will delete existing directory of the specified revision.


case "$1" in

  -h | --help) # Print help.
    usage
    exit 65
  ;;


  -f | --force) # Activate force mode.
    force_mode=true
    shift # ArgsV array shifted left 
  ;;


  -r | --restore | -t | --test | -c | --content | -s | --scavenge )
    COMMAND=$1
    shift # ArgsV array shifted left 
  ;;


  *)
    ;;

esac


if [ $# -lt 1 ] # Check if enough arguments are specified.
then
    usage
    exit 65
fi

TARGET_DIR="$1"

shift # ArgsV array shifted left 



# Proccessing specific commands

case "$COMMAND" in

  -t | --test) # Test environment
    test_env_cons "$TARGET_DIR"
    exit $?
  ;;
  

  -c | --content)
    test_content "$TARGET_DIR"/"$SITE_ROOT_SYMLINK"
    exit $?
  ;;


  -r | --restore)
    restore "$TARGET_DIR" "$SITE_ROOT_SYMLINK"
    ret=$?

    ls -l "$TARGET_DIR"

    exit $ret
  ;;


  -s | --scavenge)
    scavenge "$TARGET_DIR"
    ret=$?
    exit $ret
  ;;


  *)
    ;;
esac



# Proccessing DEPLOY


if [ $# -lt 1 ] # Check if enough arguments are specified.
then
    usage
    exit 65
fi

BUILD_SRC="$1" # there may be archive or directory



# Test if we can deploy

if ! test_env_cons "$TARGET_DIR"
then

echo "Deploy aborted"
    exit 1

fi



#Test local changes in content

if ! test_content "$TARGET_DIR/$SITE_ROOT_SYMLINK"
then

    if [ "$force_mode" = true ]  
    then
    
        echo "WARNING.........: Force mode! Ignore local changes and deploy".
        
    else

        echo "For ignoring local changes and deploying anyway use --force option."
        echo "Deploy aborted."
    
        exit 1
    
    fi
fi



# Unpack archive if need

if [ -f "$BUILD_SRC" ] 
then

    echo "$BUILD_SRC is file, try to unpack it."

    DEPLOY_BUILD_DIR="$BUILDS_DIR"/"$(basename "$BUILD_SRC" .tgz)"

    if ! unpack_archive "$TARGET_DIR" "$BUILD_SRC" "$DEPLOY_BUILD_DIR" "$force_mode"
    then
        echo "Deploy aborted."
        exit 3
    fi

elif [ -d "$TARGET_DIR"/"$BUILDS_DIR"/"$BUILD_SRC" ] 
then

    DEPLOY_BUILD_DIR="$BUILDS_DIR/$BUILD_SRC"

else

    echo "ERROR...........: Invalid argument $BUILD_SRC. No such file $BUILD_SRC or directory $TARGET_DIR/$BUILDS_DIR/$BUILD_SRC"
    echo "Deploy aborted."
    exit 3

fi




# Make deploy specific for the project

if ! deploy_project_environment "$TARGET_DIR" "$DEPLOY_BUILD_DIR"
then

   echo "Deploy aborted."
   exit 3

fi


# Handle symlinks

if ! link_to_site "$TARGET_DIR" "$DEPLOY_BUILD_DIR" "$SITE_ROOT_SYMLINK"
then
  
   echo "Deploy aborted."
   exit 3
 
fi



# Report about success

echo "Result state of TARGET_DIR $TARGET_DIR is:"

ls -l "$TARGET_DIR"

echo " "
echo "OK...............: Deploy script $(basename "$0")"
echo "    on $(hostname)"
echo "    for $TARGET_DIR" 
echo "    from  $TARGET_DIR/$DEPLOY_BUILD_DIR"
echo "    successfully done."
echo " "

exit 0

}



main "$@"