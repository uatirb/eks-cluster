# Use the official Nginx image from Docker Hub
FROM nginx:alpine

# Copy the local index.html file into the Nginx web server's default location
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80 so we can access the web server
EXPOSE 80

# Command to run when the container starts (Nginx will serve the static content by default)
CMD ["nginx", "-g", "daemon off;"]

