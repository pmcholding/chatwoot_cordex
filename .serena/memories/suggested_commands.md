# Chatwoot Development Commands

## Project Setup
```bash
# Initial setup
bundle install && pnpm install

# Install missing dependencies
bundle install  # Ruby gems
pnpm install    # JavaScript packages
```

## Development Server
```bash
# Start development server (recommended)
overmind start -f ./Procfile.dev

# Alternative development server
pnpm dev

# Start with foreman
foreman start -f ./Procfile.dev
```

## Linting & Formatting
```bash
# JavaScript/Vue linting
pnpm eslint                 # Check for issues
pnpm eslint:fix            # Auto-fix issues

# Ruby linting
bundle exec rubocop -a     # Auto-fix Ruby issues
```

## Testing
```bash
# JavaScript tests
pnpm test                  # Run all tests
pnpm test:watch           # Watch mode
pnpm test:coverage        # With coverage

# Ruby tests
bundle exec rspec spec/path/to/file_spec.rb           # Run specific file
bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER  # Run specific test
bundle exec rspec         # Run all Ruby tests
```

## Build & Production
```bash
# Build for production
pnpm build

# SDK build
pnpm build:sdk
```

## Utility Commands
```bash
# Git operations
git status
git add .
git commit -m "message"
git push

# File operations (Linux)
ls -la                     # List files with details
find . -name "*.rb"        # Find Ruby files
grep -r "search_term" .    # Search in files
cd /path/to/directory      # Change directory

# Process management
ps aux | grep rails        # Find Rails processes
pkill -f rails            # Kill Rails processes
```

## Task Completion Checklist
After completing any task:
1. Run linting: `pnpm eslint:fix && bundle exec rubocop -a`
2. Run relevant tests
3. Check git status and commit changes
4. Verify development server still works