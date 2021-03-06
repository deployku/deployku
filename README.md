# DEPLOYKU

Deploy applications using git with zero down time. Inspired by dokku but should be distribution independent.

## Instalation instructions

### Required packages

* docker or lxc (lxc not implemented yet)
* ruby with rubygems (system wide)
* postgresql client (psql command)
* nginx (server)
* sshd (server)
* git
* sudo

### Installation

```bash
gem install deployku
```

### System configuration

Add new user 'deployku' and add him to docker group
```bash
useradd -m deployku -G docker
```

Configure nginx to load nginx.conf files from ~deployku/*/nginx.conf. Eg.:
```
http {
  ...
  include /home/deployku/*/nginx.conf;
}
```

To allow user deployku to reload nginx configuration via sudo add following line to /etc/sudoers
```bash
%deployku ALL=(ALL) NOPASSWD:/usr/sbin/nginx -s reload
```

Store path to deployku into ~deployku/.sshcommand:
```bash
which deployku > /home/deployku/.sshcommand
```

As user deployku add first ssh key. The first user will be manager and will have admin privileges to all repositories.
The command reads one line from stdin and expects the line to be a public ssh key. So you can do something like this:
```bash
su - deployku
mkdir ~/.ssh
cat id_rsa.pub | deployku access:add peter
```

User peter is now deployku administrator and can do everything. Please notice that this works only for first time.
Adding another deployku users can be done over ssh by deployku administrator. So user peter now can add another administrator:
```bash
cat id_rsa2.pub | ssh deployku@localhost access:add thomas
ssh deployku@localhost access:acl:system_set thomas admin
```

For more information run command like this:
```bash
ssh deployku@localhost help
```

Replace 'localhost' with your domain.

## Custom files

### Custom start script

After the container is started the `/start` script is executed. The `/start` script is generated by the application plugin.
If you wish to use your own start script just create and commit your own start script. The custom start script has to be
in your application root and has to expect that the application is in `/app` directory.

Example of custom start script:
```bash
#!/usr/bin/env bash

source /usr/local/rvm/scripts/rvm

cd /app

export RAILS_ENV=production

bundle exec rake db:migrate RAILS_ENV=production
bundle exec rake assets:precompile RAILS_ENV=production

mkdir -p tmp/pids
bundle exec sidekiq -c 2 -e production -d -L log/sidekiq.log -P tmp/pids/sidekiq.pid
bundle exec puma -p 3000 -e production --pidfile tmp/pids/puma.pid
```

### Custom Dockerfile

You may prepare your own image or for some other reasons you may want to create custom containers. Just create Dockerfile in your
application root and commit it. When you push to deployku repository it will be used.

Example of custom Dockerfile:
```
FROM pejuko/rvm-base

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update

RUN /bin/bash -l -c 'rvm install 2.2.3 && rvm use 2.2.3 --default'
RUN /bin/bash -l -c 'rvm rubygems current'
RUN /bin/bash -l -c 'gem install bundler'

RUN /bin/bash -l -c 'rvm cleanup all'

RUN apt-get install -y libpq-dev

RUN apt-get -y autoclean
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 3000
CMD []
ENTRYPOINT ["/start"]

ADD start /start

ADD app /app
RUN /bin/bash -l -c 'cd app && RAILS_ENV=production bundle install --without development test'
```

## Supported applications

### Autoconfiguration for frameworks

* Ruby on Rails

### Services

* PostgreSQL
* Redis

## Examples

### Create new project and assign commit rights to jane

```bash
ssh deployku@localhost app:create myapp
cat jane.pub | ssh deployku@localhost access:add jane
ssh deployku@localhost access:acl:set myapp jane commit
```

Jane now can deploy with git.

### Create and start new PostgreSQL server

```bash
ssh deployku@localhost postgres:create dbserver
ssh deployku@localhost postgres:start dbserver
```

### Create and start new Redis server

```bash
ssh deployku@localhost redis:create redis
ssh deployku@localhost redis:start redis
```

### Create and configure new Rails application with PostgreSQL and Redis

Create new repository on deployku server (replace localhost with name of your server)
```bash
ssh deployku@localhost app:create myapp
```

Create new database on running database server
```bash
ssh deployku@localhost postgres:db:create dbserver myappdb
```

Link created database to our application
```bash
ssh deployku@localhost postgres:db:link dbserver myappdb myapp
```

Link Redis to our application
```bash
ssh deployku@localhost redis:link redis myapp
```

To say that we want to install postgresql dev tools in our container you can create file `deployku.yml` in your
application directory:
```yaml
packages: ['libpq-dev']
```

OR you can setup this in the repository with:
```bash
ssh deployku@localhost app:config:add_package libpq-dev
```

Configure our server domains
```bash
ssh deployku@localhost app:config:add_domain myapp myapp.com
ssh deployku@localhost app:config:add_domain myapp www.myapp.com
```

Enable nginx server
```bash
ssh deployku@localhost nginx:enable myapp
```

Check our configuration
```bash
ssh deployku@localhost app:config:show myapp
```

Setup application environment like SECRET_KEY_BASE for rails app
```bash
bundle exec rake secret
ssh deployku@localhost app:config:set myapp SECRET_KEY_BASE somesecretkey
```

Setup our deployku repository as remote branch
```bash
git remote add deployku deployku@localhost:myapp
```

Deploy.
```bash
git push deployku master
```

### Connect to database
To connect as postgres user use ssh with `-t` option.
```bash
ssh -t deployku@localhost postgres:db:connect dbserver myappdb
```

and to connect as linked application:
```bash
ssh -t deployku@localhost postgres:db:connect:app dbserver myapp
```

### Backup database
To backup all databases use:
```bash
ssh deployku@localhost postgres:dumpall dbserver
```

and to backup only one database use:
```bash
ssh deployku@localhost postgres:db:dump dbserver myappdb
```

### Exec command in container environment
Following will run bash inside container. Use ssh with `-t` option.
```bash
ssh -t deployku@localhost app:run myapp bash
```

And then you can enter your app directory:
```bash
cd app
```

And run eg. rails console:
```bash
rails c
```

## ACL: rights
- admin
- commit