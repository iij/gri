FROM centos:centos6

# cron
RUN yum install -y cronie
RUN sed -i -e 's/^session.*required.*pam_loginuid.so/# session\trequired\tpam_loginuid.so/g' /etc/pam.d/crond

# httpd
RUN yum install -y httpd

# ruby
RUN yum install -y rubygems
RUN gem install gri --no-ri --no-rdoc
RUN cp /usr/bin/grapher /var/www/cgi-bin/

# rrdtool
RUN yum install -y wget cairo gettext pango tcp_wrappers-libs libdbi
RUN yum install -y xorg-x11-fonts-Type1 ipa-gothic-fonts ipa-pgothic-fonts
RUN (cd /tmp; wget http://pkgs.repoforge.org/rrdtool/rrdtool-1.4.7-1.el6.rfx.x86_64.rpm)
RUN (cd /tmp; rpm --nodeps -i rrdtool-1.4.7-1.el6.rfx.x86_64.rpm)

# admin
RUN useradd -u 10000 admin

# setup
RUN mkdir -p /usr/local/gri; chown admin /usr/local/gri
RUN echo '*/5 * * * * admin /usr/bin/gri' >>/etc/crontab
RUN cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# sudo docker build -t gri -rm .
# sudo docker run -p 10080:80 -v /somewhere/gri:/usr/local/gri:rw -i -t gri /bin/bash
# bash# /etc/rc.d/init.d/crond start
# bash# /etc/init.d/httpd start
# bash# vi /usr/local/gri/gritab
