# FanOverlord
This is a Docker container that uses IPMI to monitor and control the fans on a Dell R610 server through the iDRAC using raw commands.  

This script will read the ambient temp sensor every X seconds (20 by default) and then apply a custom define fan speed to the iDRAC. It has normal, Med, High and Emergency states (all user configurable). Each state can have a custom fan speed but the Emergency state sets it back to Auto-control from the BIOS/iDRAC.  
  
Additionally it sends out healthchecks to healthchecks.io and uses Slacktee to send messages to a slack channel about emergencies. (this can be removed if not wanted).

https://github.com/NoLooseEnds/Scripts/tree/master/R710-IPMI-TEMP was the source of my knowledge on how to issue the commands and it was the inspiration for this effort.

# HowTo Steps
## Configure iDRAC
 - [Set IP Address for iDRAC and ensure docker can communicate with it](https://docs.extrahop.com/current/configure-i-drac/)
 - [Enable IPMI in the iDRAC ](http://www.fucking-it.com/articles/dell-idrac/214-dell-idrac-configure-ipmi)

## Install Docker
 - https://docs.docker.com/install/  

## Install Docker-Compose
 - https://docs.docker.com/compose/install/

## Download FanOverlord
Then run the following
```
git clone https://github.com/orlikoski/fanoverlord.git
```

## Add The Custom Details to .env
Modify the following `fanoverlord/.env` file for each variable needed to configure Slacktee, HealthCheck, and the IPMI connection information. This will be used to fill in the `/etc/slacktee.conf` and `docker-entrypoint.sh` file within the docker image at build time.

### Server Details and HealtCheck URL
Open `docker-entrypoint.sh` and edit the following lines to match the environment
```
IPMIHOST=<IP Address of the iDRAC on the Server>
IPMIUSER=<User for the iDRAC>
IPMIPW=<Password for the iDRAC
HC_URL=<Unique Ping URL>
```
### Slacktee Details
https://github.com/coursehero/slacktee
```
WEBHOOK_URL=<ENTER_HERE_NO_QUOTES>
UPLOAD_TOKEN=<ENTER_HERE_NO_QUOTES>
CHANNEL=<ENTER_HERE_NO_QUOTES>
TMP_DIR=<ENTER_HERE_NO_QUOTES>
USERNAME=<ENTER_HERE_NO_QUOTES>
ICON=<ENTER_HERE_NO_QUOTES>
ATTACHMENT=<ENTER_HERE_NO_QUOTES>
```

### Example .env file
```
WEBHOOK_URL=https://hooks.slack.com/services/uiowower0982344/
UPLOAD_TOKEN=
CHANNEL=myawesomechannel
TMP_DIR=
USERNAME=slacktee
ICON=ghost
ATTACHMENT=
IPMIHOST=192.168.0.50
IPMIUSER=root
IPMIPW=hobbes
HC_URL=https://hc-ping.com/987asdf987asdf987as23
```

## Build and Run the Docker
```
cd fanoverlord
docker build -t fanoverlord ./
docker-compose up -d
```
