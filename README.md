# Devops


## Setup Nginx:
```sh
curl -O https://raw.githubusercontent.com/LeanderZiehm/devops/refs/heads/main/setup-nginx.sh
```

## Backup Postges:
```sh
curl -O https://raw.githubusercontent.com/LeanderZiehm/devops/refs/heads/main/backup-postgres.sh
```

# Git Key
```sh
curl -O https://raw.githubusercontent.com/leanderziehm/devops/refs/heads/main/gitkey1.py
```


# Git clone 

```
git clone 
```
then 

```
ln -s ~/devops/backup-postgres.sh ~/backup-postgres.sh
ln -s ~/devops/backup-ssh-logs.sh ~/backup-ssh-logs.sh
ln -s ~/devops/setup-nginx.sh ~/setup-nginx.sh
```


# hosted:
umami STAYS
java
wordpress
database. STAYS # put mysql on

1. start mysql container on database vps.
2. export wordpress data and import in database server.
3. move wordpress on java server
4. move umami on java server.
5. whipe wordpress and umami servers and install rocky linux 


podman exec -e MYSQL_PWD=examplepass wordpress-stack_db_1 mysqldump -u exampleuser --all-databases > wordpress_backup.sql

podman exec -e MYSQL_PWD=examplepass wordpress-stack_db_1 mysqldump -u exampleuser --single-transaction --routines --triggers exampledb > wordpress_backup.sql


podman exec -e MYSQL_PWD=password-here wordpress-stack_db_1 mysqldump -u user-here --single-transaction --routines --triggers --no-tablespaces databse-here > wordpress_backup.sql

-----




ubuntu@wordpress-vm:~$ podman inspect wordpress-stack_db_1 | grep -i MYSQL
               "mysqld"
          "ImageName": "docker.io/library/mysql:8.0",
                    "Destination": "/var/lib/mysql",
                    "MYSQL_VERSION=8.0.45-1.el9",
                    "MYSQL_SHELL_VERSION=8.0.45-1.el9",
                    "MYSQL_RANDOM_ROOT_PASSWORD=1",
                    "MYSQL_DATABASE=exampledb",
                    "MYSQL_USER=exampleuser",
                    "MYSQL_PASSWORD=examplepass",
                    "MYSQL_MAJOR=8.0",
                    "mysqld"
               "Image": "docker.io/library/mysql:8.0",
                    "MYSQL_DATABASE=exampledb",
                    "MYSQL_USER=exampleuser",
                    "MYSQL_PASSWORD=examplepass",
                    "MYSQL_RANDOM_ROOT_PASSWORD=1",
                    "wordpress-stack_db:/var/lib/mysql",
                    "docker.io/library/mysql:8.0"
                    "wordpress-stack_db:/var/lib/mysql:rw,rprivate,nosuid,nodev,rbind"
ubuntu@wordpress-vm:~$ podman exec -it wordpress-stack_wordpress_1 cat /var/www/html/wp-con






----



## My stack: 
- revers proxy: Nginx
- containerization: docker and docker-compose
- database: postgres, mysql, sqlite
- backend: java, typescript and python
- frontend: react, angular and javascript

# Nginx 
certbot

# Quesitons 
how do I restart my tmux services after rebooting vps?

# Main Web-App Links:

https://todo.leanderziehm.com/
https://github.com/LeanderZiehm/todo-web-app

https://measure.leanderziehm.com/
https://github.com/LeanderZiehm/frontends/tree/main/measure

https://www.share-web.me/
https://github.com/LeanderZiehm/apis/tree/main/10_host-web

https://pastebins.leanderziehm.com/
https://github.com/LeanderZiehm/pastebins

https://www.leanderziehm.com/
https://github.com/LeanderZiehm/leanderziehm.com


# Currently Deployed:
| Website                                   | Type     | Description                  | Project ID       | GitHub Link                                                                                    | Deployed On |
|-------------------------------------------|----------|------------------------------|------------------|------------------------------------------------------------------------------------------------|-------------|
| https://deploy.leanderziehm.com/          | Backend  | Update deployments using git | simple-deploy    | [Simple Deploy](https://github.com/LeanderZiehm/simple-deploy)                                 | Oracle VPS  |
|  https://excalidraw-api.leanderziehm.com/ | Backend  | Excalidraw backup backend    | excalidraw       | [Excalidraw Backend](https://github.com/LeanderZiehm/excalidraw-selfhosted/tree/main/backend)  | Oracle VPS  |
| https://excalidraw.leanderziehm.com/      | Frontend | Excalidraw online editor     | excalidraw       | [Excalidraw Frontend](https://github.com/LeanderZiehm/excalidraw-selfhosted/tree/main/backend) | Vercel      |
| https://dit-quiz.vercel.app/              | Frontend | Quiz application             | dit-quiz         | [DIT Quiz](https://github.com/LeanderZiehm/CampusRalley)                                       | Vercel      |
| https://habits.leanderziehm.com/          | Frontend | Habit tracker frontend       | habits           | [Habits Frontend](https://github.com/LeanderZiehm/frontends/tree/main/habits)                  | Vercel      |
| https://measure.leanderziehm.com          | Frontend | Measurement tracker frontend | measure          | [Measure Frontend](https://github.com/LeanderZiehm/frontends/tree/main/measure)                | Vercel      |
| https://preview.leanderziehm.com          | Frontend | Preview environment          | preview          | [Preview HTML](https://github.com/LeanderZiehm/frontends/tree/main/previewHTML)                | Vercel      |
| https://audio.leanderziehm.com            | Backend  | Audio service                | audio            | [Audio ](https://github.com/LeanderZiehm/frontends/tree/main/audio)                            | Vercel      |
| https://notify.leanderziehm.com           | Backend  | Notification service         | notify           | [Notify](https://github.com/LeanderZiehm/apis/tree/main/07_notification-api)                   | Vercel      |
| https://tracker-api.leanderziehm.com      | Backend  | Tracker backend API          | tracker          | [Tracker API](https://github.com/LeanderZiehm/apis/tree/main/02_tracker-api)                   | Vercel      |
| https://www.leanderziehm.com              | Frontend | Personal website             | personal website | [LeanderZiehm.com](https://github.com/LeanderZiehm/leanderziehm.com)                          | Vercel      |
| https://paste.leanderziehm.com            | Monolith | Paste service                | Pastebins        | [Pastebins](https://github.com/LeanderZiehm/pastebins)                                         | Vercel      |
| https://lovelingo.leanderziehm.com        | Frontend | Lovelingo main app           | lovelingo        | [Livelingo](https://github.com/LeanderZiehm/lovelingo)                                         | Vercel      |
| https://lovelingo-chat.leanderziehm.com   | Frontend | Lovelingo chat service       | lovelingo        | [Livelingo](https://github.com/LeanderZiehm/lovelingo)                                         | Vercel      |
| https://lovelingo-game.leanderziehm.com   | Frontend | Lovelingo game module        | lovelingo        | [Livelingo](https://github.com/LeanderZiehm/lovelingo)                                         | Vercel      |
| https://todo.leanderziehm.com             | Frontend | Todo app frontend            | todo             | [Todo Web App](https://github.com/LeanderZiehm/todo-web-app)                                   | Vercel      |
| https://todo-api.leanderziehm.com/        | Backend  | Todo backend API             | todo             | [Todo API](https://github.com/LeanderZiehm/apis/tree/main/02_tracker-api)                      | Vercel      |
# Devops Projects:
## [Simple Deploy](https://github.com/LeanderZiehm/simple-deploy)



# Todo

- figure out a good way to auto export .env and load .env from secret manager
