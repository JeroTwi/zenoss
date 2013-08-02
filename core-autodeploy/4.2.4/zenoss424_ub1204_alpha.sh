#!/bin/bash
#######################################################
# Version: 02a Alpha                                  #
# Status: Not Functional                              # 
# Notes: Under development...ironing out bugs         #
# Zenoss Core 4.2.4 & ZenPacks                        #
# Ubuntu 12.04.2 x86_64                               #
#######################################################

echo && echo "Welcome to the Zenoss 4.2.4 core-autodeploy script for Ubuntu!"
echo "http://hydruid-blog.com/?p=124" && echo

echo "Step01: Install Ubuntu Updates and Prepare Build Environment"
mkdir /home/zenoss/zenoss424-srpm_install >/dev/null 2>/dev/null
cd /home/zenoss/zenoss424-srpm_install
wget -N https://raw.github.com/hydruid/zenoss/master/core-autodeploy/4.2.4/misc/variables.sh >/dev/null 2>/dev/null
. /home/zenoss/zenoss424-srpm_install/variables.sh
apt-get -qq update
apt-get -qq dist-upgrade -y
if grep -Fxq "Ubuntu 12.04.2 LTS" /etc/issue.net
	then	echo "...Correct OS detected."
		if uname -m | grep -Fxq "x86_64"
			then	echo "...Correct Arch detected"
			else	echo "...Incorrect Arch detected...stopped script" && exit 0
fi
	else	echo "...Incorrect OS detected...stopping script" && exit 0
fi
if [ `whoami` != 'zenoss' ]; then	echo "...All system checks passed"
	else	echo "...This script should not be ran by the zenoss user" && exit 0
fi
echo "...Step01 Complete" && echo 

echo "Step 02: Install Zenoss Dependencies"
apt-get -qq install python-software-properties -y && echo | add-apt-repository ppa:webupd8team/java
apt-get -qq install rrdtool libmysqlclient-dev rabbitmq-server nagios-plugins erlang subversion autoconf swig unzip zip g++ libssl-dev maven libmaven-compiler-plugin-java build-essential libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev oracle-java6-installer python-twisted python-gnutls python-twisted-web python-samba libsnmp-base snmp-mibs-downloader bc rpm2cpio memcached libncurses5 libncurses5-dev libreadline6-dev libreadline6 librrd-dev -y 
export DEBIAN_FRONTEND=noninteractive
apt-get -qq install mysql-server mysql-client mysql-common -y
mysql -u root -e "show databases;" 2>&1 | sudo tee /tmp/mysql.txt
if grep -Fxq "Database" /tmp/mysql.txt
        then    echo "...MySQL connection test successful."
        else    echo "...Mysql connection failed...make sure the password is blank for the root MySQL user." && exit 0
fi
echo "...Step 02 Complete" && echo

exit 0

echo "Step 04: Zenoss user setup and misc package adjustments"
useradd -m -U -s /bin/bash zenoss && mkdir $ZENHOME && chown -R zenoss:zenoss $ZENHOME
rabbitmqctl add_user zenoss zenoss && rabbitmqctl add_vhost /zenoss
rabbitmqctl set_permissions -p /zenoss zenoss '.*' '.*' '.*'
chmod 777 /home/zenoss/.bashrc
echo 'export ZENHOME=$ZENHOME' >> /home/zenoss/.bashrc
echo 'export PYTHONPATH=$ZENHOME/lib/python' >> /home/zenoss/.bashrc
echo 'export PATH=$ZENHOME/bin:$PATH' >> /home/zenoss/.bashrc
echo 'export INSTANCE_HOME=$ZENHOME' >> /home/zenoss/.bashrc
chmod 644 /home/zenoss/.bashrc
echo '#max_allowed_packet=16M' >> /etc/mysql/my.cnf
echo 'innodb_buffer_pool_size=256M' >> /etc/mysql/my.cnf
echo 'innodb_additional_mem_pool_size=20M' >> /etc/mysql/my.cnf
sed -i 's/mibs/#mibs/g' /etc/snmp/snmp.conf

echo "Step 05: Download the Zenoss install"
if [ -f $INSTALLDIR/zenoss_core-4.2.4/GNUmakefile.in ];
	then	echo "...skipping SRPM download and extraction."
	else	cd $INSTALLDIR/
		wget http://iweb.dl.sourceforge.net/project/zenoss/zenoss-4.2/zenoss-4.2.4/zenoss_core-4.2.4.el6.src.rpm
		rpm2cpio zenoss_core-4.2.4.el6.src.rpm | cpio -i --make-directories
		bunzip2 zenoss_core-4.2.4-1859.el6.x86_64.tar.bz2 && tar -xvf zenoss_core-4.2.4-1859.el6.x86_64.tar
		mkdir $INSTALLDIR && mv zenoss_core-4.2.4 $INSTALLDIR/ && chown -R zenoss:zenoss $ZENHOME
fi
echo "Step 05: Complete"

echo "Step 06: Start the Zenoss install"
tar zxvf $INSTALLDIR/zenoss_core-4.2.4/externallibs/rrdtool-1.4.7.tar.gz && cd rrdtool-1.4.7/
./configure --prefix=$ZENHOME
make && make install
cd $INSTALLDIR/zenoss_core-4.2.4/
wget https://raw.github.com/hydruid/zenoss/master/core-autodeploy/4.2.4/misc/variables.sh
wget http://dev.zenoss.org/svn/tags/zenoss-4.2.4/inst/rrdclean.sh
wget http://www.rabbitmq.com/releases/rabbitmq-server/v3.1.3/rabbitmq-server_3.1.3-1_all.deb
dpkg -i rabbitmq-server_3.1.3-1_all.deb
./configure 2>&1 | tee log-configure.log
make 2>&1 | tee log-make.log
make clean 2>&1 | tee log-make_clean.log
cp mkzenossinstance.sh mkzenossinstance.sh.orig
su - root -c "sed -i 's:# configure to generate the uplevel mkzenossinstance.sh script.:# configure to generate the uplevel mkzenossinstance.sh script.\n#\n#Custom Ubuntu Variables\n. variables.sh:g' $INSTALLDIR/zenoss_core-4.2.4/mkzenossinstance.sh"
./mkzenossinstance.sh 2>&1 | tee log-mkzenossinstance_a.log
./mkzenossinstance.sh 2>&1 | tee log-mkzenossinstance_b.log
chown -R zenoss:zenoss $ZENHOME
echo "Step 06: Complete"

echo "Step 07: Install the Core ZenPacks"
rm -fr /home/zenoss/rpm > /dev/null 2>/dev/null && rm -fr /home/zenoss/*.egg > /dev/null 2>/dev/null
mkdir /home/zenoss/rpm && cd /home/zenoss/rpm
wget http://superb-dca2.dl.sourceforge.net/project/zenoss/zenoss-4.2/zenoss-4.2.4/zenoss_core-4.2.4.el6.x86_64.rpm
rpm2cpio zenoss_core-4.2.4.el6.x86_64.rpm | sudo cpio -ivd ./opt/zenoss/packs/*.*
cp /home/zenoss/rpm/opt/zenoss/packs/*.egg /home/zenoss/
chown -R zenoss:zenoss /home/zenoss
rm /home/zenoss/zenpack-helper.sh > /dev/null 2>/dev/null && touch /home/zenoss/zenpack-helper.sh
echo '#!/bin/bash' >> /home/zenoss/zenpack-helper.sh
echo 'ZENHOME=$ZENHOME' >> /home/zenoss/zenpack-helper.sh
echo 'export ZENHOME=$ZENHOME' >> /home/zenoss/zenpack-helper.sh
echo 'PYTHONPATH=$ZENHOME/lib/python' >> /home/zenoss/zenpack-helper.sh
echo 'PATH=$ZENHOME/bin:$PATH' >> /home/zenoss/zenpack-helper.sh
echo 'INSTANCE_HOME=$ZENHOME' >> /home/zenoss/zenpack-helper.sh
echo '$ZENHOME/bin/zenoss restart' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.PySamba-1.0.2-py2.7-linux-x86_64.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.WindowsMonitor-1.0.8-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.ActiveDirectory-2.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.ApacheMonitor-2.1.3-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.DellMonitor-2.2.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.DeviceSearch-1.2.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.DigMonitor-1.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.DnsMonitor-2.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.EsxTop-1.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.FtpMonitor-1.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.HPMonitor-2.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.HttpMonitor-2.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.IISMonitor-2.0.2-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.IRCDMonitor-1.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.JabberMonitor-1.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.LDAPMonitor-1.4.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.LinuxMonitor-1.2.1-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.MSExchange-2.0.4-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.MSMQMonitor-1.2.1-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.MSSQLServer-2.0.3-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.MySqlMonitor-2.2.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.NNTPMonitor-1.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.NtpMonitor-2.2.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.PythonCollector-1.0.1-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.WBEM-1.0.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.WindowsMonitor-1.0.8-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.XenMonitor-1.1.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.ZenJMX-3.9.5-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'zenpack --install ZenPacks.zenoss.ZenossVirtualHostMonitor-2.4.0-py2.7.egg' >> /home/zenoss/zenpack-helper.sh
echo 'easy_install readline' >> /home/zenoss/zenpack-helper.sh
echo '$ZENHOME/bin/zenoss restart' >> /home/zenoss/zenpack-helper.sh
su - zenoss -c "/bin/sh /home/zenoss/zenpack-helper.sh"

echo "Step 08: Post Installation Adjustments"
cp $ZENHOME/bin/zenoss /etc/init.d/zenoss
touch $ZENHOME/var/Data.fs && chown zenoss:zenoss $ZENHOME/var/Data.fs
su - root -c "sed -i 's:# License.zenoss under the directory where your Zenoss product is installed.:# License.zenoss under the directory where your Zenoss product is installed.\n#\n#Custom Ubuntu Variables\nexport ZENHOME=$ZENHOME\nexport RRDCACHED=$ZENHOME/bin/rrdcached:g' /etc/init.d/zenoss"
update-rc.d zenoss defaults
chown root:zenoss $ZENHOME/bin/nmap && chmod u+s $ZENHOME/bin/nmap
chown root:zenoss $ZENHOME/bin/zensocket && chmod u+s $ZENHOME/bin/zensocket
chown root:zenoss $ZENHOME/bin/pyraw && chmod u+s $ZENHOME/bin/pyraw
echo 'watchdog True' >> $ZENHOME/etc/zenwinperf.conf
TEXT1="     The Zenoss Install Script is Complete......browse to http://"
TEXT2=":8080"
IP=`ifconfig | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
echo $TEXT1$IP$TEXT2
echo "The default login is:"
echo "	username: admin"
echo "	password: zenoss"
