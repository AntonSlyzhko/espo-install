# Usage

1. Download this repo
2. Run `sudo -i` to become root
3. Go to the repo directory
4. Run `./install-espo.sh`
5. Respond to requests from CLI
6. After the script is done:
    - Add to `/etc/nginx/nginx.conf`:
    
        ```nginx
        map $http_upgrade $connection_upgrade {
          default upgrade;
          '' close;
        }
        upstream websocket {
          server 127.0.0.1:8080;
        }
        ```
7. Run `sudo systemctl restart nginx.service` and go to website for further installetion of EspoCRM.
