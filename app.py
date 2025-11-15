from flask import Flask, request, jsonify, render_template, redirect, url_for, make_response
from flask_pymongo import PyMongo
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from datetime import datetime, timedelta
from functools import wraps
import os
import logging
from bson.objectid import ObjectId
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging for production
if os.environ.get('FLASK_ENV') == 'production':
    logging.basicConfig(level=logging.INFO)
else:
    logging.basicConfig(level=logging.DEBUG)

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY')
if not app.config['SECRET_KEY']:
    if os.environ.get('FLASK_ENV') == 'production':
        raise ValueError("SECRET_KEY environment variable is required in production")
    app.config['SECRET_KEY'] = 'dev-key-only'

app.config['MONGO_URI'] = os.environ.get('MONGO_URI', 'mongodb://localhost:27017/secure_notes')
app.config['JWT_EXPIRATION_DELTA'] = timedelta(hours=24)

# Security headers
@app.after_request
def after_request(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    if os.environ.get('FLASK_ENV') == 'production':
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    return response

# Initialize MongoDB
mongo = PyMongo(app)

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.cookies.get('token')
        
        if not token:
            return redirect(url_for('login'))
        
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user_id = data['user_id']
        except jwt.ExpiredSignatureError:
            return redirect(url_for('login'))
        except jwt.InvalidTokenError:
            return redirect(url_for('login'))
        
        return f(current_user_id, *args, **kwargs)
    
    return decorated

@app.route('/health')
def health_check():
    """Health check endpoint for load balancers"""
    try:
        # Test database connection
        mongo.db.command('ping')
        return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}), 200
    except Exception as e:
        app.logger.error(f'Health check failed: {str(e)}')
        return jsonify({'status': 'unhealthy', 'error': 'Database connection failed'}), 503

@app.route('/')
def index():
    token = request.cookies.get('token')
    if token:
        try:
            jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            return redirect(url_for('dashboard'))
        except:
            pass
    return redirect(url_for('login'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        try:
            data = request.get_json() if request.is_json else request.form
            username = data.get('username', '').strip()
            password = data.get('password', '')
            
            # Input validation
            if not username or not password:
                return jsonify({'error': 'Username and password required'}), 400
            
            if len(username) < 3 or len(username) > 50:
                return jsonify({'error': 'Username must be 3-50 characters'}), 400
            
            if len(password) < 6:
                return jsonify({'error': 'Password must be at least 6 characters'}), 400
            
            # Check if user exists
            if mongo.db.users.find_one({'username': username}):
                return jsonify({'error': 'Username already exists'}), 400
            
            # Create user
            hashed_password = generate_password_hash(password)
            user_id = mongo.db.users.insert_one({
                'username': username,
                'password': hashed_password,
                'created_at': datetime.utcnow()
            }).inserted_id
            
            app.logger.info(f'New user registered: {username}')
            return jsonify({'message': 'User created successfully'}), 201
            
        except Exception as e:
            app.logger.error(f'Registration error: {str(e)}')
            return jsonify({'error': 'Registration failed'}), 500
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        try:
            data = request.get_json() if request.is_json else request.form
            username = data.get('username', '').strip()
            password = data.get('password', '')
            
            if not username or not password:
                return jsonify({'error': 'Username and password required'}), 400
            
            user = mongo.db.users.find_one({'username': username})
            
            if user and check_password_hash(user['password'], password):
                # Generate JWT token
                token = jwt.encode({
                    'user_id': str(user['_id']),
                    'exp': datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA']
                }, app.config['SECRET_KEY'], algorithm='HS256')
                
                response = make_response(jsonify({'message': 'Login successful'}))
                response.set_cookie('token', token, 
                                  httponly=True, 
                                  secure=True if os.environ.get('FLASK_ENV') == 'production' else False,
                                  samesite='Lax',
                                  max_age=86400)  # 24 hours
                
                app.logger.info(f'User logged in: {username}')
                return response
            
            app.logger.warning(f'Failed login attempt for: {username}')
            return jsonify({'error': 'Invalid credentials'}), 401
            
        except Exception as e:
            app.logger.error(f'Login error: {str(e)}')
            return jsonify({'error': 'Login failed'}), 500
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    response = make_response(redirect(url_for('login')))
    response.set_cookie('token', '', expires=0)
    return response

@app.route('/dashboard')
@token_required
def dashboard(current_user_id):
    return render_template('dashboard.html')

@app.route('/api/notes', methods=['GET', 'POST'])
@token_required
def notes(current_user_id):
    try:
        if request.method == 'POST':
            data = request.get_json()
            if not data:
                return jsonify({'error': 'Invalid JSON data'}), 400
                
            title = data.get('title', '').strip()
            content = data.get('content', '').strip()
            
            # Input validation
            if not content:
                return jsonify({'error': 'Content is required'}), 400
            
            if len(content) > 10000:  # 10KB limit
                return jsonify({'error': 'Content too long (max 10,000 characters)'}), 400
            
            if len(title) > 200:
                return jsonify({'error': 'Title too long (max 200 characters)'}), 400
            
            note_id = mongo.db.notes.insert_one({
                'user_id': ObjectId(current_user_id),
                'title': title,
                'content': content,
                'created_at': datetime.utcnow(),
                'updated_at': datetime.utcnow()
            }).inserted_id
            
            return jsonify({'message': 'Note created', 'note_id': str(note_id)}), 201
        
        # GET notes with pagination
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)  # Max 100 per page
        
        notes = list(mongo.db.notes.find(
            {'user_id': ObjectId(current_user_id)},
            {'_id': 1, 'title': 1, 'content': 1, 'created_at': 1, 'updated_at': 1}
        ).sort('updated_at', -1).skip((page - 1) * per_page).limit(per_page))
        
        # Convert ObjectId to string
        for note in notes:
            note['_id'] = str(note['_id'])
        
        return jsonify(notes)
        
    except Exception as e:
        app.logger.error(f'Notes API error: {str(e)}')
        return jsonify({'error': 'Operation failed'}), 500

@app.route('/api/notes/<note_id>', methods=['PUT', 'DELETE'])
@token_required
def note_detail(current_user_id, note_id):
    try:
        note_obj_id = ObjectId(note_id)
    except:
        return jsonify({'error': 'Invalid note ID'}), 400
    
    note = mongo.db.notes.find_one({
        '_id': note_obj_id,
        'user_id': ObjectId(current_user_id)
    })
    
    if not note:
        return jsonify({'error': 'Note not found'}), 404
    
    if request.method == 'PUT':
        data = request.get_json()
        update_data = {
            'updated_at': datetime.utcnow()
        }
        
        if 'title' in data:
            update_data['title'] = data['title']
        if 'content' in data:
            update_data['content'] = data['content']
        
        mongo.db.notes.update_one(
            {'_id': note_obj_id},
            {'$set': update_data}
        )
        
        return jsonify({'message': 'Note updated'})
    
    if request.method == 'DELETE':
        mongo.db.notes.delete_one({'_id': note_obj_id})
        return jsonify({'message': 'Note deleted'})

if __name__ == '__main__':
    app.run(debug=os.environ.get('FLASK_ENV') != 'production', 
            host='0.0.0.0', 
            port=int(os.environ.get('PORT', 5000)))