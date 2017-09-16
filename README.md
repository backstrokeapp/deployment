# Generate Certificates
```
cd postgres_certs
openssl req -new -x509 -nodes -out server.crt -keyout server.key -subj /CN=TheRootCA -newkey rsa:4096 -sha512
```

# Migrate database
```
docker ps
docker exec -e DATABASE_URL=postgres://docker:docker@deployment_database_1:5432/docker -it <CONTAINERID> yarn migrate 
```
