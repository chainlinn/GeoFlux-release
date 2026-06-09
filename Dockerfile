FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/
COPY releases.json /usr/share/nginx/html/releases.json
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
