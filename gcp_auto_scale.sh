#!/bin/bash

# Configuration
GCP_ZONE="us-central1-a"
LOCAL_DATA_PATH="$HOME/local/data"  
REMOTE_DATA_PATH="$HOME" 
GCP_USER="vboxuser"  
CPU_THRESHOLD=75
APP_DIR="myapp"
PORT="8080"
GCP_PROJECT="your-gcp-project-id"
SERVICE_ACCOUNT_KEY="path/to/your/service-account-key.json"

# Authenticate with GCP
gcloud auth activate-service-account --key-file="$SERVICE_ACCOUNT_KEY"
gcloud config set project "$GCP_PROJECT"

# Get CPU Usage
CPU_USAGE=$(top -bn 1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
echo "CPU Usage: $CPU_USAGE%"

# Check if the VM exists in GCP
INSTANCE_NAME=$(gcloud compute instances list --filter="name~'scaled-vm'" --format="value(name)" | head -n 1)

# If CPU usage exceeds threshold and VM does not exist, create a new VM
if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
    if [ -z "$INSTANCE_NAME" ]; then
        echo "CPU usage exceeded $CPU_THRESHOLD%. Creating a new VM in GCP..."

        # Create a GCP VM instance
        gcloud compute instances create scaled-vm \
            --zone="$GCP_ZONE" \
            --machine-type=e2-medium \
            --image-family=ubuntu-2204-lts \
            --image-project=ubuntu-os-cloud \
            --boot-disk-size=10GB \
            --tags=http-server,https-server

        echo "Wait for the VM to be ready..."
        sleep 30

        # Transfer data to GCP VM
        echo "Transferring data to GCP VM..."
        gcloud compute scp --recurse "$LOCAL_DATA_PATH" "$GCP_USER@scaled-vm:$REMOTE_DATA_PATH" --zone="$GCP_ZONE"

        # Deploy the Sample Node.js Application
        echo "Deploying the Node.js application..."
        gcloud compute ssh scaled-vm --zone="$GCP_ZONE" --command "
            # Update and install dependencies
            sudo apt update
            sudo apt install -y nodejs npm nginx

            # Create application directory and install Express
            mkdir -p /home/$GCP_USER/$APP_DIR
            cd /home/$GCP_USER/$APP_DIR
            npm init -y
            npm install express

            # Create the app.js file
            echo \"const express = require('express'); const app = express(); const port = $PORT; app.get('/', (req, res) => { res.send('Hello, world! This is a sample app deployed on scaled-vm.'); }); app.listen(port, () => { console.log('App listening on port ' + port); });\" > app.js

            # Run the application
            nohup node app.js &

            # Configure Nginx to proxy requests to the Node app
            sudo rm /etc/nginx/sites-enabled/default
            echo 'server {
                listen 80;
                server_name _;
                location / {
                    proxy_pass http://localhost:$PORT;
                    proxy_http_version 1.1;
                    proxy_set_header Upgrade \$http_upgrade;
                    proxy_set_header Connection 'upgrade';
                    proxy_set_header Host \$host;
                    proxy_cache_bypass \$http_upgrade;
                }
            }' | sudo tee /etc/nginx/sites-available/default

            # Enable and restart Nginx
            sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
            sudo systemctl restart nginx
        "

        echo "Sample application deployed and running on scaled-vm."

    else
        echo "GCP VM already exists. Skipping creation."
    fi

# If CPU usage drops below threshold and VM exists, shut down the VM
elif (( $(echo "$CPU_USAGE < $CPU_THRESHOLD" | bc -l) )); then
    if [ -n "$INSTANCE_NAME" ]; then
        echo "CPU usage dropped below $CPU_THRESHOLD%. Shutting down GCP VM..."
        gcloud compute instances delete scaled-vm --zone="$GCP_ZONE" --quiet
    else
        echo "No active GCP VM to shut down."
    fi
fi
