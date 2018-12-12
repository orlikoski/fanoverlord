#!/bin/bash
# ----------------------------------------------------------------------------------
# Every 20 seconds this script checks the temperature reported by the ambient temperature sensor,
# and if deemed too high sends the raw IPMI command to adjust the fan speed on the R610 server.
# It also sends healthcheck pings to a healthchecks.io service.
#
#
# Requires:
# ipmitool – apt-get install ipmitool
# slacktee.sh – https://github.com/course-hero/slacktee
# ----------------------------------------------------------------------------------
# Set the state of Emergency (is it too hot or not)
EMERGENCY=false
NOTIFY=true

# IPMI SETTINGS:
# DEFAULT IP: 192.168.0.120
IPMIHOST=${IPMIHOST} # <IP Address of the iDRAC on the Server>
IPMIUSER=${IPMIUSER} # <User for the iDRAC>
IPMIPW=${IPMIPW} # <Password for the iDRAC

# HealthCheck HC_URL
HC_URL=${HC_URL} # <Unique Ping URL component>

# Slacktee Configs
WEBHOOK_URL=${WEBHOOK_URL}
UPLOAD_TOKEN=${UPLOAD_TOKEN}
CHANNEL=${CHANNEL}
TMP_DIR=${TMP_DIR}
USERNAME=${USERNAME}
ICON=${ICON}
ATTACHMENT=${ATTACHMENT}

# Configure Slacktee
sed -i 's#webhook_url=""#webhook_url="'"$WEBHOOK_URL"'"#g' /etc/slacktee.conf
sed -i 's/upload_token=""/upload_token="'"$UPLOAD_TOKEN"'"/g' /etc/slacktee.conf
sed -i 's/channel=""/channel="'"$CHANNEL"'"/g' /etc/slacktee.conf
sed -i 's#tmp_dir=""#tmp_dir="'"$TMP_DIR"'"#g' /etc/slacktee.conf
sed -i 's/username=""/username="'"$USERNAME"'"/g' /etc/slacktee.conf
sed -i 's/icon=""/icon="'"$ICON"'"/g' /etc/slacktee.conf
sed -i 's/attachment=""/attachment="'"$ATTACHMENT"'"/g' /etc/slacktee.conf

# TEMPERATURE
# Change this to the temperature in celcius you are comfortable with.
# If the temperature goes above the set degrees it will send raw IPMI command to enable dynamic fan control
StartMidTemp="29"
MidTemp=( "29" "30" "31" )
HighTemp=( "32" "33" "34" )
MAXTEMP="34"

# Last Octal controls RPM value
# 0b = 2280 RPM
# 0e = 2640 RPM
# 0f = 2760 RPM
# 10 = 3000 RPM
# 1a = 4800 RPM
# 30 = 8880 RPM
# 50 = 14640 RPM

# Default level: 2280 RPM
function FanDefault()
{
  echo "Info: Activating manual fan speeds (2280 RPM)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x0b
}

# Mid-Level: 4800 RPM
function FanMid()
{
  echo "Info: Activating manual fan speeds (4800 RPM)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x1a
}

# High-level: 8800 RPM
function FanHigh()
{
  echo "Info: Activating manual fan speeds (8880 RPM)"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff 0x30
}

# Auto-controled
function FanAuto()
{
  echo "Info: Dynamic fan control Active ($CurrentTemp C)" | /usr/bin/slacktee.sh -t "R610 [$(hostname)]"
  ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x01
}

function gettemp()
{
  TEMP=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW sdr type temperature |grep Ambient |grep degrees |grep -Po '\d{2}' | tail -1)
  echo "$TEMP"
}

function healthcheck()
{
  # healthchecks.io
  curl -fsS --retry 3 $HC_URL >/dev/null 2>&1
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

  healthcheck
  sleep 20
done
