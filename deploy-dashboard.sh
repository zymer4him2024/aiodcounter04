#!/bin/bash
################################################################################
# Deploy Web Dashboard to Firebase Hosting
# Rebuilds and deploys the dashboard with latest changes
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Deploying Web Dashboard to Firebase                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")/ai-od-counter-multitenant/web-dashboard"

echo "[1/3] Installing dependencies (if needed)..."
npm install
echo ""

echo "[2/3] Building production bundle..."
npm run build
echo ""

echo "[3/3] Deploying to Firebase Hosting..."
cd ..
firebase deploy --only hosting
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Deployment Complete!                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Dashboard URLs:"
echo "  Superadmin: https://aiodcounter04-superadmin.web.app"
echo "  Subadmin:   https://aiodcounter04.web.app"
echo ""

