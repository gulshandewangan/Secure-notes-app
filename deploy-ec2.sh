#!/bin/bash

# Secure Notes App - EC2 Deployment Script
# This script automatically deploys the application to an EC2 instance
# Run with: bash deploy-ec2.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="secure-notes-app"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="secure-notes"
NGINX_AVAILABLE="/etc/nginx/sites-available/$APP_NAME"
NGINX_ENABLED="/etc/nginx/sites-enabled/$APP_NAME"
DOMAIN_NAME="${DOMAIN_NAME:-localhost}"  # Set DOMAIN_NAME env var or defaults to localhost

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_environment() {
    log_info "Checking environment variables..."
    
    if [[ -z "$SECRET_KEY" ]]; then
        log_warning "SECRET_KEY not set. Generating random key..."
        export SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
        echo "Generated SECRET_KEY: $SECRET_KEY"
    fi
    
    if [[ -z "$MONGO_URI" ]]; then
        log_error "MONGO_URI environment variable is required!"
        echo "Please set it with: export MONGO_URI='your-mongodb-atlas-uri'"
        exit 1
    fi
    
    log_success "Environment variables validated"
}

install_dependencies() {
    log_info "Updating system packages..."
    apt update -y
    
    log_info "Installing system dependencies..."
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        nginx \
        git \
        curl \
        supervisor \
        ufw \
        certbot \
        python3-certbot-nginx
    
    log_success "System dependencies installed"
}

setup_firewall() {
    log_info "Configuring firewall..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (important!)
    ufw allow ssh
    ufw allow 22
    
    # Allow HTTP and HTTPS
    ufw allow 80
    ufw allow 443
    
    # Enable firewall
    ufw --force enable
    
    log_success "Firewall configured"
}

create_app_user() {
    log_info "Creating application user..."
    
    if ! id "$APP_NAME" &>/dev/null; then
        useradd --system --shell /bin/bash --home $APP_DIR --create-home $APP_NAME
        log_success "User $APP_NAME created"
    else
        log_info "User $APP_NAME already exists"
    fi
}

setup_application() {
    log_info "Setting up application directory..."
    
    # Create app directory
    mkdir -p $APP_DIR
    
    # Copy application files
    if [[ -f "app.py" ]]; then
        log_info "Copying application files..."
        cp -r . $APP_DIR/
        
        # Remove deployment script from app directory
        rm -f $APP_DIR/deploy-ec2.sh
    else
        log_error "app.py not found in current directory!"
        exit 1
    fi
    
    # Set ownership
    chown -R $APP_NAME:$APP_NAME $APP_DIR
    
    log_success "Application files copied"
}

setup_python_environment() {
    log_info "Setting up Python virtual environment..."
    
    # Switch to app user and directory
    cd $APP_DIR
    
    # Create virtual environment as app user
    sudo -u $APP_NAME python3 -m venv venv
    
    # Install Python dependencies
    sudo -u $APP_NAME $APP_DIR/venv/bin/pip install --upgrade pip
    sudo -u $APP_NAME $APP_DIR/venv/bin/pip install -r requirements.txt
    
    log_success "Python environment configured"
}

create_environment_file() {
    log_info "Creating environment file..."
    
    cat > $APP_DIR/.env << EOF
SECRET_KEY=$SECRET_KEY
MONGO_URI=$MONGO_URI
FLASK_ENV=production
PORT=5000
EOF
    
    # Secure the environment file
    chown $APP_NAME:$APP_NAME $APP_DIR/.env
    chmod 600 $APP_DIR/.env
    
    log_success "Environment file created"
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Secure Notes App
After=network.target

[Service]
Type=exec
User=$APP_NAME
Group=$APP_NAME
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 4 --timeout 120 wsgi:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    
    log_success "Systemd service created"
}

configure_nginx() {
    log_info "Configuring Nginx..."
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create Nginx configuration
    cat > $NGINX_AVAILABLE << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint (no logging)
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }
    
    # Static files (if any)
    location /static {
        alias $APP_DIR/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Favicon
    location = /favicon.ico {
        access_log off;
        log_not_found off;
        return 204;
    }
}
EOF
    
    # Enable site
    ln -sf $NGINX_AVAILABLE $NGINX_ENABLED
    
    # Test Nginx configuration
    nginx -t
    
    log_success "Nginx configured"
}

setup_ssl() {
    if [[ "$DOMAIN_NAME" != "localhost" ]] && [[ "$DOMAIN_NAME" != *"."* ]]; then
        log_warning "Skipping SSL setup - invalid domain name: $DOMAIN_NAME"
        return
    fi
    
    if [[ "$DOMAIN_NAME" == "localhost" ]]; then
        log_warning "Skipping SSL setup for localhost"
        return
    fi
    
    log_info "Setting up SSL certificate..."
    
    # Get SSL certificate
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME --redirect
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    
    log_success "SSL certificate configured"
}

start_services() {
    log_info "Starting services..."
    
    # Start application
    systemctl start $SERVICE_NAME
    
    # Start Nginx
    systemctl restart nginx
    
    # Enable services to start on boot
    systemctl enable nginx
    
    log_success "Services started"
}

check_deployment() {
    log_info "Checking deployment..."
    
    # Wait a moment for services to start
    sleep 5
    
    # Check if application is running
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Application service is running"
    else
        log_error "Application service failed to start"
        systemctl status $SERVICE_NAME
        exit 1
    fi
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        log_success "Nginx service is running"
    else
        log_error "Nginx service failed to start"
        systemctl status nginx
        exit 1
    fi
    
    # Test health endpoint
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "Health check endpoint is responding"
    else
        log_warning "Health check endpoint not responding (this might be normal during startup)"
    fi
}

create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Create restart script
    cat > /usr/local/bin/restart-secure-notes << 'EOF'
#!/bin/bash
echo "Restarting Secure Notes application..."
systemctl restart secure-notes
systemctl restart nginx
echo "Application restarted successfully"
EOF
    
    # Create logs script
    cat > /usr/local/bin/secure-notes-logs << 'EOF'
#!/bin/bash
echo "=== Application Logs ==="
journalctl -u secure-notes -f
EOF
    
    # Create status script
    cat > /usr/local/bin/secure-notes-status << 'EOF'
#!/bin/bash
echo "=== Service Status ==="
systemctl status secure-notes --no-pager
echo ""
echo "=== Nginx Status ==="
systemctl status nginx --no-pager
echo ""
echo "=== Health Check ==="
curl -s http://localhost/health | python3 -m json.tool 2>/dev/null || echo "Health check failed"
EOF
    
    # Make scripts executable
    chmod +x /usr/local/bin/restart-secure-notes
    chmod +x /usr/local/bin/secure-notes-logs
    chmod +x /usr/local/bin/secure-notes-status
    
    log_success "Management scripts created"
}

print_summary() {
    echo ""
    echo "=========================================="
    log_success "DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo "=========================================="
    echo ""
    echo "🚀 Your Secure Notes app is now running!"
    echo ""
    echo "📍 Access your application:"
    if [[ "$DOMAIN_NAME" == "localhost" ]]; then
        echo "   http://$(curl -s ifconfig.me || echo 'YOUR-EC2-IP')"
    else
        echo "   https://$DOMAIN_NAME"
    fi
    echo ""
    echo "🔧 Management commands:"
    echo "   restart-secure-notes    - Restart the application"
    echo "   secure-notes-logs       - View application logs"
    echo "   secure-notes-status     - Check service status"
    echo ""
    echo "📁 Application directory: $APP_DIR"
    echo "📋 Service name: $SERVICE_NAME"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   sudo systemctl status $SERVICE_NAME"
    echo "   sudo journalctl -u $SERVICE_NAME -f"
    echo "   sudo nginx -t"
    echo ""
    echo "🔐 Security:"
    echo "   - Firewall is enabled (UFW)"
    echo "   - Application runs as non-root user"
    echo "   - Environment variables are secured"
    if [[ "$DOMAIN_NAME" != "localhost" ]]; then
        echo "   - SSL certificate is configured"
    fi
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "🔒 Secure Notes App - EC2 Deployment"
    echo "=========================================="
    echo ""
    
    check_root
    check_environment
    install_dependencies
    setup_firewall
    create_app_user
    setup_application
    setup_python_environment
    create_environment_file
    create_systemd_service
    configure_nginx
    setup_ssl
    start_services
    check_deployment
    create_management_scripts
    print_summary
}

# Run main function
main "$@"