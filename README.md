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
%deployku ALL=(ALL) NOPASSWD:/usr/bin/nginx -s reload
```

Store path to deployku into ~deployku/.sshcommand:
```bash
which deployku > /home/deployku/.sshcommand
```

As user deployku add first ssh key. The first user will be manager and will have admin privileges to all repositories.
The command reads one line from stdin and expects the line to be a public ssh key. So you can do something like this:
```bash
su - deployku
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

### Create and configure new application

Create new repository on deployku server (replace localhost with name of your server)
```bash
ssh deployku@localhost app:create myapp
```

Create new database on running database server
```bash
ssh deployku@localhost postgres:db:create dbserver myapp-db
```

Link created database to our application
```bash
ssh deployku@localhost postgres:db:link dbserver myapp-db myapp
```

Configure our servers domains
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
Use ssh with `-t` option.
```bash
ssh -t deployku@localhost postgres:db:connect dbserver myapp-db
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