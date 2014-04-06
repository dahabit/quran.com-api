To start
--------

`./script/quran_api prefork -P /tmp/quran_api.pid -l 'http://*:8080?reuse=1' &`


Zero downtime upgrade
---------------------

    export OLDPID=$( cat /tmp/quran_api.pid )
    ./script/quran_api prefork -P /tmp/quran_api.pid -l 'http://*:8080?reuse=1' &
    kill -s TERM $OLDPID


Lighttpd
--------

Append the lighttpd.conf from this directory and modify appropriately.
