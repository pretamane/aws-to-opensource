# Pretamane Website Integration Guide

## Current Status

 **Backend API**: Fully operational on EC2 (http://54.179.230.219)
 **API Endpoints**: All updated to point to EC2
 **Caddy Configuration**: Updated to serve static files
 **Docker Volume Mount**: Configured for website files
 **Directory Structure**: Created on EC2
⏳ **Website Files**: Need to be uploaded to EC2

## What's Working Now

### Backend APIs (100% Functional)
- `POST /contact` - Contact form submission 
- `GET /stats` - Visitor statistics 
- `GET /health` - Health check 
- `POST /documents/upload` - Document upload 
- `POST /documents/search` - Search documents 
- `GET /analytics/insights` - Analytics 

### Frontend Files (Updated)
-  `pretamane-website/assets/js/contact-form.js` - API endpoint updated to EC2
-  `pretamane-website/pages/contact.html` - API endpoint updated to EC2
-  `pretamane-website/test-backend.html` - API endpoint updated to EC2
-  Simple `index.html` deployed to EC2 (working!)

## Next Steps to Complete Integration

### Option 1: Upload via Git (Recommended)

```bash
# In your local repo
cd /home/guest/aws-to-opensource
git add pretamane-website/
git add docker-compose/
git commit -m "Integrate pretamane-website with EC2 backend"
git push origin main

# Then on EC2 (via SSM)
aws ssm send-command \
  --instance-ids i-0c151e9556e3d35e8 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "cd /home/ubuntu/app",
    "git pull origin main",
    "docker-compose restart caddy",
    "echo Done"
  ]' \
  --region ap-southeast-1
```

### Option 2: Upload via SCP (If you have SSH key)

```bash
scp -i SingaporeKeyPair.pem -r pretamane-website/* \
  ubuntu@54.179.230.219:/home/ubuntu/app/pretamane-website/
```

### Option 3: Manual File Creation (What we did for index.html)

Each file needs to be created via SSM commands (tedious for many files).

## What's Already Configured

### Caddy Configuration (`Caddyfile`)

```caddy
# Static website files served from /var/www/pretamane
handle /assets/* {
    root * /var/www/pretamane
    file_server
}

handle /pages/* {
    root * /var/www/pretamane
    file_server
}

handle / {
    root * /var/www/pretamane
    file_server
}

# API endpoints
handle /contact {
    reverse_proxy fastapi-app:8000
}
```

### Docker Compose Volume Mount

```yaml
caddy:
  volumes:
    - ../pretamane-website:/var/www/pretamane:ro
```

On EC2, this maps to:
```
/home/ubuntu/app/pretamane-website → /var/www/pretamane (inside Caddy container)
```

## Testing After Upload

```bash
# Test homepage
curl http://54.179.230.219/

# Test contact page
curl http://54.179.230.219/pages/contact.html

# Test JavaScript files
curl http://54.179.230.219/assets/js/contact-form.js

# Test contact form submission
curl -X POST http://54.179.230.219/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","message":"Hello"}'
```

## Current Website Structure Needed on EC2

```
/home/ubuntu/app/pretamane-website/
 index.html                         Created
 favicon.ico                       ⏳ Needed
 favicon.svg                       ⏳ Needed
 style.css                         ⏳ Needed
 main.js                           ⏳ Needed
 assets/
    css/
       mobile-menu.css          ⏳ Needed
    js/
        contact-form.js          ⏳ Needed (updated with EC2 endpoint)
        navigation.js            ⏳ Needed
 pages/
     about.html                    ⏳ Needed
     contact.html                  ⏳ Needed (updated with EC2 endpoint)
     services.html                 ⏳ Needed
     portfolio.html                ⏳ Needed
```

## Integration Architecture

```

                     EC2 Instance (54.179.230.219)               

                                                                  
  Browser Request                                                
       ↓                                                          
                 
             Caddy Reverse Proxy                              
           (Port 80 → Routes traffic)                         
                 
                                                                 
                                  
       ↓                            ↓                             
  Static Files              API Endpoints                         
  /var/www/pretamane/       FastAPI App                          
                                                                
        index.html            /contact                       
        pages/                /stats                         
           contact.html      /health                        
        assets/               /docs                          
            js/               /documents/*                   
                contact-form.js                                
                                    ↓                             
                              PostgreSQL Database                
                              (contact_submissions table)        
                                                                  

```

## API Endpoint Changes Made

| File | Old Endpoint | New Endpoint |
|------|--------------|--------------|
| `contact-form.js` | AWS API Gateway | `http://54.179.230.219/contact` |
| `pages/contact.html` | AWS API Gateway | `http://54.179.230.219/contact` |
| `test-backend.html` | AWS API Gateway | `http://54.179.230.219/contact` |

## What Works Right Now

 **Backend**: All APIs functional
 **Database**: PostgreSQL storing contacts (12 contacts so far)
 **Contact Submission**: Frontend → Backend → Database 
 **Homepage**: Simple version deployed
 **Monitoring**: Grafana, Prometheus, pgAdmin all accessible

## To Complete Full Integration

**Easiest Method**: Use the existing git repository

```bash
# Make sure website files are in git
cd /home/guest/aws-to-opensource
git status

# If not committed yet:
git add pretamane-website/ docker-compose/
git commit -m "Integrate pretamane portfolio website"
git push

# Then pull on EC2
aws ssm start-session --target i-0c151e9556e3d35e8
# Inside EC2:
cd /home/ubuntu/app
git pull
docker-compose restart caddy
```

## Current Visitor Stats

- Total Visitors: 12
- Total Contacts: 11
- Total Documents: 4
- Backend: Fully operational
- Website: Partially deployed (homepage only)

## Files Available Locally

All website files ready at:
```
/home/guest/aws-to-opensource/pretamane-website/
```

Updated with EC2 endpoints and ready to upload!

