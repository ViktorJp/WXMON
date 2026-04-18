#!/bin/sh

# WXMON 2.2.0 - Asus-Merlin Weather Monitor by Viktor Jaep, 2023/2025
#
# WXMON is a shell script that provides current localized weather information directly from weather.gov and displays
# this information on screen in an SSH dashboard window. Options to expand on the weather forecast to give you more
# detail about the upcoming forecast. Also, capabilities to view aviation-related METAR and TAF forecasts are included.
# This component was originally added to my PWRMON script, which monitors your Tesla Powerwall batteries, solar panels,
# grid and home electrical usage. Having a weather component was useful in determining if upcoming days would yield good
# solar production days. Understanding that many won't be able to make use of this feature, I decided to break this out
# into its own standalone script -- WXMON... a script that demonstrates what's possible with APIs on our routers.
#
# Script last updated: 2026-Apr-17
# -------------------------------------------------------------------------------------------------------------------------

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"
unset LD_LIBRARY_PATH

##-------------------------------------##
## Added by Martinski W. [2026-Apr-13] ##
##-------------------------------------##
[ "$HOME" != "/root" ] && export HOME="/root"
export SCREENDIR="${HOME}/.screen"

# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
version="2.2.0"
beta=0
logfile="/jffs/addons/wxmon.d/wxmon.log"           # Logfile path/name that captures important date/time events - change
apppath="/jffs/scripts/wxmon.sh"                   # Path to the location of wxmon.sh
cfgpath="/jffs/addons/wxmon.d/wxmon.cfg"           # Path to the location of wxmon.cfg
dlverpath="/jffs/addons/wxmon.d/version.txt"       # Path to downloaded version from the source repository
WANwxforecast="/jffs/addons/wxmon.d/WANwx.txt"     # Path to US-only weather forecast JSON extract used for weather displays
WANwx2forecast="/jffs/addons/wxmon.d/WANwx2.txt"   # Path to global weather forecast JSON extract used for weather displays
logsize=2000                                       # Number of lines allowed in log file
hideoptions=1                                      # Variable to determine if operations menu is shown
prevHideOpts=X                                     # Operations menu variable
Interval=360                                       # Default interval time in minutes between weather forecast refreshes
FromUI=0                                           # Variable to determine if wxmon is launched from command or ui
UnitMeasure=1                                      # Default unit of measure (imperial vs metric)
WXService=1                                        # Default weather service
aviationwx="Disabled"                              # Default setting for aviation weather
icaoairportcode="KLAX"                             # Default ICAO airport code for aviation weather lookups
ProgPref=0                                         # Default progress bar (bar vs minimalist)
AVWXPage=0                                         # Variable to determine if aviation weather page is active

# Color variables
CBlack="\e[1;30m"
InvBlack="\e[1;40m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CDkGray="\e[1;90m"
InvDkGray="\e[1;100m"
InvLtGray="\e[1;47m"
CYellow="\e[1;33m"
InvYellow="\e[1;43m"
CBlue="\e[1;34m"
InvBlue="\e[1;44m"
CMagenta="\e[1;35m"
CCyan="\e[1;36m"
InvCyan="\e[1;46m"
CWhite="\e[1;37m"
InvWhite="\e[1;107m"
CClear="\e[0m"

# To support automatic script updates from AMTM #
doScriptUpdateFromAMTM=true

# -------------------------------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------------------------------

# LogoNM and LogoNMexit is a function that displays the WXMON script name in a cool ASCII font

logoNM ()
{

  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CDkGray}                        _       ___  __ __  _______  _   __"
  echo -e "                       | |     / / |/ //  |/  / __ \/ | / /"
  echo -e "                       | | /| / /|   // /|_/ / / / /  |/ /"
  echo -e "                       | |/ |/ //   |/ /  / / /_/ / /|  /"
  echo -e "                       |__/|__//_/|_/_/  /_/\____/_/ |_/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ INITIALIZING ]     ${CClear}"
  sleep 2
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CYellow}                        _       ___  __ __  _______  _   __"
  echo -e "                       | |     / / |/ //  |/  / __ \/ | / /"
  echo -e "                       | | /| / /|   // /|_/ / / / /  |/ /"
  echo -e "                       | |/ |/ //   |/ /  / / /_/ / /|  /"
  echo -e "                       |__/|__//_/|_/_/  /_/\____/_/ |_/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}[ INITIALIZING ... DONE ]${CClear}"
  sleep 1
  printf "\r                            ${CGreen}      [ LOADING... ]     ${CClear}"
  sleep 2

}

logoNMexit ()
{

  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CYellow}                        _       ___  __ __  _______  _   __"
  echo -e "                       | |     / / |/ //  |/  / __ \/ | / /"
  echo -e "                       | | /| / /|   // /|_/ / / / /  |/ /"
  echo -e "                       | |/ |/ //   |/ /  / / /_/ / /|  /"
  echo -e "                       |__/|__//_/|_/_/  /_/\____/_/ |_/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ SHUTTING DOWN ]     ${CClear}"
  sleep 2
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CDkGray}                        _       ___  __ __  _______  _   __"
  echo -e "                       | |     / / |/ //  |/  / __ \/ | / /"
  echo -e "                       | | /| / /|   // /|_/ / / / /  |/ /"
  echo -e "                       | |/ |/ //   |/ /  / / /_/ / /|  /"
  echo -e "                       |__/|__//_/|_/_/  /_/\____/_/ |_/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ SHUTTING DOWN ]     ${CClear}"
  sleep 1
  printf "\r                            ${CDkGray}      [ GOODBYE... ]     ${CClear}\n\n"
  sleep 2

}

# -------------------------------------------------------------------------------------------------------------------------
# promptyn takes input for Y/N questions
promptyn ()
{

  while true; do
    read -p "$1 [y/n]? " YESNO
      case "$YESNO" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\nPlease answer y or n.";;
      esac
  done

}

# -------------------------------------------------------------------------------------------------------------------------
# Spinner is a script that provides a small indicator on the screen to show script activity
spinner ()
{

  spins=$1

  spin=0
  totalspins=$((spins / 4))
  while [ $spin -le $totalspins ]; do
    for spinchar in / - \\ \|; do
      printf "\r$spinchar"
      sleep 1
    done
    spin=$((spin+1))
  done

  printf "\r"

}

##-------------------------------------------##
## Borrwed from ExtremeFiretop [2026-Apr-11] ##
##-------------------------------------------##
ScriptUpdateFromAMTM()
{
    if ! "$doScriptUpdateFromAMTM"
    then
        printf "Automatic script updates via AMTM are currently disabled.\n\n"
        return 1
    fi

    if [ $# -gt 0 ] && [ "$1" = "check" ]
    then return 0
    fi

    # Force a BACKUPMON download and update
    echo -e "${CClear}[i] Force Downloading WXMON... Please stand by..."
    curl --silent --fail --retry 3 "https://raw.githubusercontent.com/ViktorJp/WXMON/main/wxmon.sh" -o "/jffs/scripts/wxmon.sh" && chmod 755 "/jffs/scripts/wxmon.sh"

    DLsuccess=$?
    if [ "$DLsuccess" -eq 0 ]; then
      echo -e "${CClear}[i] WXMON Download/Update Success."
    else
      echo -e "${CClear}[X] WXMON Download/Update Failed."
    fi

    return "$DLsuccess"
}

# -------------------------------------------------------------------------------------------------------------------------
# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity
preparebar()
{
  # $1 - bar length
  # $2 - bar char
  #printf "\n"
  barlen=$1
  barspaces=$(printf "%*s" "$1")
  barchars=$(printf "%*s" "$1" | tr ' ' "$2")
}

# Had to make some mods to the variables being passed, and created an inverse colored progress bar
progressbar()
{
  # $1 - number (-1 for clearing the bar)
  # $2 - max number
  # $3 - system name
  # $4 - measurement
  # $5 - standard/reverse progressbar
  # $6 - alternate display values
  insertspc=" "

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    barch=$(($1*barlen/$2))
    barsp=$((barlen-barch))
    progr=$((100*$1/$2))
    mins=$(awk -v new=$1 -v secs=60 'BEGIN{printf "%08.3f\n", new/secs}')
    progrdet=$(awk -v new=100 -v old=$1 -v tots=$2 'BEGIN{printf "%06.2f\n", new*old/tots}')

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      if [ $progr -le 60 ]; then
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$mins${4} / ${progrdet}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 60 ] && [ $progr -le 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$mins${4} / ${progrdet}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$mins${4} / ${progrdet}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ "$5" == "Reverse" ]; then
      if [ $progr -le 35 ]; then
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$mins${4} / ${progrdet}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 35 ] && [ $progr -le 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$mins${4} / ${progrdet}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$mins${4} / ${progrdet}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    fi
  fi

}

progressbaroverride()
{
  # $1 - number (-1 for clearing the bar)
  # $2 - max number
  # $3 - system name
  # $4 - measurement
  # $5 - standard/reverse progressbar
  # $6 - alternate display values

  insertspc=" "

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    barch=$(($1*barlen/$2))
    barsp=$((barlen-barch))
    progr=$((100*$1/$2))
    mins=$(awk -v new=$1 -v secs=60 'BEGIN{printf "%08.3f\n", new/secs}')
    progrdet=$(awk -v new=100 -v old=$1 -v tots=$2 'BEGIN{printf "%06.2f\n", new*old/tots}')

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      printf "  ${CWhite}${InvDkGray}$mins${4} / ${progrdet}%%\r${CClear}" "$barchars" "$barspaces"
    fi
  fi

}

##-------------------------------------##
## Added by Martinski W. [2024-Oct-05] ##
##-------------------------------------##
_SetLAN_HostName_()
{
   [ -z "${LAN_HostName:+xSETx}" ] && \
   LAN_HostName="$($timeoutcmd$timeoutsec nvram get lan_hostname)"
}

_GetLAN_HostName_()
{ _SetLAN_HostName_ ; echo "$LAN_HostName" ; }


# -------------------------------------------------------------------------------------------------------------------------
# This function was "borrowed" graciously from @dave14305 from his FlexQoS script to determine the active WAN connection.
# Thanks much for your troubleshooting help as we tackled how to best derive the active WAN interface, Dave!

get_wan_setting()
{

  local varname varval
  varname="${1}"
  prefixes="wan0_ wan1_"

  if [ "$($timeoutcmd$timeoutsec nvram get wans_mode)" = "lb" ] ; then
      for prefix in $prefixes; do
          state="$($timeoutcmd$timeoutsec nvram get "${prefix}"state_t)"
          sbstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"sbstate_t)"
          auxstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"auxstate_t)"

          # is_wan_connect()
          [ "${state}" = "2" ] || continue
          [ "${sbstate}" = "0" ] || continue
          [ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

          # get_wan_ifname()
          proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
          if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
          else
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
          fi
      done
  else
      for prefix in $prefixes; do
          primary="$($timeoutcmd$timeoutsec nvram get "${prefix}"primary)"
          [ "${primary}" = "1" ] && break
      done

      proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
      if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
      else
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
      fi
  fi
  printf "%s" "${varval}"

}

# -------------------------------------------------------------------------------------------------------------------------
# weathercheck is a function that downloads the latest weather for your WAN IP location
weathercheck ()
{

  clear
  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting Interface]...   "

  # Get the WAN interface in order to check for the public WAN IP address
  WANIFNAME=$(get_wan_setting ifname)
  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting WAN IP]...      "
  WANIP=$(curl --silent --fail --interface $WANIFNAME --request GET --url https://ipv4.icanhazip.com)
  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting WAN City]...    "
  WANCITY=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .city)

  if [ "$Long" == "0" ] || [ "$Long" == "" ] && [ "$Lat" == "0" ] || [ "$Lat" == "" ]; then
	  # Get the latitute/longitude of the public WAN IP address
	  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting Long/Lat]...    "
	  WANlat=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lat)
	  WANlon=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lon)
	else
	  WANlat="$Lat"
	  WANlon="$Long"
	  WANCITY="Manual"
	fi

  # Test Display the city, lat and long
  #WANCITY="Atlanta"
  #WANIP="123.231.31.12"
  #WANlat=33.8348
  #WANlon=-84.5893

  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Downloading WX Feeds]..."
  # Get the Weather grid for the latitude/longitude
  WANgridurl=$(curl --silent --retry 3 --request GET --url https://api.weather.gov/points/$WANlat,$WANlon | jq --raw-output .properties.forecast)
  
  # Extract the weather JSON to a text file in order to query from it with JQ
  curl --silent --retry 3 --request GET --url $WANgridurl | jq . --raw-output > $WANwxforecast
  LINES=$(cat $WANwxforecast | wc -l) #Check to see how many lines are in this file

  if [ $LINES -eq 0 ] #If there are no lines, error out
  then
    echo ""
    echo -e "\n${CRed} [Error: Unable to download weather.gov weather data or location is non-US based. Try again later...]\n${CClear}"
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - ERROR: Unable to fetch weather.gov weather data. May be a temporary issue. Try again later." >> $logfile

    sleep 3
    exit 0
  fi

  printf "\r${CClear}"
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""

  echo -e "${InvDkGray}${CWhite} Location                                                                                                                    ${CClear}"
  echo ""
  echo -e "${InvGreen} ${CClear}${CWhite} WAN IP: ${CGreen}$WANIP  ${CWhite}|  Location: ${CGreen}$WANCITY  ${CWhite}|  Latitude: ${CGreen}$WANlat  ${CWhite}/  Longitude: ${CGreen}$WANlon"
  echo ""
  echo -e "${InvDkGray}${CWhite} Forecast                                                                                                                    ${CClear}"
  echo ""

  # Loop through the forecasts and display them
  i=0
  while [ $i -ne 6 ]
    do

      WANwxName=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].name | select( . != null )')
      WANwxTemp=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].temperature | select( . != null )')
      WANwxTempUnit=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].temperatureUnit | select( . != null )')
      WANwxWind=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].windSpeed | select( . != null )')
      WANwxWindDir=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].windDirection | select( . != null )')
      WANwxShort=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].shortForecast | select( . != null )')
      WANwxDetail=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].detailedForecast | select( . != null )')
      WANwxShortTrim=$(echo $WANwxShort | sed -e 's/.\{65\} /&\n/g')
      WANwxDetailTrim=$(echo $WANwxDetail | sed -e 's/.\{65\} /&\n/g')

      echo -e "${InvGreen} ${CClear}${CWhite} Day: ${CGreen}$WANwxName  ${CWhite}|  Temp: ${CGreen}$WANwxTemp$WANwxTempUnit  ${CWhite}|  Wind: ${CGreen}$WANwxWind from $WANwxWindDir  ${CWhite}|"
      echo -e "${InvGreen} ${CClear}${CDkGray}  |---${CWhite}Conditions: ${CClear}$WANwxShortTrim"
      echo ""

      i=$(($i+1))

    done

  echo -e "${CWhite}(M)${CGreen}ore Detail?"
  echo ""

}

# -------------------------------------------------------------------------------------------------------------------------
# weathercheckext is a function that displays the latest extended weather forecast for your WAN IP location
weathercheckext ()
{

  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader

  echo ""
  echo -e "${InvDkGray}${CWhite} Extended Forecast                                                                                                           ${CClear}"
  echo ""

  # Loop through the forecasts and display them
  i=0
  while [ $i -ne 6 ]
    do

      WANwxName=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].name | select( . != null )')
      WANwxDetail=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].detailedForecast | select( . != null )')
      WANwxDetailTrim=$(echo $WANwxDetail | sed -e 's/.\{115\} /&\n/g')

  echo -e "${InvGreen} ${CClear}${CWhite} Day: ${CGreen}$WANwxName"
  echo -e "${CClear}$WANwxDetailTrim"
  echo ""

  i=$(($i+1))

  done

  echo -e "${CWhite}(R)${CGreen}eturn to your regular scheduled forecast!"
  echo ""

}

# -------------------------------------------------------------------------------------------------------------------------
# weathercheck is a function that downloads the latest weather for your WAN IP location
worldweathercheck ()
{

  clear
  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting Interface]...   "


  # Get the WAN interface in order to check for the public WAN IP address
  WANIFNAME=$(get_wan_setting ifname)
  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting WAN IP]...      "
  WANIP=$(curl --silent --fail --interface $WANIFNAME --request GET --url https://ipv4.icanhazip.com)
  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting WAN City]...    "
  WANCITY=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .city)

  if [ "$Long" == "0" ] || [ "$Long" == "" ] && [ "$Lat" == "0" ] || [ "$Lat" == "" ]; then
	  # Get the latitute/longitude of the public WAN IP address
	  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting Long/Lat]...    "
	  WANlat=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lat)
	  WANlon=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lon)
  else
    WANlat="$Lat"
    WANlon="$Long"
    WANCITY="Manual"
  fi

  # Test Display the city, lat and long
  #WANCITY="Atlanta"
  #WANIP="123.231.31.12"
  #WANlat=33.8348
  #WANlon=-84.5893

  if [ "$UnitMeasure" == "0" ]; then
    tempunits="fahrenheit"
    tempunitsabbr="F"
    windunits="mph"
  elif [ "$UnitMeasure" == "1" ]; then
    tempunits="celsius"
    tempunitsabbr="C"
    windunits="kmh"
  fi

  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Downloading WX Feeds]..."
  # Extract weather based on lat/long to a file
  curl --silent --retry 3 --request GET --url 'https://api.open-meteo.com/v1/forecast?latitude='$WANlat'&longitude='$WANlon'&temperature_unit='$tempunits'&windspeed_unit='$windunits'&daily=weathercode,temperature_2m_max,temperature_2m_min,winddirection_10m_dominant,windspeed_10m_max,windgusts_10m_max&past_days=0&timezone=auto' | jq > $WANwx2forecast

  # Extract the weather JSON to a text file in order to query from it with JQ
  LINES=$(cat $WANwx2forecast | wc -l) #Check to see how many lines are in this file

  if [ $LINES -eq 0 ] #If there are no lines, error out
  then
    echo -e "\n${CRed} [Error: Unable to download open-meteo.com weather data. Try again later...]\n${CClear}"
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - ERROR: Unable to fetch open-meteo.com weather data. May be a temporary issue. Try again later." >> $logfile
    sleep 3
    exit 0
  fi

  printf "\r${CClear}"
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""
  echo -e "${InvDkGray}${CWhite} Location                                                                                                                    ${CClear}"
  echo ""
  echo -e "${InvGreen} ${CClear}${CWhite} WAN IP: ${CGreen}$WANIP  ${CWhite}|  Location: ${CGreen}$WANCITY  ${CWhite}|  Latitude: ${CGreen}$WANlat  ${CWhite}/  Longitude: ${CGreen}$WANlon"
  echo ""
  echo -e "${InvDkGray}${CWhite} Forecast                                                                                                                    ${CClear}"
  echo ""

  # Loop through the forecasts and display them
  i=2
  while [ $i -ne 9 ]
    do

      WANwxDay=$(cat $WANwx2forecast| jq .daily.time | tr -d '[]", ' | sed -n $i'p')
      WANwxTempMin=$(cat $WANwx2forecast | jq .daily.temperature_2m_min | tr -d '[]", ' | sed -n $i'p' | cut -d . -f 1)
      WANwxTempMax=$(cat $WANwx2forecast | jq .daily.temperature_2m_max | tr -d '[]", ' | sed -n $i'p' | cut -d . -f 1)
      WANwxWind=$(cat $WANwx2forecast | jq .daily.windspeed_10m_max | tr -d '[]", ' | sed -n $i'p')
      WANwxWindGust=$(cat $WANwx2forecast | jq .daily.windgusts_10m_max | tr -d '[]", ' | sed -n $i'p')
      WANwxWindDir=$(cat $WANwx2forecast | jq .daily.winddirection_10m_dominant | tr -d '[]", ' | sed -n $i'p')
      WANwxCode=$(cat $WANwx2forecast | jq .daily.weathercode | tr -d '[]", ' | sed -n $i'p')

      if [ $WANwxWindDir -ge 337 ] || [ $WANwxWindDir -le 22 ]; then WANwxWindCompass="N"
        elif [ $WANwxWindDir -ge 293 ] && [ $WANwxWindDir -le 336 ]; then WANwxWindCompass="NW"
        elif [ $WANwxWindDir -ge 248 ] && [ $WANwxWindDir -le 292 ]; then WANwxWindCompass="W"
        elif [ $WANwxWindDir -ge 203 ] && [ $WANwxWindDir -le 247 ]; then WANwxWindCompass="SW"
        elif [ $WANwxWindDir -ge 158 ] && [ $WANwxWindDir -le 202 ]; then WANwxWindCompass="S"
        elif [ $WANwxWindDir -ge 113 ] && [ $WANwxWindDir -le 157 ]; then WANwxWindCompass="SE"
        elif [ $WANwxWindDir -ge 68 ] && [ $WANwxWindDir -le 112 ]; then WANwxWindCompass="E"
        elif [ $WANwxWindDir -ge 23 ] && [ $WANwxWindDir -le 67 ]; then WANwxWindCompass="NE"
      fi

      echo -e "${InvGreen} ${CClear}${CWhite} Day: ${CGreen}$WANwxDay  ${CWhite}|  Max Wind: ${CGreen}$WANwxWind $windunits from $WANwxWindCompass  ${CWhite}|  Gusts: ${CGreen}$WANwxWindGust $windunits  ${CWhite}|  Temp Lo: ${CGreen}$WANwxTempMin$tempunitsabbr ${CWhite}Hi: ${CGreen}$WANwxTempMax$tempunitsabbr"

  #Decipher weathercodes
      if [ "$WANwxCode" == "0" ]; then WANwxCodeShort="Clear Skies"
        elif [ "$WANwxCode" == "1" ]; then WANwxCodeShort="Mainly Clear"
        elif [ "$WANwxCode" == "2" ]; then WANwxCodeShort="Partly Cloudy"
        elif [ "$WANwxCode" == "3" ]; then WANwxCodeShort="Overcast"
        elif [ "$WANwxCode" == "45" ]; then WANwxCodeShort="Fog"
        elif [ "$WANwxCode" == "48" ]; then WANwxCodeShort="Depositing Rime Fog"
        elif [ "$WANwxCode" == "51" ]; then WANwxCodeShort="Light Drizzle"
        elif [ "$WANwxCode" == "53" ]; then WANwxCodeShort="Moderate Drizzle"
        elif [ "$WANwxCode" == "55" ]; then WANwxCodeShort="Dense Drizzle"
        elif [ "$WANwxCode" == "56" ]; then WANwxCodeShort="Light Freezing Drizzle"
        elif [ "$WANwxCode" == "57" ]; then WANwxCodeShort="Dense Freezing Drizzle"
        elif [ "$WANwxCode" == "61" ]; then WANwxCodeShort="Slight Rain"
        elif [ "$WANwxCode" == "63" ]; then WANwxCodeShort="Moderate Rain"
        elif [ "$WANwxCode" == "65" ]; then WANwxCodeShort="Heavy Rain"
        elif [ "$WANwxCode" == "66" ]; then WANwxCodeShort="Light Freezing Rain"
        elif [ "$WANwxCode" == "67" ]; then WANwxCodeShort="Heavy Freezing Rain"
        elif [ "$WANwxCode" == "71" ]; then WANwxCodeShort="Slight Snow Fall"
        elif [ "$WANwxCode" == "73" ]; then WANwxCodeShort="Moderate Snow Fall"
        elif [ "$WANwxCode" == "75" ]; then WANwxCodeShort="Heavy Snow Fall"
        elif [ "$WANwxCode" == "77" ]; then WANwxCodeShort="Snow Grains"
        elif [ "$WANwxCode" == "80" ]; then WANwxCodeShort="Slight Rain Showers"
        elif [ "$WANwxCode" == "81" ]; then WANwxCodeShort="Moderate Rain Showers"
        elif [ "$WANwxCode" == "82" ]; then WANwxCodeShort="Violent Rain Showers"
        elif [ "$WANwxCode" == "85" ]; then WANwxCodeShort="Slight Snow Showers"
        elif [ "$WANwxCode" == "86" ]; then WANwxCodeShort="Heavy Snow Showers"
        elif [ "$WANwxCode" == "95" ]; then WANwxCodeShort="Thunderstorms"
        elif [ "$WANwxCode" == "96" ]; then WANwxCodeShort="Thunderstorms with Light Hail"
        elif [ "$WANwxCode" == "99" ]; then WANwxCodeShort="Thunderstorms with Heavy Hail"
      else
        WANwxCodeShort="Conditions Unknown"
      fi

      echo -e "${InvGreen} ${CClear}${CDkGray}  |---${CWhite}Conditions: ${CGreen}$WANwxCodeShort"
      echo ""
      i=$(($i+1))

    done

}

# -------------------------------------------------------------------------------------------------------------------------
# aviationweathercheck is a function that displays the latest aviation weather forecast for your ICAO airport code
aviationweathercheck ()
{

  clear
  if [ $aviationwx == "Disabled" ]; then
    echo ""
    echo -e "${CGreen}[Aviation Weather is disabled. Please enable it in the Config menu.]"
    echo ""
    sleep 2
    weathercheck
    return
  fi

  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Downloading WX Feeds]..."

  #Delete any current weather files
  rm -f /jffs/addons/wxmon.d/wxmetar.txt
  rm -f /jffs/addons/wxmon.d/wxtaf.txt

  curl --silent --retry 3 --request GET --url 'https://aviationweather.gov/api/data/metar?ids='$icaoairportcode'&format=xml&hours=3' > /jffs/addons/wxmon.d/wxmetar.txt

  if [ -f /jffs/addons/wxmon.d/wxmetar.txt ]; then
    FlightRules=$(cat /jffs/addons/wxmon.d/wxmetar.txt | sed -n 's:.*<flight_category>\(.*\)</flight_category>.*:\1:p' | sed -n '1p') 2>&1
    CurrMETAR=$(cat /jffs/addons/wxmon.d/wxmetar.txt | sed -n 's:.*<raw_text>\(.*\)</raw_text>.*:\1:p' | sed -n '1p') 2>&1
    CurrMETARTrim=$(echo $CurrMETAR | sed -e 's/.\{115\} /&\n/g')
    if [ "$FlightRules" == "Null" ]; then FlightRules="Unknown - Error getting weather"; fi
    if [ "$CurrMETAR" == "Null" ]; then CurrMETARTrim="Unknown - Error getting weather"; fi
  else
    FlightRules="Unknown - Error getting weather"
    CurrMETARTrim="Unknown - Error getting weather"
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - ERROR: Unable to fetch aviationweather.gov weather data. May be a temporary issue. Try again later." >> $logfile
  fi

  curl --silent --retry 3 --request GET --url 'https://aviationweather.gov/api/data/taf?ids='$icaoairportcode'&format=xml&hours=3' > /jffs/addons/wxmon.d/wxtaf.txt

  if [ -f /jffs/addons/wxmon.d/wxtaf.txt ]; then
    CurrTAF=$(cat /jffs/addons/wxmon.d/wxtaf.txt | sed -n 's:.*<raw_text>\(.*\)</raw_text>.*:\1:p' | sed -n '1p') 2>&1
    CurrTAFTrim=$(echo $CurrTAF | sed -e 's/.\{115\} /&\n/g')
    if [ "$CurrTAF" == "Null" ]; then CurrTAFTrim="Unknown - Error getting weather"; fi
  else
    CurrTAFTrim="Unknown - Error getting weather"
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - ERROR: Unable to fetch aviationweather.gov weather data. May be a temporary issue. Try again later." >> $logfile
  fi

  printf "\r${CClear}"
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""
  echo -e "${InvDkGray}${CWhite} $icaoairportcode Flight Rules                                                                                                           ${CClear}"
  echo ""
  echo -e "${InvGreen} ${CClear}${CWhite} Current Conditions: ${CGreen}$FlightRules"
  echo ""
  echo -e "${InvDkGray}${CWhite} $icaoairportcode METAR                                                                                                                  ${CClear}"
  echo ""
  echo -e "${CClear}$CurrMETARTrim"
  echo ""
  echo -e "${InvDkGray}${CWhite} $icaoairportcode TAF                                                                                                                    ${CClear}"
  echo ""
  echo -e "${CClear}$CurrTAFTrim"
  echo ""
  echo ""
  echo -e "${CWhite}(R)${CGreen}eturn to standard forecast?${CClear}"
  echo ""

}

# -------------------------------------------------------------------------------------------------------------------------
# wttrcheck is a function that utilizes the wttr.in graphical weather product
wttrcheck ()
{

  clear
  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting Interface]...   "

  if [ "$Long" == "0" ] || [ "$Long" == "" ] && [ "$Lat" == "0" ] || [ "$Lat" == "" ]; then
	  # Get the WAN interface in order to check for the public WAN IP address
	  WANIFNAME=$(get_wan_setting ifname)
	  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting WAN IP]...      "
	  WANIP=$(curl --silent --fail --interface $WANIFNAME --request GET --url https://ipv4.icanhazip.com)
	
	  # Get the latitute/longitude of the public WAN IP address
	  printf "\r${InvGreen} ${CClear} WX STATUS: ${CGreen} [Getting Long/Lat]...    "
	  WANlat=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lat)
	  WANlon=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lon)
  else
    WANlat="$Lat"
    WANlon="$Long"
  fi

  # Test Display the city, lat and long
  #WANCITY="Atlanta"
  #WANIP="123.231.31.12"
  #WANlat=33.8348
  #WANlon=-84.5893

  if [ "$UnitMeasure" == "0" ]; then
    unitsabbr="u"
  elif [ "$UnitMeasure" == "1" ]; then
    unitsabbr="m"
  fi

  printf "\r${CClear}"
  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""
  curl --silent --retry 5 --request GET --url 'wttr.in/'$WANlat','$WANlon'?dF'$unitsabbr
  WRC=$?
  if [ $WRC -ne 0 ]; then  # If mount come back successful, then proceed
    echo -e "\n${CRed} [Error: Unable to download wttr.in weather data. Try again later...]\n${CClear}"
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - ERROR: Unable to fetch wttr.in weather data. May be a temporary issue. Try again later." >> $logfile
  fi
  echo ""

}

# -------------------------------------------------------------------------------------------------------------------------
# updatecheck is a function that downloads the latest update version file, and compares it with what's currently installed
updatecheck ()
{

  # Download the latest version file from the source repository
  curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/WXMON/master/version.txt" -o "/jffs/addons/wxmon.d/version.txt"

  if [ -f $dlverpath ]
    then
      # Read in its contents for the current version file
      DLversion=$(cat $dlverpath)

      # Compare the new version with the old version and log it
      if [ "$beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLversion" != "$version" ]; then
        DLversionPF=$(printf "%-8s" $DLversion)
        versionPF=$(printf "%-8s" $version)
        UpdateNotify="${InvYellow} ${InvDkGray}${CWhite} Update available: v$versionPF -> v$DLversionPF                                                                                   ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: A new update (v$DLversion) is available to download" >> $logfile
      else
        UpdateNotify=0
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# vlogs is a function that calls the nano text editor to view the wxmon log file
vlogs()
{

  export TERM=linux
  nano +999999 --linenumbers $logfile

}

# -------------------------------------------------------------------------------------------------------------------------
# trimlogs will cut down log size (in rows) based on custom value

trimlogs()
{

  currlogsize=$(wc -l $logfile | awk '{ print $1 }' ) >/dev/null 2>&1

  if [ "$currlogsize" -gt "$logsize" ] # If it's bigger than the max allowed, tail/trim it!
    then
      echo "$(tail -$logsize $logfile)" > $logfile
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: Trimmed the log file down to $logsize lines" >> $LOGFILE
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# validate_coord is a function that checks to make a coordinate entry is formatted correctly
validate_coord() {
    echo "$1" | grep -qE '^-?[0-9]+\.[0-9]{4}$'
}

# -------------------------------------------------------------------------------------------------------------------------
# vconfig is a function that guides you through the various configuration options for wxmon
vconfig ()
{

  if [ -f $cfgpath ]; then #Making sure file exists before proceeding
    source $cfgpath

    while true; do

      if [ "$UnitMeasure" == "0" ]
      then
        UnitMeasureDisplay="Imperial"
      elif [ "$UnitMeasure" == "1" ]
      then
        UnitMeasureDisplay="Metric"
      fi

      if [ "$WXService" == "0" ]
      then
        WXServiceDisplay="Text/US-Only"
      elif [ "$WXService" == "1" ]
      then
        WXServiceDisplay="Text/Global"
      elif [ "$WXService" == "2" ]
      then
        WXServiceDisplay="Graphical/Global"
      fi

      if [ "$ProgPref" == "0" ]
      then
        ProgPrefDisplay="Progress Bar"
      elif [ "$ProgPref" == "1" ]
      then
        ProgPrefDisplay="Minimalist"
      fi
      
      if [ "$Long" == "0" ] || [ "$Long" == "" ] && [ "$Lat" == "0" ] || [ "$Lat" == "" ]; then
      	LongLatDisp="${CDkGray}OFF"
      else
        LongLatDisp="${CGreen}$Long,$Lat"
      fi

      clear
      echo -e "${InvGreen} ${InvDkGray}${CWhite} WXMON Configuration Options                                                           ${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to modify certain${CClear}"
      echo -e "${InvGreen} ${CClear} customizable parameters that affect the operation of this script.${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Refresh Interval (minutes)                   : ${CGreen}$Interval"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Manual Location Coordinates?                 : $LongLatDisp"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Units of Measurement (Imperial/Metric)       : ${CGreen}$UnitMeasureDisplay"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : Weather Service?                             : ${CGreen}$WXServiceDisplay"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(5)${CClear} : Enable Aviation WX?                          : ${CGreen}$aviationwx"
      if [ "$aviationwx" == "Enabled" ]; then
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} |-${CClear} :   ICAO Airport Code                          : ${CGreen}$icaoairportcode"
      else
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} |-${CClear}${CDkGray} :   ICAO Airport Code                          : N/A"
      fi
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(6)${CClear} : Progress Bar Preference?                     : ${CGreen}$ProgPrefDisplay"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit & Save Changes${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo ""
      read -p "Please select? (1-6, e=Exit): " SelectSlot
      case $SelectSlot in

            1) #---------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Refresh Interval                                                                      ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate after how many minutes you would like WXMON to refresh your weather${CClear}"
              echo -e "${InvGreen} ${CClear} information?${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 360)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo
              echo -e "${CClear}Current (minutes): ${CGreen}$Interval${CClear}" ; echo
              read -p "Please enter value in minutes? (1-9999, e=Exit): " Interval1

              if [ "$Interval1" = "e" ]
              then
                  echo -e "\n[Exiting]"; sleep 2
              elif echo "$Interval1" | grep -qE "^(1|[1-9][0-9]{0,3})$" && \
                  [ "$Interval1" -ge 1 ] && [ "$Interval1" -le 9999 ]
              then
                  Interval="$Interval1"
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Refresh Interval Configured (in minutes): $Interval" >> $logfile
                  saveconfig
              else
                  previousValue="$Interval"
                  Interval="${Interval:=360}"
                  [ "$Interval" != "$previousValue" ] && \
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Refresh Interval Configured (in minutes): $Interval" >> $logfile
                  saveconfig
              fi
            ;;

            2) #---------------------------------------------------------------------------------
              if [ "$Long" == "0" ] || [ "$Long" == "" ] && [ "$Lat" == "0" ] || [ "$Lat" == "" ]; then
                LongLatDisp="${CDkGray}OFF"
              else
                LongLatDisp="${CGreen}$Long,$Lat"
              fi

              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Manual Location Coordinates                                                           ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate below if you would rather use your own longitude and latitude rather${CClear}"
              echo -e "${InvGreen} ${CClear} weather coordinates? Normally, WXMON will find your approximate location by using${CClear}"
              echo -e "${InvGreen} ${CClear} the nearest location based on your WAN IP address. Sometimes this is not accurate.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = OFF)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo
              echo -e "${CClear}Current Coordinates (Long/Lat): ${CGreen}$LongLatDisp${CClear}" ; echo
              read -p "Please enter Longitude value (ex: -117.9698)? (0=off, e=Exit): " Long1
              if [ "$Long1" = "e" ]; then
                  echo -e "\n[Exiting]"; sleep 2
              elif [ "$Long1" = "0" ]; then
                  Long=0
                  Lat=0
                  saveconfig
              elif ! validate_coord "$Long1"; then
                  echo -e "\n${CRed}[ERROR] Invalid Longitude. Must have at least 1 digit before and exactly 4 digits after a decimal point (ex: -117.9698)${CClear}"
                  echo ""
                  read -rsp $'Press any key to continue...\n' -n1 key
              else
                  echo ""
                  read -p "Please enter Latitude value (ex: 38.3364)? (0=off, e=Exit): " Lat1

                  if [ "$Lat1" = "e" ]; then
                      echo -e "\n[Exiting]"; sleep 2
                  elif [ "$Lat1" = "0" ]; then
                      Long=0
                      Lat=0
                      saveconfig
                  elif ! validate_coord "$Lat1"; then
                      echo -e "\n${CRed}[ERROR] Invalid Latitude. Must have at least 1 digit before and exactly 4 digits after a decimal point (ex: 38.3364)${CClear}"
                      echo ""
                      read -rsp $'Press any key to continue...\n' -n1 key
                  else
                      Long="$Long1"
                      Lat="$Lat1"
                      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Long/Lat Location Configured: $Long,$Lat" >> $logfile
                      saveconfig
                  fi
              fi
            ;;

            3) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Unit of Measure                                                                       ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate what your preference is for the Unit of Measure? Please note: this${CClear}"
              echo -e "${InvGreen} ${CClear} will only apply for the Global Weather Service and wttr.in options. Choosing the${CClear}"
              echo -e "${InvGreen} ${CClear} US-based Weather Service will default to Imperial measurements."
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (0 = Imperial - Deg F/Mph) or (1 = Metric - Deg C/Kmh) (Default = 1)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo
              if [ "$UnitMeasure" == "0" ]
                then UnitMeagureDisp="Imperial"
              elif [ "$UnitMeasure" == "1" ]
                then UnitMeagureDisp="Metric"
              fi

              echo -e "${CClear}Unit of Measure: ${CGreen}$UnitMeasure - $UnitMeagureDisp${CClear}" ; echo
              read -p "Please enter Unit of Measure value? (0-1, e=Exit): " UnitMeasure1

              if [ "$UnitMeasure1" = "e" ]
              then
                echo -e "\n[Exiting]"; sleep 2
              elif [ "$UnitMeasure1" = "0" ] || [ "$UnitMeasure1" = "1" ]
              then
                UnitMeasure="$UnitMeasure1"
                if [ "$UnitMeasure" == "0" ]
                then UnitMeagureDisp="Imperial"
                elif [ "$UnitMeasure" == "1" ]
                then UnitMeagureDisp="Metric"
                fi
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Unit of Measure Configured: $UnitMeagureDisp" >> $logfile
                saveconfig
              else
                previousValue="$UnitMeasure"
                UnitMeasure="${UnitMeasure:=1}"
                [ "$UnitMeasure" != "$previousValue" ] && \
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Unit of Measure Configured: $UnitMeagureDisp" >> $logfile
                saveconfig
              fi
            ;;

            4) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Weather Service Provider                                                              ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please choose which Weather Service Provider you want to use? There are three basic${CClear}"
              echo -e "${InvGreen} ${CClear} choices, with each having distinct differences explained below:${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} [0] weather.gov - A US-based Weather Service will provide a 3-day forecast. It does${CClear}"
              echo -e "${InvGreen} ${CClear}     provide more content and a more easily readable and expanded forecast, but will${CClear}"
              echo -e "${InvGreen} ${CClear}     only work for US-based locations using Imperial Units of Measure.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} [1] open-meteo.com - A Global Weather Service that provides 7-day forecasts across${CClear}"
              echo -e "${InvGreen} ${CClear}     the globe in both Metric and Imperial Units of Measure, but does not provide an${CClear}"
              echo -e "${InvGreen} ${CClear}     expanded forecast narrative, and its information is more limited."
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} [2] wttr.in - A Global Weather Service and our newest option that provides a 3-day${CClear}"
              echo -e "${InvGreen} ${CClear}     forecast in a graphical format. Its information is a bit more limited, but is${CClear}"
              echo -e "${InvGreen} ${CClear}     able to provide measures in both Metric and Imperial formats. Think dashboard!${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (0 = US-Only, 1 = Global, 2 = Graphical, Default = 2)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo
              if [ "$WXService" == "0" ]
              then
                WXServiceDisplay="Text/US-Only"
              elif [ "$WXService" == "1" ]
              then
                WXServiceDisplay="Text/Global"
              elif [ "$WXService" == "2" ]
              then
                WXServiceDisplay="Graphical/Global"
              fi

              echo -e "${CClear}Weather Service: ${CGreen}$WXService - $WXServiceDisplay${CClear}" ; echo
              read -p "Please enter new Weather Service Choice? (0-2, e=Exit): " WXService1

              if [ "$WXService1" = "e" ]
              then
                echo -e "\n[Exiting]"; sleep 2
              elif [ "$WXService1" = "0" ] || [ "$WXService1" = "1" ] || [ "$WXService1" = "2" ]
              then
                WXService="$WXService1"
                if [ "$WXService" == "0" ]
                then WXServiceDisplay="Text/US-Based"
                elif [ "$WXService" == "1" ]
                then WXServiceDisplay="Text/Global"
                elif [ "$WXService" == "2" ]
                then WXServiceDisplay="Graphical/Global"
                fi
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Weather Service Configured: $WXServiceDisplay" >> $logfile
                saveconfig
              else
                previousValue="$WXService"
                WXService="${WXService:=2}"
                [ "$WXService" != "$previousValue" ] && \
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Weather Service Configured: $WXServiceDisplay" >> $logfile
                saveconfig
              fi
            ;;

            5) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Aviation Weather                                                                      ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} For the aviation enthusiasts and pilots out there, would you like to enable the${CClear}"
              echo -e "${InvGreen} ${CClear} Aviation Weather feature? This feature will provide METAR and TAF updates. These${CClear}"
              echo -e "${InvGreen} ${CClear} are global, provided by aviationweather.gov, but TAFs are primarily only used${CClear}"
              echo -e "${InvGreen} ${CClear} by MAJOR airports. Using a smaller airport ICAO code will likely only produce${CClear}"
              echo -e "${InvGreen} ${CClear} METAR reports."
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = No)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo
              echo -e "${CClear}Aviation Weather Status: ${CGreen}$aviationwx${CClear}" ; echo
              if promptyn "Enable Aviation Weather?"; then
                aviationwx="Enabled"
                echo ""
                while true; do
                  read -p 'Enter your ICAO Airport Code (ex: KLAX): ' icaoairportcode1
                  if echo "$icaoairportcode1" | grep -Eq '^[[:alnum:]]{4,4}$'; then
                    icaoairportcode=$icaoairportcode1
                    echo ""
                    echo -e "${CClear}Using: ${CGreen}$icaoairportcode${CClear}"
                    sleep 3
                    saveconfig
                    break
                  else
                    echo ""
                    echo -e "${CClear}Please use a valid 4-character ICAO Airport Code (ex: KLAX)"
                    echo ""
                  fi
                done
              else
                aviationwx="Disabled"
                saveconfig
              fi
            ;;

            6) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Interval Progress Bar                                                                 ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate what your preference is for the Interval Progress Bar. You choices${CClear}"
              echo -e "${InvGreen} ${CClear} are between a more detailed progress bar, or a minimalist counter that will show${CClear}"
              echo -e "${InvGreen} ${CClear} you how many minutes have passed since the last update.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (0 = Progress Bar, 1 = Minimalist, Default = 0)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo
              if [ "$ProgPref" == "0" ]
                then ProgPrefDisp="Progress Bar"
              elif [ "$ProgPref" == "1" ]
                then ProgPrefDisp="Minimalist"
              fi

              echo -e "${CClear}Interval Progress Bar: ${CGreen}$ProgPrefDisp${CClear}" ; echo
              read -p "Please enter Interval Progress Bar choice? (0-1, e=Exit): " ProgPref1

              if [ "$ProgPref1" = "e" ]
              then
                echo -e "\n[Exiting]"; sleep 2
              elif [ "$ProgPref1" = "0" ] || [ "$ProgPref1" = "1" ]
              then
                ProgPref="$ProgPref1"
                if [ "$ProgPref" == "0" ]
                then ProgPrefDisp="Progress Bar"
                elif [ "$ProgPref" == "1" ]
                then ProgPrefDisp="Minimalist"
                fi
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Interval Progress Bar Configured: $ProgPrefDisp" >> $logfile
                saveconfig
              else
                previousValue="$ProgPref"
                ProgPref="${ProgPref:=0}"
                [ "$ProgPref" != "$previousValue" ] && \
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New Interval Progress Bar Configured: $ProgPrefDisp" >> $logfile
                saveconfig
              fi
            ;;

            [Ss]) # -----------------------------------------------------------------------------------------
              echo ""
              { echo 'Interval='$Interval
                echo 'Long="'"$Long"'"'
                echo 'Lat="'"$Lat"'"'
                echo 'UnitMeasure='$UnitMeasure
                echo 'WXService='$WXService
                echo 'aviationwx="'"$aviationwx"'"'
                echo 'icaoairportcode="'"$icaoairportcode"'"'
                echo 'ProgPref='$ProgPref
              } > $cfgpath
              echo -e "${CGreen}Applying config changes to WXMON..."
              echo -e "$(date) - WXMON - Successfully wrote a new config file" >> $logfile
              sleep 2
              return
            ;;

            [Ee]) # -----------------------------------------------------------------------------------------
              return
            ;;

          esac
    done

  else
    #Create a new config file with default values to get it to a basic running state
    { echo 'Interval=360'
    	echo 'Long="0"'
    	echo 'Lat="0"'
      echo 'UnitMeasure=1'
      echo 'WXService=2'
      echo 'aviationwx="Disabled"'
      echo 'icaoairportcode="KLAX"'
      echo 'ProgPref=0'
    } > $cfgpath

    #Re-run wxmon -config to restart setup process
    vconfig

  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# saveconfig saves the wxmon.cfg file after every major change, and applies that to the script on the fly

saveconfig()
{

   { echo 'Interval='$Interval
     echo 'Long="'"$Long"'"'
     echo 'Lat="'"$Lat"'"'
     echo 'UnitMeasure='$UnitMeasure
     echo 'WXService='$WXService
     echo 'aviationwx="'"$aviationwx"'"'
     echo 'icaoairportcode="'"$icaoairportcode"'"'
     echo 'ProgPref='$ProgPref
   } > "$cfgpath"

   echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: New wxmon.cfg File Saved" >> $logfile
}

# -------------------------------------------------------------------------------------------------------------------------

# vuninstall is a function that uninstalls and removes all traces of wxmon from your router...
vuninstall ()
{

while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} WXMON Uninstall Utility                                                               ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} You are about to uninstall WXMON! This action is irreversible."
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${CClear}"
  if promptyn "Do you wish to proceed?"; then
    echo ""
    echo -e "\nAre you sure? Please type 'y' below to validate you wish to proceed.${CClear}"
    echo ""
      if promptyn "Please validate:"; then
        clear
        #Remove and uninstall files/directories
        rm -f -r /jffs/addons/wxmon.d
        rm -f /jffs/scripts/wxmon.sh
        UninstallComplete="True"
        echo -e "\nWXMON has been uninstalled... Goodbye!${CClear}"
        echo ""
        exit 0
      else
        echo ""
        echo -e "\nExiting Uninstall Utility...${CClear}"
        sleep 1
        return
      fi
  else
    echo ""
    echo -e "\nExiting Uninstall Utility...${CClear}"
    sleep 1
    return
  fi
done
}

# -------------------------------------------------------------------------------------------------------------------------

# vupdate is a function that provides a UI to check for script updates and allows you to install the latest version...
vupdate ()
{

updatecheck # Check for the latest version from source repository
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} WXMON Update Utility                                                                  ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} This utility allows you to check, download and install updates"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Current Version: ${CGreen}$version${CClear}"
  echo -e "Updated Version: ${CGreen}$DLversion${CClear}"
  echo ""
  if [ "$version" == "$DLversion" ]
    then
      echo -e "You are on the latest version! Would you like to download anyways? This will overwrite${CClear}"
      echo -e "your local copy with the current build.${CClear}"
      echo ""
      if promptyn "Proceed?"; then
        echo ""
        echo -e "\nDownloading WXMON ${CGreen}v$DLversion${CClear}"
        curl --silent --retry 3 --connect-timeout 3 --max-time 5 --retry-delay 2 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/WXMON/main/wxmon.sh" -o "/jffs/scripts/wxmon.sh" && chmod 755 "/jffs/scripts/wxmon.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: Successfully downloaded and installed WXMON v$DLversion" >> $logfile
        echo ""
        read -rsp $'Press any key to restart WXMON...\n' -n1 key
        exec /jffs/scripts/wxmon.sh -setup
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
    else
      echo -e "Score! There is a new version out there! Would you like to update?${CClear}"
      echo ""
      if promptyn "Proceed?"; then
        echo ""
        echo -e "\nDownloading WXMON ${CGreen}v$DLversion${CClear}"
        curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 2 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/WXMON/main/wxmon.sh" -o "/jffs/scripts/wxmon.sh" && chmod 755 "/jffs/scripts/wxmon.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - INFO: Successfully downloaded and installed WXMON v$DLversion" >> $logfile
        echo ""
        read -rsp $'Press any key to restart WXMON...\n' -n1 key
        exec /jffs/scripts/wxmon.sh -setup
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
  fi
done
}

# -------------------------------------------------------------------------------------------------------------------------

# vsetup is a function that sets up, confiures and allows you to launch wxmon on your router...
vsetup () {

  # Check for and add an alias for wxmon
  if ! grep -F "sh /jffs/scripts/wxmon.sh" /jffs/configs/profile.add >/dev/null 2>/dev/null; then
    echo "alias wxmon=\"sh /jffs/scripts/wxmon.sh\" # wxmon" >> /jffs/configs/profile.add
  fi

  while true; do
    clear
    echo -e "${InvGreen} ${InvDkGray}${CWhite} WXMON Main Setup and Configuration Menu                                               ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to perform high level${CClear}"
    echo -e "${InvGreen} ${CClear} actions in the management of the WXMON script.${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo -e "${InvGreen} ${CClear}"
    if [ "$FromUI" == "0" ]; then
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Launch WXMON into Normal Monitoring Mode${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Launch WXMON into Normal Monitoring Mode w/ Screen${CClear}"
    else
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear}${CDkGray} : Launch WXMON into Normal Monitoring Mode${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear}${CDkGray} : Launch WXMON into Normal Monitoring Mode w/ Screen${CClear}"
    fi
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Setup and Configure WXMON${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : Force reinstall Entware dependencies${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(5)${CClear} : Check for latest updates${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(6)${CClear} : View logs${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(7)${CClear} : Uninstall WXMON${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo ""
    read -p "Please select? (1-7, e=Exit): " SelectSlot
    case $SelectSlot in

          1)
            if [ "$FromUI" == "0" ]; then
              echo ""
              echo -e "\n${CClear}Launching WXMON into Monitor Mode...${CClear}"
              sleep 2
              sh $apppath -monitor
            fi
          ;;

          2)
            if [ "$FromUI" == "0" ]; then
              echo ""
              echo -e "\n${CClear}Launching WXMON into Monitor Mode with the Screen Utility...${CClear}"
              sleep 2
              sh $apppath -screen
            fi
          ;;

          3) # Check for existence of entware, and if so proceed and install the required packages
            clear
            if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]
            then
              vconfig
            else
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Install Dependencies                                                                  ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Missing dependencies required by WXMON will be installed during this process."
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "WXMON has some dependencies in order to function correctly, namely, CoreUtils-Timeout"
              echo -e "JQ, and the Screen utility. These utilities require you to have Entware already installed"
              echo -e "using the AMTM tool. If Entware is present, the Timeout, JQ and Screen utilities will"
              echo -e "automatically be downloaded and installed during this process."
              echo ""
              echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
              echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router model."
              echo ""
              echo -e "${CGreen}JQuery${CClear} is a utility for querying data across the internet through the the means of"
              echo -e "APIs for the purposes of interacting with the various weather providers to download a"
              echo -e "the appropriate weather data for your selected location."
              echo ""
              echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
              echo -e "directly on the router itself, instead of running your commands or a script from a"
              echo -e "network-attached SSH client. This can provide greater stability due to it running in"
              echo -e "the background on the router itself."
              echo ""
              echo -e "Your router model is: ${CGreen}$RouterModel${CClear}"
              echo ""
              if promptyn "Ready to install?"
              then
                  if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                    echo ""
                    echo -e "\n${CClear}Updating Entware Packages..."
                    echo ""
                    opkg update
                    echo ""
                    echo -e "Installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package...${CClear}"
                    echo ""
                    opkg install coreutils-timeout
                    echo ""
                    echo -e "Installing Entware ${CGreen}JQuery${CClear} Package...${CClear}"
                    echo ""
                    opkg install jq
                    echo ""
                    echo -e "Installing Entware ${CGreen}Screen${CClear} Package...${CClear}"
                    echo ""
                    opkg install screen
                    echo ""
                    echo -e "Install completed..."
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                    echo ""
                    echo -e "Executing Configuration Utility..."
                    sleep 2
                    vconfig
                  else
                    clear
                    echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
                    echo -e "Please install Entware using the AMTM utility before proceeding..."
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  fi
              else
                  echo ""
                  echo -e "\nExecuting Configuration Utility..."
                  sleep 2
                  vconfig
              fi
            fi
          ;;

          4) # Force re-install the CoreUtils timeout/screen package
            clear
            echo -e "${InvGreen} ${InvDkGray}${CWhite} Re-install Dependencies                                                               ${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} Missing dependencies required by WXMON will be re-installed during this process."
            echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
            echo ""
            echo -e "Would you like to re-install the CoreUtils-Timeout, JQ and the Screen utility? These"
            echo -e "utilities require you to have Entware already installed using the AMTM tool. If Entware"
            echo -e "is present, the Timeout and Screen utilities will be uninstalled, downloaded and re-"
            echo -e "installed during this setup process..."
            echo ""
            echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
            echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router"
            echo -e "model."
            echo ""
            echo -e "${CGreen}JQuery${CClear} is a utility for querying data across the internet through the the means of"
            echo -e "APIs for the purposes of interacting with the various weather providers to download a"
            echo -e "the appropriate weather data for your selected location."
            echo ""
            echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
            echo -e "directly on the router itself, instead of running your commands or a script from a"
            echo -e "network-attached SSH client. This can provide greater stability due to it running in"
            echo -e "the background on the router itself."
            echo ""
            echo -e "Your router model is: ${CGreen}$RouterModel${CClear}"
            echo ""
            if promptyn "Force Re-install?"
            then
                if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                  echo ""
                  echo -e "\nUpdating Entware Packages..."
                  echo ""
                  opkg update
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall coreutils-timeout
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}JQuery${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall . jq
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}Screen${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall screen
                  echo ""
                  echo -e "Re-install completed..."
                  echo ""
                  read -rsp $'Press any key to continue...\n' -n1 key
                else
                  clear
                  echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
                  echo -e "Please install Entware using the AMTM utility before proceeding..."
                  echo ""
                  read -rsp $'Press any key to continue...\n' -n1 key
                fi
            fi
          ;;

          5)
            echo ""
            vupdate
          ;;


          6)
            echo ""
            vlogs
          ;;

          7)
            echo ""
            vuninstall
          ;;

          [Ee])
            echo -e "${CClear}"
            if [ "$FromUI" == "1" ]; then
            	break
            else
              exit 0
            fi
          ;;

          *)
            echo ""
            echo -e "${CRed}Invalid choice - Please enter a valid option...${CClear}"
            echo ""
            sleep 2
          ;;

        esac
  done
}

#Shows the version bar formatted for build and date/time with TZ spacing#
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-04] ##
##----------------------------------------##
showheader()
{
  if [ "$hideoptions" = "0" ] && [ "$hideoptions" != "$prevHideOpts" ]
  then displayopsmenu ; fi

  timerReset=0
  prevHideOpts="$hideoptions"

  tzone="$(date +%Z)"
  tzonechars="${#tzone}"

  if   [ "$tzonechars" = "1" ]; then tzspaces="        ";
  elif [ "$tzonechars" = "2" ]; then tzspaces="       ";
  elif [ "$tzonechars" = "3" ]; then tzspaces="      ";
  elif [ "$tzonechars" = "4" ]; then tzspaces="     ";
  elif [ "$tzonechars" = "5" ]; then tzspaces="    "; fi

  #Display WXMON client header
  echo -en "${InvGreen} ${InvDkGray}${CWhite} WXMON - v"
  printf "%-8s" $version
  echo -e "                          ${CGreen}(S)${CWhite}how/${CGreen}(H)${CWhite}ide Operations Menu ${InvDkGray}               $tzspaces$(date) ${CClear}"
}

# -------------------------------------------------------------------------------------------------------------------------
# Displays the "Operations Menu" on top of screen.

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
displayopsmenu()
{
    amtmdisp="${CDkGray}[n/a]        "

    echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                                                            ${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(F)${CClear}orce Weather Refresh${CClear}                                     ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration / Setup Menu${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(U)${CClear}S-based Forecast + Extended${CClear}                              ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim Log Size (rows): ${CGreen}$logsize${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(W)${CClear}orld-based Forecast${CClear}                                      ${InvGreen} ${CClear} ${CDkGray}AM(T)M Email Notifications: $amtmdisp${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(G)${CClear}raphical World-based Forecast${CClear}                            ${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${CGreen}(A)${CClear}viation TAF/METAR Weather${CClear}                                ${InvGreen} ${CClear} Router Model/FW: ${CGreen}${RouterModel} | ${FWBUILD}${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}----------------------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""
}

# -------------------------------------------------------------------------------------------------------------------------
# Begin Commandline Argument Gatekeeper and Configuration Utility Functionality
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

#Determine router model & firmware
RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)"
[ -z "$RouterModel" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)"
FWVER="$($timeoutcmd$timeoutsec nvram get firmver | tr -d '.')"
BUILDNO="$($timeoutcmd$timeoutsec nvram get buildno)"
EXTENDNO="$($timeoutcmd$timeoutsec nvram get extendno)"
if [ -z "$EXTENDNO" ]; then EXTENDNO=0; fi
FWBUILD="${FWVER}.${BUILDNO}_${EXTENDNO}"

# Create the necessary folder/file structure for wxmon under /jffs/addons
if [ ! -d "/jffs/addons/wxmon.d" ]; then
  mkdir -p "/jffs/addons/wxmon.d"
fi

# Check for an AMTM Auto Update
if [ "$1" = "amtmupdate" ]
then
    shift
    ScriptUpdateFromAMTM "$@"
    exit "$?"
fi

# Check and see if any commandline option is being used
if [ $# -eq 0 ]
  then
    clear
    exec sh /jffs/scripts/wxmon.sh -monitor
    exit 0
fi

# Check and see if an invalid commandline option is being used
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-config" ] || [ "$1" == "-log" ] || [ "$1" == "-update" ] || [ "$1" == "-setup" ] || [ "$1" == "-uninstall" ] || [ "$1" == "-screen" ] || [ "$1" == "-monitor" ]
  then
    clear
  else
    clear
    echo ""
    echo "WXMON v$version"
    echo ""
    echo "Exiting due to invalid commandline options!"
    echo "(run 'wxmon.sh -h' for help)"
    echo ""
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the help option is being called
if [ "$1" == "-h" ] || [ "$1" == "-help" ]
  then
  clear
  echo ""
  echo "WXMON v$version Commandline Option Usage:"
  echo ""
  echo "wxmon.sh -h | -help"
  echo "wxmon.sh -log"
  echo "wxmon.sh -config"
  echo "wxmon.sh -update"
  echo "wxmon.sh -setup"
  echo "wxmon.sh -uninstall"
  echo "wxmon.sh -screen"
  echo "wxmon.sh -monitor"
  echo ""
  echo " -h | -help (this output)"
  echo " -log (display the current log contents)"
  echo " -config (configuration utility)"
  echo " -update (script update utility)"
  echo " -setup (setup/dependencies utility)"
  echo " -uninstall (uninstall utility)"
  echo " -screen (execute script using the screen utility)"
  echo " -monitor (execute normal script operation)"
  echo ""
  echo -e "${CClear}"
  exit 0
fi

# Check to see if the log option is being called, and display through nano
if [ "$1" == "-log" ]
  then
    vlogs
    exit 0
fi

# Check to see if the configuration option is being called, and run through setup utility
if [ "$1" == "-config" ]
  then
    vconfig
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the update option is being called
if [ "$1" == "-update" ]
  then
    vupdate
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the install option is being called
if [ "$1" == "-setup" ]
  then
    logoNM
    vsetup
    exit 0
fi

# Check to see if the uninstall option is being called
if [ "$1" == "-uninstall" ]
  then
    vuninstall
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the -now parameter is being called to bypass the screen timer
if [ $# -gt 1 ] && [ "$2" = "-now" ]
then
    bypassscreentimer=1
fi

# Check to see if the screen option is being called and run operations normally using the screen utility
if [ "$1" == "-screen" ]
then
    screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
    sleep 1
    ScreenSess=$(screen -ls | grep "wxmon" | awk '{print $1}' | cut -d . -f 1)
      if [ -z $ScreenSess ]; then
        if [ "$bypassscreentimer" == "1" ]; then
          screen -dmS "wxmon" $apppath -monitor
          sleep 1
          screen -r wxmon
        else
          clear
          echo -e "${CClear}Executing ${CGreen}WXMON v$version${CClear} using the SCREEN utility..."
          echo ""
          echo -e "${CClear}IMPORTANT:"
          echo -e "${CClear}In order to keep WXMON running in the background,"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          screen -dmS "wxmon" $apppath -monitor
          sleep 5
          screen -r wxmon
          exit 0
        fi
      else
        if [ "$bypassscreentimer" == "1" ]; then
          sleep 1
        else
          clear
          echo -e "${CClear}Connecting to existing ${CGreen}WXMON v$version${CClear} SCREEN session...${CClear}"
          echo ""
          echo -e "${CClear}IMPORTANT:${CClear}"
          echo -e "${CClear}In order to keep WXMON running in the background,${CClear}"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          echo -e "${CClear}Switching to the SCREEN session in T-5 sec...${CClear}"
          echo -e "${CClear}"
          spinner 5
        fi
      fi
    screen -dr $ScreenSess
    exit 0
fi

# Check to see if the monitor option is being called and run operations normally
if [ "$1" == "-monitor" ]
  then
    clear
    if [ -f "$cfgpath" ] && [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]; then
      source $cfgpath
        if [ -f "/opt/bin/timeout" ] # If the timeout utility is available then use it and assign variables
          then
            timeoutcmd="timeout "
            timeoutsec="10"
            timeoutlng="60"
          else
            timeoutcmd=""
            timeoutsec=""
            timeoutlng=""
        fi
    else
      echo -e "${CRed}Error: WXMON is not configured.  Please run 'sh wxmon.sh -setup' to complete setup${CClear}"
      echo ""
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) WXMON[$$] - ERROR: WXMON is not configured. Please run the setup/configuration utility" >> $logfile
      exit 0
    fi
fi

# Check for Updates
updatecheck

# Trim Logs
trimlogs

# -------------------------------------------------------------------------------------------------------------------------
# Begin Main Loop, pulling weather stats from API provider
# -------------------------------------------------------------------------------------------------------------------------

while true; do

  if [ "$AVWXPage" == "1" ]; then
    aviationweathercheck
  else
    if [ $WXService == "0" ]; then
      weathercheck
    elif [ $WXService == "1" ]; then
      worldweathercheck
    elif [ $WXService == "2" ]; then
      wttrcheck
    fi
  fi

  i=0
  IntervalMins=$((Interval * 60))
  while [ $i -ne $IntervalMins ]
    do
      i=$(($i+1))
      preparebar 101 "|"
      if [ "$ProgPref" == "0" ]; then
        progressbar $i $IntervalMins "" "m" "Standard"
      else
        progressbaroverride $i $IntervalMins "" "m" "Standard"
      fi

      # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
      key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

      if [ $key_press ]; then
          case $key_press in
              [Ss]) hideoptions=0 ; [ "$hideoptions" != "$prevHideOpts" ] && timerReset=1; break;;
              [Hh]) hideoptions=1 ; [ "$hideoptions" != "$prevHideOpts" ] && timerReset=1; break;;
              [Cc]) FromUI=1; vsetup; if [ "$UninstallComplete" != "True" ]; then source $cfgpath; else exit 0; fi; echo -e "${CGreen}[Returning to the Main UI momentarily]                                   "; sleep 1; FromUI=0; IntervalMins=$((Interval * 60)); clear; echo ""; if [ $WXService == "0" ]; then weathercheck; elif [ $WXService == "1" ]; then worldweathercheck; elif [ $WXService == "2" ]; then wttrcheck; fi;;
              [Aa]) AVWXPage=1; aviationweathercheck;;
              [Uu]) weathercheck;;
              [Ww]) worldweathercheck;;
              [Gg]) wttrcheck;;
              [Mm]) weathercheckext;;
              [Ff]) if [ "$AVWXPage" == "0" ]; then if [ $WXService == "0" ]; then weathercheck; elif [ $WXService == "1" ]; then worldweathercheck; elif [ $WXService == "2" ]; then wttrcheck; fi; else aviationweathercheck; fi;;
              [Rr]) AVWXPage=0; if [ $WXService == "0" ]; then weathercheck; elif [ $WXService == "1" ]; then worldweathercheck; elif [ $WXService == "2" ]; then wttrcheck; fi;;
              [Ee]) logoNMexit; echo -e "${CClear}"; exit 0;;
              [Ll]) vlogs; clear; if [ "$AVWXPage" == "0" ]; then if [ $WXService == "0" ]; then weathercheck; elif [ $WXService == "1" ]; then worldweathercheck; elif [ $WXService == "2" ]; then wttrcheck; fi; else aviationweathercheck; fi;;
          esac
      fi

      prevHideOpts=X

  done

#read -rsp $'Press any key to continue...\n' -n1 key

done

exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
