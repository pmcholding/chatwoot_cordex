# Chatwoot Code Style & Conventions

## Ruby/Rails Conventions
- **Style Guide**: Follow RuboCop rules strictly
- **Line Length**: 150 characters maximum
- **Class/Module Structure**: Use compact definitions, avoid nested styles
- **Error Handling**: Use custom exceptions from `lib/custom_exceptions/`
- **Models**: Always validate presence/uniqueness, add proper database indexes
- **Strong Parameters**: Use strong params in controllers for type safety
- **Naming**: Clear, descriptive names with consistent Ruby casing (snake_case)

## Vue.js/JavaScript Conventions
- **API Style**: Always use Composition API with `<script setup>` at the top
- **Linting**: ESLint with Airbnb base + Vue 3 recommended rules
- **Component Naming**: Use PascalCase for Vue components
- **Event Naming**: Use camelCase for events
- **Type Safety**: Use PropTypes in Vue components
- **File Structure**: Follow modular architecture pattern

## Styling Conventions
- **CSS Framework**: Tailwind CSS ONLY
- **Prohibited**: 
  - Custom CSS files
  - Scoped CSS
  - Inline styles
- **Colors**: Refer to `tailwind.config.js` for color definitions
- **Component System**: Use `components-next/` for new components

## Internationalization (i18n)
- **Templates**: No bare strings allowed, always use i18n
- **Translation Files**: 
  - Backend: Update only `en.yml`
  - Frontend: Update only `en.json`
- **Community**: Other languages handled by community translation

## General Guidelines
- **MVP Focus**: Least code change, happy-path only implementation
- **No Defensive Programming**: Avoid unnecessary defensive coding
- **Testing**: Only write specs when explicitly requested
- **Code Cleanup**: Remove dead/unreachable/unused code
- **Commit Messages**: Don't reference Claude or AI tools in commits