sudo pacman -S --needed help2man git m4 perl textinfo make automake autoconf gcc base-devel fakeroot
mkdir build
cd build/
git clone https://aur.archlinux.org/pi-hole-server.git
git clone https://aur.archlinux.org/logrotate-git.git
cd logrotate-git
makepkg -si
cd ..
rm -rf logrotate-git/
# Pihole dependencies
wget https://mirror.dkm.cz/archlinux/community/os/x86_64/jq-1.6-4-x86_64.pkg.tar.zst
wget https://mirror.dkm.cz/archlinux/extra/os/x86_64/gnu-netcat-0.7.1-9-x86_64.pkg.tar.zst
wget https://mirror.dkm.cz/archlinux/core/os/x86_64/inetutils-2.3-1-x86_64.pkg.tar.zst
wget https://mirror.dkm.cz/archlinux/extra/os/x86_64/lsof-4.98.0-1-x86_64.pkg.tar.zst
wget https://mirror.dkm.cz/archlinux/extra/os/x86_64/bind-9.18.11-1-x86_64.pkg.tar.zst
wget https://mirror.dkm.cz/archlinux/extra/os/x86_64/bc-1.07.1-4-x86_64.pkg.tar.zst
sudo pacman -U *.pkg.tar.zst
rm -rf *pkg.tar.zst
git clone https://aur.archlinux.org/patch-git.git
cd patch-git
makepkg -si
cd ..
rm -rf patch-git
git clone https://aur.archlinux.org/pi-hole-ftl.git
cd pi-hole-ftl
makepkg -si
cd ..
rm -rf pi-hole-ftl
cd pi-hole-server
makepkg -si
cd ..
rm -rf pi-hole-server
cd ..
rm -rf build
sudo pacman -S unbound
cat << EOF > /etc/unbound/unbound.conf
server:
    # If no logfile is specified, syslog is used
    # logfile: "/var/log/unbound/unbound.log"
    verbosity: 0

    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    # May be set to yes if you have IPv6 connectivity
    do-ip6: no

    # You want to leave this to no unless you have *native* IPv6. With 6to4 and
    # Terredo tunnels your web browser should favor IPv4 for the same reasons
    prefer-ip6: no

    # Use this only when you downloaded the list of primary root servers!
    # If you use the default dns-root-data package, unbound will find it automatically
    #root-hints: "/var/lib/unbound/root.hints"

    # Trust glue only if it is within the server's authority
    harden-glue: yes

    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
    harden-dnssec-stripped: yes

    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no

    # Reduce EDNS reassembly buffer size.
    # IP fragmentation is unreliable on the Internet today, and can cause
    # transmission failures when large DNS messages are sent via UDP. Even
    # when fragmentation does work, it may not be secure; it is theoretically
    # possible to spoof parts of a fragmented DNS message, without easy
    # detection at the receiving end. Recently, there was an excellent study
    # >>> Defragmenting DNS - Determining the optimal maximum UDP response size for DNS <<<
    # by Axel Koolhaas, and Tjeerd Slokker (https://indico.dns-oarc.net/event/36/contributions/776/)
    # in collaboration with NLnet Labs explored DNS using real world data from the
    # the RIPE Atlas probes and the researchers suggested different values for
    # IPv4 and IPv6 and in different scenarios. They advise that servers should
    # be configured to limit DNS messages sent over UDP to a size that will not
    # trigger fragmentation on typical network links. DNS servers can switch
    # from UDP to TCP when a DNS response is too big to fit in this limited
    # buffer size. This value has also been suggested in DNS Flag Day 2020.
    edns-buffer-size: 1232

    # Perform prefetching of close to expired message cache entries
    # This only applies to domains that have been frequently queried
    prefetch: yes

    # One thread should be sufficient, can be increased on beefy machines. In reality for most users running on small networks or on a single machine, it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
    num-threads: 1

    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m

    # Ensure privacy of local IP ranges, replace 192.168.0.0/24 with your own private ip address range!
    private-address: 192.168.0.0/24
EOF
sudo systemctl restart unbound
# Set dns to unbound
pihole -a setdns 127.0.0.1#5335
pihole -a -p untold-grief-ouch
rm -rf /etc/pihole/gravity*
pihole -g
pihole logging off
# Put all blocklist that are green on firebog.net onto pihole, for all blocklist green and blue (but no crossed ones) replace "?type=tick" by "?type=nocross"
sudo wget -qO - https://v.firebog.net/hosts/lists.php?type=tick |xargs -I {} sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (Address) VALUES ('{}');"
# To add any blocklist type that and replace https://dbl.oisd.nl/ by the blocklist address
sudo echo "https://dbl.oisd.nl/" |xargs -I {} sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (Address) VALUES ('{}');"
pihole -g
pihole restartdns
