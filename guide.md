# Prerequisites

- An Android Phone (in this case, I used a lava iris88s running Android 8.1.0, kernel version 4.4.95+. It had 2 GB RAM, and I expanded its internal storage with a 64 GB SD Card).  
- A domain you control (I used a freenom domain a friend gifted me ages ago), as well as a router that allows you to do port forwarding.




# Main Packages Needed to be Installed in Termux
 
- Dendrite (for the actual server itself)
- NGINX (to handle reverse proxying)
- Certbot (to handle HTTPS, needed for federation)
- PostgresSQL (needed for the Dendrite database)


It's also reccomended to install openSSH, and setup a termux-service for it.

# Setting up SSH 
# Setting up your DNS


