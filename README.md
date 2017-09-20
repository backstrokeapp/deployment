# Backstroke Deployment

Backstroke is a Github bot to keep repository forks up to date with their upstream. While it used to
be a monolith, it's now a number of smaller microservices. These mainly consist of:
- [server](https://github.com/backstrokeapp/server), the service that handles User auth and Link
  CRUD. In addition, this service adds link operations to a queue when a link is out of date.
- [worker](https://github.com/backstrokeapp/worker), a worker that eats off the queue of link
  operations, performs the operations, and stores the results.
- [legacy](https://github.com/backstrokeapp/legacy), a service that maintains backwards
  compatibility for legacy features.

![Services.png](Services.png)

# Tasks

## Migrate database
```
docker ps
docker exec -e DATABASE_URL=postgres://docker:docker@deployment_database_1:5432/docker -it <CONTAINERID> yarn migrate 
```
