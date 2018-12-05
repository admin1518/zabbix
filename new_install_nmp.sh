#!/bin/bash

        echo ""
        echo -e "\033[31m############################################\033[0m"
        echo -e "\033[31m#   script version  1.0                    #\033[0m"
        echo -e "\033[31m#   date : 2018-09-01                      #\033[0m"
	    echo -e "\033[31m############################################\033[0m"

url="http://192.168.31.9"
dir_tmp='/data/software/webserver'
user="www"

# logfile path
logfile="/root/nginx_sys.log"
web_install="/tmp/web_install-$(date +%F).log"

if [ -f ${dir_tmp}/software.log ];then
	rm -rf ${dir_tmp}/software.log
	find ${dir_tmp} >${dir_tmp}/software.log
else
	find ${dir_tmp} >${dir_tmp}/software.log
fi

Menu (){
# Define Menu
menu_num=$1
menu[1]=$2
menu[2]=$3
menu[3]=$4
menu[4]=$5
menu[5]=$6
menu[6]=$7
menu[7]=$8
menu[8]=$9

# Display menu
	[[ -e $logfile ]] || touch ${logfile}
        # Print Menu
        for ((i=1;i<=$menu_num;i++))
        do
                [ -e  $logfile ] && cat $logfile | grep -q $i && echo -n -e '\e[34m'
                echo "$i) ${menu[$i]}"
                echo -n -e '\e[0m'
        done
        read -p "Pls input your choise(s), e.g 1 or 1 2 3 : " choise
}

ftp_download (){
[ ! -d ${dir_tmp} ] && mkdir -p ${dir_tmp}
cd ${dir_tmp}
yum -y install wget
downloads=("nginx-1.12.1.tar.gz" "pcre-8.39.tar.gz" "openssl-1.0.2k.tar.gz" "mysql-5.7.23-linux-glibc2.12-x86_64.tar.gz" "php-5.6.30.tar.gz")
for i in $(seq 0 $((${#downloads[@]}-1)));do
	wget ${url}"/${downloads[$i]}"
done
}

init (){
cd $dir_tmp
yum install -y epel-release
yum update -y >> ${web_install} 2>&1
yum install -y libjpeg-devel libpng-devel gd-devel libmcrypt-devel libmcrypt mhash-devel  freetype-devel libxml2-devel curl-devel libtool-ltdl-devel openssl-devel gcc gcc-c++ >> ${web_install} 2>&1
echo "yum_install" >>${dir_tmp}/stat.log

###pcre install
echo ""
echo "################## Install pcre.... #####################"
cd ${dir_tmp}
/bin/cat ${dir_tmp}/software.log |grep "pcre" |awk '{printf "tar zxvf %s\n",$1}'|bash >$dir_tmp/code.log ||exit 1
if [ ! -s "$dir_tmp/code.log" ]; then
  echo "error $dir_tmp/code.log"
  exit 1
else
  path=`cat $dir_tmp/code.log|awk -F/ '/\//{print $1}'|sort -u`
  if [ ! -d "$dir_tmp/$path" ]; then
    echo "$dir_tmp/$path is not dir"
    exit 1
  fi
  cd $dir_tmp/$path
fi

./configure >> ${web_install} 2>&1
make >> ${web_install} 2>&1
make install >> ${web_install} 2>&1
if [ $? -ne 0 ];then
  echo -e "\033[31m [Error]: Install pcre failed! Please check. \033[0m"
  exit 0
fi

rm -rf $dir_tmp/$path
echo "pcre_install" >>${dir_tmp}/stat.log
echo -e "\033[40;32m [INFO]: Install pcre completed. \n \033[40;37m"
}

nginx_install (){
user_exit=`id -u www`
if [ ! -d $dir_tmp ];then
mkdir -p $dir_tmp
fi

if [ -z "$user_exit" ];then
useradd www -u 2000 -p txwgame.com@abc -s /sbin/nologin
fi

echo "Install nginx...."
sleep 5
cd ${dir_tmp}
/bin/cat "${dir_tmp}/software.log" |grep "nginx" |awk '{printf "tar xvf %s\n",$1}'|bash >$dir_tmp/code.log ||exit 10
/bin/cat "${dir_tmp}/software.log" |grep "openssl" |awk '{printf "tar xvf %s\n",$1}'|bash ||exit 10
if [ ! -s "$dir_tmp/code.log" ]; then
  echo "error $dir_tmp/code.log"
  exit 11
else
  path=`cat $dir_tmp/code.log|awk -F/ '/\//{print $1}'|sort -u`
  if [ ! -d "$dir_tmp/$path" ]; then
    echo "$dir_tmp/$path is not dir"
    exit 1
  fi
  cd $dir_tmp/$path
fi

./configure --user=www --group=www --prefix=/usr/local/webserver/nginx \
--with-http_stub_status_module \
--with-openssl=/data/software/webserver/openssl-1.0.2k \
--with-http_ssl_module \
--with-http_gzip_static_module \
--with-http_v2_module \
--with-debug >> ${web_install} 2>&1

make >> ${web_install} 2>&1
make install >> ${web_install} 2>&1

cd ../
rm -rf ${dir_tmp}/${path}
nginx_conf=/usr/local/webserver/nginx
cp ${nginx_conf}/conf/nginx.conf ${nginx_conf}/conf/nginx.conf.bak
mkdir -pv ${nginx_conf}/conf/sites
cat > ${nginx_conf}/conf/nginx.conf << EOF
user  www www;
worker_processes  2;
worker_cpu_affinity 01 10;
worker_rlimit_nofile 65535;
error_log  logs/error.log  notice;
pid        logs/nginx.pid;

events {
    use epoll;
    worker_connections  65535;
    accept_mutex off;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for" "\$request_time"';

    log_format  proxy '\$http_x_forwarded_for - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_user_agent" "\$request_time"';

    server_tokens off;
    server_names_hash_bucket_size   128;
    client_header_buffer_size   2k;
    large_client_header_buffers 4 16k;
    client_max_body_size    8m;
    sendfile        on;

    tcp_nopush     on;
    tcp_nodelay     on;
    keepalive_timeout  65;

    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 300;
    fastcgi_buffer_size 64k;
    fastcgi_buffers 4 64k;
    fastcgi_busy_buffers_size 128k;
    fastcgi_temp_file_write_size 128k;

    gzip  on;
    gzip_min_length 1k;
    gzip_buffers    4 16k;
    gzip_http_version   1.0;
    gzip_comp_level 2;
    gzip_types text/plain application/x-javascript text/css application/xml;
    gzip_vary   on;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }

    include sites/*.conf;

}
EOF

echo "nginx_install" >>${dir_tmp}/stat.log
touch ${nginx_conf}/conf/forbid.conf
cat > ${nginx_conf}/conf/forbid.conf << EOF
location ~ /(uploads|logs|cron)/.*.(php|php5)?$
{
    deny all;
}
EOF

echo -e "\033[40;32m [INFO]: Install nginx completed. \n \033[40;37m"
}

mysql_install (){
mysql=/usr/local/mysql
/usr/bin/id mysql
[ $? -ne 0 ] && groupadd -r mysql && useradd -g mysql -s /sbin/nologin -M mysql

cd ${dir_tmp}
yum -y install libaio libstdc++ libgcc numactl >> ${web_install} 2>&1
tar xvf mysql-5.7.23-linux-glibc2.12-x86_64.tar.gz
if [ $? -ne 0 ];then
  echo -e "\033[31m [Error]: Decompression mysql.tar.gz failed. \033[0m"
  exit 0
fi
mv mysql-5.7.23-linux-glibc2.12-x86_64 ${mysql}

cd ${mysql}
chown -R mysql:mysql .
mkdir -p /mydata/mysqldata/{mydata,binlog}
chown -R mysql:mysql /mydata/mysqldata/*
mkdir -p /mydata/logs/mysql
chown -R mysql:mysql /mydata/logs/mysql
cp support-files/mysql.server /etc/init.d/mysqld
chmod +x /etc/init.d/mysqld
chkconfig --add mysqld
ln -sv ${mysql}/include /usr/include/mysql
echo "/usr/local/mysql/lib" >>/etc/ld.so.conf
ln -sv ${mysql}/bin /usr/bin/mysql
sed -i 's#PATH=$PATH:$HOME/bin#PATH=$PATH:$HOME/bin:/usr/bin/mysql#' /root/.bash_profile
/sbin/ldconfig

cat > /etc/my.cnf << EOF
[client]
port		= 3306
socket		= /tmp/mysql.sock
default-character-set = utf8

[mysqld]
user        = mysql
port		= 3306
socket		= /tmp/mysql.sock
basedir     = /usr/local/mysql
datadir     = /mydata/mysqldata/mydata
log-error   = /mydata/logs/mysql/mysql_error.log
pid-file    = /mydata/mysqldata/mydata/mysql.pid
secure_file_priv =
explicit_defaults_for_timestamp=true
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
collation-server = utf8_unicode_ci
init-connect='SET NAMES utf8'
character-set-server = utf8
skip-name-resolve
back_log = 5000
max_connections = 6000
max_connect_errors = 6000
table_open_cache = 8192
max_allowed_packet = 16M
binlog_cache_size = 1M
max_heap_table_size = 64M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 0
query_cache_type = 0
query_cache_limit = 2M
ft_min_word_len = 4
default-storage-engine = INNODB
thread_stack = 192K
transaction_isolation = REPEATABLE-READ
tmp_table_size = 128M
log-bin = /mydata/mysqldata/binlog/mysql-bin
binlog_format = mixed
slow_query_log = on
slow_query_log_file = /mydata/logs/mysql/slow-query.log
long_query_time = 2
server-id = 1
interactive_timeout = 2880000
wait_timeout = 2880000
net_write_timeout = 60
key_buffer_size = 32M
bulk_insert_buffer_size = 64M
myisam_sort_buffer_size = 128M
myisam_max_sort_file_size = 2G
myisam_repair_threads = 1
innodb_buffer_pool_size = 1G
innodb_data_file_path = ibdata1:10M:autoextend
innodb_write_io_threads = 8
innodb_read_io_threads = 8
innodb_thread_concurrency = 16
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 8M
innodb_log_file_size = 256M
innodb_log_files_in_group = 3
innodb_max_dirty_pages_pct = 90
innodb_lock_wait_timeout = 120
innodb_file_per_table = 1

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash
default-character-set = utf8

[myisamchk]
key_buffer_size = 512M
sort_buffer_size = 512M
read_buffer = 8M
write_buffer = 8M

[mysqlhotcopy]
interactive-timeout

[mysqld_safe]
open-files-limit = 65535
EOF

bin/mysqld --initialize --user=mysql     #执行完密码放在mysql_error.log日志中
if [ $? -ne 0 ];then
  echo -e "\033[31m [Error]: Init mysql failed. \033[0m"
  exit 0
fi
bin/mysql_ssl_rsa_setup
chown -R mysql:mysql /mydata/mysqldata/mydata   # 再改次权限是为了解决SSL error: Unable to get private key from 'server-key.pem'报错。
bin/mysqld_safe --user=mysql --basedir=${mysql} --datadir=/mydata/mysqldata/mydata &
echo "mysql_install" >>${dir_tmp}/stat.log
mysql_passwd=`cat /mydata/logs/mysql/mysql_error.log | grep password | awk '{print $11}'`
echo -e "\033[40;32m [INFO]: Install mysql completed. \033[40;37m"
echo -e "\033[40;32m [INFO]: Mysql root password is: ${mysql_passwd} \033[40;37m"
sleep 5
}

php_install (){
yum install -y libjpeg-turbo-devel libpng-devel gd-devel libmcrypt-devel libmcrypt mhash-devel freetype-devel libxml2-devel libcurl-devel libtool-ltdl-devel libstdc++ libgcc libaio >> ${web_install} 2>&1
cd ${dir_tmp}
[[ -f $dir_tmp/code.log ]] && rm -rf $dir_tmp/code.log
/bin/cat ${dir_tmp}/software.log |grep "php" |awk '{printf "tar xvf %s\n",$1}'|bash >$dir_tmp/code.log||exit 1

if [ ! -s "$dir_tmp/code.log" ]; then
echo "error $dir_tmp/code.log"
exit 1
else
path=`cat $dir_tmp/code.log|awk -F/ '/\//{print $1}'|sort -u`
if [ ! -d "$dir_tmp/$path" ]; then
echo "$dir_tmp/$path is not dir"
exit 1
fi
cd $dir_tmp/$path
fi

LDFLAGS="-L/usr/lib64/mysql"
./configure --prefix=/usr/local/webserver/php \
--with-config-file-path=/usr/local/webserver/php/etc \
--with-mcrypt=/usr/local/libmcrypt \
--with-mysql=/usr/local/mysql \
--with-mysqli=/usr/local/mysql/bin/mysql_config \
--with-pdo-mysql=/usr/local/mysql \
--with-gd \
--with-jpeg-dir \
--with-freetype-dir \
--with-zlib \
--with-png-dir \
--with-libxml-dir \
--with-mcrypt \
--with-openssl \
--with-mhash \
--with-curl \
--with-curlwrappers \
--enable-sockets \
--enable-mbregex \
--enable-xml \
--enable-bcmath \
--enable-shmop \
--enable-sysvsem \
--enable-soap \
--enable-pdo \
--enable-short-tags \
--enable-mbstring \
--enable-fpm \
--disable-rpath \
--disable-debug >> ${web_install} 2>&1

make >> ${web_install} 2>&1
make install >> ${web_install} 2>&1
if [ $? -ne 0 ];then
  echo -e "\033[31m [Error]: Install php failed. \033[0m"
  exit 0
fi

extensions_dir=`cat Makefile|grep "^EXTENSION_DIR"|awk -F= '{print $2}'|sed -r 's/^\s*(.*)\s*$/\1/g'`
/bin/cp sapi/fpm/init.d.php-fpm /etc/rc.d/init.d/php-fpm
chmod 755 /etc/rc.d/init.d/php-fpm
chkconfig --add php-fpm
chkconfig --level 345 php-fpm on
cd ../
mkdir -p /usr/local/webserver/php/logs/

echo "################ Configure phpize##################" >> ${web_install} 2>&1
yum install automake -y >> ${web_install} 2>&1
cd $dir_tmp/$path/ext/ftp/
/usr/local/webserver/php/bin/phpize
chmod 755 configure 
./configure --with-php-config=/usr/local/webserver/php/bin/php-config >> ${web_install} 2>&1
make >> ${web_install} 2>&1
make install >> ${web_install} 2>&1
if [ $? -ne 0 ];then
  echo -e "\033[31m [Error]: Install phpize failed. \033[0m"
  exit 0
fi

cd $dir_tmp/$path/
cd ../

cat > /usr/local/webserver/php/etc/php-fpm.conf <<EOF
[global]
pid = run/php-fpm.pid
error_log = /mydata/logs/php/php-fpm.log
log_level = warning 
emergency_restart_threshold = 60 
emergency_restart_interval = 1m
process_control_timeout = 30s 
 
rlimit_files = 65535 
 
rlimit_core = 0
events.mechanism = epoll
[www]
user = www 
group = www
listen = /dev/shm/php-fpm.sock 
listen.backlog = 65535
listen.owner = www
listen.group = www
listen.mode = 0660
 
listen.allowed_clients = 127.0.0.1
pm = static 
pm.max_children = 128 
pm.start_servers = 20
pm.min_spare_servers = 5
pm.max_spare_servers = 35
 
pm.max_requests = 5000
 
 
slowlog = /mydata/logs/php/\$pool.log.slow
 
request_slowlog_timeout = 4s 
 
request_terminate_timeout = 60s
 
rlimit_files = 65535 
 
rlimit_core = 0
EOF

cat > /usr/local/webserver/php/etc/php.ini <<EOF
[PHP]
engine = On
short_open_tag = Off
asp_tags = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = 17
disable_functions =
disable_classes =
zend.enable_gc = On
expose_php = Off
max_execution_time = 300
max_input_time = 300
memory_limit = 128M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
html_errors = On
error_log = /mydata/logs/php/error.log
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 16M
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
always_populate_raw_post_data = -1 
doc_root =
user_dir =
enable_dl = Off
file_uploads = On
upload_max_filesize = 2M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60
[CLI Server]
cli_server.color = On
[Date]
date.timezone = Asia/Shanghai
[filter]
[iconv]
[intl]
[sqlite]
[sqlite3]
[Pcre]
[Pdo]
[Pdo_mysql]
pdo_mysql.cache_size = 2000
pdo_mysql.default_socket=
[Phar]
[mail function]
SMTP = localhost
smtp_port = 25
mail.add_x_header = On
[SQL]
sql.safe_mode = Off
[ODBC]
odbc.allow_persistent = On
odbc.check_persistent = On
odbc.max_persistent = -1
odbc.max_links = -1
odbc.defaultlrl = 4096
odbc.defaultbinmode = 1
[Interbase]
ibase.allow_persistent = 1
ibase.max_persistent = -1
ibase.max_links = -1
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"
ibase.dateformat = "%Y-%m-%d"
ibase.timeformat = "%H:%M:%S"
[MySQL]
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.cache_size = 2000
mysql.max_persistent = -1
mysql.max_links = -1
mysql.default_port =
mysql.default_socket =
mysql.default_host =
mysql.default_user =
mysql.default_password =
mysql.connect_timeout = 60
mysql.trace_mode = Off
[MySQLi]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.default_host =
mysqli.default_user =
mysqli.default_pw =
mysqli.reconnect = Off
[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off
[OCI8]
[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0
[Sybase-CT]
sybct.allow_persistent = On
sybct.max_persistent = -1
sybct.max_links = -1
sybct.min_server_severity = 10
sybct.min_client_severity = 10
[bcmath]
bcmath.scale = 0
[browscap]
[Session]
session.save_handler = files
session.save_path = "/dev/shm"
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.referer_check =
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.hash_function = 0
session.hash_bits_per_character = 5
url_rewriter.tags = "a=href,area=href,frame=src,input=src,form=fakeentry"
[MSSQL]
mssql.allow_persistent = On
mssql.max_persistent = -1
mssql.max_links = -1
mssql.min_error_severity = 10
mssql.min_message_severity = 10
mssql.compatibility_mode = Off
mssql.secure_connection = Off
[Assertion]
[COM]
[mbstring]
[gd]
[exif]
[Tidy]
tidy.clean_output = Off
[soap]
soap.wsdl_cache_enabled=1
soap.wsdl_cache_dir="/tmp"
soap.wsdl_cache_ttl=86400
soap.wsdl_cache_limit = 5
[sysvshm]
[ldap]
ldap.max_links = -1
[mcrypt]
[dba]
[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=3000
[curl]
[module]
extension_dir = "/usr/local/webserver/php/lib/php/extensions/no-debug-non-zts-20131226/"
EOF
rm -rf ${dir_tmp}/${path}
mkdir -p /www/logs
echo "php_install" >>${dir_tmp}/stat.log
echo -e "\033[40;32m [INFO]: Install php completed. \n \033[40;37m"
}


re2c_install (){
cd ${dir_tmp}
/bin/cat "${dir_tmp}/software.log" |grep "re2c" |awk '{printf "tar zxvf %s\n",$1}'|bash >$dir_tmp/code.log ||exit 1
if [ ! -s "$dir_tmp/code.log" ]; then
echo "error $dir_tmp/code.log"
exit 1
else
path=`cat $dir_tmp/code.log|awk -F/ '/\//{print $1}'|sort -u`
if [ ! -d "$dir_tmp/$path" ]; then
echo "$dir_tmp/$path is not dir"
exit 1
fi
cd $dir_tmp/$path
fi
./configure||exit 1
make||exit 1
make install||exit 1
cd ../
rm -rf $dir_tmp/$path
        echo "re2c_install" >>${dir_tmp}/stat.log
}


memcache_install (){
cd ${dir_tmp}
/bin/cat "${dir_tmp}/software.log" |grep "memcache" |awk '{printf "tar zxvf %s\n",$1}'|bash >$dir_tmp/code.log ||exit 1
if [ ! -s "$dir_tmp/code.log" ]; then
echo "error $dir_tmp/code.log"
exit 1
else
path=`cat $dir_tmp/code.log|awk -F/ '/\//{print $1}'|sort -u`
if [ ! -d "$dir_tmp/$path" ]; then
echo "$dir_tmp/$path is not dir"
exit 1
fi
cd $dir_tmp/$path
fi
/usr/local/webserver/php/bin/phpize
chmod 755 configure 
./configure --with-php-config=/usr/local/webserver/php/bin/php-config || exit 1
make  || exit 1
make install  || exit 1
cd ../
	rm -rf $dir_tmp/$path
        echo "memcache_install" >>${dir_tmp}/stat.log
}

phpredis_install (){
cd ${dir_tmp}
/bin/cat "${dir_tmp}/software.log" |grep "redis" |awk '{printf "tar zxvf %s\n",$1}'|bash >$dir_tmp/code.log ||exit 1
if [ ! -s "$dir_tmp/code.log" ]; then
echo "error $dir_tmp/code.log"
exit 1
else
path=`cat $dir_tmp/code.log|cut -d: -f2|awk -F/ '/\//{print $1}'|sed 's/^[ \t]*//;s/[ \t]*$//'|sort -u`
if [ ! -d "$dir_tmp/$path" ]; then
echo "$dir_tmp/$path is not dir"
exit 1
fi
cd $dir_tmp/$path
fi
/usr/local/webserver/php/bin/phpize
./configure --with-php-config=/usr/local/webserver/php/bin/php-config || exit 1
make  || exit 1
make install  || exit 1
cd ../
	rm -rf $dir_tmp/$path
        echo "phpredis_install" >>${dir_tmp}/stat.log
}

eaccelerator_install () {
cd ${dir_tmp}
/bin/cat "${dir_tmp}/software.log" |grep "eaccelerator" |awk '{printf "tar zxvf %s\n",$1}'|bash >$dir_tmp/code.log ||exit 1
if [ ! -s "$dir_tmp/code.log" ]; then
echo "error $dir_tmp/code.log"
exit 1
else
path=`cat $dir_tmp/code.log|awk -F/ '/\//{print $1}'|sort -u`
if [ ! -d "$dir_tmp/$path" ]; then
echo "$dir_tmp/$path is not dir"
exit 1
fi
cd $dir_tmp/$path
fi

/usr/local/webserver/php/bin/phpize
chmod 755 configure 
./configure --enable-eaccelerator=shared --with-php-config=/usr/local/webserver/php/bin/php-config || exit 1
make || exit 1
make install || exit 1
cd ../
mkdir -p /usr/local/webserver/eaccelerator_cache

cd ${dir_tmp}
if [ "$extensions_dir" ];then
	cp ZendGuardLoader.so $extensions_dir
else
	cp ZendGuardLoader.so /usr/local/webserver/php/lib/php/extensions/no-debug-non-zts-20090626/
fi

if [ ! "`grep '/etc/init.d/php-fpm start' /etc/rc.local`" ];then
echo "/etc/init.d/php-fpm start" >>/etc/rc.local 
fi
	rm -rf $dir_tmp/$path
        echo "eaccelerator_install" >>${dir_tmp}/stat.log
if [ "$extensions_dir" ];then
sed -i "s#/usr/local/webserver/php/lib/php/extensions/no-debug-non-zts-20090626#$extensions_dir#g" /usr/local/webserver/php/etc/php.ini
fi

}


Menu 7 "ftp download" "init" "install nginx" "install mysql" "install php" "install lnmp" "Webserver plus"

        #######################################
        #  0)  Exit              #
        #######################################
        case "$choise" in
	0)
                echo "bye..."
                exit 0
	;;
        #######################################
        #     1)  ftp download                #
        #######################################
	1)
		ftp_download	
		echo "1" >>${logfile}	
	;;

        #######################################
        #     2)  init                        #
        #######################################
	2)
		init
		echo "2" >>${logfile}	
	;;
        #######################################
        #     3)  install nginx               #
        #######################################

	3)
		nginx_install	
		echo "3" >>${logfile}	
	;;


        #######################################
        #     4)  install mysql               #
        #######################################

	4)
		mysql_install
		echo "4" >>${logfile}	
	;;

        #######################################
        #     5)  install php                 #
        #######################################

	5)
		php_install
		echo "5" >>${logfile}	
	;;

        #######################################
        #     6)  install lnmp                #
        #######################################

	6)
		nginx_install
		mysql_install
		php_install	
		echo "6" >>${logfile}	
	;;

        #######################################
        #     7)  Webserver plus              #
        #######################################

	7)
		Menu 4 "re2c" "memcache" "phpredis" "eaccelerator"
		case "$choise" in
		1)
			re2c_install
		;;
		2)
			memcache_install
		;;
		3)
			phpredis_install
		;;
		4)
			eaccelerator_install
		;;
		esac
		echo "7" >>${logfile}
	;;
	esac

#/usr/local/webserver/nginx/sbin/nginx
#service mysqld start
#/usr/local/webserver/php/sbin/php-fpm
#10: tar nginx error
#11: nginx code file not found

