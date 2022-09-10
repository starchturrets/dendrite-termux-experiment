#!/data/data/com.termux/files/usr/bin/sh

echo "updating termux packages..."
pkg update -y && pkg upgrade -y
echo "updating certbot..."
/data/data/com.termux/files/usr/opt/certbot/bin/pip install --upgrade pip certbot
echo "updating dendrite..."
cd "/data/data/com.termux/files/home/dendrite"
git pull
/data/data/com.termux/files/home/dendrite/build.sh
echo "updating mautrix-whatsapp..."
cd "/data/data/com.termux/files/home/whatsapp"
git pull
/data/data/com.termux/files/home/whatsapp/build.sh -tags nocrypto
echo "restarting services..."
source /data/data/com.termux/files/home/restart.sh
