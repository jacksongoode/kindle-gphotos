#!/bin/sh

PWD=$(pwd)
LOG="/mnt/us/photos.log"
BATTERY_NOTIFY_TRESHOLD=95
SLEEP_MINUTES=5 #24h
FONT="regular=/usr/java/lib/fonts/Caecilia_LT_65_Medium.ttf"
FBINK="fbink -q"

### Uncomment/adjust according to your hardware
# KT
FBROTATE="/sys/devices/platform/imx_epdc_fb/graphics/fb0/rotate"
BACKLIGHT="/dev/null"

# PW3
#FBROTATE="/sys/devices/platform/imx_epdc_fb/graphics/fb0/rotate"
#BACKLIGHT="/sys/devices/platform/imx-i2c.0/i2c-0/0-003c/max77696-bl.0/backlight/max77696-bl/brightness"

# PW2
#FBROTATE="/sys/devices/platform/mxc_epdc_fb/graphics/fb0/rotate"
#BACKLIGHT="/sys/devices/system/fl_tps6116x/fl_tps6116x0/fl_intensity"

wait_wlan_connected() {
  return "$(lipc-get-prop com.lab126.wifid cmState | grep CONNECTED | wc -l)"
}

wait_wlan_ready() {
  return "$(lipc-get-prop com.lab126.wifid cmState | grep -e READY -e PENDING -e CONNECTED | wc -l)"
}

### Dim Backlight
echo -n 0 >$BACKLIGHT

### Prepare Kindle, shutdown framework etc.
echo "------------------------------------------------------------------------" >>$LOG
echo "$(date '+%Y-%m-%d_%H:%M:%S'): Starting up, killing framework et. al." >>$LOG

### Stop processes that we don't need
stop lab126_gui
### Give an update to the outside world...
echo 0 >$FBROTATE
fbink -q -w -c -f -mM -t $FONT,size=18 "Starting photos..." >/dev/null 2>&1
#echo 3 > $FBROTATE
sleep 1

### Keep stopping stuff
stop otaupd
stop phd
stop tmd
stop x
stop todo
stop mcsd
stop archive
stop dynconfig
stop dpmd
stop appmgrd
stop stackdumpd
#stop powerd  ### Otherwise the pw3 is not going to suspend to RAM?
sleep 2

# At this point we should be left with a more or less Amazon-free environment
# I leave
# - powerd & deviced
# - lipc-daemon
# - rcm
# running.

### If we have a wan module installed...
#if [ -f /usr/sbin/wancontrol ]
#then
#    wancontrol wanoffkill
#fi

### Disable Screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 1

echo "$(date '+%Y-%m-%d_%H:%M:%S'): Entering main loop..." >>$LOG

while true; do
  NOW=$(date +%s)

  SLEEP_SECONDS=$((60 * SLEEP_MINUTES))
  WAKEUP_TIME=$((NOW + SLEEP_SECONDS))

  ### Dim Backlight
  echo -n 0 >$BACKLIGHT
  echo "$(date '+%Y-%m-%d_%H:%M:%S'): Wake-up time set for $(date -d @${WAKEUP_TIME})" >>$LOG

  ### Disable CPU Powersave
  echo ondemand >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

  echo 0 >$FBROTATE

  lipc-set-prop com.lab126.cmd wirelessEnable 1
  ### Wait for wifi interface to come up
  echo "$(date '+%Y-%m-%d_%H:%M:%S'): Waiting for wifi interface to come up..." >>$LOG
  while wait_wlan_ready; do
    sleep 1
  done

  ### Wifi interface is up, connect to access point
  ./wifi.sh

  ### Wait for WIFI connection
  TRYCNT=0
  echo "$(date '+%Y-%m-%d_%H:%M:%S'): Waiting for wifi interface to become ready..." >>$LOG
  while wait_wlan_connected; do
    if [ ${TRYCNT} -gt 30 ]; then
      ### Waited long enough
      echo "$(date '+%Y-%m-%d_%H:%M:%S'): No Wifi! ($TRYCNT)" >>$LOG
      $FBINK -o -t $FONT,top=24,left=12 "No WiFi!"
      break
    fi
    sleep 1
    TRYCNT=$((TRYCNT + 1))
  done

  echo "$(date '+%Y-%m-%d_%H:%M:%S'): WIFI connected!" >>$LOG

  BAT=$(gasgauge-info -c | tr -d "%")
  $FBINK -t $FONT,top=12,left=-12 "Fetching new image..."
  ./get_photo.py
  $FBINK -c -f -i photo.jpg -g w=-1,h=-1,dither=PASSTHROUGH

  if [ ${BAT} -lt ${BATTERY_NOTIFY_TRESHOLD} ]; then
    $FBINK -o -t $FONT,top=12,left=12 "$BAT%"
  fi
  echo "$(date '+%Y-%m-%d_%H:%M:%S'): Battery level: $BAT" >>$LOG

  ### Enable powersave
  echo powersave >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

  ### Flight mode on...
  lipc-set-prop com.lab126.cmd wirelessEnable 0

  sleep 2

  ### Set wake up time to calculated time
  echo "$(date '+%Y-%m-%d_%H:%M:%S')": Sleeping now... >>$LOG

  rtcwake -d /dev/rtc1 -m mem -s $SLEEP_SECONDS
  ### Go into Suspend to Memory (STR)
done
