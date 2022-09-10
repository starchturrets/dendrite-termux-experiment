# Prerequisites

- An Android Phone (in this case, I used a lava iris88s running Android 8.1.0, kernel version 4.4.95+. It had 2 GB RAM, and I expanded its internal storage with a 64 GB SD Card. While Termux can't be directly installed onto an SD card, dendrite can be configured to store media files on it, which should help avoid clogging up the internal storage.)
- A domain you control (I used a freenom domain a friend gifted me ages ago).
- A router that allows you to do port forwarding.




# Main Packages Needed to be Installed in Termux
 
- Certbot (to handle HTTPS, needed for federation)
- PostgreSQL (needed for the Dendrite database)
- NGINX (to handle reverse proxying)
- Dendrite (for the actual server itself)



It's also reccomended to install openSSH, and setup a termux-service for it. Vim is also handy for editing config files. 


# Setting up SSH 
[Based off of the termux wiki:](https://wiki.termux.com/wiki/Remote_Access)

    $ pkg update && pkg upgrade
    $ pkg install openssh termux-services
    $ passwd 

- Restart Termux so you can run `sv-enable sshd` (this starts the SSH daemon whenever termux is started).
- The device's local IP address can be found under WiFi settings.
- You can then execute `ssh user@IP -p 8022` to gain access from another device.

# Setting up Certbot

Instructions are based off of [here](https://github.com/medanisjbara/synapse-termux/blob/main/GUIDE.md). In my case, my ISP was blocking port 80, so I couldn't easily have certbot run automatically to obtain certificates. I had to do the DNS manual challenge in order to get them. (Cloudflare DNS does allow the challenge to be run automatically, but apparently not on freenom domains).

- You have to set CARGO_BUILD_TARGET manually in order for the cryptography dependency to be able to install.
      
      $ pkg install python rust
      $ uname -m # to find out your architecture, armv7l in my case
      $ rustc --print target-list | grep android # to figure out what you should set CARGO_BUILD_TARGET to
      $ export CARGO_BUILD_TARGET=armv7-linux-androideabi

- Setup the virtual environment, and install certbot:

      $ python -m venv $PREFIX/opt/certbot
      $ $PREFIX/opt/certbot/bin/pip install --upgrade pip
      $ $PREFIX/opt/certbot/bin/pip install certbot
      $ ln -s $PREFIX/opt/certbot/bin/certbot $PREFIX/bin/certbot

- This step takes a while, especially when building the wheel for the `cryptography` package. To obtain the certificates, I ran:

      certbot certonly --work-dir $PREFIX/var/lib/letsencrypt --logs-dir $PREFIX/var/log/letsencrypt --config-dir $PREFIX/etc/letsencrypt --preferred-challenges dns --manual -d my.domain,*.my.domain

As I was using the manual DNS challenge, I had to edit the DNS from the Cloudflare Dashboard. Certbot walks you through it however, so it's fairly easy.

# Setting up PostgreSQL

At this time, postgres does not appear to support having its data directory on an external SD card because of ownership errors.
- First, create a database cluster, and setup termux-service so it starts the postgres server automatically.

      $ pkg install postgresql
      $ pg_ctl -D $PREFIX/var/lib/postgresql initdb
      $ sv-enable postgres 
      $ /data/data/com.termux/files/usr/etc/profile.d/start-services.sh

- The [official Dendrite documentation](https://matrix-org.github.io/dendrite/installation/database) provide instructions for how to prepare the database. The Termux version does have some slight differences in syntax, however. 
      
      $ createuser -P dendrite
      $ createdb -O dendrite dendrite
      $ for i in appservice federationapi mediaapi mscs roomserver syncapi keyserver userapi; do
          createdb -O dendrite dendrite_$i
        done


# Setting up NGINX

- The Dendrite devs provide a [sample configuration](https://github.com/matrix-org/dendrite/blob/main/docs/nginx/monolith-sample.conf) which is very helpful.
- /u/medanisjbara's [guide](https://github.com/medanisjbara/synapse-termux/blob/main/GUIDE.md) is also very helpful. 

      $ pkg install nginx
      $ cd $PREFIX/etc/nginx
      $ cp nginx.conf nginx.conf.orig # copy the original file in case I need to restore
      $ rm -f nginx.conf
      $ curl "https://raw.githubusercontent.com/medanisjbara/synapse-termux/main/nginx.conf" -O $PREFIX/etc/nginx/nginx.conf
      

      
- Set up the virtual hosts:

      $ mkdir $PREFIX/etc/nginx/sites-available $PREFIX/etc/nginx/sites-enabled
      $ vim $PREFIX/etc/nginx/sites-available/matrix

- Copy paste the following in: 


      #change IP to location of monolith server
      upstream monolith{
          server 127.0.0.1:8008;
      }
      server {
          listen 8443 ssl; # IPv4
          listen [::]:8443 ssl; # IPv6
          server_name MY.DOMAIN;

          ssl_certificate /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/fullchain.pem;
          ssl_certificate_key /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/privkey.pem;

          proxy_set_header Host      $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_read_timeout         600;

          location /.well-known/matrix/server {
              return 200 '{ "m.server": "MY.DOMAIN:443" }';
          }

          location /.well-known/matrix/client {
              # If your sever_name here doesn't match your matrix homeserver URL
              # (e.g. hostname.com as server_name and matrix.hostname.com as homeserver URL)
              # add_header Access-Control-Allow-Origin '*';
              return 200 '{ "m.homeserver": { "base_url": "https://MY.DOMAIN" } }';
          }

          location /_matrix {
              proxy_pass http://monolith;
          }
      }

Then, run:

      $ ln -s $PREFIX/etc/nginx/sites-available/matrix $PREFIX/etc/nginx/sites-enabled
      $ sv-enable nginx 
      $ /data/data/com.termux/files/usr/etc/profile.d/start-services.sh

Don't forget to point your domain at your home IP Address, and to port forward 443 to 8443 in your router config.

# Setting up Dendrite itself

- Instructions are taken from the [official docs](https://github.com/matrix-org/dendrite):
     
      $ pkg install golang git
      $ git clone https://github.com/matrix-org/dendrite
      $ cd dendrite
      $ ./build.sh # This takes a LONG time
      $ ./bin/generate-keys --private-key matrix_key.pem
      $ cp dendrite-sample.monolith.yaml dendrite.yaml
      $ vim dendrite.yaml

- At minimum, you'll have to edit the server name (MY.DOMAIN), as well as the Postgres user you created earlier:
  
      database:
        connection_string: postgresql://username:password@localhost/dendrite?sslmode=disable
        
 Also, don't forget to use an absolute path for the `private_key: /data/data/com.termux/files/home/dendrite/matrix_key.pem`.

- If you wish to configure for dendrite to store media files in an external SD card, run `termux-setup-storage` first as per [their docs](https://wiki.termux.com/wiki/Termux-setup-storage), then change the base_path as shown:
   
      # Configuration for the Media API.
      media_api:
          # Storage path for uploaded media. May be relative or absolute.
  		      base_path: /data/data/com.termux/files/storage/shared/Download/media_store  

If you wish to transfer an already existing `media_store` directory you can do so by zipping it with `tar`, copying the generated file over, then unzipping it on the SD card. 

- To run the server and verify that it is properly connecting with postgres:
      
      $ ./bin/dendrite-monolith-server --tls-cert /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/fullchain.pem --tls-key /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/privkey.pem --config dendrite.yaml
      
If it shows no errors, then you can proceed to [the federation tester](https://federationtester.matrix.org) to see if it passes the checks there. The only thing that remains afterwards is to setup a `termux-service` for dendrite.

      $ mkdir -p $PREFIX/var/service/quickstart-dendrite/log
      $ ln -sf $PREFIX/share/termux-services/svlogger $PREFIX/var/service/quickstart-dendrite/log/run
      $ vim $PREFIX/var/service/quickstart-dendrite/run
Copy and paste the following in:

      #!/data/data/com.termux/files/usr/bin/sh
      exec /data/data/com.termux/files/home/dendrite/bin/dendrite-monolith-server --tls-cert /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/fullchain.pem --tls-key /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/privkey.pem --config /data/data/com.termux/files/home/dendrite/dendrite.yaml 2>&1
      
Finally,
 
    $ chmod +x $PREFIX/var/service/quickstart-dendrite/run # Makes it executable
    $ sv-enable quickstart-dendrite 
    $ /data/data/com.termux/files/usr/etc/profile.d/start-services.sh


You can create a user account by running: 
   
    $ cd dendrite
    $ ./bin/create-account --config dendrite.yaml --url http://localhost:8008 --username alice

Said account should be accessible in Element. Don't forget to backup your keys as well!


# mautrix-whatsapp

[Based off of the official docs here.](https://docs.mau.fi/bridges/go/setup.html?bridge=whatsapp)

From my testing, bridges such as `mautrix-whatsapp` function decently enough (when manually compiled), with the caveat that end to bridge encryption doesn't work. As I understand it, regardless of encryption, the dendrite homeserver will still be able to read your whatsapp message contents (this is just how bridges between different protocols seem to function). However, it can be handy if you want to access the bridge from another homeserver (such as matrix.org, tchncs.de, etc) without trusting their admins with your message conents. 

     $ git clone https://github.com/mautrix/whatsapp
     $ cd whatsapp 
     $ pkg install ffmpeg # needed for gifs according to the official docs
     $ ./build.sh -tags nocrypto 
     $ cp example-config.yaml config.yaml
     
Similar to earlier, you'll have to create a postgres user and database cluster for the bridge.

     $ createuser -P mautrix
     $ createdb -O mautrix mautrix-whatsapp

Then go open up `whatsapp/config.yaml` with vim. And add in  `postgres://mautrix:PASSWORD@localhost/mautrix-whatsapp?sslmode=disable` under `appservice.database.uri`. Don't forget to edit in the homeserver settings and bridge permissions as well.

     $ ./mautrix-whatsapp -g
     $ cd && cd cd dendrite
     $ vim dendrite.yaml

Under `app_service_api` -> `config_files` add in `- /data/data/com.termux/files/home/whatsapp/registration.yaml`.

Finally, you can `cd && cd whatsapp` and run `./mautrix-whatsapp` to start the bridge. I haven't been able to get the `termux-service` working with it yet. 



# Maintenance
      
Despite the massive limitations on an EOL Android Phone (no kernel updates, can't easily setup stuff like `fail2ban`), keeping SSH access to your local network only and updating what you can can't hurt. 

To upgrade, run the following commands before restarting Termux:

      $ pkg update && pkg upgrade
      $ $PREFIX/opt/certbot/bin/pip install --upgrade pip certbot
      $ cd dendrite
      $ git pull
      $ ./build.sh     
      $ cd && cd whatsapp
      $ git pull
      $ ./build.sh -tags nocrypto


 Alternatively, you can setup a cronjob to automatically update things every day at midnight.
 
 First, create ´update.sh´ and ´restart.sh´ in your home directory and make them executable with ´chmod +x´. 
 
 For ´update.sh´, paste in:
 
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

For ´restart.sh´, paste in:

     #!/data/data/com.termux/files/usr/bin/sh
     for service in crond nginx postgres quickstart-dendrite sshd whatsapp
          do 
               touch "/data/data/com.termux/files/usr/var/service/${service}/down"
               rm -f "/data/data/com.termux/files/usr/var/service/${service}/down"
               source /data/data/com.termux/files/usr/etc/profile.d/start-services.sh
          done
   
Enable the cronjob:

      $ pkg install cronie
      $ crontab -e 
Paste in: ´00 00 * * * /data/data/com.termux/files/home/update.sh´
 
      $ sv-enable crond
      $ ./restart.sh
If the SSL certs are expired, rerun `certbot` to obtain new ones.
