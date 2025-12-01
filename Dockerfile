FROM nginx:1.25

# Página simple para ver la versión que está desplegada
RUN echo "KubeFoods Backend - version v1" > /usr/share/nginx/html/index.html