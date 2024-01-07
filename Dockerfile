FROM debian:bookworm

ENV DB_NAME=nsites
ENV DB_USER=cts
ENV DB_PASSWORD=Chen_0104

# source codes
COPY data/phytolrr /code/phytolrr
COPY data/database /code/database

# install, build...
RUN sed -i 's/http:\/\/deb.debian.org/http:\/\/mirrors.tuna.tsinghua.edu.cn/' /etc/apt/sources.list.d/debian.sources
RUN apt update && apt-get install -y systemctl mariadb-server python3 python3-pip nginx git nodejs npm
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

## build frontend files
RUN cd /code/phytolrr/frontend \
    && npm install \
    && NODE_OPTIONS=--openssl-legacy-provider npm run build \
    && rm -rf /code/phytolrr/frontend/dist/dist.zip

## biopython delete Bio.Alphabet we use at version 1.78(see https://biopython.org/wiki/Alphabet) 
RUN pip install --break-system-packages -r /code/phytolrr/requirements.txt

# recovery database
RUN cd /code/database && \
    service mariadb start && \
    tar -xf nsites.2019-08-07.19.39.sql.tar.gz && \
    sleep 5 && \
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;" && \
    mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';" && \
    mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" && \
    mysql -u root -e "FLUSH PRIVILEGES;" && \
    mysql -u root $DB_NAME < $(ls *.sql) && \
    service mariadb stop

# nginx, py config files
COPY nginx.conf /etc/nginx/
COPY settings.ini /runtime/py/config/settings.ini
EXPOSE 80

# prepare runtime folder
RUN mkdir -p /runtime/nginx/log \
    && mkdir -p /runtime/nginx/cache \
    && mkdir -p /runtime/py/log \
    && ln -s /code/phytolrr/frontend/dist/ /runtime/dist

CMD service mariadb start && service nginx start && cd /runtime/py/config/ && PYTHONPATH=/code/phytolrr python3 /code/phytolrr/web_service/lrr_search_web_service.py
