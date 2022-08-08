# Prerequisites

- An Android Phone (in this case, I used a lava iris88s running Android 8.1.0, kernel version 4.4.95+. It had 2 GB RAM, and I expanded its internal storage with a 64 GB SD Card).  
- A domain you control (I used a freenom domain a friend gifted me ages ago), as well as a router that allows you to do port forwarding.




# Main Packages Needed to be Installed in Termux
 
- Certbot (to handle HTTPS, needed for federation)
- PostgreSQL (needed for the Dendrite database)
- NGINX (to handle reverse proxying)
- Dendrite (for the actual server itself)


It's also reccomended to install openSSH, and setup a termux-service for it.


# Setting up SSH 
[Based off of the termux wiki:](https://wiki.termux.com/wiki/Remote_Access)

- Run `pkg update && pkg upgrade` to update everything first.
- Then run `pkg install openssh termux-services`.
- Run `passwd` to setup a password.
- Restart Termux so you can run `sv-enable sshd` (this starts the SSH daemon whenever termux is started).
- The device's local IP address can be found under WiFi settings.
- You can then execute `ssh user@IP -p 8022` to gain access from another device.

# Setting up Certbot

Instructions are based off of [here](https://github.com/medanisjbara/synapse-termux/blob/main/GUIDE.md) and [here.](https://gist.github.com/meijerwynand/d2627fd2d45299ac70330f957de2d545)

# Setting up your DNS


