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

      $ pkg install nginx
      $ sv-enable nginx # restart termux after this
      $ mkdir $PREFIX/etc/nginx/sites-available $PREFIX/etc/nginx/sites-enabled
 
- I am using a [sample configuration provided by the official dendrite devs](https://github.com/matrix-org/dendrite/blob/main/docs/nginx/monolith-sample.conf).


   

# Setting up your DNS


