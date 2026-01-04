#!/bin/bash
# deploy-functions.sh
# Deploys only the Firebase functions

set -e

PROJECT_ROOT="/Users/shawnshlee/1_CursorAI/1_aiodcounter04"
FIREBASE_DIR="${PROJECT_ROOT}/ai-od-counter-multitenant/firebase-backend"

cd "${FIREBASE_DIR}"

echo "🚀 Deploying Firebase functions..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo "✅ Functions deployed successfully"
else
    echo "❌ Function deployment failed"
    exit 1
fi



