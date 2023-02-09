#!/bin/sh

# WXMON 0.1b - Asus-Merlin Weather Monitor by Viktor Jaep, 2023
#
# KILLMON is a shell script that provides current localized weather information directly from weather.gov and displays
# this information on screen in an SSH dashboard window. Options to expand on the weather forecast to give you more
# detail about the upcoming forecast. Also, capabilities to view aviation-related METAR and TAF forecasts are included.
# This component was originally added to my PWRMON script, which monitors your Tesla Powerwall batteries, solar panels,
# grid and home electrical usage. Having a weather component was useful in determining if upcoming days would yield good
# solar production days. Understanding that many won't be able to make use of this feature, I decided to break this out
# into its own standalone script -- WXMON.
#
# -------------------------------------------------------------------------------------------------------------------------
# Shellcheck exclusions
# -------------------------------------------------------------------------------------------------------------------------
# shellcheck disable=SC2034
# shellcheck disable=SC3037
# shellcheck disable=SC2162
# shellcheck disable=SC3045
# shellcheck disable=SC2183
# shellcheck disable=SC2086
# shellcheck disable=SC3014
# shellcheck disable=SC2059
# shellcheck disable=SC2002
# shellcheck disable=SC2004
# shellcheck disable=SC3028
# shellcheck disable=SC2140
# shellcheck disable=SC3046
# shellcheck disable=SC1090
#
# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version=0.1b
Beta=1
LOGFILE="/jffs/addons/wxmon.d/wxmon.log"           # Logfile path/name that captures important date/time events - change
APPPATH="/jffs/scripts/wxmon.sh"                   # Path to the location of wxmon.sh
CFGPATH="/jffs/addons/wxmon.d/wxmon.cfg"           # Path to the location of wxmon.cfg
DLVERPATH="/jffs/addons/wxmon.d/version.txt"       # Path to downloaded version from the source repository
WANwxforecast="/jffs/addons/wxmon.d/WANwx.txt"     # Path to weather forecast JSON extract used for weather displays
Interval=360
FromUI=0
aviationwx="Disabled"
avwxapitoken="N/A"
icaoairportcode="KLAX"
ProgPref=0
AVWXPage=0

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

# -------------------------------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------------------------------

# Logo is a function that displays the WXMON script name in a cool ASCII font
logo () {
  echo -e "${CYellow}   _       ___  __ __  _______  _   __"
  echo -e "  | |     / / |/ //  |/  / __ \/ | / /  ${CGreen}v$Version${CYellow}"
  echo -e "  | | /| / /|   // /|_/ / / / /  |/ / ${CRed}(S)${CGreen}etup ${CRed}(F)${CGreen}orce Refresh${CYellow}"
  echo -e "  | |/ |/ //   |/ /  / / /_/ / /|  / ${CRed}(A)${CGreen}viation WX${CYellow}"
  echo -e "  |__/|__//_/|_/_/  /_/\____/_/ |_/ ${CRed}(E)${CGreen}xit${CClear}"
}

# -------------------------------------------------------------------------------------------------------------------------

# LogoNM is a function that displays the WXMON script name in a cool ASCII font sans menu
logoNM () {
  echo -e "${CYellow}   _       ___  __ __  _______  _   __"
  echo -e "  | |     / / |/ //  |/  / __ \/ | / /  ${CGreen}v$Version${CYellow}"
  echo -e "  | | /| / /|   // /|_/ / / / /  |/ /"
  echo -e "  | |/ |/ //   |/ /  / / /_/ / /|  /"
  echo -e "  |__/|__//_/|_/_/  /_/\____/_/ |_/"
}

# -------------------------------------------------------------------------------------------------------------------------

# promptyn takes input for Y/N questions
promptyn () {   # No defaults, just y or n
  while true; do
    read -p "[y/n]? " -n 1 -r yn
      case "${yn}" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\nPlease answer y or n.";;
      esac
  done
}

# -------------------------------------------------------------------------------------------------------------------------

# Spinner is a script that provides a small indicator on the screen to show script activity
spinner() {

  i=0
  j=$((SPIN / 4))
  while [ $i -le $j ]; do
    for s in / - \\ \|; do
      printf "\r$s"
      sleep 1
    done
    i=$((i+1))
  done

  printf "\r"
}

# -------------------------------------------------------------------------------------------------------------------------

# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity
preparebar() {
  # $1 - bar length
  # $2 - bar char
  #printf "\n"
  barlen=$1
  barspaces=$(printf "%*s" "$1")
  barchars=$(printf "%*s" "$1" | tr ' ' "$2")
}

# Had to make some mods to the variables being passed, and created an inverse colored progress bar
progressbar() {
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

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      if [ $progr -le 60 ]; then
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 60 ] && [ $progr -le 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ "$5" == "Reverse" ]; then
      if [ $progr -le 35 ]; then
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 35 ] && [ $progr -le 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    fi
  fi
}

progressbaroverride() {
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

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      printf "  ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function was "borrowed" graciously from @dave14305 from his FlexQoS script to determine the active WAN connection.
# Thanks much for your troubleshooting help as we tackled how to best derive the active WAN interface, Dave!

get_wan_setting() {
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
} # get_wan_setting

# -------------------------------------------------------------------------------------------------------------------------
# weathercheck is a function that downloads the latest weather for your WAN IP location
weathercheck () {

  # Get the WAN interface in order to check for the public WAN IP address
  WANIFNAME=$(get_wan_setting ifname)
  WANIP=$(curl --silent --fail --interface $WANIFNAME --request GET --url https://ipv4.icanhazip.com)
  WANCITY=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .city)

  # Get the latitute/longitude of the public WAN IP address
  WANlat=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lat)
  WANlon=$(curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WANIP | jq --raw-output .lon)

  # Get the Weather grid for the latitude/longitude
  WANgridurl=$(curl --silent --retry 3 --request GET --url https://api.weather.gov/points/$WANlat,$WANlon | jq --raw-output .properties.forecast)

  # Extract the weather JSON to a text file in order to query from it with JQ
  curl --silent --retry 3 --request GET --url $WANgridurl | jq . --raw-output > $WANwxforecast
  LINES=$(cat $WANwxforecast | wc -l) #Check to see how many lines are in this file

  if [ $LINES -eq 0 ] #If there are no lines, error out
  then
    echo -e "\n${CRed} [Error: Unable to download weather data. Try again later...]\n${CClear}"
    echo -e "$(date) - WXMON ----------> ERROR: Unable to fetch weather data. May be a temporary issue. Try again later." >> $LOGFILE
    sleep 3
    exit 0
  else
    # Display the city, lat and long
    #WANCITY="Your City"
    #WANlat=32.3321
    #WANlon=-64.7660
    clear
    logo
    if [ "$UpdateNotify" != "0" ]; then
      echo -e "${CRed}  $UpdateNotify${CClear}"
      echo -e "${CGreen} ________${CClear}"
    else
      echo -e "${CGreen} ________${CClear}"
    fi
    echo -e "${CGreen}/${CRed}Location${CClear}${CGreen}\_________________________________________________________${CClear}"
    echo ""
    echo -e "${InvGreen} ${CClear}${CGreen} Location: ${CCyan}$WANCITY ${CGreen}-- Latitude: ${CCyan}$WANlat ${CGreen}-- Longitude: ${CCyan}$WANlon"
    echo -e "${CGreen} ________${CClear}"
    echo -e "${CGreen}/${CRed}Forecast${CClear}${CGreen}\_________________________________________________________${CClear}"
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
        WANwxShortTrim=$(echo $WANwxShort | sed -e 's/.\{50\} /&\n/g')
        WANwxDetailTrim=$(echo $WANwxDetail | sed -e 's/.\{50\} /&\n/g')

    echo -e "${InvGreen} ${CClear}${CGreen} Day: ${CCyan}$WANwxName ${CGreen}-- Temp: ${CCyan}$WANwxTemp$WANwxTempUnit ${CGreen}-- Wind: ${CCyan}$WANwxWind from $WANwxWindDir"
    echo -e "${InvGreen} ${CClear}${CGreen} Conditions: ${CCyan}$WANwxShortTrim"
    echo ""

    i=$(($i+1))

  done

  echo -e "${CRed}(M)${CGreen}ore Detail?"
  echo ""

fi
}

# -------------------------------------------------------------------------------------------------------------------------
# weathercheckext is a function that displays the latest extended weather forecast for your WAN IP location
weathercheckext () {

  clear
  logo
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed}  $UpdateNotify${CClear}"
    echo -e "${CGreen} _________________${CClear}"
  else
    echo -e "${CGreen} _________________${CClear}"
  fi
  echo -e "${CGreen}/${CRed}Extended Forecast${CClear}${CGreen}\________________________________________________${CClear}"
  echo ""

  # Loop through the forecasts and display them
  i=0
  while [ $i -ne 6 ]
    do

      WANwxName=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].name | select( . != null )')
      WANwxDetail=$(cat $WANwxforecast | jq -r '.properties.periods['$i'].detailedForecast | select( . != null )')
      WANwxDetailTrim=$(echo $WANwxDetail | sed -e 's/.\{57\} /&\n/g')

  echo -e "${InvGreen} ${CClear}${CGreen} Day: ${CCyan}$WANwxName"
  echo -e "${CCyan}$WANwxDetailTrim"
  echo ""

  i=$(($i+1))

done

echo -e "${CRed}(R)${CGreen}eturn to condensed forecast?"
echo ""

}

# -------------------------------------------------------------------------------------------------------------------------
# aviationweathercheck is a function that displays the latest aviation weather forecast for your ICAO airport code
aviationweathercheck () {

  clear
  logo
  if [ $aviationwx == "Disabled" ]; then
    echo ""
    echo -e "${CGreen}[Aviation Weather is disabled. Please enable it in the Config menu.]"
    echo ""
    sleep 2
    weathercheck
    return
  fi

  curl --silent --retry 3 --request GET --url https://avwx.rest/api/metar/$icaoairportcode --header 'Authorization: BEARER '$avwxapitoken | jq --raw-output '.flight_rules,.sanitized'> /jffs/addons/wxmon.d/wxmetar.txt

  if [ -f /jffs/addons/wxmon.d/wxmetar.txt ]; then
    FlightRules=$(cat /jffs/addons/wxmon.d/wxmetar.txt | sed -n '1p' | cut -d '"' -f2) 2>&1
    CurrMETAR=$(cat /jffs/addons/wxmon.d/wxmetar.txt | sed -n '2p' | cut -d '"' -f2) 2>&1
    CurrMETARTrim=$(echo $CurrMETAR | sed -e 's/.\{57\} /&\n/g')
    if [ "$FlightRules" == "Null" ]; then FlightRules="Unknown - Error getting weather"; fi
    if [ "$CurrMETAR" == "Null" ]; then CurrMETARTrim="Unknown - Error getting weather"; fi
  else
    FlightRules="Unknown - Error getting weather"
    CurrMETARTrim="Unknown - Error getting weather"
  fi

  curl --silent --retry 3 --request GET --url https://avwx.rest/api/taf/$icaoairportcode --header 'Authorization: BEARER '$avwxapitoken | jq --raw-output '.raw'> /jffs/addons/wxmon.d/wxtaf.txt

  if [ -f /jffs/addons/wxmon.d/wxtaf.txt ]; then
    CurrTAF=$(cat /jffs/addons/wxmon.d/wxtaf.txt | sed -n '1p' | cut -d '"' -f2) 2>&1
    CurrTAFTrim=$(echo $CurrTAF | sed -e 's/.\{57\} /&\n/g')
    if [ "$CurrTAF" == "Null" ]; then CurrTAFTrim="Unknown - Error getting weather"; fi
  else
    CurrTAFTrim="Unknown - Error getting weather"
  fi

  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed}  $UpdateNotify${CClear}"
    echo -e "${CGreen} _________________${CClear}"
  else
    echo -e "${CGreen} _________________${CClear}"
  fi
  echo -e "${CGreen}/${CRed}$icaoairportcode Flight Rules${CClear}${CGreen}\________________________________________________${CClear}"
  echo ""
  echo -e ${CGreen}Current Conditions: ${CCyan}$FlightRules
  echo ""
  echo -e "${CGreen} __________${CClear}"
  echo -e "${CGreen}/${CRed}$icaoairportcode METAR${CClear}${CGreen}\_______________________________________________________${CClear}"
  echo ""
  echo -e "${CCyan}$CurrMETARTrim"
  echo ""
  echo -e "${CGreen} ________${CClear}"
  echo -e "${CGreen}/${CRed}$icaoairportcode TAF${CClear}${CGreen}\_________________________________________________________${CClear}"
  echo ""
  echo -e "${CCyan}$CurrTAFTrim"
  echo ""
  echo ""
  echo -e "${CRed}(R)${CGreen}eturn to condensed forecast?"
  echo ""

}

# -------------------------------------------------------------------------------------------------------------------------
# updatecheck is a function that downloads the latest update version file, and compares it with what's currently installed
updatecheck () {

  # Download the latest version file from the source repository
  curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/wxmon/master/version.txt" -o "/jffs/addons/wxmon.d/version.txt"

  if [ -f $DLVERPATH ]
    then
      # Read in its contents for the current version file
      DLVersion=$(cat $DLVERPATH)

      # Compare the new version with the old version and log it
      if [ "$Beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLVersion" != "$Version" ]; then
        UpdateNotify="Update available: v$Version -> v$DLVersion"
        echo -e "$(date) - WXMON - A new update (v$DLVersion) is available to download" >> $LOGFILE
      else
        UpdateNotify=0
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vlogs is a function that calls the nano text editor to view the wxmon log file
vlogs() {

export TERM=linux
nano $LOGFILE

}

# -------------------------------------------------------------------------------------------------------------------------

# vconfig is a function that guides you through the various configuration options for wxmon
vconfig () {

  if [ -f $CFGPATH ]; then #Making sure file exists before proceeding
    source $CFGPATH

    while true; do
      clear
      logoNM
      echo ""
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${CGreen}Configuration Utility Options"
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${InvDkGray}${CWhite} 1 ${CClear}${CCyan}: Refresh Interval (min)      :"${CGreen}$Interval
      echo -e "${InvDkGray}${CWhite} 2 ${CClear}${CCyan}: Enable Aviation WX?         :"${CGreen}$aviationwx
      if [ "$aviationwx" == "Enabled" ]; then
        echo -e "${InvDkGray}${CWhite} |-${CClear}${CCyan}-  AVWX API Token             :"${CGreen}$avwxapitoken
        echo -e "${InvDkGray}${CWhite} |-${CClear}${CCyan}-  ICAO Airport Code          :"${CGreen}$icaoairportcode
      else
        echo -e "${InvDkGray}${CWhite} | ${CClear}${CDkGray}-  AVWX API Token             :${CDkGray}N/A"
        echo -e "${InvDkGray}${CWhite} | ${CClear}${CDkGray}-  ICAO Airport Code          :${CDkGray}N/A"
      fi
      echo -en "${InvDkGray}${CWhite} 3 ${CClear}${CCyan}: Progress Bar Preference?    :"${CGreen}
      if [ "$ProgPref" == "0" ]; then
        printf "Standard"; printf "%s\n";
      else printf "Minimalist"; printf "%s\n"; fi
      echo -e "${InvDkGray}${CWhite} | ${CClear}"
      echo -e "${InvDkGray}${CWhite} s ${CClear}${CCyan}: Save & Exit"
      echo -e "${InvDkGray}${CWhite} e ${CClear}${CCyan}: Exit & Discard Changes"
      echo -e "${CGreen}----------------------------------------------------------------"
      echo ""
      printf "Selection: "
      read -r ConfigSelection

      # Execute chosen selections
          case "$ConfigSelection" in

            1) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}1. How many minutes would you like to use to refresh your WX stats?"
              echo -e "${CYellow}(Default = 360)${CClear}"
              read -p 'Interval (minutes): ' Interval1
              Interval=$Interval1
            ;;

            2) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}2. Would you like to enable aviation weather METAR and TAF updates?"
              echo -e "${CCyan}This will require you to create a free account on https://avwx.rest/"
              echo -e "${CCyan}in order to enter an API token below. This free API token will grant"
              echo -e "${CCyan}access to the latest aviation weather for the aiport of your choice."
              echo -e "${CYellow}(Aviation Weather Enabled Default = No)${CClear}"
              if promptyn "Enable Aviation Weather? (y/n): "; then
                aviationwx="Enabled"
                echo ""
                echo ""
                echo -e "${CGreen}NOTE: Press ENTER at the prompt to use your previously"
                echo -e "${CGreen}saved entry.${CClear}"
                echo ""
                read -p 'Enter your AVWX API key: ' avwxapitoken1
                if [ ! -z "$avwxapitoken1" ]; then avwxapitoken=$avwxapitoken1; fi
                echo -e "${CGreen}Using: $avwxapitoken${CClear}"
                echo ""
                read -p 'Enter your ICAO Airport Code (ex: KLAX): ' icaoairportcode1
                if [ ! -z "$icaoairportcode1" ]; then icaoairportcode=$icaoairportcode1; fi
                echo -e "${CGreen}Using: $icaoairportcode${CClear}"
                echo ""
              else
                aviationwx="Disabled"
              fi
            ;;

            3) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}3. What is your preference for the Interval Progress Bar?"
              echo -e "${CCyan}(0 = Standard) or (1 = Minimalist)?"
              echo -e "${CYellow}(Default = 0)${CClear}"
              read -p 'Progress Bar Pref: ' ProgPref1
              ProgPref2=$(echo $ProgPref1 | tr '[0-1]')
              if [ -z "$ProgPref1" ]; then ProgPref=0; else ProgPref=$ProgPref2; fi
            ;;

            [Ss]) # -----------------------------------------------------------------------------------------
              echo ""
              { echo 'Interval='$Interval
                echo 'aviationwx="'"$aviationwx"'"'
                echo 'avwxapitoken="'"$avwxapitoken"'"'
                echo 'icaoairportcode="'"$icaoairportcode"'"'
                echo 'ProgPref='$ProgPref
              } > $CFGPATH
              echo ""
              echo -e "${CGreen}Applying config changes to WXMON..."
              echo -e "$(date) - WXMON - Successfully wrote a new config file" >> $LOGFILE
              sleep 3
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
        echo 'aviationwx="Disabled"'
        echo 'avwxapitoken="N/A"'
        echo 'icaoairportcode="KLAX"'
        echo 'ProgPref=0'
      } > $CFGPATH

      #Re-run wxmon -config to restart setup process
      vconfig

  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# vuninstall is a function that uninstalls and removes all traces of wxmon from your router...
vuninstall () {
  clear
  logoNM
  echo ""
  echo -e "${CYellow}Uninstall Utility${CClear}"
  echo ""
  echo -e "${CCyan}You are about to uninstall WXMON!  This action is irreversible."
  echo -e "${CCyan}Do you wish to proceed?${CClear}"
  if promptyn "(y/n): "; then
    echo ""
    echo -e "\n${CCyan}Are you sure? Please type 'Y' to validate you want to proceed.${CClear}"
      if promptyn "(y/n): "; then
        clear
        rm -r /jffs/addons/wxmon.d
        rm /jffs/scripts/wxmon.sh
        echo ""
        echo -e "\n${CGreen}WXMON has been uninstalled...${CClear}"
        echo ""
        exit 0
      else
        echo ""
        echo -e "\n${CGreen}Exiting Uninstall Utility...${CClear}"
        sleep 1
        return
      fi
  else
    echo ""
    echo -e "\n${CGreen}Exiting Uninstall Utility...${CClear}"
    sleep 1
    return
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vupdate is a function that provides a UI to check for script updates and allows you to install the latest version...
vupdate () {
  updatecheck # Check for the latest version from source repository
  clear
  logoNM
  echo ""
  echo -e "${CYellow}Update Utility${CClear}"
  echo ""
  echo -e "${CCyan}Current Version: ${CYellow}$Version${CClear}"
  echo -e "${CCyan}Updated Version: ${CYellow}$DLVersion${CClear}"
  echo ""
  if [ "$Version" == "$DLVersion" ]
    then
      echo -e "${CCyan}You are on the latest version! Would you like to download anyways?${CClear}"
      echo -e "${CCyan}This will overwrite your local copy with the current build.${CClear}"
      if promptyn "(y/n): "; then
        echo ""
        echo -e "${CCyan}Downloading WXMON ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/wxmon/master/wxmon-$DLVersion.sh" -o "/jffs/scripts/wxmon.sh" && chmod a+rx "/jffs/scripts/wxmon.sh"
        echo ""
        echo -e "${CCyan}Download successful!${CClear}"
        echo -e "$(date) - WXMON - Successfully downloaded WXMON v$DLVersion" >> $LOGFILE
        echo ""
        echo -e "${CYellow}Please exit, restart and configure new options using: 'wxmon.sh -config'.${CClear}"
        echo -e "${CYellow}NOTE: New features may have been added that require your input to take${CClear}"
        echo -e "${CYellow}advantage of its full functionality.${CClear}"
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        return
      else
        echo ""
        echo ""
        echo -e "${CGreen}Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
    else
      echo -e "${CCyan}Score! There is a new version out there! Would you like to update?${CClear}"
      if promptyn " (y/n): "; then
        echo ""
        echo -e "${CCyan}Downloading WXMON ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/wxmon/master/wxmon-$DLVersion.sh" -o "/jffs/scripts/wxmon.sh" && chmod a+rx "/jffs/scripts/wxmon.sh"
        echo ""
        echo -e "${CCyan}Download successful!${CClear}"
        echo -e "$(date) - WXMON - Successfully downloaded WXMON v$DLVersion" >> $LOGFILE
        echo ""
        echo -e "${CYellow}Please exit, restart and configure new options using: 'wxmon.sh -config'.${CClear}"
        echo -e "${CYellow}NOTE: New features may have been added that require your input to take${CClear}"
        echo -e "${CYellow}advantage of its full functionality.${CClear}"
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        return
      else
        echo ""
        echo ""
        echo -e "${CGreen}Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
  fi
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
    logoNM
    echo ""
    echo -e "${CYellow}Setup Utility${CClear}" # Provide main setup menu
    echo ""
    echo -e "${CGreen}----------------------------------------------------------------"
    echo -e "${CGreen}Operations"
    echo -e "${CGreen}----------------------------------------------------------------"
    echo -e "${InvDkGray}${CWhite} sc ${CClear}${CCyan}: Setup and Configure WXMON"
    echo -e "${InvDkGray}${CWhite} fr ${CClear}${CCyan}: Force Re-install Entware Dependencies"
    echo -e "${InvDkGray}${CWhite} up ${CClear}${CCyan}: Check for latest updates"
    echo -e "${InvDkGray}${CWhite} vl ${CClear}${CCyan}: View logs"
    echo -e "${InvDkGray}${CWhite} un ${CClear}${CCyan}: Uninstall"
    echo -e "${InvDkGray}${CWhite}  e ${CClear}${CCyan}: Exit"
    echo -e "${CGreen}----------------------------------------------------------------"
    if [ "$FromUI" == "0" ]; then
      echo -e "${CGreen}Launch"
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${InvDkGray}${CWhite} m1 ${CClear}${CCyan}: Launch WXMON into Normal Monitoring Mode"
      echo -e "${InvDkGray}${CWhite} m2 ${CClear}${CCyan}: Launch WXMON into Normal Monitoring Mode w/ Screen"
      echo -e "${CGreen}----------------------------------------------------------------"
    fi
    echo ""
    printf "Selection: "
    read -r InstallSelection

    # Execute chosen selections
        case "$InstallSelection" in

          sc) # Check for existence of entware, and if so proceed and install the timeout package, then run wxmon -config
            clear
            if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]; then
              vconfig
            else
              logoNM
              echo -e "${CYellow}Installing WXMON Dependencies...${CClear}"
              echo ""
              echo -e "${CCyan}WXMON has some dependencies in order to function correctly, namely,${CClear}"
              echo -e "${CCyan}CoreUtils-Timeout, JQuery and the Screen utility. These utilities ${CClear}"
              echo -e "${CCyan}require you to have Entware already installed using the AMTM tool. If${CClear}"
              echo -e "${CCyan}Entware is present, the Timeout, JQ and Screen utilities will ${CClear}"
              echo -e "${CCyan}automatically be downloaded and installed during this setup process.${CClear}"
              echo ""
              echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
              echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
              echo -e "${CCyan}hang scripts running on this router model.${CClear}"
              echo ""
              echo -e "${CGreen}Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone${CClear}"
              echo -e "${CCyan}environment directly on the router itself, instead of running your${CClear}"
              echo -e "${CCyan}commands or a script from a network-attached SSH client. This can${CClear}"
              echo -e "${CCyan}provide greater stability due to it running on the router itself.${CClear}"
              echo ""
              echo -e "${CGreen}JQuery${CCyan} is a utility for querying data locally or across the${CClear}"
              echo -e "${CCyan}internet through the means of APIs for the purposes of interacting${CClear}"
              echo -e "${CCyan}with public APIs to extract current weather stats.${CClear}"
              echo ""
              [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
              echo -e "${CCyan}Your router model is: ${CYellow}$RouterModel"
              echo ""
              echo -e "${CCyan}Ready to install?${CClear}"
              if promptyn "(y/n): "
                then
                  if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                    echo ""
                    echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
                    echo ""
                    opkg update
                    echo ""
                    echo -e "${CGreen}Installing Entware CoreUtils-Timeout Package...${CClear}"
                    echo ""
                    opkg install coreutils-timeout
                    echo ""
                    echo -e "${CGreen}Installing Entware Screen Package...${CClear}"
                    echo ""
                    opkg install screen
                    echo ""
                    echo -e "${CGreen}Installing Entware JQuery Package...${CClear}"
                    echo ""
                    opkg install jq
                    echo ""
                    echo -e "${CGreen}Install completed...${CClear}"
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                    echo ""
                    echo -e "${CGreen}Executing WXMON Configuration Utility...${CClear}"
                    sleep 2
                    vconfig
                  else
                    clear
                    echo -e "${CGreen}ERROR: Entware was not found on this router...${CClear}"
                    echo -e "${CGreen}Please install Entware using the AMTM utility before proceeding...${CClear}"
                    echo ""
                    sleep 3
                  fi
                else
                  echo ""
                  echo -e "\n${CGreen}Executing WXMON Configuration Utility...${CClear}"
                  sleep 2
                  vconfig
              fi
            fi
          ;;


          fr) # Force re-install the CoreUtils timeout/screen package
            clear
            logoNM
            echo ""
            echo -e "${CYellow}Force Re-installing WXMON Dependencies...${CClear}"
            echo ""
            echo -e "${CCyan}Would you like to re-install the CoreUtils-Timeout, JQuery and the${CClear}"
            echo -e "${CCyan}Screen utility? These utilities require you to have Entware already${CClear}"
            echo -e "${CCyan}installed using the AMTM tool. If Entware is present, the Timeout,${CClear}"
            echo -e "${CCyan}JQ, and Screen utilities will be uninstalled, downloaded and${CClear}"
            echo -e "${CCyan}re-installed during this setup process.${CClear}"
            echo ""
            echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
            echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
            echo -e "${CCyan}hang scripts running on this router model.${CClear}"
            echo ""
            echo -e "${CGreen}Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone${CClear}"
            echo -e "${CCyan}environment directly on the router itself, instead of running your${CClear}"
            echo -e "${CCyan}commands or a script from a network-attached SSH client. This can${CClear}"
            echo -e "${CCyan}provide greater stability due to it running on the router itself.${CClear}"
            echo ""
            echo -e "${CGreen}JQuery${CCyan} is a utility for querying data locally or across the${CClear}"
            echo -e "${CCyan}internet through the means of APIs for the purposes of interacting${CClear}"
            echo -e "${CCyan}with public APIs to extract current weather stats.${CClear}"
            echo ""
            [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
            echo -e "${CCyan}Your router model is: ${CYellow}$RouterModel"
            echo ""
            echo -e "${CCyan}Force Re-install?${CClear}"
            if promptyn "(y/n): "
              then
                if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                  echo ""
                  echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
                  echo ""
                  opkg update
                  echo ""
                  echo -e "${CGreen}Force Re-installing Entware CoreUtils-Timeout Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall coreutils-timeout
                  echo ""
                  echo -e "${CGreen}Force Re-installing Entware Screen Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall screen
                  echo ""
                  echo -e "${CGreen}Force Re-installing Entware JQuery Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall jq
                  echo ""
                  echo -e "${CGreen}Re-install completed...${CClear}"
                  echo ""
                  read -rsp $'Press any key to continue...\n' -n1 key
                else
                  clear
                  echo -e "${CGreen}ERROR: Entware was not found on this router...${CClear}"
                  echo -e "${CGreen}Please install Entware using the AMTM utility before proceeding...${CClear}"
                  echo ""
                  sleep 3
                fi
            fi
          ;;

          up)
            echo ""
            vupdate
          ;;

          m1)
            echo ""
            echo -e "\n${CGreen}Launching WXMON into Monitor Mode...${CClear}"
            sleep 2
            sh $APPPATH -monitor
          ;;

          m2)
            echo ""
            echo -e "\n${CGreen}Launching WXMON into Monitor Mode with the Screen Utility...${CClear}"
            sleep 2
            sh $APPPATH -screen
          ;;

          vl)
            echo ""
            vlogs
          ;;

          un)
            echo ""
            vuninstall
          ;;

          [Ee])
            echo -e "${CClear}"
            exit 0
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

# -------------------------------------------------------------------------------------------------------------------------
# Begin Commandline Argument Gatekeeper and Configuration Utility Functionality
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

  # Create the necessary folder/file structure for wxmon under /jffs/addons
  if [ ! -d "/jffs/addons/wxmon.d" ]; then
		mkdir -p "/jffs/addons/wxmon.d"
  fi

  # Check for Updates
  updatecheck

  # Check and see if any commandline option is being used
  if [ $# -eq 0 ]
    then
      clear
      sh /jffs/scripts/wxmon.sh -monitor
      exit 0
  fi

  # Check and see if an invalid commandline option is being used
  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-config" ] || [ "$1" == "-log" ] || [ "$1" == "-update" ] || [ "$1" == "-setup" ] || [ "$1" == "-uninstall" ] || [ "$1" == "-screen" ] || [ "$1" == "-monitor" ]
    then
      clear
    else
      clear
      echo ""
      echo "WXMON v$Version"
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
    echo "WXMON v$Version Commandline Option Usage:"
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
      vsetup
  fi

  # Check to see if the uninstall option is being called
  if [ "$1" == "-uninstall" ]
    then
      vuninstall
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the screen option is being called and run operations normally using the screen utility
  if [ "$1" == "-screen" ]
    then
      screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
      sleep 1
      ScreenSess=$(screen -ls | grep "wxmon" | awk '{print $1}' | cut -d . -f 1)
      if [ -z $ScreenSess ]; then
        clear
        echo -e "${CGreen}Executing WXMON using the SCREEN utility...${CClear}"
        echo ""
        echo -e "${CCyan}IMPORTANT:${CClear}"
        echo -e "${CCyan}In order to keep WXMON running in the background,${CClear}"
        echo -e "${CCyan}properly exit the SCREEN session by using: CTRL-A + D${CClear}"
        echo ""
        screen -dmS "wxmon" $APPPATH
        sleep 2
        echo -e "${CGreen}Switching to the SCREEN session in T-5 sec...${CClear}"
        echo -e "${CClear}"
        SPIN=5
        spinner
        screen -r wxmon
        exit 0
      else
        clear
        echo -e "${CGreen}Connecting to existing WXMON SCREEN session...${CClear}"
        echo ""
        echo -e "${CCyan}IMPORTANT:${CClear}"
        echo -e "${CCyan}In order to keep WXMON running in the background,${CClear}"
        echo -e "${CCyan}properly exit the SCREEN session by using: CTRL-A + D${CClear}"
        echo ""
        echo -e "${CGreen}Switching to the SCREEN session in T-5 sec...${CClear}"
        echo -e "${CClear}"
        SPIN=5
        spinner
        screen -dr $ScreenSess
        exit 0
      fi
  fi

  # Check to see if the monitor option is being called and run operations normally
  if [ "$1" == "-monitor" ]
    then
      clear
      if [ -f $CFGPATH ] && [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]; then
        source $CFGPATH
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
        echo -e "${CRed}Error: WXMON is not configured.  Please run 'wxmon.sh -setup' to complete setup${CClear}"
        echo ""
        echo -e "$(date) - WXMON ----------> ERROR: WXMON is not configured. Please run the setup tool." >> $LOGFILE
        kill 0
      fi
  fi

# -------------------------------------------------------------------------------------------------------------------------
# Begin Main Loop, pulling weather stats from API provider
# -------------------------------------------------------------------------------------------------------------------------

while true; do

  if [ "$AVWXPage" == "1" ]; then
    clear
    aviationweathercheck
  else
    clear
    weathercheck
  fi

  i=0
  IntervalMins=$((Interval * 60))
  while [ $i -ne $IntervalMins ]
    do
      i=$(($i+1))
      preparebar 48 "|"
      if [ "$ProgPref" == "0" ]; then
        progressbar $i $IntervalMins "" "s" "Standard"
      else
        progressbaroverride $i $IntervalMins "" "s" "Standard"
      fi

      # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
      key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

      if [ $key_press ]; then
          case $key_press in
              [Ss]) FromUI=1; (vsetup); source $CFGPATH; echo -e "${CGreen}[Returning to the Main UI momentarily]                                   "; sleep 1; FromUI=0; IntervalMins=$((Interval * 60)); clear; logo; echo ""; weathercheck;;
              [Aa]) AVWXPage=1; aviationweathercheck;;
              [Mm]) weathercheckext;;
              [Ff]) if [ "$AVWXPage" == "0" ]; then weathercheck; else aviationweathercheck; fi;;
              [Rr]) AVWXPage=0; weathercheck;;
              [Ee]) echo -e "${CClear}"; exit 0;;
          esac
      fi
  done

#read -rsp $'Press any key to continue...\n' -n1 key

done

exit 0
