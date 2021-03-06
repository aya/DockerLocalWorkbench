#!/bin/bash
source 'MessageInclude.sh'
###############################################################################
##
##  Purpose:
##    Retrieve a list of component names that comprise the project.  For each
##    component name, determine if the Context associated to a given target
##    type, exists.  If so, generate the target name by concatenating the
##    component name with the provided suffix.
##
##  Input:
##    $1 - Directory path to component directory.
##    $2 - Context path scheme.  A path containing the replaceable keyword
##         "<ComponentName>".
##    $3 - Context suffix value.
## 
##  Output:
##    When Successful:
##      SYSOUT - A list of target names presented as a single row. 
##
###############################################################################
function ContextTargetGen () {
  local -r pathScheme="$2"
  local -r suffixValue="$3"
  local componentName
  local targetNameList=''
  for componentName in `ls -F -- "$1"`
  do
    local directoryContext
    directoryContext="${pathScheme/<ComponentName>/$componentName}"
    if [ -d "$directoryContext" ]; then
      local targetName="${componentName/\//$suffixValue}"
      targetNameList+=" $targetName"
    fi
  done
  echo "${targetNameList:1}"
  return 0
}
###############################################################################
##
##  Purpose:
##    Attempts to replicate a 'make' timestamp comparison between a prerequsite
##    and its target.  
##    
##  Input:
##    $1  - File name of target.
##    $2  - File name of a prerequsite resource to the target
## 
##  Output:
##    0 - true:  target must be rebuilt.
##    1 - false: target need not be rebuilt.
## 
###############################################################################
function TimeStampTripIs () {
  local -r TARGET=`find "$1" -type f -printf '%T@ %p\n' 2> /dev/null | sort -n | tail -1 | awk '{print $1}'`
  local -r PREREQ=`find "$2" -type f -printf '%T@ %p\n' 2> /dev/null | sort -n | tail -1 | awk '{print $1}'`
  # prerequsite or target don't exist, then return true
  if [ -z "$PREREQ" ] || [ -z "$TARGET" ]; then return 0; fi
  # prerequsite older than the target - return false
  if [[ "$PREREQ" > "$TARGET" ]];          then return 1; fi
  # prerequsite same age or younger than target - return true
  return 0
}
###############################################################################
##
##  Purpose:
##    Given a directory, recursively retrive all its subdirectories and 
##    create one long prerequsite line.  The prerequsite includes all
##    nonempty directories and their associated files via the wildcard,
##   '*', specification.
##    
##  Input:
##    $1  - Directory to recurse and return all other directories.
## 
##  Output:
##    When Successful:
##      A single line of all nonempty subdirectories appended with wildcard.
##    When Failure:
##      Issue message to STDERR and return "BuildContextEmpty" as a prerequsite
##      via STDOUT.
## 
###############################################################################
function DirectoryRecurse () {
  local dirPathList
  local fileEntry
  if [ -z "$(ls -A "$1")" ]; then
    ScriptError "Empty build context: '$1'.  Needs at least 'Dockerfile'."
    # generate a prerequsite that references a target that will result in
    # a failure detected by make.
    echo "BuildContextEmpty"
    return 1
  fi
  # use while - read instead of for loop because file name can contain spaces.
  # However, newlines in file names will break this code. 
  while read fileEntry; do
    # Escape spaces in the directory name. Vaccinates make from spaces within
    # prequsite names.
    fileEntry="${fileEntry// /\\ }"
    # include a reference to the directory, as a change to it may reflect
    # a deletion of a subdirectory or file that would not be detected by 
    # simply including its contents appending '/*' wildcard.
    dirPathList+="$fileEntry "
    # An empty directory causes make to fail as it doesn't know how to build
    # nothing, therefore, if a directory is empty ignore it.
    if [ -z "$(ls -A $fileEntry)" ]; then continue; fi
    # Include all the current directory's files as prerequsites.
    dirPathList+="$fileEntry/* "
  done < <( find "$1" -type d )
  echo "$dirPathList"
  return 0
}
###############################################################################
##
##  Purpose:
##    Encapsulates shell methods used within the makefile layer to manage
##    its abstractions/concepts.
##    
##  Input:
##    $1    - Method name.
##    $2-$N - Method argument list. 
## 
###############################################################################
  case "$1" in
    ContextTargetGen)	    ContextTargetGen       "$2" "$3" "$4" ;; 
    TimeStampTripIs)        TimeStampTripIs        "$2" "$3"      ;;
    DirectoryRecurse)       DirectoryRecurse       "$2"           ;;
    *) ScriptUnwind "$LINENO" "Unknown method specified: '$1'"    ;;
  esac
exit $?;
