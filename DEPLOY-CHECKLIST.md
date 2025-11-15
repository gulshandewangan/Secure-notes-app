# 🚀 EC2 Deployment Checklist

## Before You Start

### ✅ Prerequisites Checklist
- [ ] EC2 instance running Ubuntu 20.04/22.04
- [ ] Security group allows ports 22, 80, 443
- [ ] SSH key pair for EC2 access
- [ ] MongoDB Atlas cluster created
- [ ] MongoDB connection string ready
- [ ] Domain name (optional, for SSL)

## 📋 Deployment Steps

### 1. Connect to EC2
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2. Upload Application Files
```bash
# Option A: Git clone (recommended)
git clone https://github.com/your-username/secure-notes-app.git
cd secure-notes-app

# Option B: SCP upload
# (Run from your local machine)
scp -i your-key.pem -r . ubuntu@your-ec2-ip:~/secure-notes-app
```

### 3. Set Environment Variables
```bash
# Required
export MONGO_URI="mongodb+srv://username:password@cluster.mongodb.net/secure_notes"

# Optional (for SSL)
export DOMAIN_NAME="yourdomain.com"
```

### 4. Run Deployment Script
```bash
# Make executable
chmod +x deploy-ec2.sh

# Deploy (with environment variables)
sudo -E ./deploy-ec2.sh
```

### 5. Verify Deployment
- [ ] Script completes without errors
- [ ] Application accessible via browser
- [ ] Health check responds: `curl http://your-ip/health`
- [ ] Can register new user
- [ ] Can create and view notes

## 🔧 Post-Deployment

### Management Commands
```bash
restart-secure-notes     # Restart app
secure-notes-logs        # View logs
secure-notes-status      # Check status
```

### Update Application
```bash
cd /opt/secure-notes-app
sudo -u secure-notes-app git pull
restart-secure-notes
```

## 🆘 Troubleshooting

### If Deployment Fails

1. **Check MongoDB Connection**
   ```bash
   echo $MONGO_URI  # Verify it's set
   ```

2. **Check Logs**
   ```bash
   sudo journalctl -u secure-notes -f
   ```

3. **Restart Services**
   ```bash
   sudo systemctl restart secure-notes
   sudo systemctl restart nginx
   ```

### Common Issues
- **Port 80/443 blocked**: Check EC2 security group
- **MongoDB connection**: Verify URI and IP whitelist
- **SSL fails**: Ensure domain points to EC2 IP
- **Permission denied**: Run script with `sudo -E`

## 🎯 Success Indicators

✅ **Deployment Successful When:**
- Script shows "DEPLOYMENT COMPLETED SUCCESSFULLY!"
- Browser shows login page at your IP/domain
- Health check returns JSON response
- Can register, login, and create notes
- SSL certificate active (if domain used)

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section
2. Review application logs
3. Verify all prerequisites are met
4. Ensure environment variables are set correctly

**Your app will be accessible at:**
- HTTP: `http://your-ec2-ip`
- HTTPS: `https://yourdomain.com` (if domain configured)