#!/bin/bash

##Print splash
echo '************************************************'
echo '**Ferron 1.x to 2.x upgrade tool for GNU/Linux**'
echo '************************************************'
echo

##Check if user is root
if [ "$(id -u)" != "0" ]; then
  echo 'You need to have root privileges to update Ferron'
  exit 1
fi

##Check if Ferron is installed
if ! [ -f /usr/sbin/ferron ]; then
  echo 'Ferron isn'"'"'t installed (or it'"'"'s installed without using Ferron installer)!'
  exit 1
fi

##Select Ferron installation type
echo 'Select your Ferron installation type. Valid Ferron installation types:'
echo '0 - Latest stable version'
echo '1 - Install and update manually'
echo -n 'Your Ferron installation type: '
read ITP
case $ITP in
  0) INSTALLTYPE=stable;;
  1) INSTALLTYPE=manual;;
  *) echo 'Invalid Ferron installation type!'; exit 1;;
esac

if [ "$INSTALLTYPE" == "manual" ]; then
  echo -n 'Path to Ferron zip archive: '
  read FERRONZIPARCHIVE
elif [ "$INSTALLTYPE" == "stable" ]; then
  ##Detect the machine architecture
  ARCH=$(uname -m)

  ##Normalize architecture name
  case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    i386 | i486 | i586 | i686) ARCH="i686" ;;
    armv7*) ARCH="armv7" ;;
    aarch64) ARCH="aarch64" ;;
    riscv64) ARCH="riscv64gc" ;;
    s390x) ARCH="s390x" ;;
    ppc64le) ARCH="powerpc64le" ;;
    *) echo "Unknown architecture: $ARCH"; exit 1 ;;
  esac

  ##Detect the operating system
  OS=$(uname -s)

  case "$OS" in
    Linux) OS="linux" ;;
    FreeBSD) OS="freebsd" ;;
    *) echo "Unknown OS: $OS"; exit 1 ;;
  esac

  ##Detect the C library
  if [ "$OS" = "linux" ]; then
    if ldd --version 2>&1 | grep -q "musl"; then
      LIBC="musl"
    else
      LIBC="gnu"
    fi
  else
    LIBC=""
  fi

  ##Detect the ABI
  if [ "$ARCH" = "armv7" ]; then
    ABI="eabihf"
  else
    ABI=""
  fi

  ##Construct the target triple
  if [ -n "$LIBC" ]; then
    TARGETTRIPLE="${ARCH}-unknown-${OS}-${LIBC}${ABI}"
  elif [ -n "$ABI" ]; then
    TARGETTRIPLE="${ARCH}-unknown-${OS}-${ABI}"
  else
    TARGETTRIPLE="${ARCH}-unknown-${OS}"
  fi

  FERRONVERSION="$(curl -fsL https://downloads.ferronweb.org/latest2.ferron)"
  if [ "$FERRONVERSION" == "" ]; then
    echo 'There was a problem while determining latest Ferron version!'
    exit 1
  fi
  FERRONZIPARCHIVE="$(mktemp /tmp/ferron.XXXXX.zip)"
  if ! curl -fsSL "https://downloads.ferronweb.org/$FERRONVERSION/ferron-$FERRONVERSION-$TARGETTRIPLE.zip" > $FERRONZIPARCHIVE; then
    echo 'There was a problem while downloading latest Ferron version!'
    exit 1
  fi
else
  echo 'There was a problem determining Ferron installation type!'
  exit 1
fi

##Create .installer.prop file, if it doesn't exist
if ! [ -f /etc/.ferron-installer.prop ]; then
  echo $INSTALLTYPE > /etc/.ferron-installer.prop;
fi

##Detect systemd
systemddetect=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f systemctl | awk '{ print $2}' | xargs)

##Check the Ferron installation type
if [ "$INSTALLTYPE" == "manual" ]; then
  echo -n 'Path to Ferron zip archive: '
  read FERRONZIPARCHIVE
elif [ "$INSTALLTYPE" == "stable" ]; then
  ##Detect the machine architecture
  ARCH=$(uname -m)

  ##Normalize architecture name
  case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    i386 | i486 | i586 | i686) ARCH="i686" ;;
    armv7*) ARCH="armv7" ;;
    aarch64) ARCH="aarch64" ;;
    riscv64) ARCH="riscv64gc" ;;
    s390x) ARCH="s390x" ;;
    ppc64le) ARCH="powerpc64le" ;;
    *) echo "Unknown architecture: $ARCH"; exit 1 ;;
  esac

  ##Detect the operating system
  OS=$(uname -s)

  case "$OS" in
    Linux) OS="linux" ;;
    FreeBSD) OS="freebsd" ;;
    *) echo "Unknown OS: $OS"; exit 1 ;;
  esac

  ##Detect the C library
  if [ "$OS" = "linux" ]; then
    if ldd --version 2>&1 | grep -q "musl"; then
      LIBC="musl"
    else
      LIBC="gnu"
    fi
  else
    LIBC=""
  fi

  ##Detect the ABI
  if [ "$ARCH" = "armv7" ]; then
    ABI="eabihf"
  else
    ABI=""
  fi

  ##Construct the target triple
  if [ -n "$LIBC" ]; then
    TARGETTRIPLE="${ARCH}-unknown-${OS}-${LIBC}${ABI}"
  elif [ -n "$ABI" ]; then
    TARGETTRIPLE="${ARCH}-unknown-${OS}-${ABI}"
  else
    TARGETTRIPLE="${ARCH}-unknown-${OS}"
  fi

  FERRONVERSION="$(curl -fsL https://downloads.ferronweb.org/latest2.ferron)"
  if [ "$FERRONVERSION" == "" ]; then
    echo 'There was a problem while determining latest Ferron version!'
    exit 1
  fi
  FERRONZIPARCHIVE="$(mktemp /tmp/ferron.XXXXX.zip)"
  if ! curl -fsSL "https://downloads.ferronweb.org/$FERRONVERSION/ferron-$FERRONVERSION-$TARGETTRIPLE.zip" > $FERRONZIPARCHIVE; then
    echo 'There was a problem while downloading latest Ferron version!'
    exit 1
  fi
else
  echo 'There was a problem determining Ferron installation type!'
  exit 1
fi

##Check if Ferron zip archive exists
if ! [ -f $FERRONZIPARCHIVE ]; then
  echo 'Can'"'"'t find Ferron archive! Make sure to download Ferron archive file from https://ferronweb.org and rename it to "ferron.zip".'
  exit 1
fi

##Stop Ferron
echo "Stopping Ferron..."
if [ "$systemddetect" == "" ]; then
  /etc/init.d/ferron stop
else
  systemctl stop ferron
fi

##Copy Ferron files
echo "Copying Ferron files..."
FERRONEXTRACTIONDIRECTORY="$(mktemp -d /tmp/ferron.XXXXX)"
echo $INSTALLTYPE > /etc/.ferron-installer.prop;
if [ "$FERRONVERSION" != "" ]; then
  echo "$FERRONVERSION" > /etc/.ferron-installer.version
fi
unzip $FERRONZIPARCHIVE -d $FERRONEXTRACTIONDIRECTORY > /dev/null
if [ "$INSTALLTYPE" != "manual" ]; then
  rm -f $FERRONZIPARCHIVE
fi
mv $FERRONEXTRACTIONDIRECTORY/ferron{,-*} /usr/sbin
chown root:root /usr/sbin/ferron{,-*}
chmod a+rx /usr/sbin/ferron{,-*}
rm -rf $FERRONEXTRACTIONDIRECTORY

##Install Ferron utilities
echo "Installing Ferron utilities..."
cat > /usr/bin/ferron-updater << 'EOF'
#!/bin/bash

##Print splash
echo '************************************'
echo '**Ferron 2.x updater for GNU/Linux**'
echo '************************************'
echo

##Check if user is root
if [ "$(id -u)" != "0" ]; then
  echo 'You need to have root privileges to update Ferron'
  exit 1
fi

##Check if Ferron is installed
if ! [ -f /usr/sbin/ferron ]; then
  echo 'Ferron isn'"'"'t installed (or it'"'"'s installed without using Ferron installer)!'
  exit 1
fi

##Create .installer.prop file, if it doesn't exist
if ! [ -f /etc/.ferron-installer.prop ]; then
  echo manual > /etc/.ferron-installer.prop;
fi

##Detect systemd
systemddetect=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f systemctl | awk '{ print $2}' | xargs)


##Check the Ferron installation type
INSTALLTYPE="$(cat /etc/.ferron-installer.prop)"
if [ "$INSTALLTYPE" == "manual" ]; then
  echo -n 'Path to Ferron zip archive: '
  read FERRONZIPARCHIVE
elif [ "$INSTALLTYPE" == "stable" ]; then
  ##Detect the machine architecture
  ARCH=$(uname -m)

  ##Normalize architecture name
  case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    i386 | i486 | i586 | i686) ARCH="i686" ;;
    armv7*) ARCH="armv7" ;;
    aarch64) ARCH="aarch64" ;;
    riscv64) ARCH="riscv64gc" ;;
    s390x) ARCH="s390x" ;;
    ppc64le) ARCH="powerpc64le" ;;
    *) echo "Unknown architecture: $ARCH"; exit 1 ;;
  esac

  ##Detect the operating system
  OS=$(uname -s)

  case "$OS" in
    Linux) OS="linux" ;;
    FreeBSD) OS="freebsd" ;;
    *) echo "Unknown OS: $OS"; exit 1 ;;
  esac

  ##Detect the C library
  if [ "$OS" = "linux" ]; then
    if ldd --version 2>&1 | grep -q "musl"; then
      LIBC="musl"
    else
      LIBC="gnu"
    fi
  else
    LIBC=""
  fi

  ##Detect the ABI
  if [ "$ARCH" = "armv7" ]; then
    ABI="eabihf"
  else
    ABI=""
  fi

  ##Construct the target triple
  if [ -n "$LIBC" ]; then
    TARGETTRIPLE="${ARCH}-unknown-${OS}-${LIBC}${ABI}"
  elif [ -n "$ABI" ]; then
    TARGETTRIPLE="${ARCH}-unknown-${OS}-${ABI}"
  else
    TARGETTRIPLE="${ARCH}-unknown-${OS}"
  fi

  FERRONVERSION="$(curl -fsL https://downloads.ferronweb.org/latest2.ferron)"
  if [ "$FERRONVERSION" == "" ]; then
    echo 'There was a problem while determining latest Ferron version!'
    exit 1
  fi
  FERRONZIPARCHIVE="$(mktemp /tmp/ferron.XXXXX.zip)"
  if ! curl -fsSL "https://downloads.ferronweb.org/$FERRONVERSION/ferron-$FERRONVERSION-$TARGETTRIPLE.zip" > $FERRONZIPARCHIVE; then
    echo 'There was a problem while downloading latest Ferron version!'
    exit 1
  fi
else
  echo 'There was a problem determining Ferron installation type!'
  exit 1
fi

##Check if Ferron zip archive exists
if ! [ -f $FERRONZIPARCHIVE ]; then
  echo 'Can'"'"'t find Ferron archive! Make sure to download Ferron archive file from https://ferronweb.org and rename it to "ferron.zip".'
  exit 1
fi

##Stop Ferron
echo "Stopping Ferron..."
if [ "$systemddetect" == "" ]; then
  /etc/init.d/ferron stop
else
  systemctl stop ferron
fi

##Copy Ferron files
echo "Copying Ferron files..."
FERRONEXTRACTIONDIRECTORY="$(mktemp -d /tmp/ferron.XXXXX)"
echo $INSTALLTYPE > /etc/.ferron-installer.prop;
if [ "$FERRONVERSION" != "" ]; then
  echo "$FERRONVERSION" > /etc/.ferron-installer.version
fi
unzip $FERRONZIPARCHIVE -d $FERRONEXTRACTIONDIRECTORY > /dev/null
if [ "$INSTALLTYPE" != "manual" ]; then
  rm -f $FERRONZIPARCHIVE
fi
mv $FERRONEXTRACTIONDIRECTORY/ferron{,-*} /usr/sbin
chown root:root /usr/sbin/ferron{,-*}
chmod a+rx /usr/sbin/ferron{,-*}
rm -rf $FERRONEXTRACTIONDIRECTORY

##Fix SELinux context
restoreconutil=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f restorecon | awk '{ print $2}' | xargs)
if [ "$restoreconutil" != "" ]; then
  echo "Fixing SELinux context..."
  restorecon -r /usr/sbin/ferron{,-*} /usr/bin/ferron-updater /etc/ferron.kdl /var/www/ferron /var/log/ferron /var/lib/ferron
fi

##Restart Ferron
echo "Restarting Ferron..."
if [ "$systemddetect" == "" ]; then
  /etc/init.d/ferron start
else
  systemctl start ferron
fi

echo "Done! Ferron is updated successfully!"
EOF
chmod a+rx /usr/bin/ferron-updater

##Modify Ferron user
if ! [ -d "$(getent passwd ferron | cut -d: -f6)"]; then
  echo "Modifying Ferron user..."
  mkdir -p /var/lib/ferron
  chown -hR ferron:ferron /var/lib/ferron
  usermod -h /var/lib/ferron ferron
fi

##Fix SELinux context
restoreconutil=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f restorecon | awk '{ print $2}' | xargs)
if [ "$restoreconutil" != "" ]; then
  echo "Fixing SELinux context..."
  restorecon -r /usr/sbin/ferron{,-*} /usr/bin/ferron-updater /etc/ferron.kdl /var/www/ferron /var/log/ferron /var/lib/ferron
fi

##Migrate Ferron configuration
echo "Migrating Ferron configuration..."
/usr/sbin/ferron-yaml2kdl /etc/ferron.yaml /etc/ferron.kdl
mv /etc/ferron.yaml /etc/ferron.yaml.bak
chmod a+r /etc/ferron.kdl

##Reinstall Ferron service
echo "Reinstalling Ferron service..."
systemddetect=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f systemctl | awk '{ print $2}' | xargs)
cat > /etc/init.d/ferron << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          ferron
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:     $local_fs $remote_fs $network $syslog $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# X-Interactive:     true
# Short-Description: Ferron web server
# Description:       Start the web server
#  This script will start the Ferron web server.
### END INIT INFO

server="/usr/sbin/ferron"
serverargs="-c /etc/ferron.kdl"
servicename="Ferron web server"

user="ferron"

script="$(basename $0)"
lockfile="/var/lock/$script"

. /etc/rc.d/init.d/functions 2>/dev/null || . /etc/rc.status 2>/dev/null || . /lib/lsb/init-functions 2>/dev/null

ulimit -n 12000 2>/dev/null
RETVAL=0

privilege_check()
{
  if [ "$(id -u)" != "0" ]; then
    echo 'You need to have root privileges to manage Ferron service'
    exit 1
  fi
}

do_start()
{
    if [ ! -f "$lockfile" ] ; then
        echo -n $"Starting $servicename: "
        setcap 'cap_net_bind_service=+ep' $server
        runuser -l "$user" -c "$server $serverargs > /dev/null &" && echo_success || echo_failure
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && touch "$lockfile"
    else
        echo "$servicename is locked."
        RETVAL=1
    fi
}

echo_failure() {
    echo -n "fail"
}

echo_success() {
    echo -n "success"
}

echo_warning() {
    echo -n "warning"
}

do_stop()
{
    echo -n $"Stopping $servicename: "
    pid=`ps -aefw | grep "$server $serverargs" | grep -v " grep " | awk '{print $2}'`
    kill -9 $pid > /dev/null 2>&1 && echo_success || echo_failure
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f "$lockfile"

    if [ "$pid" = "" -a -f "$lockfile" ]; then
        rm -f "$lockfile"
        echo "Removed lockfile ( $lockfile )"
    fi
}

do_reload()
{
    echo -n $"Reloading $servicename: "
    pid=`ps -aefw | grep "$server $serverargs" | grep -v " grep " | awk '{print $2}'`
    kill -1 $pid > /dev/null 2>&1 && echo_success || echo_failure
    echo
}

do_status()
{
   pid=`ps -aefw | grep "$server $serverargs" | grep -v " grep " | awk '{print $2}' | head -n 1`
   if [ "$pid" != "" ]; then
     echo "$servicename (pid $pid) is running..."
   else
     echo "$servicename is stopped"
   fi
}

case "$1" in
    start)
        privilege_check
        do_start
        ;;
    stop)
        privilege_check
        do_stop
        ;;
    status)
        do_status
        ;;
    restart)
        privilege_check
        do_stop
        do_start
        RETVAL=$?
        ;;
    reload)
        privilege_check
        do_reload
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|reload}"
        RETVAL=1
esac

exit $RETVAL
EOF
  chmod a+rx /etc/init.d/ferron
if [ "$systemddetect" == "" ]; then
  update-rc.d ferron defaults
else
  cat > /etc/systemd/system/ferron.service << 'EOF'
[Unit]
Description=Ferron web server
After=network.target

[Service]
Type=simple
User=ferron
ExecStart=/usr/sbin/ferron -c /etc/ferron.kdl
ExecReload=kill -HUP $MAINPID
Restart=on-failure
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable ferron
fi

##Restart Ferron
RESTART_SUCCESSFUL=0
RESTART_MAX_TRIES=5
for RESTART_TRY in $(seq 1 $RESTART_MAX_TRIES); do
  echo "Restarting Ferron..."
  if [ "$systemddetect" == "" ]; then
    /etc/init.d/ferron start
    sleep 0.5
    /etc/init.d/ferron status 2>&1 | (grep "is running..." >/dev/null 2>/dev/null && RESTART_SUCCESSFUL=1)
  else
    systemctl start ferron
    sleep 0.5
    systemctl status ferron >/dev/null 2>/dev/null && RESTART_SUCCESSFUL=1
  fi
  if [ $RESTART_SUCCESSFUL -eq 0 ]; then
    if [ $RESTART_TRY -ge $RESTART_MAX_TRIES ]; then
      echo "Ferron couldn't be restarted at try #$RESTART_TRY, not retrying..."
    else
      echo "Ferron couldn't be restarted at try #$RESTART_TRY, retrying in 1 minute..."
      sleep 60
    fi
  else
    break
  fi
done

echo "Done! Ferron is updated successfully!"
