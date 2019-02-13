ARMBIAN UNOFFICIAL RK3328 MEDIA TESTING SCRIPT
----------------------------------------------
v1.0 Bionic - 2019/01/13


This script will install several multimedia-related software pieces in a
RK3328 Ubuntu Bionic Armbian desktop default image (kernel 4.4.y).
Currently it only supports the installation of the features, while
uninstall must be performed manually.

The script must be run in a command line from the same directory it was
unpacked (./media-rk3328.sh), and will ask for superuser privileges if
not launched with "sudo". Each subfolder contains, in addition to the
packages needed for installation, a text file with information about the
sources for those packages.

The script will present the user with a menu where they can select the
features to be installed. Here is a brief description of each option:

- System: This option will install the base libraries, X server packages
          and system files configuration. It must be run at least once
          before installing any of the other features, or after any
          system upgrade that modified X or Chromium configuration.
          Enabling system config will also present the user with the
          choice of two different versions of the Rockchip X server:
            · Glamor: The tweaked X server that you can download from 
              Rockchip repos, with a few additional tweaks. It will use
              Glamor for GPU acceleration, providing good 3D performance
              and complete vsync, but giving a very laggy experience in 
              general desktop usage.
            · Armsoc: An updated version of the xf86 Armsoc driver. It
              only supports fullscreen vsync, but on the other hand the
              overall desktop experience is much snappier.
           
- Devel: When this option is enabled, the script will install the 
         development libraries for every other option that is selected.
         So, for example, if in your first run of the script you keep 
         this option disabled and enable the rest, it will install all 
         the features but without any devel lib. If eventually you need,
         e.g., to compile some app requiring Gstreamer development libs,
         then you can run again the script, and select only "Devel" and
         "Gstreamer", so in that run it will only install Gstreamer with
         the development libraries, without touching the rest.
         
- MPV: This is a RKMPP accelerated version of MPV. In order to use the 
       hardware acceleration, it needs to make use of KMS for display,
       which means that it will ignore the X server if it is running,
       and play video in a full-screen overlay, using keyboard or LIRC
       to control the player. Type "man mpv" for a list of keyboard
       controls (tip: shift+Q will save position and exit).
       Alternatively, you can also use software decoding, and output to
       a X window with mouse support. It will still have some display
       acceleration through X11/EGL, though not as efficient as GBM/KMS.
         · To use the X, non-RKMPP version, just type "mpv <file>" in
           the console, or use the launcher labeled simply "MPV".
         . To use the GBM+RKMPP version, type "mpv-gbm <file>", or use
           the "MPV (GBM)" launcher.
         · You can use the player even in a console-only session.

- Gstreamer: These are the Rockchip Gstreamer plugins for media playback
             and capture.
             Notice that the Gstreamer plugin is the only method that
             allows full RKMMP+KMS acceleration associated to a X 
             window.
               · To play a video in a X session, use the launcher "Rock-
                 chip Gst Player".
               . From the command line, in a X session, type:
                 "gst-play-1.0 --videosink=rkximagesink <file>"
               . From a console-only session, type:
                 "gst-play-1.0 --videosink=kmssink <file>"

- GL4ES: An Opengl-ES wrapper library that will allow you to use OpenGL
         1.5-2.0 compatible programs with hardware acceleration. 
         More info: https://github.com/ptitSeb/gl4es.
         · In order to make it easier to use the library, we have
           included a script called "glrun", that will set the proper
           environment variables. Launch your OpenGL program like this:
           "glrun <command>"
         
- Streaming: This will install Chromium with the Widevine DRM and
             Pepper-Flash libraries enabled, allowing you to watch 
             videos from sites such as Netflix, Amazon Prime or Hulu.
             It will also install the h264ify addon, which will force
             all Youtube videos to use the H.264 codec.
             Since those libraries are only available for 32-bit ARM,
             the script will install a whole armhf docker container,
             with a minimal ubuntu and Chromium installation on it. It
             will also install a wrapper for running commands inside the
             docker container called "armhf-run":
               · Type "armhf-run chromium-browser" to launch the 32-bit
                 Chromium in regular mode.
               . Type "armhf-run chromium-streaming" to launch it in
                 streaming mode (may cause problems with non-streaming
                 webpages).
             The script will also install desktop entries for both 
             options.

- Equalizer: A GTK-based equalizer for PulseAudio, using LADSPA. You
             need to enable it through the menu entry, and select the
             desired preset or tweak your own settings. The "Boosted"
             preset is recommended for everyday use.
             This package is old and unmaintained, but I still find it
             useful.

- Kodi: Kodi 18.0 Leia rc4. This version is supposed to be stable
        enough for normal use. But the main purpose of including Kodi in
        the script is to test the new RKMPP+KMS implementation. We don't
        intend to offer a full-fledged distribution of Kodi. For that, I
        recommend using LibreELEC.
        It cannot be launched from an active X session, you need to
        switch to a virtual terminal and stop the X server first.
        · The "Kodi" desktop launcher will do the whole process for you.
        · From the command line, in a X session, type:
          "kodi-gbm-wrapper" for the same effect.
        · If you are already in a console-only session, you can just 
          type "kodi".

All the RKMPP accelerated players should handle up to 4K@60 10-bit HEVC 
with perfect smoothness.	


Please report bugs and suggestions in the thread dedicated to this
script at the Armbian Forum. Enjoy!

JMCC.
