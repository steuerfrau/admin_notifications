#!/bin/bash
# Check for updates depending on the distribution and send email notification.

#################
### Variables ###
#################
# PACKAGELIST is the list of available updates
PACKAGELIST=$( mktemp )
# SHORTLIST also is the list of available updates, but shorter
SHORTLIST=$( mktemp )
# MAILFILE is the email's content
MAILFILE=$( mktemp )
# KERNELINFO will be toggled in case of kernel update
KERNELINFO=false
# MAILTO is the recipient of notification emails
MAILTO=""

export LC_ALL=C

logger -t "check-for-updates" "Checking for software updates..."

#######################
### Opensuse / SLES ###
#######################
if [ -x /usr/bin/zypper ]; then
    # check for updates on opensuse / sles
    zypper ref 1>/dev/null
    zypper lu > $PACKAGELIST
    # if no updates, stop here.
    if grep -Fxq "No updates found." $PACKAGELIST; then
        logger -t "check-for-updates" "No software updates available"
        exit 0
    fi
    # find out if kernel update
    if grep "kernel" $PACKAGELIST; then
        KERNELINFO=true
    fi
    # reduce amount of information in $PACKAGELIST
    cat $PACKAGELIST | egrep -v "^(Loading|Reading)" > $SHORTLIST
#######################
### CentOS / Redhat ###
#######################
elif [ -x /usr/bin/yum ]; then
    # check for updates on centos / redhat
    yum check-update 1>/dev/null
    yum --disableplugin=fastestmirror list updates > $PACKAGELIST
    # if no updates, stop here.
    if [ ! -s $PACKAGELIST ]; then
        logger -t "check-for updates" "No software updates available"
        exit 0
    fi
    # find out if kernel update
    if grep "kernel" $PACKAGELIST; then
        KERNELINFO=true
    fi
    # reduce amount of information in $PACKAGELIST
    cat $PACKAGELIST | egrep -v "^(Updated\ Packages)" > $SHORTLIST
#######################
### Debian / Ubuntu ###
#######################
elif [ -x /usr/bin/apt-get ]; then
    # check for updates on debian / ubuntu
    apt-get update 1>/dev/null 2>$PACKAGELIST
    apt-get -s upgrade >> $PACKAGELIST
    # if no updates, stop here.
    if grep -Fxq "0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded." $PACKAGELIST; then
        logger -t "check-for updates" "No software updates available"
        exit 0
    fi
    # find out if kernel update
    if grep -e "linux-headers" -e "linux-image" "$PACKAGELIST" ; then
        KERNELINFO=true
    fi
    # reduce amount of information in $PACKAGELIST
    cat $PACKAGELIST | egrep -v "^(Reading|Building|Inst|Conf)" > $SHORTLIST 
fi

#########################
### Compose the email ###
#########################
logger -t "check-for-updates" "Found software updates..."

cat << EOF > $MAILFILE
From: Sendername <support@company>
To: ${MAILTO// /, }
Content-Type: text/plain; charset=utf-8
Subject: Softwareupdates für $HOSTNAME

EOF

# intro
echo -e "Lieber Admin,\n\nauf Ihrem Server $HOSTNAME stehen Updates zur Installation bereit. Wenn Sie die automatische Update-Installation gewählt haben, werden die Updates innerhalb von 24 Stunden eingespielt. Wenn Sie sich gegen Auto-Updates entschieden haben, installieren Sie die Updates bitte manuell.\n" >> $MAILFILE

# if kernel update add extra notification
if [ "$KERNELINFO" == true ]; then
    echo -e "Bitte beachten Sie:\nKernelupdates müssen immer manuell installiert werden und erfordern einen Neustart des Servers. Benötigen Sie dabei Hilfe, dann kommen Sie gern auf uns zu.\n\nMöchten Sie uns mit dem Einspielen des Kernel-Updates beauftragen, nennen Sie uns bitte einen Zeitpunkt, zu dem wir Ihren Server neu starten dürfen. Beachten Sie bitte, dass wir Zeiten außerhalb des von Ihnen gebuchten SLA ggf. gesondert berechnen.\n" >> $MAILFILE
fi
# list the actual updates
echo -e "Folgende Updates stehen zur Installation bereit:\n
--\n" >> $MAILFILE
cat $SHORTLIST >> $MAILFILE
# outro
echo -e "\n--\n\nHaben Sie Fragen, oder benötigen Sie Unterstützung? Wir stehen gerne zur Verfügung.\n\n" >> $MAILFILE
# send the email
if [ ! -z "$MAILTO" ]; then
    logger -t "check-for-updates" "Sending notification email..."
    cat $MAILFILE | sendmail $MAILTO
fi

##########################
### clean up tmp files ###
##########################
logger -t "check-for-updates" "Clean up list of old updates..."
rm $PACKAGELIST
rm $SHORTLIST
logger -t "check-for-updates" "Clean up list of old email notification..."
rm $MAILFILE

# EOF

