#!/data/data/com.termux/files/usr/bin/sh


for service in crond nginx postgres quickstart-dendrite sshd whatsapp
do
        touch "/data/data/com.termux/files/usr/var/service/${service}/down"
        rm -f "/data/data/com.termux/files/usr/var/service/${service}/down"

        /data/data/com.termux/files/usr/etc/profile.d/start-services.sh
done
