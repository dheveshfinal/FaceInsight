#!/bin/bash

# ==============================================================
#  FaceInsight – Deployment Setup Script
#  Usage: bash setup-deployment.sh
# ==============================================================

set -e  # Exit on error

echo "🚀 FaceInsight Deployment Setup"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ── Check Prerequisites ────────────────────────────────────
echo "📋 Checking prerequisites..."

if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Git${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python 3${NC}"

if ! command -v flutter &> /dev/null; then
    echo -e "${YELLOW}⚠️  Flutter not found (needed for building web)${NC}"
else
    echo -e "${GREEN}✅ Flutter${NC}"
fi

echo ""

# ── Create Environment Files ───────────────────────────────
echo "📝 Creating environment files..."

# Backend .env
if [ ! -f backend/.env ]; then
    echo "Creating backend/.env from template..."
    cp backend/.env.example backend/.env
    
    # Generate random secrets
    APP_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
    
    # Update .env with generated secrets (macOS and Linux compatible)
    sed -i.bak "s/your-super-secret-key-change-this/$APP_SECRET/" backend/.env
    sed -i.bak "s/your-jwt-secret-key-change-this/$JWT_SECRET/" backend/.env
    sed -i.bak "s/your-postgres-password/$DB_PASSWORD/" backend/.env
    rm -f backend/.env.bak
    
    echo -e "${GREEN}✅ Created backend/.env${NC}"
else
    echo -e "${YELLOW}⚠️  backend/.env already exists, skipping${NC}"
fi

# Frontend .env
if [ ! -f flutter_app/.env ]; then
    echo "Creating flutter_app/.env from template..."
    cp flutter_app/.env.example flutter_app/.env
    echo -e "${GREEN}✅ Created flutter_app/.env${NC}"
else
    echo -e "${YELLOW}⚠️  flutter_app/.env already exists, skipping${NC}"
fi

echo ""

# ── Initialize Git Repository ──────────────────────────────
if [ ! -d .git ]; then
    echo "🔧 Initializing Git repository..."
    git init
    echo -e "${GREEN}✅ Git repository initialized${NC}"
else
    echo -e "${YELLOW}⚠️  Git already initialized${NC}"
fi

echo ""

# ── Setup Git Ignore ───────────────────────────────────────
echo "🔒 Ensuring .gitignore exists..."
if [ -f .gitignore ]; then
    echo -e "${GREEN}✅ .gitignore found${NC}"
else
    echo -e "${RED}❌ .gitignore not found${NC}"
fi

echo ""

# ── Python Virtual Environment ─────────────────────────────
echo "🐍 Setting up Python virtual environment..."

if [ ! -d "backend/venv" ]; then
    python3 -m venv backend/venv
    echo -e "${GREEN}✅ Virtual environment created${NC}"
else
    echo -e "${YELLOW}⚠️  Virtual environment already exists${NC}"
fi

# Activate and install dependencies
echo "📦 Installing Python dependencies..."
source backend/venv/bin/activate || true
pip install --upgrade pip setuptools wheel
pip install -r backend/requirements.txt
echo -e "${GREEN}✅ Dependencies installed${NC}"

echo ""

# ── Flutter Dependencies ───────────────────────────────────
if command -v flutter &> /dev/null; then
    echo "📦 Getting Flutter dependencies..."
    cd flutter_app
    flutter pub get
    cd ..
    echo -e "${GREEN}✅ Flutter dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping Flutter setup (not installed)${NC}"
fi

echo ""

# ── Generate Secrets for Documentation ─────────────────────
echo "🔐 Generating secrets (for reference)..."
echo ""
echo "Add these to Render environment variables:"
echo "---"
echo "APP_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
echo "JWT_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
echo "POSTGRES_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
echo "---"
echo ""

# ── Final Summary ──────────────────────────────────────────
echo "✨ Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "  1. Fill in missing values in backend/.env"
echo "  2. Add GROQ_API_KEY to backend/.env"
echo "  3. Test locally: python -m uvicorn backend.main:app --reload"
echo "  4. Read DEPLOYMENT_CHECKLIST.md for deployment steps"
echo ""
echo "📖 Documentation:"
echo "  - DEPLOYMENT.md - Complete deployment guide"
echo "  - DEPLOYMENT_CHECKLIST.md - Quick checklist"
echo "  - README.md - Project overview"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"
