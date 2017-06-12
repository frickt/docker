# TIE Docker

### Login 

```sh
$ docker login
```

### edit docker-compose.yml: 
 - volumes location ->  z.B. - C:\temp\docker\img\oracle\:/opt/oracle/oradata # persistent oracle database data.

####start docker container for database	

```sh
cd docker/compose/testdb/
docker-compose up
```	

### edit docker-compose.yml
 - SVN user
 - SVN password
	
####start docker container for testdbsetup

```sh
cd docker/compose/testdbsetup/
docker-compose up
```

