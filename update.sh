#!/data/data/com.termux/files/usr/bin/sh

echo "updating termux packages..."
pkg update && pkg upgrade -y
echo "updating certbot..."
$PREFIX/opt/certbot/bin/pip install --upgrade pip certbot
echo "updating dendrite..."
cd dendrite
git pull
./build.sh
echo "updating mautrix-whatsapp..."
cd
cd whatsapp
git pull
./build.sh -tags nocrypto
echo "restarting services..."
/data/data/com.termux/files/usr/etc/profile.d/start-services.sh
