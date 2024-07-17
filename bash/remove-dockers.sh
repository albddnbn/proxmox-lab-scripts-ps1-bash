## Stop and rm all docker containers:
docker container stop $(docker ps -a -q)

docker container rm $(docker ps -a -q)
