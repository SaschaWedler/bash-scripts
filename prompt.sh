#!/bin/bash
# Usage: prompt.sh
# export PSX=$PS1 PS1='\[\e]0;\u@\h:\w\a\]$(~/bash/prompt.sh)\n\$${USER}@\h:\w: '
# Prepare Sensor Readings ...
#LANG=C
if [ ! -e /etc/debian_version ]
   then echo Error: This script only supports Debian systems. >&2; exit 1
fi
if [ ! -e /usr/bin/sensors ]
   then echo Error: Sensors package not found. Please install the sensors package. >&2; exit 1
fi
findWattSensors() {
  local IFS=$'\n'
    set -- /sys/bus/pci/drivers/*/*/*power*input*
   echo "$*"
}
configureWattSensors() {
  if [ ! -e "/dev/shm/bash-toolbox-power-sensors" ]
     then findWattSensors > "/dev/shm/bash-toolbox-power-sensors"
  fi
  WattSensors="$(</dev/shm/bash-toolbox-power-sensors)"
}
getWattValues() {
    for sensor in $WattSensors
     do echo $(<"$sensor")
   done
}
configureWattSensors
WattValues="$(getWattValues)"
findVoltSensors() {
  local IFS=$'\n'
    set -- /sys/devices/platform/*/hwmon/hwmon*/*in*input*
   echo "$*"
}
configureVoltSensors() {
  if [ ! -e "/dev/shm/bash-toolbox-volt-sensors" ]
     then findVoltSensors > "/dev/shm/bash-toolbox-volt-sensors"
  fi
  VoltSensors="$(</dev/shm/bash-toolbox-volt-sensors)"
}
getVoltValues() {
    for sensor in $VoltSensors
     do echo $(<"$sensor")
   done
}
configureVoltSensors
VoltValues="$(getVoltValues)"
getCPUticks() {
   local stat
    read stat < /proc/stat
    echo ${stat:3}
}
getCPUload() {
      ticks1="$(getCPUticks)"
       sleep 0.05s
      ticks2="$(getCPUticks)"
      total1="$((${ticks1[@]// /+}))"
      total2="$((${ticks2[@]// /+}))"
         set -- $ticks1
       idle1=$4
         set -- $ticks2
       idle2=$4
       total=$((total2 - total1))
        part=$((idle2 - idle1))
          if [ "$part" -gt "0" ]
             then    B=100 # 100=Percentage.
                     R=$((1000000000000000000))
                     U=$(( (R / total) * part ))
                  echo $(( 100 - (U / (R / B)) ))
             else echo 100
          fi
}
CPU_LOAD=$(getCPUload)
getDiskUsage() { searchFieldValue 'total'      +4 $DiskInfo; }
getMemTotal()  { searchFieldValue 'MemTotal:'  +1 $MemInfo; }
getMemFree()   { searchFieldValue 'MemFree:'   +1 $MemInfo; }
getSwapFree()  { searchFieldValue 'SwapFree:'  +1 $MemInfo; }
getSwapTotal() { searchFieldValue 'SwapTotal:' +1 $MemInfo; }
searchFieldValue() {
    for ((i=3; i<$#; i++))
     do if [ "${@:$i:1}" == "$1" ]
           then echo "${@:$[$i + $2]:1}"
           return 0
        fi
   done
 return 1
}
findTemperatureSensors() {
  local IFS=$'\n'
    set -- /sys/devices/platform/*/hwmon/hwmon*/temp*_label
   echo "$*"
}
configureTemperatureSensors() {
  if [ ! -e "/dev/shm/bash-toolbox-temperature-sensors" ]
     then findTemperatureSensors > "/dev/shm/bash-toolbox-temperature-sensors"
  fi
  TemperatureSensors="$(</dev/shm/bash-toolbox-temperature-sensors)"
}
configureTemperatureSensors
findCoreFrequencies() {
  local IFS=$'\n' cores="$(getAvailableCores)"
    set -- /sys/devices/system/cpu/cpu[$cores]/cpufreq/scaling_cur_freq
   echo "$*"
}
getFrequencyValues() {
    for core in $(findCoreFrequencies)
     do echo $(<"$core")
   done
}
getAvailableCores() {
   echo "$(</sys/devices/system/cpu/possible)"
}
getCpuTemperatures() {
    for sensor in $(findTemperatureSensors)
     do local label=$(<"$sensor")
        if [ "$label" == "CPUTIN" ]
           then echo $(<"${sensor:0:-5}input")
        fi
   done
}
getFullyQualifiedTime() {
   echo $(</etc/timezone) $(date '+(%Z, %:z) %Y-%m-%d %H:%M:%S.%N')
}
readSensorData() {
         FullTime="$(getFullyQualifiedTime)"
  FrequencyValues="$(getFrequencyValues)"
         DiskInfo="$(df -PH --total)"
          MemInfo="$(</proc/meminfo)"
          MemFree="$(getMemFree)"
         SwapFree="$(getSwapFree)"
         MemTotal="$(getMemTotal)"
        SwapTotal="$(getSwapTotal)"
  CpuTemperatures="$(getCpuTemperatures)"
# Watt measurement moved to the beginning. Because, the execution of the
# bash script creates a huge increase in power draw, like the sensor enumeration.
# VoltValues="$(getVoltValues)"
# WattValues="$(getWattValues)"
}
computeResults() { # 100=100% RAM ; 300=100% RAM + 2x the RAM size in swap space.
     total=$((MemTotal))
      part=$((MemTotal - MemFree + SwapTotal - SwapFree))
         B=100 # 100=Percentage.
         R=$((1000000000000))
         U=$(( (R / total) * part ))
  MemUsage=$(( (U / (R / B)) ))
}
getMax() {
  local result="-1"
    for item in $@
     do if [ "$item" -gt "$result" ]
           then result="$item"
        fi
   done
   echo "$result"
}
formatFrequencyValues() {
  local data=""
    for value in $@
     do value=$((value / 1000000)).$(((value % 1000000) / 100000))
        while [ "${#value}" -lt "5" ]
           do value="${value}0"
         done
         data="$data ${value:0:5}"
   done
  echo $data
}
formatVoltValues() {
  local data=""
    for value in $@
     do value=$((value / 1000)).$((value % 1000))
        while [ "${#value}" -lt "5" ]
           do value="${value}0"
         done
         data="$data $value"
   done
  echo $data
}
formatWattValues() {
  local data=""
    for value in $@
     do value=$((value / 1000000)).$(((value % 1000000) / 100000))
        while [ "${#value}" -lt "5" ]
           do value="${value}0"
         done
         data="$data ${value:0:5}"
   done
  echo $data
}
formatCpuTemperatures() {
  local data=""
    for value in $@
     do value=$((value / 1000)).$((value % 1000))
        while [ "${#value}" -lt "4" ]
           do value="${value}0"
         done
         data="$data ${value:0:4}"
   done
  echo $data
}
formatOutput() {
  DiskUsage=$(getDiskUsage)
  VoltValues=$(formatVoltValues $VoltValues)
  WattValues=$(formatWattValues $WattValues)
  FrequencyValues=$(formatFrequencyValues $FrequencyValues)
  CpuTemperatures=$(formatCpuTemperatures $CpuTemperatures)
}
getCPUload() {
       sleep 0.05s
      ticks1="$CPU_TICKS"
      ticks2="$(getCPUticks)"
      total1="$((${ticks1[@]// /+}))"
      total2="$((${ticks2[@]// /+}))"
         set -- $ticks1
       idle1=$4
         set -- $ticks2
       idle2=$4
       total=$((total2 - total1))
        part=$((idle2 - idle1))
          if [ "$part" -gt "0" ]
             then    B=100 # 100=Percentage.
                     R=$((1000000000000000000))
                     U=$(( (R / total) * part ))
                  echo $(( 100 - (U / (R / B)) ))
             else echo 100
          fi
}
debugPrintData() { # "$MemInfo"
    for item in "$FullTime" "$FrequencyValues" "$WattValues" "$VoltValues" \
        "$DiskInfo" "$MemTotal" "$MemFree" "$SwapTotal" "$SwapFree" \
        "$MemUsage" "$CpuTemperatures"
     do echo "$item"
   done
}
printOutput() {
  echo "# Time $FullTime"
#  echo "# PCIe $VoltValues Volt"
  echo "# Core ${FrequencyValues//$'\n'/ } GHz"
  echo "# Watt $WattValues Disk ${DiskUsage} Memory ${MemUsage}% Processor ${CPU_LOAD}% (${CpuTemperatures}°C)"
}
# Read sensor data, compute additional data results,
# re-format some values, output formatted data.
readSensorData
computeResults
formatOutput
#debugPrintData
printOutput
