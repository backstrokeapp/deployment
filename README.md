# Backstroke Deployment

Backstroke is a Github bot to keep repository forks up to date with their upstream. While it used to
be a monolith, it's now a number of smaller microservices.

![Services.png](Services.png)

- [server](https://github.com/backstrokeapp/server), the service that handles User auth and Link
  CRUD. In addition, this service adds link operations to a queue when a link is out of date.
- [worker](https://github.com/backstrokeapp/worker), a worker that eats off the queue of link
  operations, performs the operations, and stores the results.
- [legacy](https://github.com/backstrokeapp/legacy), a service that maintains backwards
  compatibility for legacy features like Backstroke classic and forwarding of old api requests to
  the `server` service.
- [dashboard](https://github.com/backstrokeapp/dashboard), a react-based frontend to the api
  provided by the `server` service. Mainly handles logging in and Link CRUD.
- [www](https://github.com/backstrokeapp/www), the Backstroke website found at
  https://backstroke.co.

# Deployment
Deployment is orchestrated with `docker-compose`, which is powered by
[docker](https://docs.docker.com/engine/docker-overview/) containers.  The `docker-compose.yml` file
in the root of this repository provides some default settings that hold true no matter the
environment Backstroke is being deployed in. To deploy Backstroke, kick off docker-compose
with a command similar to `docker-compose -f docker-compose.yml -f my-environment-docker-compose.yml
up`. In a nutshell, this combines the two configuration files together which allows you to customize
each service without modifying the main `docker-compose.yml`. Depending on the environment
Backstroke is being deployed into, the contents of the second docker-compose file will vary.

## Development
In development, we want to run all services locally and make it as easy as possible to reset the
state of the entire application. Here's an example second `development-docker-compose.yml` file that
has the minimal required configuration to start Backstroke in devlopment mode.

### Prerequisites
- A Github [Personal access token](https://github.com/settings/tokens) for the user that will be
  making pull requests. 
- A Github [oauth application](https://github.com/settings/developers) for Backstroke to use to
  login users. The callback url should be `http://localhost:8000/auth/github/callback`.

```yml
version: "3.1"

services:

  # A database for the `server` service
  database:
    image: library/postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: docker
      POSTGRES_PASSWORD: docker
      POSTGRES_DB: docker

  worker:
    environment:
      REDIS_URL: redis://redis:6379
      GITHUB_TOKEN: <insert github personal access token here>

  server:
    depends_on:
      - database
    environment:
      DEBUG: backstroke:*

      DATABASE_URL: postgres://docker:docker@database:5432/docker
      DATABASE_REQUIRE_SSL: 'false'

      GITHUB_TOKEN: <insert github personal access token here>
      GITHUB_CLIENT_ID: <insert github client id here>
      GITHUB_CLIENT_SECRET: <insert github client secret here>
      GITHUB_CALLBACK_URL: <insert gitthub oauth callback here>
      SESSION_SECRET: "backstroke development session secret"
      CORS_ORIGIN_REGEXP: .*

      APP_URL: http://localhost:3000
      API_URL: http://localhost:8000
      ROOT_URL: https://backstroke.co

  legacy:
    environment:
      GITHUB_TOKEN: <insert github personal access token here>


volumes:
  database:
```

After placing this file into `development-docker-compose.yml`, run `docker-compose -f
docker-compose.yml -f development-docker-compose.yml up`. Visit http://localhost:8000 for the
`server` service and http://localhost:3000 for the `dashboard` service.

### Live-reloading
In the above configuration, changing server code locally won't restart the service. If you'd like
for the service to restart when you save your code, two things are required:

1. Change the `command` of the service to use [nodemon](https://npmjs.com/nodemon).
2. Mount your code into the service as a volume

Here's an example for the `server` service above:
```yml
...
server:
  # 1. Use nodemon.
  command: yarn start-dev
  # 2. Mount code into container.
  volumes:
    - "./path/to/my/code/from/this/repository:/app"
  environment:
    ...
...
```
All services should have a `start-dev` npm task associated with them. If not, open an issue.

### A note on the worker
The worker will make **real, live github pull requests** by default. Don't spam other people's
repositories! However, there [is a flag that can be enabled to ensure the worker won't actually make
any pull requests](https://github.com/backstrokeapp/worker#arguments).

### Running outside Docker
Sometimes, you'd like to test a service in isolation. Using docker-compose isn't really all that
helpful in this case. If docker-compose isn't helpful, don't feel like you have to use it.

# Tasks

## Migrate database
```
docker ps
docker exec -e DATABASE_URL=postgres://docker:docker@deployment_database_1:5432/docker -it <CONTAINERID> yarn migrate 
```
