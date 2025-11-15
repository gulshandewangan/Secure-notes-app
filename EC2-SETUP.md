# EC2 Deployment Guide

## 🚀 One-Command Deployment

This script automatically deploys your Secure Notes app to an EC2 instance with full production setup including Nginx, SSL, firewall, and monitoring.

## Prerequisites

### 1. EC2 Instance Setup
- **Instance Type**: t2.micro or larger (t3.micro recommended)
- **OS**: Ubuntu 20.04 LTS or Ubuntu 22.04 LTS
- **Security Group**: Allow ports 22 (SSH), 80 (HTTP), 443 (HTTPS)
- **Storage**: 8GB minimum (20GB recommended)

### 2. Domain Setup (Optional)
- Point your domain to EC2 instance IP
- Set `DOMAIN_NAME` environment variable
- If no domain, the app will be accessible via IP address

### 3. MongoDB Atlas
- Create MongoDB Atlas cluster
- Get connection string
- Whitelist EC2 IP or use 0.0.0.0/0

## 🎯 Quick Deployment

### Step 1: Connect to EC2
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### Step 2: Upload Files
```bash
# Option A: Clone from Git (recommended)
git clone your-repo-url
cd your-repo-name

# Option B: Upload files via SCP
scp -i your-key.pem -r . ubuntu@your-ec2-ip:~/secure-notes-app
```

### Step 3: Set Environment Variables
```bash
# Required: MongoDB connection
export MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/secure_notes"

# Optional: Custom domain (for SSL)
export DOMAIN_NAME="yourdomain.com"

# Optional: Custom secret key (auto-generated if not set)
export SECRET_KEY="your-super-secret-key"
```

### Step 4: Run Deployment Script
```bash
# Make script executable
chmod +x deploy-ec2.sh

# Run deployment (requires sudo)
sudo -E ./deploy-ec2.sh
```

That's it! The script will:
- ✅ Install all dependencies (Python, Nginx, etc.)
- ✅ Configure firewall (UFW)
- ✅ Create application user
- ✅ Set up Python virtual environment
- ✅ Configure systemd service
- ✅ Set up Nginx reverse proxy
- ✅ Configure SSL certificate (if domain provided)
- ✅ Start all services
- ✅ Create management scripts

## 🔧 Post-Deployment Management

### Service Management
```bash
# Restart application
restart-secure-notes

# View logs
secure-notes-logs

# Check status
secure-notes-status

# Manual service control
sudo systemctl start/stop/restart secure-notes
sudo systemctl start/stop/restart nginx
```

### File Locations
- **App Directory**: `/opt/secure-notes-app/`
- **Logs**: `journalctl -u secure-notes`
- **Nginx Config**: `/etc/nginx/sites-available/secure-notes-app`
- **Service File**: `/etc/systemd/system/secure-notes.service`

## 🔍 Troubleshooting

### Common Issues

1. **MongoDB Connection Failed**
   ```bash
   # Check environment variables
   sudo cat /opt/secure-notes-app/.env
   
   # Test connection
   cd /opt/secure-notes-app
   sudo -u secure-notes-app ./venv/bin/python -c "from app import mongo; print(mongo.db.command('ping'))"
   ```

2. **Service Won't Start**
   ```bash
   # Check service status
   sudo systemctl status secure-notes
   
   # View detailed logs
   sudo journalctl -u secure-notes -f
   ```

3. **Nginx Issues**
   ```bash
   # Test Nginx config
   sudo nginx -t
   
   # Check Nginx logs
   sudo tail -f /var/log/nginx/error.log
   ```

4. **SSL Certificate Issues**
   ```bash
   # Renew certificate manually
   sudo certbot renew
   
   # Check certificate status
   sudo certbot certificates
   ```

### Health Checks
```bash
# Application health
curl http://localhost/health

# External access
curl http://your-ec2-ip/health
```

## 🔐 Security Features

The deployment script automatically configures:

- **Firewall**: UFW with minimal required ports
- **User Security**: App runs as non-root user
- **File Permissions**: Secure environment file (600)
- **Nginx Security**: Security headers, rate limiting
- **SSL**: Automatic HTTPS with Let's Encrypt
- **Auto-renewal**: SSL certificates auto-renew

## 📊 Monitoring

### Application Monitoring
```bash
# Real-time logs
sudo journalctl -u secure-notes -f

# Service status
sudo systemctl status secure-notes

# Resource usage
htop
```

### Nginx Monitoring
```bash
# Access logs
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log
```

## 🚀 Scaling & Updates

### Update Application
```bash
# Pull latest code
cd /opt/secure-notes-app
sudo -u secure-notes-app git pull

# Restart services
restart-secure-notes
```

### Backup Database
```bash
# MongoDB Atlas has automatic backups
# For manual backup, use mongodump with your Atlas connection
```

### Scale Up
- Upgrade EC2 instance type
- Add load balancer for multiple instances
- Use RDS for database if needed

## 💰 Cost Optimization

- **t2.micro**: Free tier eligible (~$0/month)
- **t3.micro**: ~$7.50/month
- **MongoDB Atlas**: Free tier (512MB)
- **Domain**: ~$10-15/year
- **SSL**: Free with Let's Encrypt

**Total monthly cost**: $0-10 (depending on instance type)