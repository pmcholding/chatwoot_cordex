# Task Completion Workflow

## When a Development Task is Completed

### 1. Code Quality Checks
```bash
# Run linting and auto-fix
pnpm eslint:fix
bundle exec rubocop -a
```

### 2. Testing
```bash
# Run relevant tests
pnpm test                  # For JavaScript changes
bundle exec rspec spec/    # For Ruby changes
```

### 3. Verification
- Check that development server still runs: `overmind start -f ./Procfile.dev`
- Manually test the implemented feature
- Verify no existing functionality is broken

### 4. Git Operations
```bash
git status                 # Check what changed
git add .                 # Stage changes
git commit -m "descriptive message"  # Commit with clear message
```

### 5. Documentation
- Update relevant documentation if needed
- Add comments for complex logic
- Update i18n files if UI text was added

## Code Review Checklist
- [ ] Follows Tailwind-only styling
- [ ] Uses Composition API for Vue components
- [ ] No bare strings in templates (uses i18n)
- [ ] Proper error handling with custom exceptions
- [ ] Database indexes added for new queries
- [ ] No defensive programming unless necessary
- [ ] Follows naming conventions (PascalCase for components, camelCase for events)
- [ ] Removes any dead/unused code

## Integration Testing
- Test across different browsers
- Verify mobile responsiveness
- Check WebSocket connectivity (if applicable)
- Validate API endpoints work correctly