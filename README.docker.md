## Sample Data

Grab some sample data, for exmaple: https://github.com/hathitrust/imgsrv-sample-data

`imgsrv-sample-data` should be in the same directory as `imgsrv`.

## Setup

Check out the submodules:

```
$ cd imgsrv
$ git submodule init
$ git submodule update
```

And _for now_ copy the application specific SQL into the `mdp-lib` submodule so the `mariadb` service can see it:

```
$ cd imgsrv
$ cp sql/*.sql ../vendor/common-lib/lib/sql
```

## Running

The docker setup has the imgsrv container running `startup_imgsrv` as a FastCGI service on port 31028.

Use a webserver for FastCGI like https://github.com/beberlei/fastcgi-serve to access the FastCGI app:

`fastcgi-serve --listen 127.0.0.1:7777 --server-port 31028`

Then:

* `http://localhost:7777/cover?id=loc.ark:/13960/t5v69h717`
* `http://localhost:7777/image?id=loc.ark:/13960/t5v69h717;seq=1`
* `http://localhost:7777/html?id=loc.ark:/13960/t5v69h717;seq=1`

