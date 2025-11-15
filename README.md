# Secure Notes App

A simple, production-ready secure notes application built with Flask, JWT authentication, and MongoDB.

## Features

- 🔐 Secure user authentication with JWT tokens
- 🍪 HTTP-only secure cookies for session management
- 📝 Create, read, update, and delete notes
- 🛡️ Password hashing with Werkzeug
- 📱 Responsive Bootstrap UI
- ☁️ MongoDB Atlas ready
- 🚀 Heroku/AWS deployment ready

## Tech Stack

- **Backend**: Python Flask
- **Database**: MongoDB (Atlas compatible)
- **Authentication**: JWT with secure cookies
- **Frontend**: Bootstrap 5 + Vanilla JavaScript
- **Deployment**: Heroku/AWS ready with Gunicorn

## Quick Start

### Local Development

1. **Clone and setup**:
   ```bash
   git clone <your-repo>
   cd secure-notes-app
   pip install -r requirements.txt
   ```

2. **Environment setup**:
   ```bash
   cp .env.example .env
   # Edit .env with your MongoDB URI and secret key
   ```

3. **Run the app**:
   ```bash
   python app.py
   ```

4. **Visit**: http://localhost:5000

### MongoDB Setup

1. **MongoDB Atlas** (Recommended):
   - Create account at [MongoDB Atlas](https://www.mongodb.com/atlas)
   - Create cluster and get connection string
   - Add to `.env` as `MONGO_URI`

2. **Local MongoDB**:
   ```bash
   # Install MongoDB locally
   # Default URI: mongodb://localhost:27017/secure_notes
   ```

## Deployment

### Heroku Deployment

1. **Install Heroku CLI** and login:
   ```bash
   heroku login
   ```

2. **Create Heroku app**:
   ```bash
   heroku create your-app-name
   ```

3. **Set environment variables**:
   ```bash
   heroku config:set SECRET_KEY=your-super-secret-key
   heroku config:set MONGO_URI=your-mongodb-atlas-uri
   heroku config:set FLASK_ENV=production
   ```

4. **Deploy**:
   ```bash
   git add .
   git commit -m "Initial commit"
   git push heroku main
   ```

### AWS Deployment (EC2)

1. **Launch EC2 instance** (Ubuntu 20.04+)

2. **Install dependencies**:
   ```bash
   sudo apt update
   sudo apt install python3 python3-pip nginx
   pip3 install -r requirements.txt
   ```

3. **Set environment variables**:
   ```bash
   export SECRET_KEY=your-super-secret-key
   export MONGO_URI=your-mongodb-atlas-uri
   export FLASK_ENV=production
   ```

4. **Run with Gunicorn**:
   ```bash
   gunicorn --bind 0.0.0.0:5000 app:app
   ```

5. **Configure Nginx** (optional for production):
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       
       location / {
           proxy_pass http://127.0.0.1:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

## Security Features

- **Password Hashing**: Werkzeug PBKDF2 SHA256
- **JWT Tokens**: Secure token-based authentication
- **HTTP-only Cookies**: Prevents XSS attacks
- **Secure Cookies**: HTTPS-only in production
- **SameSite Protection**: CSRF protection
- **Input Validation**: Server-side validation
- **MongoDB Injection Protection**: PyMongo handles escaping

## API Endpoints

- `POST /register` - User registration
- `POST /login` - User login
- `GET /logout` - User logout
- `GET /dashboard` - Notes dashboard
- `GET /api/notes` - Get user notes
- `POST /api/notes` - Create note
- `PUT /api/notes/<id>` - Update note
- `DELETE /api/notes/<id>` - Delete note

## Environment Variables

```bash
SECRET_KEY=your-super-secret-key-here
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/secure_notes
FLASK_ENV=production  # or development
PORT=5000
```

## Project Structure

```
secure-notes-app/
├── app.py              # Main Flask application
├── requirements.txt    # Python dependencies
├── Procfile           # Heroku deployment
├── runtime.txt        # Python version
├── .env.example       # Environment template
├── templates/         # HTML templates
│   ├── base.html
│   ├── login.html
│   ├── register.html
│   └── dashboard.html
└── README.md
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## License

MIT License - feel free to use for personal or commercial projects.