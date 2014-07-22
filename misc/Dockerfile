FROM centos:centos7

# cron
RUN yum install -y cronie
RUN sed -i -e 's/^session.*required.*pam_loginuid.so/# session\trequired\tpam_loginuid.so/g' /etc/pam.d/crond

# httpd
RUN yum install -y httpd

# ruby
RUN yum install -y rubygems
RUN gem install gri --no-ri --no-rdoc
RUN cp /usr/local/bin/grapher /var/www/cgi-bin/

# rrdtool
RUN yum install -y rrdtool

# admin
RUN useradd -u 10000 admin

# setup
RUN mkdir -p /usr/local/gri; chown admin /usr/local/gri
RUN echo '*/5 * * * * admin /usr/local/bin/gri' >>/etc/crontab
RUN cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
RUN echo '/usr/sbin/crond&&/usr/sbin/httpd 2>/dev/null&&while true; do /bin/bash; done' > /tmp/boot.sh
CMD ["/bin/bash", "/tmp/boot.sh"]

# sudo docker build -t gri .
# sudo docker run -d -p 10080:80 -v /somewhere/gri:/usr/local/gri:rw -i -t gri
# vi /somewhere/gri/gritab
