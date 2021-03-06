#!/bin/bash

set -e
set -x

apt-get update
apt-get install -y git python-pip python-dev
pip install virtualenv

SCRIPTS=`dirname $0`

if [ ! -d "/opt/hpfeeds-logger" ]
then
    cd /opt/
    git clone https://github.com/threatstream/hpfeeds-logger.git
    cd hpfeeds-logger
    virtualenv env
    . env/bin/activate
    pip install -r requirements.txt
    chmod 755 -R .
    deactivate
else
    echo "It looks like hpfeeds-logger is already installed. Moving on to configuration."
fi

IDENT=hpfeeds-logger-splunk
SECRET=`python -c 'import uuid;print str(uuid.uuid4()).replace("-","")'`
CHANNELS='amun.events,dionaea.connections,dionaea.capture,glastopf.events,beeswarm.hive,kippo.sessions,conpot.events,snort.alerts,suricata.events,wordpot.events,shockpot.events,p0f.events,elastichoney.events'

cat > /opt/hpfeeds-logger/splunk.json <<EOF
{
    "host": "localhost",
    "port": 10000,
    "ident": "${IDENT}", 
    "secret": "${SECRET}",
    "channels": [
        "amun.events",
        "dionaea.connections",
        "dionaea.capture",
        "glastopf.events",
        "beeswarm.hive",
        "kippo.sessions",
        "conpot.events",
        "snort.alerts",
        "suricata.events",
        "wordpot.events",
        "shockpot.events",
        "p0f.events",
        "elastichoney.events"
    ],
    "log_file": "/var/log/mhn/mhn-splunk.log",
    "formatter_name": "splunk"
}
EOF

. /opt/hpfeeds/env/bin/activate
python /opt/hpfeeds/broker/add_user.py "$IDENT" "$SECRET" "" "$CHANNELS"

mkdir -p /var/log/mhn

apt-get install -y supervisor

cat >> /etc/supervisor/conf.d/hpfeeds-logger-splunk.conf <<EOF 
[program:hpfeeds-logger-splunk]
command=/opt/hpfeeds-logger/env/bin/python logger.py splunk.json
directory=/opt/hpfeeds-logger
stdout_logfile=/var/log/mhn/hpfeeds-logger-splunk.log
stderr_logfile=/var/log/mhn/hpfeeds-logger-splunk.err
autostart=true
autorestart=true
startsecs=1
EOF

supervisorctl update
