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

## Running

The `imgsrv` service will start up the "image" service using `startup_imgsrv` as a FastCGI service on port 31028.

`apache-cgi` will start up `apache` configured to proxy API request to `imgsrv:31028` or the download applications via CGI on port 8888, e.g.

* `http://localhost:8888/cgi/imgsrv/cover?id=test.pd_open`
* `http://localhost:8888/cgi/imgsrv/image?id=test.pd_open&seq=1`
* `http://localhost:8888/cgi/imgsrv/html?id=test.pd_open&seq=1`
* `http://localhost:8888/cgi/imgsrv/download/pdf?id=test.pd_open&seq=1&attachment=0`


Use a webserver for FastCGI like https://github.com/beberlei/fastcgi-serve to access the FastCGI app:

`fastcgi-serve --listen 127.0.0.1:7777 --server-port 31028`

Then:

* `http://localhost:7777/cover?id=test.pd_open`
* `http://localhost:7777/image?id=test.pd_open&seq=1`
* `http://localhost:7777/html?id=test.pd_open&seq=1`
