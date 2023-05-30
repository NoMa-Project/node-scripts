#!/bin/bash
#debian 10 / 11
#install haproxy as load balancer between 2 web servers
#need to have .crt + .key combined in a .pem file in /etc/ssl/private/

apt update && apt -y upgrade
apt -y install haproxy

read -p "Enter IP address of web server 1: " webserver1
read -p "Enter IP address of web server 2: " webserver2

#apache config
echo "frontend apache_front
        bind *:80
        default_backend    apache_backend_servers
        option             forwardfor

frontend https-in
    bind *:443 ssl crt /etc/ssl/private/noemieanneg.pem    
    default_backend apache_backend_servers
    option forwardfor

backend apache_backend_servers
        balance            roundrobin
        server             backend01 $webserver1:80 check
        server             backend02 $webserver2:80 check" >> /etc/haproxy/haproxy.cfg

systemctl restart haproxy

myip=$(ip a s dev ens33 | awk '/inet /{print $2}' | cut -d/ -f1)

echo "Haproxy is enabled. Enter $myip in your navigator to access your website."