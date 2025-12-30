#!/bin/bash
################################################################################
# Deploy Provisioning Route Fix
# Rebuilds and redeploys the dashboard with /activate route
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Deploying Provisioning Route Fix                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_ROOT="/Users/shawnshlee/1_CursorAI/1_aiodcounter04"
DASHBOARD_DIR="${PROJECT_ROOT}/ai-od-counter-multitenant/web-dashboard"
FIREBASE_DIR="${PROJECT_ROOT}/ai-od-counter-multitenant"

cd "${DASHBOARD_DIR}"

echo "[1/4] Checking ActivateCamera component..."
if [ ! -f "src/components/ActivateCamera.jsx" ]; then
    echo "❌ Error: ActivateCamera.jsx not found!"
    echo "   Expected: ${DASHBOARD_DIR}/src/components/ActivateCamera.jsx"
    exit 1
fi
echo "✅ Component found"
echo ""

echo "[2/4] Installing dependencies..."
npm install
echo "✅ Dependencies installed"
echo ""

echo "[3/4] Building React app..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build successful"
echo ""

echo "[4/4] Deploying to Firebase hosting..."
cd "${FIREBASE_DIR}"
firebase deploy --only hosting:superadmin

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ Deployment Complete!                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Test the provisioning route:"
    echo "  https://aiodcounter04-superadmin.web.app/activate?token=TEST_TOKEN"
    echo ""
    echo "Note: Wait 1-2 minutes for deployment to propagate."
else
    echo ""
    echo "❌ Deployment failed!"
    exit 1
fi



