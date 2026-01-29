#!/bin/bash

# YouTube Video Chat App - Project Cleanup Script
# This script organizes the project without changing functionality

set -e  # Exit on error

echo "🧹 Starting Project Cleanup..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Create new directory structure
echo -e "${BLUE}📁 Creating new directory structure...${NC}"
mkdir -p docs/{setup,features,development}
mkdir -p scripts/{setup,docker,development,windows,maintenance,tests}
mkdir -p test/fixtures/html

# Move documentation files
echo -e "${BLUE}📚 Organizing documentation...${NC}"

# Main documentation
[ -f "README.md" ] && mv README.md docs/README.original.md
[ -f "START_HERE.md" ] && mv START_HERE.md docs/GETTING_STARTED.md

# Setup docs
[ -f "DOCKER_GUIDE.md" ] && mv DOCKER_GUIDE.md docs/setup/docker.md
[ -f "DOCKER_SOUNDCLOUD_GUIDE.md" ] && mv DOCKER_SOUNDCLOUD_GUIDE.md docs/setup/docker-soundcloud.md
[ -f "WINDOWS_DOCKER_GUIDE.md" ] && mv WINDOWS_DOCKER_GUIDE.md docs/setup/windows-docker.md
[ -f "READY_TO_RUN.md" ] && mv READY_TO_RUN.md docs/setup/quick-start.md
[ -f "RED_BUTTON_GUIDE.md" ] && mv RED_BUTTON_GUIDE.md docs/setup/emergency-fixes.md

# Feature docs
[ -f "QUEUE_SYSTEM_DOCS.md" ] && mv QUEUE_SYSTEM_DOCS.md docs/features/queue-system.md
[ -f "ENHANCED_QUEUE_SYSTEM.md" ] && mv ENHANCED_QUEUE_SYSTEM.md docs/features/queue-system-enhanced.md
[ -f "SOUNDCLOUD_INTEGRATION.md" ] && mv SOUNDCLOUD_INTEGRATION.md docs/features/soundcloud.md
[ -f "SOUNDCLOUD_TESTING.md" ] && mv SOUNDCLOUD_TESTING.md docs/features/soundcloud-testing.md
[ -f "TEST_URLS.md" ] && mv TEST_URLS.md docs/features/test-urls.md

# Development/Fix history
mv *FIX*.md docs/development/ 2>/dev/null || true
mv *SOLUTION*.md docs/development/ 2>/dev/null || true
mv YOUTUBE_*.md docs/development/ 2>/dev/null || true
mv SOUNDCLOUD_*.md docs/development/ 2>/dev/null || true
mv AUTOMATIC_*.md docs/development/ 2>/dev/null || true
mv AUTO_*.md docs/development/ 2>/dev/null || true
mv COMPLETE_*.md docs/development/ 2>/dev/null || true
mv QUEUE_FIX*.md docs/development/ 2>/dev/null || true
mv ELIXIR_*.md docs/development/ 2>/dev/null || true
mv CLAUDE.md docs/development/ 2>/dev/null || true
mv test_queue_system.md docs/development/ 2>/dev/null || true

# Move shell scripts
echo -e "${BLUE}🔧 Organizing shell scripts...${NC}"

# Setup scripts
[ -f "setup_asdf.sh" ] && mv setup_asdf.sh scripts/setup/
[ -f "install_asdf_elixir.sh" ] && mv install_asdf_elixir.sh scripts/setup/
[ -f "install_and_run_docker.sh" ] && mv install_and_run_docker.sh scripts/setup/
[ -f "downgrade_elixir.sh" ] && mv downgrade_elixir.sh scripts/setup/
mv phoenix_*.sh scripts/setup/ 2>/dev/null || true
mv use_phoenix_*.sh scripts/setup/ 2>/dev/null || true

# Docker scripts
mv docker*.sh scripts/docker/ 2>/dev/null || true

# Development scripts
[ -f "start.sh" ] && mv start.sh scripts/development/
[ -f "quick.sh" ] && mv quick.sh scripts/development/
[ -f "quick_restart.sh" ] && mv quick_restart.sh scripts/development/
[ -f "quick_test.sh" ] && mv quick_test.sh scripts/development/

# Fix scripts
mv fix*.sh scripts/maintenance/ 2>/dev/null || true
mv *fix*.sh scripts/maintenance/ 2>/dev/null || true
[ -f "nuclear_option.sh" ] && mv nuclear_option.sh scripts/maintenance/
[ -f "rebuild_all.sh" ] && mv rebuild_all.sh scripts/maintenance/
[ -f "ultimate_fix.sh" ] && mv ultimate_fix.sh scripts/maintenance/
[ -f "smart_fix.sh" ] && mv smart_fix.sh scripts/maintenance/

# Test scripts
mv test_*.sh scripts/tests/ 2>/dev/null || true
mv diagnose*.sh scripts/tests/ 2>/dev/null || true
mv debug*.sh scripts/tests/ 2>/dev/null || true
mv check*.sh scripts/tests/ 2>/dev/null || true
[ -f "test_soundcloud.exs" ] && mv test_soundcloud.exs scripts/tests/

# Move Windows scripts
echo -e "${BLUE}🪟 Organizing Windows scripts...${NC}"
mkdir -p scripts/windows/{setup,fixes,docker}

mv *.bat scripts/windows/fixes/ 2>/dev/null || true
mv *.ps1 scripts/windows/fixes/ 2>/dev/null || true
[ -f "scripts/windows/fixes/quick-start-windows.bat" ] && mv scripts/windows/fixes/quick-start-windows.bat scripts/windows/setup/ 2>/dev/null || true
[ -f "scripts/windows/fixes/start-windows.bat" ] && mv scripts/windows/fixes/start-windows.bat scripts/windows/setup/ 2>/dev/null || true
[ -f "scripts/windows/fixes/start-docker-windows.ps1" ] && mv scripts/windows/fixes/start-docker-windows.ps1 scripts/windows/docker/ 2>/dev/null || true
[ -f "scripts/windows/fixes/troubleshoot-windows.ps1" ] && mv scripts/windows/fixes/troubleshoot-windows.ps1 scripts/windows/setup/ 2>/dev/null || true

# Move test HTML files
echo -e "${BLUE}🧪 Organizing test files...${NC}"
mv test-*.html test/fixtures/html/ 2>/dev/null || true

# Remove backup files
echo -e "${BLUE}🗑️  Removing backup files...${NC}"
find . -name "*.backup*" -type f -delete
find . -name "*.working" -type f -delete

# Remove .DS_Store files
echo -e "${BLUE}🍎 Removing macOS files...${NC}"
find . -name ".DS_Store" -type f -delete

# Remove _build if it exists (should be gitignored)
if [ -d "_build" ]; then
    echo -e "${BLUE}🏗️  Removing _build directory...${NC}"
    rm -rf _build
fi

# Update .gitignore
echo -e "${BLUE}📝 Updating .gitignore...${NC}"
cat >> .gitignore << 'EOF'

# Backup files
*.backup
*.backup_*
*.working
*.bak

# Test artifacts
test/fixtures/html/*.html

# Script logs
scripts/**/*.log
EOF

# Create a new README.md
echo -e "${BLUE}📖 Creating new README.md...${NC}"
cat > README.md << 'EOF'
# YouTube Video Chat App

A real-time video synchronization and chat application built with Phoenix LiveView.

## Features

- 🎥 YouTube video synchronization across multiple users
- 🎵 SoundCloud track synchronization
- 💬 Real-time chat
- 📋 Queue management system
- 👥 Presence tracking
- 🔄 Automatic video advancement

## Quick Start

### Prerequisites

- Elixir 1.17+ and OTP 27+
- PostgreSQL
- Node.js (for assets)

### Development Setup

```bash
# Install dependencies
mix deps.get
cd assets && npm install && cd ..

# Setup database
mix ecto.setup

# Start the server
mix phx.server
```

Visit `http://localhost:4000`

### Docker Setup

```bash
# Build and start
docker-compose up --build
```

## Documentation

- [Getting Started](docs/GETTING_STARTED.md)
- [Docker Setup](docs/setup/docker.md)
- [Queue System](docs/features/queue-system.md)
- [Development Guides](docs/development/)

## Project Structure

```
├── lib/                    # Application code
│   ├── youtube_video_chat_app/      # Business logic
│   └── youtube_video_chat_app_web/  # Web interface
├── assets/                 # Frontend assets
│   ├── js/                # JavaScript
│   └── css/               # Stylesheets
├── priv/                  # Static files and migrations
├── test/                  # Tests
├── scripts/               # Utility scripts
└── docs/                  # Documentation
```

## License

[Your License Here]
EOF

# Create script index
echo -e "${BLUE}📋 Creating script index...${NC}"
cat > scripts/README.md << 'EOF'
# Scripts Directory

## Setup Scripts (`setup/`)
- Initial project setup
- Dependency installation
- Environment configuration

## Docker Scripts (`docker/`)
- Container management
- Docker deployment
- Service orchestration

## Development Scripts (`development/`)
- Start development server
- Quick restart
- Development utilities

## Maintenance Scripts (`maintenance/`)
- Bug fixes
- Database migrations
- Cleanup utilities

## Test Scripts (`tests/`)
- Test runners
- Debug utilities
- Diagnostics

## Windows Scripts (`windows/`)
- Windows-specific setup
- PowerShell utilities
- Batch file helpers
EOF

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "  - Documentation organized in docs/"
echo "  - Scripts organized in scripts/"
echo "  - Test files organized in test/fixtures/html/"
echo "  - Backup files removed"
echo "  - .DS_Store files removed"
echo "  - .gitignore updated"
echo "  - New README.md created"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "  1. Review the changes: git status"
echo "  2. Test the application: mix phx.server"
echo "  3. Update any scripts that reference old paths"
echo "  4. Commit the cleaned structure: git add . && git commit -m 'Clean up project structure'"
echo ""
echo -e "${GREEN}🎉 Your project is now organized!${NC}"
