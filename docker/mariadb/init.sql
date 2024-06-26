CREATE USER IF NOT EXISTS 'your-user'@'%' IDENTIFIED BY 'your-user';
GRANT ALL PRIVILEGES ON your-db.* TO 'your-user'@'%';
FLUSH PRIVILEGES;