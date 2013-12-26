## About

GRI is a monitoring tool that collects various data from network
devices such as routers, switches, and hosts, and creates a lot of
graphs from the collected data.

GRI uses rrdtool for data storage and visualization, and the framework
is written in Ruby.

## Quick start guide

### Requirements

 * Unix OS
 * apache or other web server that supports cgi
 * rrdtool (1.0 or later, 1.4 later is highly recommended)
 * Ruby (1.8.7 or later, 2.0 later is highly recommended)
 * rack gem

### Installation

 1. Install rrdtool
 2. `gem install rack`, `gem install gri --no-ri --no-rdoc`
 3. Copy the grapher cgi script into the directory for CGI executables used by your web server (commonly named cgi-bin). (e.g. `cp -p /usr/bin/grapher /var/www/cgi-bin`)

### Configuration
 1. Create an administrative user for gri, e.g. "admin"
 2. Set up the gri root directory.
<pre>
# mkdir /usr/local/gri
# chown admin /usr/local/gri
</pre>
Replace admin with the valid user that you created.
 3. Create `/usr/local/gri/gritab` file;
gritab is a file used to specify the information collection target.
<pre>
host.example.com    ver=2c community=public
router.example.com  ver=2c community=xxxxxxxx
</pre>
 4. (Optional) Create `/usr/local/gri/gri.conf` file;
gri.conf is a configuration file for setting GRI global parameters.
<pre>
root-dir    /usr/local/gri
gritab-path /usr/local/gri/gritab
font        DEFAULT:0:IPAPGothic
</pre>
 5. Add a line to your /etc/crontab file similar to:
<pre>
*/5 * * * * admin /usr/bin/gri
</pre>
Replace admin with the valid user that you created.
 6. visit `http://<your host>/<path to>/grapher`, e.g. `http://localhost/cgi-bin/grapher`

#### gritab

gritab is a file used to specify the information collection target.
By default, the file path is `/usr/local/gri/gritab`

Example:
<pre>
# gritab example
host.example.com    ver=2c community=public
router.example.com  ver=2c community=xxxxxxxx
</pre>

 * A line beginning with # is a comment line.
 * Each line consists of one host for which data is to be collected by GRI.
 * The hosts can be specified in any order. They are SNMP-polled in the order specified.
 * A host name can be followed by multiple options, each of which is separated by a space. When no option is specified, the default value is assumed.

##### Description of typical options

To disable (turn off) any of these options, specify `no-` at the beginning (example: `no-interfaces` stops collecting the interfaces MIB).

* community=COMMUNITY

  Specifies the text string password for SNMPv1 or SNMPv2c systems. (default: public)

* interfaces

  Specifies to get interfaces MIB. This option is enabled by default.

* type=TYPE,...

  Specifies the data collection type. When this option is omitted, snmp is assumed. Multiple sets can be specified with each set separated by a comma.

* ver=VERSION

  Specifies the snmp version supported by the agent. Available versions are "1" and "2c".

#### gri.conf

gri.conf is the settings file that determines the global operation of GRI.
By default, the file path is `/usr/local/gri/gri.conf`.

Example:
<pre>
# gri.conf example
root-dir    /usr/local/gri
gritab-path /usr/local/gri/gritab
font        DEFAULT:0:IPAPGothic
</pre>

##### Description of typical options

* root-dir *path*

  Root directory of the GRI work directory [/usr/local/gri]

* tra-dir *path*

  tra directory [root-dir + /tra]

* gra-dir *path*

  gra directory [root-dir + /gra]

* log-dir *path*

  log directory [root-dir + /log]

* plugin-dir *path*

  plugin-dir [root-dir + /plugin]

* option *option*

  Option to be added to all gritab targets. Multiple options can be specified.

* option-if-host *PAT* *option*

  Option to be added to the default when the host name matches PAT (regexp). Multiple options can be specified.
