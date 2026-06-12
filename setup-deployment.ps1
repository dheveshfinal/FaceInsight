# ==============================================================
#  FaceInsight – Deployment Setup Script (Windows)
#  Usage: powershell -ExecutionPolicy Bypass -File setup-deployment.ps1
# ==============================================================

$ErrorActionPreference = "Stop"

Write-Host "🚀 FaceInsight Deployment Setup" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

# ── Check Prerequisites ────────────────────────────────────
Write-Host "📋 Checking prerequisites..." -ForegroundColor Cyan

$checks = @{
    "Git" = "git"
    "Python 3" = "python"
}

foreach ($name in $checks.Keys) {
    $cmd = $checks[$name]
    try {
        $null = & $cmd --version
        Write-Host "✅ $name" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ $name not installed" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# ── Helper function for generating secrets ────────────────
function New-Secret {
    param([int]$Length = 32)
    $bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes($Length)
    return [Convert]::ToBase64String($bytes).Replace("+", "-").Replace("/", "_").Substring(0, $Length)
}

# ── Create Environment Files ───────────────────────────────
Write-Host "📝 Creating environment files..." -ForegroundColor Cyan

# Backend .env
if (-not (Test-Path "backend\.env")) {
    Write-Host "Creating backend\.env from template..."
    Copy-Item "backend\.env.example" "backend\.env"
    
    # Generate random secrets
    $APP_SECRET = New-Secret 32
    $JWT_SECRET = New-Secret 32
    $DB_PASSWORD = New-Secret 24
    
    # Update .env with generated secrets
    $content = Get-Content "backend\.env"
    $content = $content -replace "your-super-secret-key-change-this", $APP_SECRET
    $content = $content -replace "your-jwt-secret-key-change-this", $JWT_SECRET
    $content = $content -replace "your-postgres-password", $DB_PASSWORD
    Set-Content "backend\.env" $content
    
    Write-Host "✅ Created backend\.env" -ForegroundColor Green
}
else {
    Write-Host "⚠️  backend\.env already exists, skipping" -ForegroundColor Yellow
}

# Frontend .env
if (-not (Test-Path "flutter_app\.env")) {
    Write-Host "Creating flutter_app\.env from template..."
    Copy-Item "flutter_app\.env.example" "flutter_app\.env"
    Write-Host "✅ Created flutter_app\.env" -ForegroundColor Green
}
else {
    Write-Host "⚠️  flutter_app\.env already exists, skipping" -ForegroundColor Yellow
}

Write-Host ""

# ── Initialize Git Repository ──────────────────────────────
if (-not (Test-Path ".git")) {
    Write-Host "🔧 Initializing Git repository..." -ForegroundColor Cyan
    & git init
    Write-Host "✅ Git repository initialized" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Git already initialized" -ForegroundColor Yellow
}

Write-Host ""

# ── Setup Git Ignore ───────────────────────────────────────
Write-Host "🔒 Ensuring .gitignore exists..." -ForegroundColor Cyan
if (Test-Path ".gitignore") {
    Write-Host "✅ .gitignore found" -ForegroundColor Green
}
else {
    Write-Host "❌ .gitignore not found" -ForegroundColor Red
}

Write-Host ""

# ── Python Virtual Environment ─────────────────────────────
Write-Host "🐍 Setting up Python virtual environment..." -ForegroundColor Cyan

if (-not (Test-Path "backend\venv")) {
    & python -m venv "backend\venv"
    Write-Host "✅ Virtual environment created" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Virtual environment already exists" -ForegroundColor Yellow
}

# Activate and install dependencies
Write-Host "📦 Installing Python dependencies..." -ForegroundColor Cyan
& "backend\venv\Scripts\Activate.ps1"
& python -m pip install --upgrade pip setuptools wheel
& pip install -r "backend\requirements.txt"
Write-Host "✅ Dependencies installed" -ForegroundColor Green

Write-Host ""

# ── Flutter Dependencies ───────────────────────────────────
try {
    & flutter --version | Out-Null
    Write-Host "📦 Getting Flutter dependencies..." -ForegroundColor Cyan
    Push-Location "flutter_app"
    & flutter pub get
    Pop-Location
    Write-Host "✅ Flutter dependencies installed" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Skipping Flutter setup (not installed)" -ForegroundColor Yellow
}

Write-Host ""

# ── Generate Secrets for Documentation ─────────────────────
Write-Host "🔐 Generating secrets (for reference)..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Add these to Render environment variables:" -ForegroundColor Yellow
Write-Host "---"
Write-Host "APP_SECRET_KEY=$(New-Secret 32)"
Write-Host "JWT_SECRET_KEY=$(New-Secret 32)"
Write-Host "POSTGRES_PASSWORD=$(New-Secret 24)"
Write-Host "---"
Write-Host ""

# ── Final Summary ──────────────────────────────────────────
Write-Host "✨ Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Fill in missing values in backend\.env"
Write-Host "  2. Add GROQ_API_KEY to backend\.env"
Write-Host "  3. Test locally: python -m uvicorn backend.main:app --reload"
Write-Host "  4. Read DEPLOYMENT_CHECKLIST.md for deployment steps"
Write-Host ""
Write-Host "📖 Documentation:" -ForegroundColor Cyan
Write-Host "  - DEPLOYMENT.md - Complete deployment guide"
Write-Host "  - DEPLOYMENT_CHECKLIST.md - Quick checklist"
Write-Host "  - README.md - Project overview"
Write-Host ""
Write-Host "Happy deploying! 🚀" -ForegroundColor Green
