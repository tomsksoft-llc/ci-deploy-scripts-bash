# ci-deploy-scripts-bash
Easy deploy automation tool

This is a tool for deployment web-sites or services to Linux base system.

The tool consist of only two bash scripts that must be integrated to you project sources. There are enough to provide for you:
- Deploy to remote servers via ssh (no git needed on the target servers)
- Testing environment on the servers before start deploy process
- Detect local changes on remote servers to prevent loss the changes
- Restore to previous version (up to 3)
- Cleaning server from old unused versions
- Easy integration to you project (see below)
- Compatibility with most of CI and DevOps systems (i.e. Gitlab CI, Jenkins)

<b>Quick start:</b>

Step 1: integrate scripts to you project

Download the `build-inst.sh` and `deploy.sh` to your project repo into separate directory i.e. `CI`.

Step 2: adapt scripts for your projects

In `build-inst.sh` set `INSTALL_PCKG_SUFFIX` to something that identify your project. 

In `build-inst.sh` lookup for string:

`tar -czf "${BUILD_VERSION}_${INSTALL_PCKG_SUFFIX}.tgz" --exclude="CI" ./*`

modify tar arguments as you needed. 

As result of runing `build-inst.sh` you must give the archive that can be uploaded to remote server and your project can be started from the archive content.

In `deploy.sh` modify a few constants to properly value:

`OWNER="myusername"` – set to ssh user name (the deploy will works under that ssh user on remote servers).

`TARGET_DIR_STATE="drwxr-xr-x${OWNER}mygroupname"` – set myusergroup to properly group of the your project dir on remote server.

Do the same for `BUILDS_DIR_STATE="drwxr-xr-x${OWNER}mygroupname"`.

The same for `SITE_ROOT_SYMLINK_STATE="lrwxrwxrwx${OWNER}mygroupname"`.

Step 3: prepare environment for deploy on remote servers

`
$ mkdir myproject
$ chmod 755 myproject/
$ mkdir myproject/revs
$ chmod 755 myproject/revs/
$ ln -s foo myproject/site
`

Please, do it from the user = OWNER, and group from previous step.

Step 4: try to use

Launch command in your project repo:

`$ ./CI/build-inst.sh 1`

The install package must be created. The file name will be like `1_myproject.tgz`.

Deploy the package to server via ssh with commands like these:

```
$ scp CI/deploy.sh myuser@myserver:~
$ scp 1_myproject.tgz myuser@myserver:/home/myuser/myproject/revs/
$ ssh myuser@myserver bash ~/deploy.sh /home/myuser/myproject /home/myuser/myproject/revs/1_myproject.tgz
```

If all gone properly then we will see in the remote directory the state like:

```
lrwxrwxrwx  1 myuser mygroup   23 Sep 19 12:16 backup1 -> /home/myuser/myproject/foo
drwxr-xr-x  3 myuser mygroup 4096 Sep 19 12:16 revs
lrwxrwxrwx  1 myuser mygroup   36 Sep 19 12:16 site -> /home/myuser/myproject/revs/1_myproject
```

Step 5: launch to prod

Just set `/home/myuser/myproject/site` as document root for your web server.

To see all possibilities of the deploy script just start it without arguments.
