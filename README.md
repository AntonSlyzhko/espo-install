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
    
    - Add to `/etc/mysql/mariadb.conf.d/50-server.cnf`:
    
        ```ini
        max_connections = 200
        table_definition_cache = 800
        table_open_cache = 4000
        innodb_buffer_pool_size = {70% of RAM}
        innodb_flush_method = O_DIRECT
        innodb_log_file_size = 2G
        innodb_flush_log_at_trx_commit = 2
        ```
    
    - Change in `/etc/php/{version}/cli/php.ini` and `/etc/php/{version}/fpm/php.ini`:
    
        ```ini
        max_execution_time = 180
        max_input_time = 180
        memory_limit = 256M
        post_max_size = 128M
        upload_max_filesize = 128M
        ```
7. Run `sudo systemctl restart nginx.service` and go to website for further installetion of EspoCRM.
