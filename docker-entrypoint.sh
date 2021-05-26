#!/bin/bash
# ----------------------------------------------------------------------------------
# Every 20 seconds this script checks the temperature reported by the ambient temperature sensor,
# and if deemed too high sends the raw IPMI command to adjust the fan speed on the R610 server.
# It also sends healthcheck pings to a healthchecks.io service.
#
#
# Requires:
# ipmitool – apt-get install ipmitool
# ----------------------------------------------------------------------------------
# Set the state of Emergency (is it too hot or not)
EMERGENCY=false
NOTIFY=true

CURRENT_MODE=default

# IPMI SETTINGS:
IPMIHOST=${IPMIHOST} # <IP Address of the iDRAC on the Server>
IPMIUSER=${IPMIUSER} # <User for the iDRAC>
IPMIPW=${IPMIPW} # <Password for the iDRAC

# SLEEP SETTING:
SLEEP=${SLEEP}

# TEMPERATURE
# Change this to the temperature in celcius you are comfortable with.
# If the temperature goes above the set degrees it will send raw IPMI command to enable dynamic fan control
# According to iDRAC Min Warning is 42C and Failure (shutdown) is 47C
StartMidTemp="28"
MidTemp=( "28" "29" "30" "31" "32" "33" "34")
HighTemp=( "35" "36" "37" "38" "39" "40" "41" "42")
VeryHighTemp=( "43" "44" "45" "46" "47" "48" "49" "50" )
MAXTEMP="50"



# Last Octal controls values to know
# Query Fan speeds
# ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW sdr type fan
#
# Fan Power Percentages
# 0x00 = 0%
# 0x64 = 100%
#
# R610 RPM values
# 0b = 2280 RPM
# 0e = 2640 RPM
# 0f = 2760 RPM
# 10 = 3000 RPM
# 1a = 4800 RPM
# 20 = 5880 RPM
# 30 = 8880 RPM
# 50 = 14640 RPM

# Default level: 3000 RPM
function FanDefault()
{
  if [ "$CURRENT_MODE" == "default" ] ; then
    echo "Maintaining current mode: $CURRENT_MODE"
    return 0
  fi

  echo "Info: Activating manual fan speeds (3000 RPM)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x10

  CURRENT_MODE=default
}

# Mid-Level: 5880 RPM
function FanMid()
{
  if [ "$CURRENT_MODE" == "mid" ] ; then
    echo "Maintaining current mode: $CURRENT_MODE"
    return 0
  fi

  echo "Info: Activating manual fan speeds (5880 RPM)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x20

  CURRENT_MODE=mid
}

# High-level: 8800 RPM
function FanHigh()
{
  if [ "$CURRENT_MODE" == "high" ] ; then
    echo "Maintaining current mode: $CURRENT_MODE"
    return 0
  fi


  echo "Info: Activating manual fan speeds (8880 RPM)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x30

  CURRENT_MODE=high
}

# Very-High-level: 14640 RPM
function FanVeryHigh()
{
  if [ "$CURRENT_MODE" == "veryhigh" ] ; then
    echo "Maintaining current mode: $CURRENT_MODE"
    return 0
  fi


  echo "Info: Activating manual fan speeds (14640 RPM)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x50

  CURRENT_MODE=veryhigh
}

# Auto-controled
function FanAuto()
{
  if [ "$CURRENT_MODE" == "auto" ] ; then
    echo "Maintaining current mode: $CURRENT_MODE"
    return 0
  fi


  echo "Info: Dynamic fan control Active ($CurrentTemp C)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x01

  CURRENT_MODE=auto
}

function gettemp()
{
  TEMP=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW sdr type temperature |grep -E ^Temp |grep degrees |grep -Po '\d{2}' | tail -1)
  echo "$TEMP"
}

function healthcheck()
{
  if $EMERGENCY; then
    echo "Temperature is NOT OK ($CurrentTemp C). Emergency Status: $EMERGENCY"
  else
    echo "Temperature is OK ($CurrentTemp C). Emergency Status: $EMERGENCY"
  fi
}

# Helper function for does an array contain a this value
array_contains () {
    local array="$1[@]"
    local seeking=$2
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            return 1
        fi
    done
    return 0
}

# Start by setting the fans to default low level
echo "Info: Activating manual fan speeds (2280 RPM)"
ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x0f

while :
do
  CurrentTemp=$(gettemp)
  if [[ $CurrentTemp > $MAXTEMP ]]; then
    EMERGENCY=true
    FanAuto
  fi

  if [[ $CurrentTemp < $StartMidTemp ]]; then
    EMERGENCY=false
    NOTIFY=false
    FanDefault
  fi

  array_contains MidTemp $CurrentTemp
  result=$(echo $?)
  if [ "$result" -eq 1 ] ; then
    EMERGENCY=false
    NOTIFY=false
    FanMid
  fi

  array_contains HighTemp $CurrentTemp
  result=$(echo $?)
  if [ "$result" -eq 1 ] ; then
    EMERGENCY=false
    NOTIFY=false
    FanHigh
  fi

  array_contains VeryHighTemp $CurrentTemp
  result=$(echo $?)
  if [ "$result" -eq 1 ] ; then
    EMERGENCY=false
    NOTIFY=false
    FanVeryHigh
  fi

  healthcheck

  echo "Sleeping for $SLEEP seconds..."
  sleep $SLEEP
