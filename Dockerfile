
FROM alpine:3.13

# Update the base image
RUN apk -U upgrade

# Install impitool and curl
RUN apk add --no-cache ipmitool curl git bash grep

# Copy the entrypoint script into the container
COPY docker-entrypoint.sh /

RUN chmod a+x /docker-entrypoint.sh

# Load the entrypoint script to be run later
ENTRYPOINT ["/docker-entrypoint.sh"]
