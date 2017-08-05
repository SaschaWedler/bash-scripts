#!/bin/bash
# usage: filter.sh [+|-word] ... < text-file.log
# -: Remove line, if it contains this character sequence.
# +: Remove line, if this character sequence is not found.
filter() {
 local IFS=$'\n' x="" line="" item=""
 while read -r line
    do for item in $@
    do x="${line//${item:1}/}"
       if [ "${item:0:1}" == "+" ]
       then if [ "$x" == "$line" ]
            then continue 2
       fi
       elif [ "${item:0:1}" == "-" ]
       then if [ "$x" != "$line" ]
            then continue 2
       fi
       elif [ "$x" != "$line" ]
       then continue 2
       fi
  done
  echo "$line"
  done
}
filter $@
