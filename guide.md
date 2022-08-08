# Prerequisites

- An Android Phone (in this case, I used a lava iris88s running Android 8.1.0, kernel version 4.4.95+. It had 2 GB RAM, and I expanded its internal storage with a 64 GB SD Card).  
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

- First, create a database cluster, and setup termux-service so it starts the postgres server automatically.

      $ pkg install postgresql
      $ pg_ctl -D $PREFIX/var/lib/postgresql initdb
      $ sv-enable postgres # restart termux after this
    
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

      $ ln -s $PREFIX/etc/nginx/sites-available/matrix $PREFIX/etc/nginx/sites-enabled
      $ sv-enable nginx # restart termux after this


# Setting up Dendrite itself

- Instructions are taken from the [official docs](https://github.com/matrix-org/dendrite):
     
      $ pkg install golang git
      $ git clone https://github.com/matrix-org/dendrite
      $ cd dendrite
      $ ./build.sh
      $ ./bin/generate-keys --private-key matrix_key.pem
      $ cp dendrite-sample.monolith.yaml dendrite.yaml
      $ vim dendrite.yaml

- At minimum, you'll have to edit the server name (MY.DOMAIN), as well as the Postgres user you created earlier:
  
      database:
        connection_string: postgresql://username:password@localhost/dendrite?sslmode=disable
        
- To run the server:
      
      $ ./bin/dendrite-monolith-server --tls-cert /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/fullchain.pem --tls-key /data/data/com.termux/files/usr/etc/letsencrypt/live/MY.DOMAIN/privkey.pem --config dendrite.yaml



