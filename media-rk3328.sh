#!/bin/bash
# Version 1.0

# Get superuser privileges
if [ $EUID != 0 ]; then
    echo "This script requires superuser privileges:"
    sudo "$0" "$@"
    exit $?
fi

# Set error detection
ERROR=0
trap 'ERROR=1' ERR

# Set dialog variables
DIALOG=dialog
BACKTITLE="Armbian Bionic RK3328 media testing script (v1.0)"

# Set misc variables
DEBIAN_FRONTEND=noninteractive
DEFAULTUSER=$(getent passwd 1000 | cut -f1 -d:)

# Set features variables
SYSTEM=0
DEVEL=0
MPV=0
GSTREAMER=0
CLSAMPLES=0
KODI=0
STREAMING=0
EQUALIZER=0
XSERVER="Arm"
GL4ES=0

# Greeting and confirmation
$DIALOG --backtitle "$BACKTITLE" \
        --yesno "This script will install the libraries and config files required to enable X11 video and 3D acceleration. It can also install several apps and features that make use of the accelerated multimedia capabilites.\nIn the next screen, you will be able to select which extra features to install.\nProceed?" \
        15 40
        
if [ $? -eq 1 ]
then
	clear
	exit 1
fi

# Apps selection dialog
while true
do
exec 3>&1
SELECTION=$($DIALOG --backtitle "$BACKTITLE" \
		--help-button \
        --title "Feature selection" \
        --checklist "Please mark the extra features you want to install:" 16 76 14 \
        "System" "Install libs and perform base configurations" on\
        "Devel" "Install development libraries" off\
        "MPV" "MPV player with EGL/GBM+RKMPP acceleration" on \
        "Gstreamer" "Gstreamer Rockchip plugins and Qt player" on \
        "GL4ES" "OpenGL 1.5-2.0 wrapper" off \
        "Streaming" "Widevine, Pepper-Flash and h264ify for Chromium" off \
        "Equalizer" "Pulseaudio LADSPA GTK equalizer" off \
        "Kodi" "RKMPP+GBM accelerated Kodi 18.0" off \
        2>&1 1>&3)

RETVAL=$?
exec 3>&-

if [ $RETVAL -eq 2 ]
then
	$DIALOG --backtitle "$BACKTITLE" --textbox readme.txt 21 76
elif [ $RETVAL -eq 1 ]
then
	exit 1
else
	for i in $SELECTION
	do
		case $i in
			System)
				SYSTEM=1 ;;
			Devel)
				DEVEL=1 ;;
			MPV)
				MPV=1 ;;
			Gstreamer)
				GSTREAMER=1 ;;
#			CLSamples)
#				CLSAMPLES=1 ;;
			GL4ES)
				GL4ES=1 ;;
			Streaming)
				STREAMING=1 ;;
			Equalizer)
				EQUALIZER=1 ;;
			Kodi)
				KODI=1 ;;
		esac
	done
	break
fi
done

# Prepare for installation
if [ $SYSTEM -eq 0 ]
then
	# Warn if no system config selected
	$DIALOG --colors --backtitle "$BACKTITLE" \
	        --yesno "\Zb\Z1WARNING:\ZB \Z0You have chosen not to perform basic system configuration. This means that your system is already configured and you have the basic libraries installed. Otherwise, the other apps will not install properly.\nAre you sure you want to continue?" \
	        15 40
	        
	if [ $? -eq 1 ]
	then
		clear
		exit 1
	fi
elif [ $STREAMING -eq 1 ]
then
	# Warn before installing Docker armhf Chromium container
	$DIALOG --colors --backtitle "$BACKTITLE" \
	        --yesno "\Zb\Z1WARNING:\ZB \Z0You have chosen to install 32-bit Chromium with streaming support. It will install Docker, and create an armhf container that will take approximately 420 Mb of disk space.\nYou will also be able to use that container to install and run other 32-bit apps.\nProceed?" \
	        15 40
	        
	if [ $? -eq 1 ]
	then
		clear
		exit 1
	fi
else
	# Select X server to install
	XSERVER=$($DIALOG --stdout --backtitle "$BACKTITLE" --title "Alternate X server" \
	        --menu "We are going to install two different drivers for accelerated X desktop. You can switch between them by editing /etc/X11/xorg.conf.d/01-armbian-defaults.conf\nWhich version do you prefer by default?" \
	        18 60 12 Arm "Armsoc, only fulscreen vsync but better desktop" Gla "Glamor, complete vsync but laggier desktop")
fi

# Log installation output to file, and follow it in a tailbox
$DIALOG --backtitle "$BACKTITLE" --exit-label "HIDE" --tailbox install.log 21 75 &
exec &> install.log

# Basic configuration and install base packages
apt-get -y -q update
if [ $SYSTEM -eq 1 ]
then
echo '*************************************************** 
* Installing base packages and configuring system *
***************************************************'
echo "Installing base libs..."
dpkg --unpack packages/libs/*.deb
[ $DEVEL -eq 1 ] && dpkg --unpack packages/libs/dev/*.deb
apt-get -y -q -f install

# Check if udev and sysfs rules are present
[ -f /etc/udev/rules.d/50-mali.rules ] || echo 'KERNEL=="mali*", MODE="0660", GROUP="video"
' > /etc/udev/rules.d/50-mali.rules
[ -f /etc/udev/rules.d/50-rockchip64-vpu.rules ] || echo 'KERNEL=="vpu_service", MODE="0660", GROUP="video"
KERNEL=="rkvdec", MODE="0660", GROUP="video"
' > /etc/udev/rules.d/50-rockchip64-vpu.rules

sed -i '/ff300000.gpu.devfreq.ff300000.gpu.governor/d' /etc/sysfs.conf
echo 'devices/platform/ff300000.gpu/devfreq/ff300000.gpu/governor = performance' >> /etc/sysfs.conf

echo "Configuring X server..."

# Install packages
touch /var/log/Xorg.0.log.old # To avoid error message when purging xserver
[ $(dpkg-query --show --showformat='${db:Status-Status}\n' xserver-xorg-core) == 'not-installed' ] || 	dpkg --purge --force-depends xserver-xorg-core
[ $(dpkg-query --show --showformat='${db:Status-Status}\n' xserver-common) == 'not-installed' ] || dpkg --purge --force-depends xserver-common
dpkg --unpack packages/xserver/*.deb
#[ $DEVEL -eq 1 ] && dpkg --unpack packages/xserver/dev/*.deb
apt-get -y -q -f install

# Configure xorg.conf file
rm -f /etc/X11/xorg.conf.d/*
rm -f /etc/X11/xorg.conf

if [ $XSERVER == "Gla" ]
then
	# Glamor
		echo 'Section "Device"
		    Identifier  "Rockchip Graphics"
		
		## Use armsoc driver
		#	Driver		"armsoc"
		## End armsoc configuration
		
		## Use modesetting and glamor
		    Driver      "modesetting"
		    Option      "AccelMethod"    "glamor"     ### "glamor" to enable 3D acceleration, "none" to disable.
		    Option      "DRI"            "2"
		    Option      "Dri2Vsync"      "true"
		## End glamor configuration
		
		EndSection
		
		Section "Screen"
		    Identifier "Default Screen"
		    SubSection "Display"
		        Depth 24
		        # Modes "1920x1080" "1280x1024" "1024x768" "800x600"
		    EndSubSection
		EndSection
		' > /etc/X11/xorg.conf.d/01-armbian-defaults.conf
else
	# Armsoc
	echo 'Section "Device"
		    Identifier  "Rockchip Graphics"
		
		## Use armsoc driver
			Driver		"armsoc"
		## End armsoc configuration
		
		## Use modesetting and glamor
		#    Driver      "modesetting"
		#    Option      "AccelMethod"    "glamor"     ### "glamor" to enable 3D acceleration, "none" to disable.
		#    Option      "DRI"            "2"
		#    Option      "Dri2Vsync"      "true"
		## End glamor configuration
		
		EndSection
		
		Section "Screen"
		    Identifier "Default Screen"
		    SubSection "Display"
		        Depth 24
		        # Modes "1920x1080" "1280x1024" "1024x768" "800x600"
		    EndSubSection
		EndSection
		' > /etc/X11/xorg.conf.d/01-armbian-defaults.conf
fi

# Disable window compositing
[ -f /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml ] && sed -i -e 's/name="use_compositing" type="bool" value="true"/name="use_compositing" type="bool" value="false"/g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
sed -i -e 's/name="use_compositing" type="bool" value="true"/name="use_compositing" type="bool" value="false"/g' /home/$DEFAULTUSER/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

# Configure Chromium
echo "Configuring Chromium acceleration..."
rm -f /etc/chromium-browser/default
echo '# Default settings for chromium-browser. This file is sourced by /bin/sh from /usr/bin/chromium-browser
CHROMIUM_FLAGS="$CHROMIUM_FLAGS \
--disable-low-res-tiling \
--num-raster-threads=$(grep -c processor /proc/cpuinfo) \
--profiler-timing=0 \
--disable-composited-antialiasing \
--disk-cache-dir=/tmp/${USER}-cache \
--disk-cache-size=$(findmnt --target /tmp -n -o AVAIL -b | awk '\''{printf ("%0.0f",$1*0.3); }'\'') \
--no-sandbox \
--test-type \
--show-component-extension-options \
--ignore-gpu-blacklist \
--use-gl=egl"
' > /etc/chromium-browser/default

fi

# Install MPV
if [ $MPV -eq 1 ]
then
	echo '*************************************************** 
*     Installing accelerated MPV media player     *
***************************************************'
	[ $(dpkg-query --show --showformat='${db:Status-Status}\n' mpv) == 'not-installed' ] || dpkg --purge --force-depends mpv
	dpkg --unpack packages/mpv/*.deb
	apt-get -f -y install
fi

# Install Gstreamer
if [ $GSTREAMER -eq 1 ]
then
	echo '*************************************************** 
*Installing Gstreamer backport, plugins and player*
***************************************************'
	apt-get -y -q install gstreamer1.0-plugins-base-apps qtgstreamer-plugins-qt5 gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-plugins-good gstreamer1.0-plugins-base libqt5opengl5 libqt5qml5 libqt5quick5 libqt5widgets5 libqt5gui5 libqt5core5a qml-module-qtquick2 libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediaquick-p5 qtmultimedia5-examples qtmultimedia5-doc-html
	dpkg --unpack packages/gstreamer/*.deb
	apt-get -f -y install
	echo '#!/usr/bin/env xdg-open
[Desktop Entry]
Type=Application
Name=Rockchip Gst Player
GenericName=Media Player
Comment=A gstreamer base player
Exec=env QT_GSTREAMER_WIDGET_VIDEOSINK=rkximagesink /usr/lib/aarch64-linux-gnu/qt5/examples/multimediawidgets/player/player --geometry 960x640+0+0
Icon=/usr/share/icons/gnome/48x48/categories/applications-multimedia.png
Terminal=false
Categories=Qt;AudioVideo;Player;Video;
MimeType=application/ogg;application/x-ogg;application/mxf;application/sdp;application/smil;application/x-smil;application/streamingmedia;application/x-streamingmedia;application/vnd.rn-realmedia;application/vnd.rn-realmedia-vbr;audio/aac;audio/x-aac;audio/vnd.dolby.heaac.1;audio/vnd.dolby.heaac.2;audio/aiff;audio/x-aiff;audio/m4a;audio/x-m4a;application/x-extension-m4a;audio/mp1;audio/x-mp1;audio/mp2;audio/x-mp2;audio/mp3;audio/x-mp3;audio/mpeg;audio/mpeg2;audio/mpeg3;audio/mpegurl;audio/x-mpegurl;audio/mpg;audio/x-mpg;audio/rn-mpeg;audio/musepack;audio/x-musepack;audio/ogg;audio/scpls;audio/x-scpls;audio/vnd.rn-realaudio;audio/wav;audio/x-pn-wav;audio/x-pn-windows-pcm;audio/x-realaudio;audio/x-pn-realaudio;audio/x-ms-wma;audio/x-pls;audio/x-wav;video/mpeg;video/x-mpeg2;video/x-mpeg3;video/mp4v-es;video/x-m4v;video/mp4;application/x-extension-mp4;video/divx;video/vnd.divx;video/msvideo;video/x-msvideo;video/ogg;video/quicktime;video/vnd.rn-realvideo;video/x-ms-afs;video/x-ms-asf;audio/x-ms-asf;application/vnd.ms-asf;video/x-ms-wmv;video/x-ms-wmx;video/x-ms-wvxvideo;video/x-avi;video/avi;video/x-flic;video/fli;video/x-flc;video/flv;video/x-flv;video/x-theora;video/x-theora+ogg;video/x-matroska;video/mkv;audio/x-matroska;application/x-matroska;video/webm;audio/webm;audio/vorbis;audio/x-vorbis;audio/x-vorbis+ogg;video/x-ogm;video/x-ogm+ogg;application/x-ogm;application/x-ogm-audio;application/x-ogm-video;application/x-shorten;audio/x-shorten;audio/x-ape;audio/x-wavpack;audio/x-tta;audio/AMR;audio/ac3;audio/eac3;audio/amr-wb;video/mp2t;audio/flac;audio/mp4;application/x-mpegurl;video/vnd.mpegurl;application/vnd.apple.mpegurl;audio/x-pn-au;video/3gp;video/3gpp;video/3gpp2;audio/3gpp;audio/3gpp2;video/dv;audio/dv;audio/opus;audio/vnd.dts;audio/vnd.dts.hd;audio/x-adpcm;application/x-cue;audio/m3u;
' > /usr/share/applications/demo-player.desktop
fi

# Install Chromium streaming support
if [ $STREAMING -eq 1 ]
then
	echo '*************************************************** 
*   Installing Chromium armhf with web streaming support    *
***************************************************'
	echo "Installing Docker..."
	# Install docker, and give rights to the default user
	apt-get -y -q install docker.io
	sudo usermod -aG docker $DEFAULTUSER
	cd packages/streaming
	echo "Creating container..."
	# Create armhf container with Chromium
	docker build -t teacupx/chromium-armhf .
	# Create volume to store settings
	docker volume create chromium_home
	# Install wrappers for launching Chromium
	mkdir -p /usr/local/bin
	mkdir -p /usr/local/share/applications
	install -m 755 armhf-run /usr/local/bin
	cp chromium-32*desktop /usr/local/share/applications/
	cd ../..
fi

# Not supported: Install OpenCL examples
# if [ $CLSAMPLES -eq 1 ]
# then
	# echo '*************************************************** 
# *            Installing OpenCL examples           *
# ***************************************************'
	# sudo apt-get -y -q install libcurl4
	# mkdir -p /home/$DEFAULTUSER/clsamples
	# tar xf packages/clsamples/clsamples.tar.xz -C /home/$DEFAULTUSER/clsamples
	# chown -R $DEFAULTUSER:$DEFAULTUSER /home/$DEFAULTUSER/clsamples
# fi

# Install GL4ES
if [ $GL4ES -eq 1 ]
then
	echo '*************************************************** 
*             Installing GL4ES wrapper            *
***************************************************'
	tar xvf packages/gl4es/*.tar.xz -C /
fi

# Install Pulseaudio LADSPA GTK equalizer
if [ $EQUALIZER -eq 1 ]
then
	echo '*************************************************** 
*       Installing Pulseaudio GTK Equalizer       *
***************************************************'
	dpkg --unpack packages/paeq/*.deb
	apt-get -f -y install
fi

# Install Kodi
if [ $KODI -eq 1 ]
then
	echo '*************************************************** 
*      Installing accelerated Kodi 18.0-rc4       *
***************************************************'
	sudo usermod -aG input $DEFAULTUSER # Workaround until this fix is included in stable Armbian
	apt-get -y -q purge *kodi*
	apt-get -y -q --allow-downgrades install ./packages/kodi/deps/*.deb
	apt-get -y -q --allow-downgrades install ./packages/kodi/*.deb
	[ $DEVEL -eq 1 ] && apt-get -y -q --allow-downgrades install ./packages/kodi/deps/dev/*.deb
	[ $DEVEL -eq 1 ] && apt-get -y -q --allow-downgrades install ./packages/kodi/dev/*.deb
fi

# Finish and exit with proper message
echo Finished.
sleep 2
exec &> /dev/tty
killall $DIALOG
clear

if [ $ERROR -eq 0 ]
then
	$DIALOG --colors --backtitle "$BACKTITLE" \
        --msgbox "Installation has succeeded. Please reboot your device.\n\Z2NOTE: Disabling window manager compositing is recommended to improve performance." \
        9 40
	exit 0
else
	$DIALOG --colors --backtitle "$BACKTITLE" \
        --msgbox "\Zb\Z1WARNING:\ZB \Z0There were errors during installation! You can see the log in the file 'install.log'." \
        9 40
	exit 1
fi
