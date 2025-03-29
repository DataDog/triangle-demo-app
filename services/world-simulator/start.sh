#!/bin/sh

echo "🚀 Starting container..."

# Start Nginx in the background
nginx -g 'daemon off;' &

# Wait briefly for Nginx to start
sleep 2

# Confirm Nginx is running
if ! pgrep nginx > /dev/null; then
    echo "❌ Nginx failed to start"
    exit 1
fi

# Verify VITE_BASE_TOWER_URL is present in the built JS bundle
echo "🔍 Verifying VITE_BASE_TOWER_URL in frontend bundle..."
if ! grep -q "VITE_BASE_TOWER_URL" /usr/share/nginx/html/assets/*.js; then
    echo "❌ ERROR: VITE_BASE_TOWER_URL not found in the built frontend assets"
    echo "💡 Make sure --build-arg VITE_BASE_TOWER_URL=... is passed during docker build"
    exit 1
fi
echo "✅ VITE_BASE_TOWER_URL found in built assets"

# Check if the app is responding
echo "🔎 Checking application health on http://localhost:80/"
if ! curl -f http://localhost:80/ > /dev/null; then
    echo "❌ Application is not responding"
    exit 1
fi
echo "✅ Application is up and responding"

# Tail logs to keep container running
echo "📜 Tailing Nginx access logs..."
tail -F /var/log/nginx/access.log
