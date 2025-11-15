# Production Deployment Guide

## ✅ Production Readiness Checklist

### Security ✅
- [x] JWT authentication with secure cookies
- [x] Password hashing (PBKDF2 SHA256)
- [x] HTTP-only cookies
- [x] Security headers (XSS, CSRF, etc.)
- [x] Input validation and sanitization
- [x] Error handling without data leakage
- [x] Logging for security events

### Performance ✅
- [x] Database indexing ready
- [x] Pagination for notes API
- [x] Content length limits
- [x] Gunicorn WSGI server

### Monitoring ✅
- [x] Health check endpoint (`/health`)
- [x] Application logging
- [x] Error tracking

### Configuration ✅
- [x] Environment-based configuration
- [x] Production/development modes
- [x] Secret key validation

## Pre-Deployment Requirements

### 1. Environment Variables (Required)
```bash
SECRET_KEY=your-super-secure-random-key-here
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/secure_notes
FLASK_ENV=production
PORT=5000
```

### 2. MongoDB Setup
- Create MongoDB Atlas cluster
- Set up database user with read/write permissions
- Configure IP whitelist (0.0.0.0/0 for cloud deployment)
- Create indexes for performance:
```javascript
// In MongoDB shell
db.users.createIndex({ "username": 1 }, { unique: true })
db.notes.createIndex({ "user_id": 1, "updated_at": -1 })
```

## Deployment Options

### Option 1: Heroku (Recommended for beginners)

1. **Install Heroku CLI**
2. **Create app**:
   ```bash
   heroku create your-secure-notes-app
   ```

3. **Set environment variables**:
   ```bash
   heroku config:set SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex(32))')
   heroku config:set MONGO_URI=your-mongodb-atlas-uri
   heroku config:set FLASK_ENV=production
   ```

4. **Deploy**:
   ```bash
   git add .
   git commit -m "Production deployment"
   git push heroku main
   ```

5. **Open app**:
   ```bash
   heroku open
   ```

### Option 2: AWS EC2

1. **Launch EC2 instance** (Ubuntu 20.04 LTS)
2. **Install dependencies**:
   ```bash
   sudo apt update
   sudo apt install python3 python3-pip nginx certbot python3-certbot-nginx
   ```

3. **Clone and setup**:
   ```bash
   git clone your-repo
   cd secure-notes-app
   pip3 install -r requirements.txt
   ```

4. **Set environment variables**:
   ```bash
   export SECRET_KEY=your-secret-key
   export MONGO_URI=your-mongodb-uri
   export FLASK_ENV=production
   ```

5. **Run with Gunicorn**:
   ```bash
   gunicorn --bind 0.0.0.0:5000 --workers 4 wsgi:app
   ```

6. **Configure Nginx** (optional):
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       
       location / {
           proxy_pass http://127.0.0.1:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
       
       location /health {
           proxy_pass http://127.0.0.1:5000/health;
           access_log off;
       }
   }
   ```

7. **SSL Certificate**:
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```

### Option 3: Docker (Advanced)

Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "wsgi:app"]
```

Build and run:
```bash
docker build -t secure-notes .
docker run -p 5000:5000 --env-file .env secure-notes
```

## Production Monitoring

### Health Checks
- Endpoint: `GET /health`
- Returns: `{"status": "healthy", "timestamp": "..."}`
- Use for load balancer health checks

### Logging
- Application logs to stdout (captured by platform)
- Security events logged (login attempts, etc.)
- Error tracking included

### Performance Monitoring
- Monitor `/health` endpoint response time
- Database connection monitoring
- Memory and CPU usage

## Security Best Practices

1. **Never commit secrets** to version control
2. **Use strong SECRET_KEY** (32+ random bytes)
3. **Enable HTTPS** in production
4. **Regular security updates** of dependencies
5. **Monitor failed login attempts**
6. **Backup database regularly**

## Scaling Considerations

- **Horizontal scaling**: Multiple app instances behind load balancer
- **Database**: MongoDB Atlas auto-scaling
- **Caching**: Add Redis for session storage if needed
- **CDN**: Serve static assets via CDN

## Troubleshooting

### Common Issues:
1. **MongoDB connection**: Check URI encoding and IP whitelist
2. **Secret key**: Ensure it's set in production
3. **HTTPS cookies**: Secure cookies require HTTPS in production
4. **Memory limits**: Increase if handling large notes

### Debug Commands:
```bash
# Check health
curl https://your-app.com/health

# View logs (Heroku)
heroku logs --tail

# Test database connection
python -c "from app import mongo; print(mongo.db.command('ping'))"
```